/**
 * Validación del carrito contra MySQL (productos a la venta) y el Sistema de Nortfarma
 * (precio, descuento y stock actuales de cada presentación, por botica).
 */
const { HttpsError } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");
const core = require("./core_cliente");
const {
  PRESENTACIONES,
  COLUMNAS_PRESENTACION,
  nombrePresentacion,
  ofrece,
  codigosBoticas,
} = require("./presentaciones");

const MAX_LINEAS = 30;
const MAX_CANTIDAD = 99;

/**
 * Devuelve las líneas del carrito con precio y stock, y las que no tienen stock
 * suficiente sumando todas las boticas de la app. Cada línea trae el stock por
 * botica para elegir después qué botica atiende el pedido.
 */
async function prepararLineas(items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Tu carrito está vacío.");
  }
  // Agrupa por producto y presentación por si llega repetido.
  const cantidades = new Map();
  for (const item of items) {
    const id = Number(item?.idProducto);
    const cantidad = Number(item?.cantidad);
    const presentacion = item?.presentacion ?? "EMPAQUE";
    if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(cantidad) || cantidad <= 0
        || !PRESENTACIONES.includes(presentacion)) {
      throw new HttpsError("invalid-argument", "El carrito tiene un producto no válido.");
    }
    const clave = `${id}|${presentacion}`;
    cantidades.set(clave, (cantidades.get(clave) || 0) + cantidad);
  }
  if (cantidades.size > MAX_LINEAS || [...cantidades.values()].some((c) => c > MAX_CANTIDAD)) {
    throw new HttpsError("invalid-argument", `Máximo ${MAX_LINEAS} productos y ${MAX_CANTIDAD} de cada uno.`);
  }

  const ids = [...new Set([...cantidades.keys()].map((c) => Number(c.split("|")[0])))];
  const [filas] = await obtenerPool().query(
    `SELECT p.id_producto, p.id_producto_core, COALESCE(p.nombre_app, p.nombre_comercial) AS nombre,
            p.requiere_receta, ${COLUMNAS_PRESENTACION}
       FROM Producto_App p JOIN Categoria_App c ON c.id_categoria = p.id_categoria AND c.activa = TRUE
      WHERE p.id_producto IN (?) AND p.apto_ecommerce = TRUE`,
    [ids],
  );
  if (filas.length !== ids.length) {
    throw new HttpsError("failed-precondition", "Algún producto de tu carrito ya no está a la venta.");
  }
  const porId = new Map(filas.map((f) => [f.id_producto, f]));

  let datos;
  try {
    datos = await core.consultarPrecios(filas.map((f) => f.id_producto_core), await codigosBoticas());
  } catch (error) {
    logger.warn("Nortfarma no disponible al validar el carrito", error.message);
    throw new HttpsError("unavailable", "No pudimos confirmar precios y stock. Inténtalo en unos minutos.");
  }

  const lineas = [];
  const sinStock = [];
  for (const [clave, cantidad] of cantidades) {
    const [id, presentacion] = clave.split("|");
    const f = porId.get(Number(id));
    const enCore = datos.get(f.id_producto_core);
    const dato = enCore?.presentaciones.get(presentacion);
    if (!ofrece(f, presentacion) || !dato) {
      throw new HttpsError("failed-precondition", `${f.nombre} ya no se vende en esa presentación.`);
    }
    const linea = {
      idProducto: f.id_producto,
      idProductoCore: f.id_producto_core,
      nombre: f.nombre,
      presentacion,
      nombrePresentacion: nombrePresentacion(f, presentacion),
      requiereReceta: Boolean(f.requiere_receta),
      idPrecio: dato.idPrecio,
      precio: dato.precio,
      precioRegular: dato.precioRegular,
      descuento: enCore.descuento,
      stock: dato.stock,
      stockPorBotica: dato.stockPorBotica,
      cantidad,
    };
    lineas.push(linea);
    if (dato.stock < cantidad) {
      sinStock.push({
        idProducto: linea.idProducto, presentacion, nombre: `${linea.nombre} (${linea.nombrePresentacion})`,
        disponible: dato.stock,
      });
    }
  }
  return { lineas, sinStock };
}

/** Productos del carrito que esa botica no tiene en cantidad suficiente. */
function faltantesEn(lineas, codigoBotica) {
  return lineas.filter((l) => (l.stockPorBotica[codigoBotica] ?? 0) < l.cantidad);
}

module.exports = { prepararLineas, faltantesEn };
