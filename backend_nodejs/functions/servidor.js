/**
 * Servidor de la API para AWS Lightsail (producción del prototipo).
 *
 * Ejecuta las mismas funciones de index.js, sin modificarlas, como un servidor Express:
 * - Funciones onCall:    POST /api/<nombre>  (mismo protocolo que Cloud Functions, así la app
 *                        las llama con httpsCallableFromUrl y la librería de Firebase).
 * - Funciones onRequest: /api/<nombre>/...   (verReceta, coreApi, salud).
 * - sincronizacionDiaria: todos los días a las 3:00 a. m. (hora del servidor: America/Lima).
 *
 * La sesión se sigue validando con Firebase Authentication: cada llamada trae el token del
 * usuario y aquí se verifica con el Admin SDK antes de ejecutar la función.
 *
 * Uso: node --env-file=.env servidor.js   (Caddy publica el puerto con HTTPS)
 */
const express = require("express");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { HttpsError } = require("firebase-functions/https");
const { logger } = require("firebase-functions");
const api = require("./index");

const PUERTO = Number(process.env.PUERTO || 8080);
const HORA_SINCRONIZACION = 3;

initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const app = express();
app.disable("x-powered-by");
// Las recetas llegan en base64 (máximo 3 MB de imagen, unos 4 MB en texto).
app.use(express.json({
  limit: "6mb",
  verify: (req, _res, buf) => {
    req.rawBody = buf;
  },
}));

for (const [nombre, funcion] of Object.entries(api)) {
  const endpoint = funcion.__endpoint;
  if (endpoint?.callableTrigger) {
    app.post(`/api/${nombre}`, (req, res) => atenderCallable(funcion, nombre, req, res));
  } else if (endpoint?.httpsTrigger) {
    app.use(`/api/${nombre}`, funcion);
  }
}

app.use((_req, res) => res.status(404).json({ error: { status: "NOT_FOUND", message: "No existe." } }));

/** Protocolo callable: { data } -> { result } o { error: { status, message, details } }. */
async function atenderCallable(funcion, nombre, req, res) {
  try {
    const auth = await verificarSesion(req.get("authorization"));
    const data = decodificar(req.body?.data ?? null);
    const result = await funcion.run({ data, auth, rawRequest: req, acceptsStreaming: false });
    res.json({ result: result ?? null });
  } catch (error) {
    const httpsError = error instanceof HttpsError ? error : new HttpsError("internal", "INTERNAL");
    if (!(error instanceof HttpsError)) logger.error(`Error en ${nombre}`, error);
    res.status(httpsError.httpErrorCode.status).json({ error: httpsError.toJSON() });
  }
}

/**
 * Igual que Cloud Functions: la app de Android envía los enteros largos como
 * { "@type": "...Int64Value", "value": "123" }; aquí se convierten a número.
 */
function decodificar(valor) {
  if (valor === null || typeof valor !== "object") return valor;
  if (Array.isArray(valor)) return valor.map(decodificar);
  if (/protobuf\.U?Int64Value$/.test(valor["@type"] ?? "")) {
    const numero = Number(valor.value);
    if (Number.isNaN(numero)) throw new HttpsError("invalid-argument", "Dato numérico no válido.");
    return numero;
  }
  return Object.fromEntries(Object.entries(valor).map(([clave, v]) => [clave, decodificar(v)]));
}

/** Sin token: llamada anónima (la función decide). Con token inválido: sesión vencida. */
async function verificarSesion(cabecera) {
  const token = /^Bearer (.+)$/.exec(cabecera || "")?.[1];
  if (!token) return undefined;
  try {
    const decodificado = await getAuth().verifyIdToken(token);
    return { uid: decodificado.uid, token: decodificado, rawToken: token };
  } catch {
    throw new HttpsError("unauthenticated", "Tu sesión venció. Vuelve a iniciar sesión.");
  }
}

/** Programa la sincronización diaria con Nortfarma a la hora indicada. */
function programarSincronizacion() {
  const ahora = new Date();
  const proxima = new Date(ahora);
  proxima.setHours(HORA_SINCRONIZACION, 0, 0, 0);
  if (proxima <= ahora) proxima.setDate(proxima.getDate() + 1);
  setTimeout(async () => {
    try {
      await api.sincronizacionDiaria.run({ scheduleTime: new Date().toISOString() });
    } catch (error) {
      logger.error("Falló la sincronización diaria", error);
    }
    programarSincronizacion();
  }, proxima - ahora);
}

app.listen(PUERTO, "127.0.0.1", () => {
  logger.info(`API de Boticas Felicidad en el puerto ${PUERTO}`);
  programarSincronizacion();
});
