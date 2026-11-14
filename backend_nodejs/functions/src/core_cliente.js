/**
 * Cliente HTTP del Sistema de Nortfarma (usado por las Cloud Functions de la app).
 * En local apunta a la Mock API (coreApi); en producción, a la API real de la empresa.
 * La app nunca lee la base de datos de Nortfarma directamente: siempre pasa por aquí.
 */
const TIEMPO_MAXIMO_MS = 8000;

function urlBase() {
  const url = process.env.CORE_API_URL;
  if (!url) throw new Error("Falta la variable de entorno CORE_API_URL");
  return url.replace(/\/+$/, "");
}

async function pedir(ruta, cuerpo) {
  const respuesta = await fetch(`${urlBase()}${ruta}`, {
    method: cuerpo === undefined ? "GET" : "POST",
    headers: { "Content-Type": "application/json" },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    signal: AbortSignal.timeout(TIEMPO_MAXIMO_MS),
  });
  const datos = await respuesta.json().catch(() => ({}));
  if (!respuesta.ok) {
    const error = new Error(datos.mensaje || datos.error || `Nortfarma respondió ${respuesta.status}`);
    error.status = respuesta.status;
    error.cuerpo = datos;
    throw error;
  }
  return datos;
}

/**
 * Tiempo real (VERDE): precio vigente, descuento vigente y stock por presentación.
 * Devuelve un Map referencia -> { descuento, presentaciones: Map tipo -> {...} }.
 * Si se pasan boticas, el stock es solo de esas (con el detalle por botica).
 */
async function consultarPrecios(referencias, boticas) {
  if (referencias.length === 0) return new Map();
  const { productos } = await pedir("/stock", { referencias, boticas });
  return new Map(productos.map((p) => [p.referencia, {
    descuento: p.descuento ? p.descuento.porcentaje : 0,
    presentaciones: new Map(p.presentaciones.map((pr) => [pr.tipo, {
      idPrecio: pr.id_precio,
      precioRegular: pr.precio,
      precio: pr.precio_final,
      stock: pr.stock,
      stockPorBotica: pr.stock_por_botica,
    }])),
  }]));
}

/** Tiempo real: referencias con descuento vigente (para la sección de ofertas). */
async function descuentosVigentes() {
  return (await pedir("/descuentos")).descuentos.map((d) => d.referencia);
}

/** Copia diaria (NARANJA): productos y boticas. */
async function obtenerProductos() {
  return (await pedir("/productos")).productos;
}

async function obtenerBoticas() {
  return (await pedir("/boticas")).boticas;
}

/**
 * ROSADO: registra la venta en Nortfarma (descuenta el stock de la botica y asigna
 * la serie-correlativo del comprobante). Devuelve { id_venta, numero_comprobante, precio_total }.
 */
async function registrarVenta(venta) {
  return pedir("/ventas", venta);
}

/** ROSADO: informa a Nortfarma el pago aprobado (id de la transacción en la pasarela). */
async function registrarPagoVenta(idVenta, pago) {
  return pedir(`/ventas/${idVenta}/pago`, pago);
}

/** Anula la venta (pedido cancelado): Nortfarma devuelve el stock. */
async function anularVenta(idVenta) {
  return pedir(`/ventas/${idVenta}/anular`, {});
}

module.exports = {
  consultarPrecios,
  descuentosVigentes,
  obtenerProductos,
  obtenerBoticas,
  registrarVenta,
  registrarPagoVenta,
  anularVenta,
};
