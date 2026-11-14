/**
 * Fotos que suben los usuarios (además de las recetas):
 * - productos/:  foto principal de un producto (Administrador).
 * - evidencias/: foto de la entrega a domicilio (Repartidor).
 * PROTOTIPO: igual que las recetas, se guardan en una carpeta del servidor (imagenes_local/).
 * La ruta guardada en MySQL ("productos/<id>.jpg") no cambia si luego se usa Amazon S3.
 */
const fs = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");
const { onCall, onRequest, HttpsError } = require("firebase-functions/https");
const { ROLES, exigirRol } = require("./sesion");

// Fuera de functions/ para que el emulador no se reinicie al guardar archivos.
const CARPETA = process.env.IMAGENES_DIR || path.resolve(__dirname, "..", "..", "imagenes_local");
const TAMANO_MAXIMO = 3 * 1024 * 1024;
const TIPOS = { "image/jpeg": "jpg", "image/png": "png" };
const PATRON_RUTA = /^(productos|evidencias)\/[0-9a-f-]{36}\.(jpg|png)$/;

/** Valida la imagen en base64 y la guarda en la subcarpeta indicada. Devuelve su ruta. */
async function guardarImagen(subcarpeta, data) {
  const { imagenBase64, tipo } = data || {};
  const extension = TIPOS[tipo];
  if (!extension || typeof imagenBase64 !== "string") {
    throw new HttpsError("invalid-argument", "La foto debe ser una imagen JPG o PNG.");
  }
  const bytes = Buffer.from(imagenBase64, "base64");
  if (bytes.length === 0 || bytes.length > TAMANO_MAXIMO) {
    throw new HttpsError("invalid-argument", "La foto debe pesar menos de 3 MB.");
  }
  const nombre = `${crypto.randomUUID()}.${extension}`;
  await fs.mkdir(path.join(CARPETA, subcarpeta), { recursive: true });
  await fs.writeFile(path.join(CARPETA, subcarpeta, nombre), bytes);
  return `${subcarpeta}/${nombre}`;
}

/** subirImagenProducto: foto tomada o elegida por el Administrador para un producto. */
exports.subirImagenProducto = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  return { ruta: await guardarImagen("productos", request.data) };
});

/** subirEvidencia: foto del pedido entregado, tomada por el Repartidor. */
exports.subirEvidencia = onCall(async (request) => {
  await exigirRol(request, ROLES.REPARTIDOR);
  return { ruta: await guardarImagen("evidencias", request.data) };
});

/** verImagen?ruta=productos/<id>.jpg: devuelve la foto (la usan la app y el panel). */
exports.verImagen = onRequest(async (req, res) => {
  const ruta = String(req.query.ruta || "");
  if (!PATRON_RUTA.test(ruta)) {
    res.status(400).send("Ruta no válida");
    return;
  }
  try {
    const [subcarpeta, nombre] = ruta.split("/");
    const archivo = await fs.readFile(path.join(CARPETA, subcarpeta, path.basename(nombre)));
    // El nombre es único y nunca cambia: el celular puede guardarla en caché.
    res.set("Cache-Control", "public, max-age=604800, immutable");
    res.type(ruta.endsWith(".png") ? "image/png" : "image/jpeg").send(archivo);
  } catch {
    res.status(404).send("Imagen no encontrada");
  }
});

/** true si la ruta la generó este módulo dentro de la subcarpeta indicada. */
function esRutaImagen(ruta, subcarpeta) {
  return typeof ruta === "string" && PATRON_RUTA.test(ruta) && ruta.startsWith(`${subcarpeta}/`);
}

module.exports.esRutaImagen = esRutaImagen;
