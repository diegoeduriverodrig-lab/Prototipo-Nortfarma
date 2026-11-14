const { onCall, HttpsError } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");
const { ROLES, exigirSesion, buscarPerfil } = require("./sesion");

/**
 * obtenerPerfil: devuelve el perfil (con rol) del usuario que llama.
 * { registrado: false } si tiene cuenta en Firebase pero aún no tiene perfil
 * (por ejemplo, la primera vez que entra con Google).
 */
exports.obtenerPerfil = onCall(async (request) => {
  const { uid } = exigirSesion(request);
  const perfil = await buscarPerfil(uid);
  return perfil ? { registrado: true, perfil } : { registrado: false };
});

/**
 * registrarPerfil (RF16): guarda los datos personales del cliente en MySQL.
 * El rol siempre es Cliente: las cuentas del personal las crea el Administrador.
 * El correo se toma del token de Firebase, no de lo que envía la app.
 */
exports.registrarPerfil = onCall(async (request) => {
  const auth = exigirSesion(request);
  const correo = auth.token.email;
  if (!correo) {
    throw new HttpsError("failed-precondition", "Tu cuenta no tiene un correo asociado.");
  }

  const datos = validarDatos(request.data || {});

  // Si ya existe (por ejemplo, la app reintentó), se devuelve el mismo perfil.
  const existente = await buscarPerfil(auth.uid);
  if (existente) return { registrado: true, perfil: existente };

  try {
    await obtenerPool().execute(
      `INSERT INTO Usuario (uid_firebase, id_rol, nombre, apellido, dni, telefono, correo)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [auth.uid, ROLES.CLIENTE, datos.nombres, datos.apellidos, datos.dni, datos.celular, correo],
    );
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") {
      const campo = error.message.includes("uq_usuario_dni") ? "DNI" : "correo";
      throw new HttpsError("already-exists", `Ya existe una cuenta registrada con este ${campo}.`);
    }
    logger.error("Error al registrar perfil", error);
    throw new HttpsError("internal", "No se pudo guardar tu perfil. Inténtalo de nuevo.");
  }

  return { registrado: true, perfil: await buscarPerfil(auth.uid) };
});

/** Mismas reglas que la app; el servidor no confía en lo que recibe. */
function validarDatos(data) {
  const texto = (v) => (typeof v === "string" ? v.trim() : "");
  const datos = {
    nombres: texto(data.nombres),
    apellidos: texto(data.apellidos),
    dni: texto(data.dni),
    celular: texto(data.celular),
  };

  const errores = [];
  if (!datos.nombres || datos.nombres.length > 100) errores.push("nombres");
  if (!datos.apellidos || datos.apellidos.length > 100) errores.push("apellidos");
  if (!/^\d{8}$/.test(datos.dni)) errores.push("DNI (8 dígitos)");
  if (!/^9\d{8}$/.test(datos.celular)) errores.push("celular (9 dígitos, empieza con 9)");

  if (errores.length > 0) {
    throw new HttpsError("invalid-argument", `Datos no válidos: ${errores.join(", ")}.`);
  }
  return datos;
}

module.exports.validarDatos = validarDatos;
