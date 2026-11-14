const { onCall, HttpsError } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");
const { ROLES, exigirRol } = require("./sesion");
const { SELECT_RESUMEN, resumenAJson } = require("./seguimiento");
const { validarDatos } = require("./perfil");
const { ESTADO, textoLimpio, exigirId } = require("./estados_pedido");
const { esRutaImagen } = require("./imagenes");

const ROLES_PERSONAL = [ROLES.ADMINISTRADOR, ROLES.ENCARGADO, ROLES.REPARTIDOR];

/** resumenAdmin: indicadores del panel administrativo. */
exports.resumenAdmin = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const pool = obtenerPool();
  const [porEstado] = await pool.query(
    `SELECT ep.id_estado_pedido AS id, ep.nombre, COUNT(p.id_pedido) AS cantidad
       FROM Estado_Pedido ep LEFT JOIN Pedido p ON p.id_estado_pedido = ep.id_estado_pedido
      GROUP BY ep.id_estado_pedido ORDER BY ep.id_estado_pedido`,
  );
  const [hoy] = await pool.query(
    `SELECT COUNT(*) AS pedidos, COALESCE(SUM(monto_total), 0) AS ventas
       FROM Pedido WHERE DATE(fecha_pedido) = CURDATE() AND id_estado_pedido <> ?`,
    [ESTADO.FALLIDO],
  );
  const [porRol] = await pool.query(
    `SELECT r.id_rol AS id, r.nombre, COUNT(u.id_usuario) AS cantidad
       FROM Rol r LEFT JOIN Usuario u ON u.id_rol = r.id_rol GROUP BY r.id_rol ORDER BY r.id_rol`,
  );
  const [productos] = await pool.query(
    "SELECT COUNT(*) AS total, COALESCE(SUM(apto_ecommerce), 0) AS aVenta FROM Producto_App",
  );
  const numeros = (filas) => filas.map((f) => ({ ...f, cantidad: Number(f.cantidad) }));
  return {
    pedidosPorEstado: numeros(porEstado),
    pedidosHoy: Number(hoy[0].pedidos),
    ventasHoy: Number(hoy[0].ventas),
    usuariosPorRol: numeros(porRol),
    productos: { total: Number(productos[0].total), aVenta: Number(productos[0].aVenta) },
  };
});

/** todosLosPedidos: consulta de pedidos de todas las boticas, con filtros. */
exports.todosLosPedidos = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const condiciones = [];
  const parametros = [];
  if (Number.isInteger(request.data?.idEstado)) {
    condiciones.push("p.id_estado_pedido = ?");
    parametros.push(request.data.idEstado);
  }
  if (Number.isInteger(request.data?.idBotica)) {
    condiciones.push("p.id_botica = ?");
    parametros.push(request.data.idBotica);
  }
  const [filas] = await obtenerPool().query(
    `${SELECT_RESUMEN} ${condiciones.length ? `WHERE ${condiciones.join(" AND ")}` : ""}
      ORDER BY p.fecha_pedido DESC, p.id_pedido DESC LIMIT 200`,
    parametros,
  );
  return { pedidos: filas.map(resumenAJson) };
});

// ---------------------------------------------------------------------
// Gestión de personal (RF17)
// ---------------------------------------------------------------------

/** listarPersonal: cuentas del personal y boticas disponibles. */
exports.listarPersonal = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const [filas] = await obtenerPool().query(
    `SELECT u.id_usuario, u.id_rol, r.nombre AS rol, u.id_botica, b.nombre AS botica,
            u.nombre, u.apellido, u.dni, u.telefono, u.correo
       FROM Usuario u JOIN Rol r ON r.id_rol = u.id_rol
       LEFT JOIN Botica b ON b.id_botica = u.id_botica
      WHERE u.id_rol IN (?) ORDER BY u.id_rol, u.nombre`,
    [ROLES_PERSONAL],
  );
  const [boticas] = await obtenerPool().query("SELECT id_botica, nombre FROM Botica ORDER BY nombre");
  return {
    personal: filas.map((f) => ({
      idUsuario: f.id_usuario,
      rol: { id: f.id_rol, nombre: f.rol },
      idBotica: f.id_botica,
      botica: f.botica,
      nombre: f.nombre,
      apellido: f.apellido,
      dni: f.dni,
      telefono: f.telefono,
      correo: f.correo,
    })),
    boticas: boticas.map((b) => ({ id: b.id_botica, nombre: b.nombre })),
  };
});

/**
 * crearPersonal: crea la cuenta en Firebase Authentication y su perfil con rol.
 * Así el personal ya no se registra como cliente ni se cambia el rol a mano.
 */
exports.crearPersonal = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const data = request.data || {};
  const datos = validarDatos(data);
  const { idRol, idBotica } = await validarRolYBotica(data);
  const correo = textoLimpio(data.correo, 150).toLowerCase();
  const contrasena = typeof data.contrasena === "string" ? data.contrasena : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) throw new HttpsError("invalid-argument", "El correo no es válido.");
  if (contrasena.length < 6) throw new HttpsError("invalid-argument", "La contraseña debe tener al menos 6 caracteres.");

  const cuenta = await crearCuentaFirebase(correo, contrasena);
  try {
    const [r] = await obtenerPool().execute(
      `INSERT INTO Usuario (uid_firebase, id_rol, id_botica, nombre, apellido, dni, telefono, correo)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [cuenta.uid, idRol, idBotica, datos.nombres, datos.apellidos, datos.dni, datos.celular, correo],
    );
    return { idUsuario: r.insertId };
  } catch (error) {
    // Si el perfil no se pudo guardar, se borra la cuenta recién creada para no dejarla huérfana.
    await borrarCuentaFirebase(cuenta.idToken);
    if (error.code === "ER_DUP_ENTRY") {
      throw new HttpsError("already-exists", "Ya existe un usuario con ese DNI o correo.");
    }
    logger.error("Error al crear personal", error);
    throw new HttpsError("internal", "No se pudo crear la cuenta.");
  }
});

/** actualizarPersonal: datos, rol y botica de una cuenta del personal. */
exports.actualizarPersonal = onCall(async (request) => {
  const admin = await exigirRol(request, ROLES.ADMINISTRADOR);
  const data = request.data || {};
  const idUsuario = exigirId(data.idUsuario, "Usuario no válido.");
  const datos = validarDatos({ ...data, dni: "00000000" }); // el DNI no se edita
  const { idRol, idBotica } = await validarRolYBotica(data);
  if (idUsuario === admin.idUsuario && idRol !== ROLES.ADMINISTRADOR) {
    throw new HttpsError("failed-precondition", "No puedes quitarte el rol de administrador a ti mismo.");
  }
  await exigirPersonal(idUsuario);
  if (idRol !== ROLES.REPARTIDOR) await exigirSinEntregasActivas(idUsuario);

  await obtenerPool().execute(
    "UPDATE Usuario SET nombre = ?, apellido = ?, telefono = ?, id_rol = ?, id_botica = ? WHERE id_usuario = ?",
    [datos.nombres, datos.apellidos, datos.celular, idRol, idBotica, idUsuario],
  );
  return { ok: true };
});

/**
 * quitarAccesoPersonal: la cuenta vuelve a ser de Cliente (pierde los módulos del personal).
 * No se borra la cuenta de Firebase porque eso requiere el Admin SDK con credenciales.
 */
exports.quitarAccesoPersonal = onCall(async (request) => {
  const admin = await exigirRol(request, ROLES.ADMINISTRADOR);
  const idUsuario = exigirId(request.data?.idUsuario, "Usuario no válido.");
  if (idUsuario === admin.idUsuario) {
    throw new HttpsError("failed-precondition", "No puedes quitarte el acceso a ti mismo.");
  }
  await exigirPersonal(idUsuario);
  await exigirSinEntregasActivas(idUsuario);
  await obtenerPool().execute(
    "UPDATE Usuario SET id_rol = ?, id_botica = NULL WHERE id_usuario = ?",
    [ROLES.CLIENTE, idUsuario],
  );
  return { ok: true };
});

// ---------------------------------------------------------------------
// Configuración del catálogo
// ---------------------------------------------------------------------

/**
 * listarProductosAdmin: todo el catálogo, incluidos los que no se venden en línea.
 * Primero los productos nuevos (llegaron de Nortfarma sin categoría).
 */
exports.listarProductosAdmin = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const [filas] = await obtenerPool().query(
    `SELECT p.id_producto, p.id_producto_core, p.nombre_comercial, p.nombre_app, p.apto_ecommerce,
            p.requiere_receta, p.empaque, p.se_vende_blister, p.unidades_blister, p.se_vende_fraccion,
            p.id_categoria, c.nombre_visual AS categoria,
            (SELECT i.url_imagen FROM Imagen_Producto i WHERE i.id_producto = p.id_producto
              ORDER BY i.es_principal DESC, i.id_imagen LIMIT 1) AS imagen_url
       FROM Producto_App p LEFT JOIN Categoria_App c ON c.id_categoria = p.id_categoria
      ORDER BY (p.id_categoria IS NULL) DESC, COALESCE(p.nombre_app, p.nombre_comercial)`,
  );
  return {
    productos: filas.map((f) => ({
      idProducto: f.id_producto,
      idProductoCore: f.id_producto_core,
      nombre: f.nombre_app ?? f.nombre_comercial,
      nombreNortfarma: f.nombre_comercial,
      nombreApp: f.nombre_app,
      presentaciones: [f.empaque, f.se_vende_blister ? `Blíster x ${f.unidades_blister}` : null,
        f.se_vende_fraccion ? "Unidad" : null].filter(Boolean),
      aptoEcommerce: Boolean(f.apto_ecommerce),
      requiereReceta: Boolean(f.requiere_receta),
      idCategoria: f.id_categoria,
      categoria: f.categoria,
      imagenUrl: f.imagen_url,
    })),
  };
});

/**
 * actualizarProducto: nombre en la app, categoría, venta en línea e imagen principal.
 * Así el Administrador clasifica y publica los productos nuevos que llegan de Nortfarma.
 * La imagen puede ser un enlace (http/https) o una foto subida con subirImagenProducto.
 * El nombre en la app es opcional: si se deja vacío, el cliente ve el nombre de Nortfarma.
 */
exports.actualizarProducto = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const data = request.data || {};
  const idProducto = exigirId(data.idProducto, "Producto no válido.");
  const idCategoria = exigirId(data.idCategoria, "Elige una categoría válida.");
  const aptoEcommerce = data.aptoEcommerce === true;
  const nombreApp = textoLimpio(data.nombreApp, 150) || null;
  const imagenUrl = textoLimpio(data.imagenUrl, 255);
  if (imagenUrl && !/^https?:\/\/\S+$/.test(imagenUrl) && !esRutaImagen(imagenUrl, "productos")) {
    throw new HttpsError("invalid-argument", "La imagen debe ser un enlace que empiece con http:// o https://");
  }

  const conexion = await obtenerPool().getConnection();
  try {
    await conexion.beginTransaction();
    const [r] = await conexion.execute(
      "UPDATE Producto_App SET nombre_app = ?, id_categoria = ?, apto_ecommerce = ? WHERE id_producto = ?",
      [nombreApp, idCategoria, aptoEcommerce, idProducto],
    );
    if (r.affectedRows === 0) throw new HttpsError("not-found", "El producto no existe.");

    // Una sola imagen principal por producto.
    await conexion.execute("DELETE FROM Imagen_Producto WHERE id_producto = ? AND es_principal = TRUE", [idProducto]);
    if (imagenUrl) {
      await conexion.execute(
        "INSERT INTO Imagen_Producto (id_producto, url_imagen, es_principal) VALUES (?, ?, TRUE)",
        [idProducto, imagenUrl],
      );
    }
    await conexion.commit();
    return { ok: true };
  } catch (error) {
    await conexion.rollback();
    if (error instanceof HttpsError) throw error;
    if (error.code === "ER_NO_REFERENCED_ROW_2") throw new HttpsError("invalid-argument", "Elige una categoría válida.");
    logger.error("Error al actualizar producto", error);
    throw new HttpsError("internal", "No se pudo guardar el producto.");
  } finally {
    conexion.release();
  }
});

// ---------------------------------------------------------------------
// Categorías del catálogo
// ---------------------------------------------------------------------

/** Íconos que la app sabe dibujar (icono://<clave>). */
const ICONOS_CATEGORIA = [
  "medicinas", "dolor_fiebre", "vitaminas", "cuidado_personal", "bebe", "botiquin", "piel", "dental",
  "nutricion", "ojos", "corazon", "respiratorio", "digestivo", "mujer", "adulto_mayor", "deporte",
];

/** listarCategoriasAdmin: todas las categorías, también las ocultas, con su cantidad de productos. */
exports.listarCategoriasAdmin = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const [filas] = await obtenerPool().query(
    `SELECT c.id_categoria, c.nombre_visual, c.icono_url, c.activa, COUNT(p.id_producto) AS productos
       FROM Categoria_App c LEFT JOIN Producto_App p ON p.id_categoria = c.id_categoria
      GROUP BY c.id_categoria ORDER BY c.id_categoria`,
  );
  return {
    categorias: filas.map((f) => ({
      id: f.id_categoria,
      nombre: f.nombre_visual,
      iconoUrl: f.icono_url,
      activa: Boolean(f.activa),
      productos: Number(f.productos),
    })),
    iconos: ICONOS_CATEGORIA,
  };
});

/**
 * guardarCategoria: crea (sin idCategoria) o edita una categoría: nombre, ícono y si está visible.
 * Ocultar una categoría saca sus productos del catálogo del cliente, sin borrar nada.
 */
exports.guardarCategoria = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const data = request.data || {};
  const nombre = textoLimpio(data.nombre, 100);
  const icono = textoLimpio(data.icono, 40);
  const activa = data.activa !== false;
  if (nombre.length < 3) throw new HttpsError("invalid-argument", "El nombre debe tener al menos 3 letras.");
  if (!ICONOS_CATEGORIA.includes(icono)) throw new HttpsError("invalid-argument", "Elige un ícono.");

  const pool = obtenerPool();
  const idCategoria = data.idCategoria == null ? null : exigirId(data.idCategoria, "Categoría no válida.");
  const [repetida] = await pool.query(
    "SELECT id_categoria FROM Categoria_App WHERE LOWER(nombre_visual) = LOWER(?) AND id_categoria <> ?",
    [nombre, idCategoria ?? 0],
  );
  if (repetida.length > 0) throw new HttpsError("already-exists", "Ya existe una categoría con ese nombre.");

  if (idCategoria == null) {
    const [r] = await pool.execute(
      "INSERT INTO Categoria_App (nombre_visual, icono_url, activa) VALUES (?, ?, ?)",
      [nombre, `icono://${icono}`, activa],
    );
    return { idCategoria: r.insertId };
  }
  const [r] = await pool.execute(
    "UPDATE Categoria_App SET nombre_visual = ?, icono_url = ?, activa = ? WHERE id_categoria = ?",
    [nombre, `icono://${icono}`, activa, idCategoria],
  );
  if (r.affectedRows === 0) throw new HttpsError("not-found", "La categoría no existe.");
  return { idCategoria };
});

/** eliminarCategoria: solo si no tiene productos (si tiene, primero hay que pasarlos a otra). */
exports.eliminarCategoria = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  const idCategoria = exigirId(request.data?.idCategoria, "Categoría no válida.");
  const pool = obtenerPool();
  const [productos] = await pool.query(
    "SELECT COUNT(*) AS n FROM Producto_App WHERE id_categoria = ?", [idCategoria],
  );
  const n = Number(productos[0].n);
  if (n > 0) {
    throw new HttpsError("failed-precondition",
      `La categoría tiene ${n} producto${n === 1 ? "" : "s"}. Pásalos a otra categoría u ocúltala.`);
  }
  const [r] = await pool.execute("DELETE FROM Categoria_App WHERE id_categoria = ?", [idCategoria]);
  if (r.affectedRows === 0) throw new HttpsError("not-found", "La categoría no existe.");
  return { ok: true };
});

// ---------------------------------------------------------------------

async function validarRolYBotica(data) {
  const idRol = data.idRol;
  if (!ROLES_PERSONAL.includes(idRol)) throw new HttpsError("invalid-argument", "Elige el rol.");
  if (idRol !== ROLES.ENCARGADO) return { idRol, idBotica: null };

  const idBotica = Number(data.idBotica);
  const sinBotica = new HttpsError("invalid-argument", "El encargado necesita una botica.");
  if (!Number.isInteger(idBotica) || idBotica <= 0) throw sinBotica;
  const [b] = await obtenerPool().query("SELECT id_botica FROM Botica WHERE id_botica = ?", [idBotica]);
  if (b.length === 0) throw sinBotica;
  return { idRol, idBotica };
}

async function exigirPersonal(idUsuario) {
  const [u] = await obtenerPool().query("SELECT id_rol FROM Usuario WHERE id_usuario = ?", [idUsuario]);
  if (u.length === 0 || !ROLES_PERSONAL.includes(u[0].id_rol)) {
    throw new HttpsError("not-found", "La cuenta no existe o no es del personal.");
  }
}

/** Un repartidor con entregas en curso no puede perder su rol. */
async function exigirSinEntregasActivas(idUsuario) {
  const [p] = await obtenerPool().query(
    "SELECT COUNT(*) AS n FROM Pedido WHERE id_repartidor = ? AND id_estado_pedido IN (?, ?)",
    [idUsuario, ESTADO.EMPAQUETADO, ESTADO.EN_CAMINO],
  );
  if (Number(p[0].n) > 0) {
    throw new HttpsError("failed-precondition", "Tiene entregas en curso. Reasígnalas o termínalas primero.");
  }
}

/**
 * Crea la cuenta con la API REST de Firebase Authentication.
 * PROTOTIPO: en producción se usaría admin.auth().createUser() del Admin SDK.
 */
async function crearCuentaFirebase(correo, contrasena) {
  const clave = process.env.APP_API_KEY;
  if (!clave) throw new HttpsError("internal", "Falta configurar APP_API_KEY.");
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${clave}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: correo, password: contrasena, returnSecureToken: true }),
    signal: AbortSignal.timeout(10000),
  });
  const cuerpo = await r.json().catch(() => ({}));
  if (!r.ok) {
    const codigo = cuerpo.error?.message ?? "";
    if (codigo === "EMAIL_EXISTS") throw new HttpsError("already-exists", "Ya existe una cuenta con ese correo.");
    if (codigo.startsWith("WEAK_PASSWORD")) throw new HttpsError("invalid-argument", "La contraseña es muy débil.");
    logger.error("Firebase Auth rechazó la creación", codigo);
    throw new HttpsError("internal", "No se pudo crear la cuenta en Firebase.");
  }
  return { uid: cuerpo.localId, idToken: cuerpo.idToken };
}

async function borrarCuentaFirebase(idToken) {
  try {
    await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${process.env.APP_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
      signal: AbortSignal.timeout(10000),
    });
  } catch (error) {
    logger.warn("No se pudo borrar la cuenta huérfana", error.message);
  }
}
