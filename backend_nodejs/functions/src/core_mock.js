/**
 * =====================================================================
 * MOCK API: simulación del "Sistema de Nortfarma" (Java SE 6 + MySQL).
 * NO es parte de la app: representa la API de la empresa. Lee y escribe en su
 * propia base de datos (nortfarma_core), con su propio usuario de MySQL.
 * En producción se reemplaza por la API real cambiando CORE_API_URL.
 *
 * Datos que la app copia una vez al día (sincronización):
 *   GET  /productos                  productos (sin precio ni stock)
 *   GET  /boticas                    boticas con horario y ubicación
 * Datos en tiempo real:
 *   POST /stock                      { referencias, boticas? } precio, descuento y stock
 *   GET  /descuentos                 productos con descuento vigente hoy
 * Datos que la app envía a Nortfarma (la venta y su pago):
 *   POST /ventas                     registra la venta, descuenta stock y asigna el comprobante (V0001)
 *   POST /ventas/:id/pago            { pasarela, id_transaccion } marca la venta como pagada
 *   POST /ventas/:id/anular          anula la venta y devuelve el stock
 * =====================================================================
 */
const { onRequest } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const mysql = require("mysql2/promise");

const TIPOS = ["EMPAQUE", "BLISTER", "FRACCION"];
const COLUMNA_STOCK = { EMPAQUE: "stock_empaque", BLISTER: "stock_blister", FRACCION: "stock_fraccion" };
// Comprobante de venta: V + correlativo de 4 dígitos (V0001, V0002...), indicado por Nortfarma.
const SERIE = "V";

let pool;
function bd() {
  if (!pool) {
    pool = mysql.createPool({
      host: process.env.CORE_DB_HOST || process.env.DB_HOST,
      port: Number(process.env.CORE_DB_PORT || process.env.DB_PORT || 3306),
      user: process.env.CORE_DB_USER,
      password: process.env.CORE_DB_PASSWORD,
      database: process.env.CORE_DB_NAME || "nortfarma_core",
      connectionLimit: 5,
      charset: "utf8mb4",
      timezone: "-05:00",
      decimalNumbers: true,
      dateStrings: true,
    });
  }
  return pool;
}

/** Error con código HTTP y datos para la respuesta. */
class ErrorCore extends Error {
  constructor(status, mensaje, extra = {}) {
    super(mensaje);
    this.status = status;
    this.extra = extra;
  }
}

/** Precio con descuento, redondeado al céntimo (la app usa la misma fórmula). */
function precioFinal(precio, descuento) {
  return Math.round(precio * (100 - descuento)) / 100;
}

function lista(valor) {
  return Array.isArray(valor) ? valor.filter((v) => typeof v === "string" && v.length <= 20) : [];
}

// ---------------------------------------------------------------------

async function productos() {
  const [filas] = await bd().query(
    `SELECT referencia, nombre, categoria, empaque, unidades_empaque, se_vende_blister, unidades_blister,
            se_vende_fraccion, receta_medica, especificaciones
       FROM producto ORDER BY referencia`,
  );
  return {
    productos: filas.map((f) => ({
      ...f,
      se_vende_blister: Boolean(f.se_vende_blister),
      se_vende_fraccion: Boolean(f.se_vende_fraccion),
    })),
  };
}

async function boticas() {
  const [filas] = await bd().query(
    `SELECT botica_id, nombre, direccion, departamento, zona, hora_apertura_semana, hora_cierre_semana,
            hora_apertura_domingo, hora_cierre_domingo, latitud, longitud
       FROM botica ORDER BY botica_id`,
  );
  return { boticas: filas };
}

/**
 * Precio vigente, descuento vigente y stock de cada presentación.
 * Si se indican boticas, el stock es solo de esas (y se detalla por botica).
 */
async function stock(cuerpo) {
  const referencias = lista(cuerpo?.referencias);
  const soloBoticas = lista(cuerpo?.boticas);
  if (referencias.length === 0) return { productos: [] };

  const [precios] = await bd().query(
    "SELECT id_precio, referencia, tipo, precio FROM precio WHERE vigente = TRUE AND referencia IN (?)",
    [referencias],
  );
  const [descuentos] = await bd().query(
    `SELECT referencia, MAX(porcentaje) AS porcentaje, MIN(fecha_fin) AS fecha_fin FROM descuento
      WHERE referencia IN (?) AND CURDATE() BETWEEN fecha_inicio AND fecha_fin GROUP BY referencia`,
    [referencias],
  );
  const [stocks] = await bd().query(
    `SELECT botica_id, referencia, stock_empaque, stock_blister, stock_fraccion FROM stock
      WHERE referencia IN (?) ${soloBoticas.length ? "AND botica_id IN (?)" : ""}`,
    soloBoticas.length ? [referencias, soloBoticas] : [referencias],
  );

  const descuentoDe = new Map(descuentos.map((d) => [d.referencia, d]));
  const respuesta = new Map(referencias.map((r) => [r, { referencia: r, descuento: null, presentaciones: [] }]));
  for (const p of precios) {
    const producto = respuesta.get(p.referencia);
    const d = descuentoDe.get(p.referencia);
    producto.descuento = d ? { porcentaje: d.porcentaje, fecha_fin: d.fecha_fin } : null;
    const porBotica = {};
    for (const s of stocks) {
      if (s.referencia === p.referencia && s[COLUMNA_STOCK[p.tipo]] != null) {
        porBotica[s.botica_id] = s[COLUMNA_STOCK[p.tipo]];
      }
    }
    producto.presentaciones.push({
      tipo: p.tipo,
      id_precio: p.id_precio,
      precio: p.precio,
      precio_final: precioFinal(p.precio, d ? d.porcentaje : 0),
      stock: Object.values(porBotica).reduce((a, b) => a + b, 0),
      stock_por_botica: porBotica,
    });
  }
  return { productos: [...respuesta.values()].filter((p) => p.presentaciones.length > 0) };
}

async function descuentosVigentes() {
  const [filas] = await bd().query(
    `SELECT referencia, MAX(porcentaje) AS porcentaje FROM descuento
      WHERE CURDATE() BETWEEN fecha_inicio AND fecha_fin GROUP BY referencia ORDER BY porcentaje DESC`,
  );
  return { descuentos: filas };
}

/** Registra una venta de la app: valida precio y stock, descuenta el stock y asigna el comprobante. */
async function registrarVenta(cuerpo) {
  const items = Array.isArray(cuerpo?.items) ? cuerpo.items : [];
  const comprobante = cuerpo?.tipo_comprobante === "FACTURA" ? "FACTURA" : "BOLETA";
  if (typeof cuerpo?.botica_id !== "string" || items.length === 0) {
    throw new ErrorCore(400, "Faltan la botica o los productos");
  }
  for (const i of items) {
    if (!TIPOS.includes(i.tipo) || !Number.isInteger(i.cantidad) || i.cantidad <= 0 || !Number.isInteger(i.id_precio)) {
      throw new ErrorCore(400, "Producto no válido en la venta");
    }
  }

  const conexion = await bd().getConnection();
  try {
    await conexion.beginTransaction();
    const sinStock = [];
    const detalles = [];
    let total = 0;
    for (const i of items) {
      const [precio] = await conexion.query(
        "SELECT precio FROM precio WHERE id_precio = ? AND referencia = ? AND tipo = ? AND vigente = TRUE",
        [i.id_precio, i.referencia, i.tipo],
      );
      if (precio.length === 0) {
        throw new ErrorCore(409, "El precio cambió", { codigo: "PRECIO_CAMBIO", referencia: i.referencia });
      }
      const [d] = await conexion.query(
        `SELECT COALESCE(MAX(porcentaje), 0) AS porcentaje FROM descuento
          WHERE referencia = ? AND CURDATE() BETWEEN fecha_inicio AND fecha_fin`,
        [i.referencia],
      );
      const columna = COLUMNA_STOCK[i.tipo];
      const [s] = await conexion.query(
        `SELECT id_stock, ${columna} AS disponible FROM stock WHERE botica_id = ? AND referencia = ? FOR UPDATE`,
        [cuerpo.botica_id, i.referencia],
      );
      if (s.length === 0 || s[0].disponible == null || s[0].disponible < i.cantidad) {
        sinStock.push({ referencia: i.referencia, tipo: i.tipo, disponible: s[0]?.disponible ?? 0 });
        continue;
      }
      await conexion.execute(`UPDATE stock SET ${columna} = ${columna} - ? WHERE id_stock = ?`, [i.cantidad, s[0].id_stock]);
      const unitario = precioFinal(precio[0].precio, d[0].porcentaje);
      const subtotal = Math.round(unitario * i.cantidad * 100) / 100;
      total += subtotal;
      detalles.push([i.referencia, i.id_precio, i.tipo, i.cantidad, d[0].porcentaje, subtotal]);
    }
    if (sinStock.length > 0) throw new ErrorCore(409, "Stock insuficiente", { codigo: "SIN_STOCK", productos: sinStock });

    const serie = SERIE;
    const [ultimo] = await conexion.query(
      "SELECT COALESCE(MAX(correlativo), 0) AS n FROM venta WHERE serie = ? FOR UPDATE", [serie],
    );
    const correlativo = ultimo[0].n + 1;
    total = Math.round(total * 100) / 100;
    const [r] = await conexion.execute(
      `INSERT INTO venta (serie, correlativo, botica_id, precio_total, medio_pago, tipo_pago, tipo_comprobante,
                          ruc, razon_social, estado, origen, referencia_origen, fecha)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'REGISTRADA', 'APP', ?, NOW())`,
      [serie, correlativo, cuerpo.botica_id, total, String(cuerpo.medio_pago || "").slice(0, 30),
        String(cuerpo.tipo_pago || "").slice(0, 30), comprobante, cuerpo.ruc || null, cuerpo.razon_social || null,
        cuerpo.referencia_origen ? String(cuerpo.referencia_origen).slice(0, 30) : null],
    );
    for (const d of detalles) {
      await conexion.execute(
        `INSERT INTO detalle_venta (id_venta, referencia, id_precio, tipo, cantidad, descuento_porcentaje, subtotal)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [r.insertId, ...d],
      );
    }
    await conexion.commit();
    return {
      id_venta: r.insertId,
      serie,
      correlativo,
      numero_comprobante: `${serie}${String(correlativo).padStart(4, "0")}`,
      precio_total: total,
    };
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }
}

async function pagarVenta(idVenta, cuerpo) {
  const [r] = await bd().execute(
    `UPDATE venta SET estado = 'PAGADA', pasarela = ?, id_transaccion_pasarela = ?
      WHERE id_venta = ? AND estado = 'REGISTRADA'`,
    [cuerpo?.pasarela ? String(cuerpo.pasarela).slice(0, 50) : null,
      cuerpo?.id_transaccion ? String(cuerpo.id_transaccion).slice(0, 255) : null, idVenta],
  );
  if (r.affectedRows === 0) throw new ErrorCore(409, "La venta no existe o no está pendiente de pago");
  return { ok: true };
}

/** Anula la venta y devuelve el stock a la botica. Si ya estaba anulada no hace nada. */
async function anularVenta(idVenta) {
  const conexion = await bd().getConnection();
  try {
    await conexion.beginTransaction();
    const [ventas] = await conexion.query("SELECT botica_id, estado FROM venta WHERE id_venta = ? FOR UPDATE", [idVenta]);
    if (ventas.length === 0) throw new ErrorCore(404, "La venta no existe");
    if (ventas[0].estado !== "ANULADA") {
      const [detalles] = await conexion.query("SELECT referencia, tipo, cantidad FROM detalle_venta WHERE id_venta = ?", [idVenta]);
      for (const d of detalles) {
        const columna = COLUMNA_STOCK[d.tipo];
        await conexion.execute(
          `UPDATE stock SET ${columna} = ${columna} + ? WHERE botica_id = ? AND referencia = ?`,
          [d.cantidad, ventas[0].botica_id, d.referencia],
        );
      }
      await conexion.execute("UPDATE venta SET estado = 'ANULADA' WHERE id_venta = ?", [idVenta]);
    }
    await conexion.commit();
    return { ok: true };
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }
}

// ---------------------------------------------------------------------

exports.coreApi = onRequest(async (req, res) => {
  const ruta = req.path.replace(/\/+$/, "");
  const venta = ruta.match(/^\/ventas\/(\d+)\/(pago|anular)$/);
  try {
    let respuesta;
    if (req.method === "GET" && ruta === "/productos") respuesta = await productos();
    else if (req.method === "GET" && ruta === "/boticas") respuesta = await boticas();
    else if (req.method === "POST" && ruta === "/stock") respuesta = await stock(req.body);
    else if (req.method === "GET" && ruta === "/descuentos") respuesta = await descuentosVigentes();
    else if (req.method === "POST" && ruta === "/ventas") respuesta = await registrarVenta(req.body);
    else if (req.method === "POST" && venta?.[2] === "pago") respuesta = await pagarVenta(Number(venta[1]), req.body);
    else if (req.method === "POST" && venta?.[2] === "anular") respuesta = await anularVenta(Number(venta[1]));
    else throw new ErrorCore(404, `Ruta no encontrada: ${req.method} ${ruta}`);
    res.json(respuesta);
  } catch (error) {
    if (error instanceof ErrorCore) {
      res.status(error.status).json({ ok: false, mensaje: error.message, ...error.extra });
      return;
    }
    logger.error("Error en la API de Nortfarma", error);
    res.status(500).json({ ok: false, mensaje: "Error interno del sistema de Nortfarma" });
  }
});
