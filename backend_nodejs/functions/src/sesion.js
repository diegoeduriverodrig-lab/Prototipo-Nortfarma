const { HttpsError } = require("firebase-functions/https");
const { obtenerPool } = require("./db");

/** Ids de la tabla Rol. */
const ROLES = Object.freeze({
  ADMINISTRADOR: "RL01",
  ENCARGADO: "RL02",
  REPARTIDOR: "RL03",
  CLIENTE: "RL04",
});

/** Exige un usuario con sesión de Firebase y devuelve sus datos de autenticación. */
function exigirSesion(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return request.auth;
}

/** Busca el perfil del usuario en MySQL por su uid de Firebase. Devuelve null si no existe. */
async function buscarPerfil(uid, conexion = obtenerPool()) {
  const [filas] = await conexion.query(
    `SELECT u.id_usuario, u.uid_firebase, u.id_rol, r.nombre AS rol_nombre, u.id_botica,
            u.nombre, u.apellido, u.dni, u.telefono, u.correo
       FROM Usuario u
       JOIN Rol r ON r.id_rol = u.id_rol
      WHERE u.uid_firebase = ?`,
    [uid],
  );
  if (filas.length === 0) return null;
  const f = filas[0];
  return {
    idUsuario: f.id_usuario,
    uid: f.uid_firebase,
    rol: { id: f.id_rol, nombre: f.rol_nombre },
    idBotica: f.id_botica,
    nombre: f.nombre,
    apellido: f.apellido,
    dni: f.dni,
    telefono: f.telefono,
    correo: f.correo,
  };
}

/**
 * Exige sesión, perfil registrado y uno de los roles indicados.
 * Las reglas de acceso viven aquí (en la nube), no en la app.
 */
async function exigirRol(request, ...rolesPermitidos) {
  const { uid } = exigirSesion(request);
  const perfil = await buscarPerfil(uid);
  if (!perfil) {
    throw new HttpsError("failed-precondition", "Completa tu perfil para continuar.");
  }
  if (rolesPermitidos.length > 0 && !rolesPermitidos.includes(perfil.rol.id)) {
    throw new HttpsError("permission-denied", "No tienes permiso para esta acción.");
  }
  return perfil;
}

module.exports = { ROLES, exigirSesion, buscarPerfil, exigirRol };
