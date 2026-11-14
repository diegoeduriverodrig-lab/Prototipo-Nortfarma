/**
 * Utilidades comunes para cambiar el estado de un pedido
 * (las usan el Encargado de botica y el Repartidor).
 */
const { HttpsError } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");
const core = require("./core_cliente");
const { devolverCargo } = require("./culqi");

// Ids de Estado_Pedido y Estado_Pago (datos_iniciales.sql).
const ESTADO = { PROCESANDO: 1, EMPAQUETADO: 2, EN_CAMINO: 3, LISTO_RECOGER: 4, ENTREGADO: 5, FALLIDO: 6 };
const PAGO = { PENDIENTE: 1, APROBADO: 2, FALLIDO: 3 };

async function registrarHistorial(conexion, idPedido, idEstado, idUsuario, motivo) {
  await conexion.execute(
    "INSERT INTO Historial_Estado_Pedido (id_pedido, id_estado_pedido, id_usuario, motivo) VALUES (?, ?, ?, ?)",
    [idPedido, idEstado, idUsuario, motivo],
  );
}

/** Cambia el estado y deja constancia en el historial. */
async function cambiarEstado(conexion, idPedido, idEstado, idUsuario, motivo = null) {
  await conexion.execute("UPDATE Pedido SET id_estado_pedido = ? WHERE id_pedido = ?", [idEstado, idPedido]);
  await registrarHistorial(conexion, idPedido, idEstado, idUsuario, motivo);
}

/**
 * Al entregar, el pago contraentrega queda registrado como cobrado y se informa
 * a Nortfarma (la venta pasa a pagada).
 */
async function registrarCobroContraentrega(conexion, idPedido) {
  const [r] = await conexion.execute(
    `UPDATE Pago SET id_estado_pago = ?, fecha_pago = NOW()
      WHERE id_pedido = ? AND id_estado_pago = ?`,
    [PAGO.APROBADO, idPedido, PAGO.PENDIENTE],
  );
  if (r.affectedRows === 0) return;
  const [pedidos] = await conexion.query("SELECT id_venta_core FROM Pedido WHERE id_pedido = ?", [idPedido]);
  const idVenta = pedidos[0]?.id_venta_core;
  if (!idVenta) return;
  try {
    await core.registrarPagoVenta(idVenta, { pasarela: null, id_transaccion: `CONTRAENTREGA-${idPedido}` });
  } catch (error) {
    logger.error("No se pudo informar el cobro a Nortfarma: revisar a mano", { idVenta, error: error.message });
  }
}

/** Marca el pedido como Fallido y anula la venta en Nortfarma (el stock vuelve a la botica). */
async function pasarAFallido(conexion, pedido, idUsuario, motivo) {
  await cambiarEstado(conexion, pedido.id_pedido, ESTADO.FALLIDO, idUsuario, motivo);

  const [pedidos] = await conexion.query("SELECT id_venta_core FROM Pedido WHERE id_pedido = ?", [pedido.id_pedido]);
  const idVenta = pedidos[0]?.id_venta_core;
  if (idVenta) {
    try {
      await core.anularVenta(idVenta);
    } catch {
      throw new HttpsError("unavailable", "El sistema de Nortfarma no responde. Inténtalo en unos minutos.");
    }
  }

  // Si el pago en línea ya se cobró, se pide la devolución a la pasarela.
  const [pagos] = await conexion.query(
    "SELECT token_transaccion, monto_procesado FROM Pago WHERE id_pedido = ? AND id_estado_pago = ? ORDER BY id_pago DESC LIMIT 1",
    [pedido.id_pedido, PAGO.APROBADO],
  );
  if (pagos.length > 0 && pagos[0].token_transaccion.startsWith("chr_")) {
    const { devuelto } = await devolverCargo(pagos[0].token_transaccion, pagos[0].monto_procesado);
    await registrarHistorial(conexion, pedido.id_pedido, ESTADO.FALLIDO, idUsuario,
      devuelto ? "Pago devuelto al cliente (Culqi)" : "No se pudo devolver el pago: revisar en el panel de Culqi");
  }
}

// ---------------------------------------------------------------------
// Entrega a domicilio (tablas Entrega e Incidencia_Entrega)
// ---------------------------------------------------------------------

/** Al asignar (o cambiar) el repartidor, la entrega empieza de nuevo desde la asignación. */
async function registrarAsignacion(conexion, idPedido, idRepartidor) {
  await conexion.execute(
    `INSERT INTO Entrega (id_pedido, id_repartidor, fecha_asignacion) VALUES (?, ?, NOW())
     ON DUPLICATE KEY UPDATE id_repartidor = VALUES(id_repartidor), fecha_asignacion = NOW(), fecha_salida = NULL`,
    [idPedido, idRepartidor],
  );
}

/**
 * Devuelve el id de la entrega del pedido; si no existe (pedido asignado antes de
 * crear la tabla Entrega), la crea con el repartidor del pedido.
 */
async function asegurarEntrega(conexion, idPedido) {
  await conexion.execute(
    `INSERT IGNORE INTO Entrega (id_pedido, id_repartidor)
     SELECT id_pedido, id_repartidor FROM Pedido WHERE id_pedido = ? AND id_repartidor IS NOT NULL`,
    [idPedido],
  );
  const [filas] = await conexion.query("SELECT id_entrega FROM Entrega WHERE id_pedido = ?", [idPedido]);
  return filas[0]?.id_entrega ?? null;
}

/** Hora de salida (En camino); solo la primera vez. */
async function registrarSalida(conexion, idPedido) {
  if (!(await asegurarEntrega(conexion, idPedido))) return;
  await conexion.execute(
    "UPDATE Entrega SET fecha_salida = COALESCE(fecha_salida, NOW()) WHERE id_pedido = ?", [idPedido],
  );
}

/** Hora de entrega con su evidencia (foto, ubicación GPS y observación), si las hay. */
async function registrarEntregaRealizada(conexion, idPedido, evidencia = {}) {
  if (!(await asegurarEntrega(conexion, idPedido))) return;
  const { ruta = null, latitud = null, longitud = null, observacion = null } = evidencia;
  await conexion.execute(
    `UPDATE Entrega SET fecha_entrega = NOW(), evidencia_url = COALESCE(?, evidencia_url),
            latitud_entrega = ?, longitud_entrega = ?, observacion = COALESCE(?, observacion)
      WHERE id_pedido = ?`,
    [ruta, latitud, longitud, observacion, idPedido],
  );
}

/** Problema durante la entrega; terminaEntrega = la entrega se marcó como fallida. */
async function registrarIncidencia(conexion, idPedido, tipo, detalle, terminaEntrega) {
  const idEntrega = await asegurarEntrega(conexion, idPedido);
  if (!idEntrega) return;
  await conexion.execute(
    "INSERT INTO Incidencia_Entrega (id_entrega, tipo, detalle, termina_entrega) VALUES (?, ?, ?, ?)",
    [idEntrega, tipo, detalle || null, terminaEntrega],
  );
}

/** Ejecuta en una transacción: COMMIT si todo sale bien, ROLLBACK si algo falla. */
async function enTransaccion(trabajo) {
  const conexion = await obtenerPool().getConnection();
  try {
    await conexion.beginTransaction();
    const resultado = await trabajo(conexion);
    await conexion.commit();
    return resultado;
  } catch (error) {
    await conexion.rollback();
    if (error instanceof HttpsError) throw error;
    logger.error("Error en una operación sobre pedidos", error);
    throw new HttpsError("internal", "No se pudo completar la operación. Inténtalo de nuevo.");
  } finally {
    conexion.release();
  }
}

/** Texto libre de la app: recortado y con largo máximo. */
function textoLimpio(valor, maximo = 200) {
  return typeof valor === "string" ? valor.trim().slice(0, maximo) : "";
}

/** Id numérico positivo enviado por la app; si no lo es, error con el mensaje dado. */
function exigirId(valor, mensaje) {
  const id = Number(valor);
  if (!Number.isInteger(id) || id <= 0) throw new HttpsError("invalid-argument", mensaje);
  return id;
}

module.exports = {
  exigirId,
  ESTADO,
  PAGO,
  registrarHistorial,
  cambiarEstado,
  registrarCobroContraentrega,
  pasarAFallido,
  registrarAsignacion,
  registrarSalida,
  registrarEntregaRealizada,
  registrarIncidencia,
  enTransaccion,
  textoLimpio,
};
