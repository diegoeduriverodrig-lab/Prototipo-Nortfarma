/**
 * Presentaciones de venta de un producto: empaque (caja, frasco...), blíster y fracción
 * (unidad suelta). Qué presentaciones ofrece el producto lo dice Producto_App (copia
 * diaria); precio, descuento y stock de cada una vienen del Sistema de Nortfarma.
 */
const { obtenerPool } = require("./db");

const PRESENTACIONES = ["EMPAQUE", "BLISTER", "FRACCION"];

/** Columnas de Producto_App que se necesitan para armar las presentaciones. */
const COLUMNAS_PRESENTACION = "p.empaque, p.unidades_empaque, p.se_vende_blister, p.unidades_blister, p.se_vende_fraccion";

function nombrePresentacion(fila, tipo) {
  if (tipo === "BLISTER") return `Blíster x ${fila.unidades_blister}`;
  if (tipo === "FRACCION") return "Unidad";
  return fila.empaque;
}

function unidadesDe(fila, tipo) {
  if (tipo === "BLISTER") return fila.unidades_blister;
  if (tipo === "FRACCION") return 1;
  return fila.unidades_empaque;
}

/** ¿El producto se vende en esa presentación (según la copia de Nortfarma)? */
function ofrece(fila, tipo) {
  if (tipo === "BLISTER") return Boolean(fila.se_vende_blister);
  if (tipo === "FRACCION") return Boolean(fila.se_vende_fraccion);
  return tipo === "EMPAQUE";
}

/**
 * Lista de presentaciones a la venta con su precio y stock. Solo incluye las que el
 * producto ofrece y tienen precio en Nortfarma. enCore puede ser undefined (sin datos).
 */
function armarPresentaciones(fila, enCore) {
  const lista = [];
  for (const tipo of PRESENTACIONES) {
    const dato = enCore?.presentaciones.get(tipo);
    if (!ofrece(fila, tipo) || !dato) continue;
    lista.push({
      tipo,
      nombre: nombrePresentacion(fila, tipo),
      unidades: unidadesDe(fila, tipo),
      precio: dato.precio,
      precioRegular: dato.precioRegular,
      stock: dato.stock,
    });
  }
  return lista;
}

/** Códigos de Nortfarma de las boticas que operan con la app (para consultar su stock). */
async function codigosBoticas(conexion = obtenerPool()) {
  const [filas] = await conexion.query("SELECT id_botica_core FROM Botica");
  return filas.map((f) => f.id_botica_core);
}

function redondear(monto) {
  return Math.round(monto * 100) / 100;
}

module.exports = {
  PRESENTACIONES,
  COLUMNAS_PRESENTACION,
  nombrePresentacion,
  ofrece,
  armarPresentaciones,
  codigosBoticas,
  redondear,
};
