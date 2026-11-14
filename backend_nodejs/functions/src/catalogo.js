const { onCall, HttpsError } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");
const { exigirSesion } = require("./sesion");
const core = require("./core_cliente");
const { COLUMNAS_PRESENTACION, armarPresentaciones, codigosBoticas } = require("./presentaciones");

const LIMITE_MAXIMO = 50;
const ORDENES = ["relevancia", "nombre", "precio_asc", "precio_desc"];

/** obtenerCategorias: categorías visibles con la cantidad de productos a la venta. */
exports.obtenerCategorias = onCall(async (request) => {
  exigirSesion(request);
  const [filas] = await obtenerPool().query(
    `SELECT c.id_categoria, c.nombre_visual, c.icono_url,
            COUNT(p.id_producto) AS cantidad
       FROM Categoria_App c
       LEFT JOIN Producto_App p ON p.id_categoria = c.id_categoria AND p.apto_ecommerce = TRUE
      WHERE c.activa = TRUE
      GROUP BY c.id_categoria
      ORDER BY c.id_categoria`,
  );
  return {
    categorias: filas.map((f) => ({
      id: f.id_categoria,
      nombre: f.nombre_visual,
      iconoUrl: f.icono_url,
      cantidad: f.cantidad,
    })),
  };
});

/**
 * consultarCatalogo (Sprint 2): búsqueda por nombre y filtros.
 * 1. Datos estáticos desde MySQL (copia diaria de Nortfarma; solo productos a la venta).
 * 2. Precio, descuento y stock en tiempo real desde el Sistema de Nortfarma.
 * 3. Combina ambos y aplica filtros y orden que dependen del precio o stock.
 */
exports.consultarCatalogo = onCall(async (request) => {
  exigirSesion(request);
  const data = request.data || {};
  const termino = typeof data.termino === "string" ? data.termino.trim().slice(0, 100) : "";
  const idCategoria = Number.isInteger(data.idCategoria) ? data.idCategoria : null;
  const soloDisponibles = data.soloDisponibles === true;
  const soloOfertas = data.soloOfertas === true;
  const orden = ORDENES.includes(data.orden) ? data.orden : "relevancia";
  const limite = Math.min(Number(data.limite) || LIMITE_MAXIMO, LIMITE_MAXIMO);

  const condiciones = ["p.apto_ecommerce = TRUE"];
  const parametros = [];
  const escapado = termino.replace(/[%_\\]/g, "\\$&");
  if (termino) {
    // Nombre en la app, nombre de Nortfarma y especificaciones: "paracetamol" encuentra "Panadol".
    condiciones.push("(p.nombre_app LIKE ? OR p.nombre_comercial LIKE ? OR p.especificaciones LIKE ?)");
    parametros.push(`%${escapado}%`, `%${escapado}%`, `%${escapado}%`);
  }
  if (idCategoria) {
    condiciones.push("p.id_categoria = ?");
    parametros.push(idCategoria);
  }
  if (soloOfertas) {
    // Los descuentos viven en Nortfarma: primero se piden los productos en oferta.
    let enOferta;
    try {
      enOferta = await core.descuentosVigentes();
    } catch (error) {
      logger.warn("Sistema de Nortfarma no disponible al consultar ofertas", error.message);
      return { productos: [], total: 0, coreDisponible: false };
    }
    if (enOferta.length === 0) return { productos: [], total: 0, coreDisponible: true };
    condiciones.push("p.id_producto_core IN (?)");
    parametros.push(enOferta);
  }

  // Relevancia: 1) el nombre empieza con el término, 2) el nombre lo contiene,
  // 3) solo aparece en las especificaciones (principio activo, presentación).
  const ordenSql = termino
    ? `CASE WHEN ${NOMBRE} LIKE ? THEN 0
            WHEN ${NOMBRE} LIKE ? THEN 1
            ELSE 2 END, ${NOMBRE}`
    : soloOfertas
      ? `imagen_url IS NULL, ${NOMBRE}` // en Inicio, primero las ofertas con foto
      : NOMBRE;
  if (termino) parametros.push(`${escapado}%`, `%${escapado}%`);

  const [filas] = await obtenerPool().query(
    `${SELECT_PRODUCTO}
      WHERE ${condiciones.join(" AND ")}
      ORDER BY ${ordenSql}
      LIMIT ?`,
    [...parametros, limite],
  );

  const { productos, coreDisponible } = await combinarConCore(filas);

  let resultado = soloDisponibles ? productos.filter((p) => p.disponible) : productos;
  if (orden === "precio_asc" || orden === "precio_desc") {
    const signo = orden === "precio_asc" ? 1 : -1;
    resultado = [...resultado].sort(
      (a, b) => signo * ((a.precio ?? Infinity) - (b.precio ?? Infinity)),
    );
  } else if (orden === "nombre") {
    resultado = [...resultado].sort((a, b) => a.nombre.localeCompare(b.nombre, "es"));
  }

  return { productos: resultado, total: resultado.length, coreDisponible };
});

/** obtenerProducto: detalle de un producto con todas sus imágenes y stock en tiempo real. */
exports.obtenerProducto = onCall(async (request) => {
  exigirSesion(request);
  const idProducto = Number(request.data?.idProducto);
  if (!Number.isInteger(idProducto) || idProducto <= 0) {
    throw new HttpsError("invalid-argument", "Producto no válido.");
  }

  const [filas] = await obtenerPool().query(
    `${SELECT_PRODUCTO} WHERE p.id_producto = ? AND p.apto_ecommerce = TRUE`,
    [idProducto],
  );
  if (filas.length === 0) {
    throw new HttpsError("not-found", "El producto no existe o no está a la venta.");
  }

  const [imagenes] = await obtenerPool().query(
    `SELECT url_imagen FROM Imagen_Producto
      WHERE id_producto = ? ORDER BY es_principal DESC, id_imagen`,
    [idProducto],
  );

  const { productos, coreDisponible } = await combinarConCore(filas);
  return {
    producto: { ...productos[0], imagenes: imagenes.map((i) => i.url_imagen) },
    coreDisponible,
  };
});

// Nombre que ve el cliente: el de la app si el Administrador lo puso; si no, el de Nortfarma.
const NOMBRE = "COALESCE(p.nombre_app, p.nombre_comercial)";

// Solo productos con categoría visible: los nuevos sin clasificar no se muestran.
const SELECT_PRODUCTO = `
  SELECT p.id_producto, p.id_producto_core, ${NOMBRE} AS nombre, p.especificaciones,
         p.requiere_receta, ${COLUMNAS_PRESENTACION}, c.id_categoria, c.nombre_visual AS categoria,
         (SELECT i.url_imagen FROM Imagen_Producto i
           WHERE i.id_producto = p.id_producto
           ORDER BY i.es_principal DESC, i.id_imagen LIMIT 1) AS imagen_url
    FROM Producto_App p
    JOIN Categoria_App c ON c.id_categoria = p.id_categoria AND c.activa = TRUE`;

/**
 * Añade precio, descuento y stock (suma de las boticas de la app) por presentación.
 * Si Nortfarma no responde, los productos se devuelven sin precio y como no
 * disponibles: nunca se vende sin confirmar stock.
 * precio y stock del producto son los del empaque (para listas y orden por precio).
 */
async function combinarConCore(filas) {
  let datos = new Map();
  let coreDisponible = true;
  try {
    datos = await core.consultarPrecios(filas.map((f) => f.id_producto_core), await codigosBoticas());
  } catch (error) {
    coreDisponible = false;
    logger.warn("Sistema de Nortfarma no disponible al consultar precios", error.message);
  }

  const productos = filas.map((f) => {
    const enCore = datos.get(f.id_producto_core);
    const presentaciones = armarPresentaciones(f, enCore);
    const empaque = presentaciones.find((p) => p.tipo === "EMPAQUE") ?? presentaciones[0];
    return {
      idProducto: f.id_producto,
      idProductoCore: f.id_producto_core,
      nombre: f.nombre,
      especificaciones: f.especificaciones,
      empaque: f.empaque,
      requiereReceta: Boolean(f.requiere_receta),
      categoria: { id: f.id_categoria, nombre: f.categoria },
      imagenUrl: f.imagen_url,
      descuento: enCore?.descuento ?? 0,
      presentaciones,
      precio: empaque ? empaque.precio : null,
      precioRegular: empaque ? empaque.precioRegular : null,
      stock: empaque ? empaque.stock : null,
      disponible: presentaciones.some((p) => p.stock > 0),
    };
  });
  return { productos, coreDisponible };
}
