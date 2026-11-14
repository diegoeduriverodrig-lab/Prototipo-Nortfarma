/**
 * Recetas médicas (RF14).
 * PROTOTIPO: las imágenes se guardan en una carpeta local (recetas_local/).
 * En producción se usaría Firebase Storage, que requiere el plan Blaze.
 * La ruta guardada en MySQL ("recetas/<id>.jpg") tiene el mismo formato que
 * tendría en Storage, así que el cambio no afecta a la base de datos.
 */
const fs = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");
const { onCall, onRequest, HttpsError } = require("firebase-functions/https");
const { ROLES, exigirRol } = require("./sesion");

// Fuera de functions/ para que el emulador no se reinicie al guardar archivos.
const CARPETA = path.resolve(__dirname, "..", "..", "recetas_local");
const TAMANO_MAXIMO = 3 * 1024 * 1024;
const TIPOS = { "image/jpeg": "jpg", "image/png": "png" };
const PATRON_RUTA = /^recetas\/[0-9a-f-]{36}\.(jpg|png)$/;

/** subirReceta: recibe la foto en base64 y devuelve su ruta para registrarPedido. */
exports.subirReceta = onCall(async (request) => {
  await exigirRol(request, ROLES.CLIENTE);
  const { imagenBase64, tipo } = request.data || {};
  const extension = TIPOS[tipo];
  if (!extension || typeof imagenBase64 !== "string") {
    throw new HttpsError("invalid-argument", "La receta debe ser una imagen JPG o PNG.");
  }
  const bytes = Buffer.from(imagenBase64, "base64");
  if (bytes.length === 0 || bytes.length > TAMANO_MAXIMO) {
    throw new HttpsError("invalid-argument", "La imagen debe pesar menos de 3 MB.");
  }

  const nombre = `${crypto.randomUUID()}.${extension}`;
  await fs.mkdir(CARPETA, { recursive: true });
  await fs.writeFile(path.join(CARPETA, nombre), bytes);
  return { ruta: `recetas/${nombre}` };
});

/** verReceta?ruta=recetas/<id>.jpg: devuelve la imagen (para la app y el encargado). */
exports.verReceta = onRequest(async (req, res) => {
  const ruta = String(req.query.ruta || "");
  if (!PATRON_RUTA.test(ruta)) {
    res.status(400).send("Ruta no válida");
    return;
  }
  try {
    const archivo = await fs.readFile(path.join(CARPETA, path.basename(ruta)));
    res.type(ruta.endsWith(".png") ? "image/png" : "image/jpeg").send(archivo);
  } catch {
    res.status(404).send("Receta no encontrada");
  }
});

/** Solo se aceptan rutas generadas por subirReceta. */
function esRutaReceta(ruta) {
  return typeof ruta === "string" && PATRON_RUTA.test(ruta);
}

module.exports.esRutaReceta = esRutaReceta;
