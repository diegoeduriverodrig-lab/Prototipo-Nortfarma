const { onRequest } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");

/**
 * GET /salud
 * Comprueba que la API responde y que llega a MySQL. Útil para probar el entorno.
 */
exports.salud = onRequest(async (req, res) => {
  try {
    const [filas] = await obtenerPool().query(
      `SELECT
         (SELECT COUNT(*) FROM Producto_App) AS productos,
         (SELECT COUNT(*) FROM Botica)       AS boticas,
         (SELECT COUNT(*) FROM Usuario)      AS usuarios`,
    );
    res.json({ estado: "ok", baseDeDatos: "conectada", ...filas[0] });
  } catch (error) {
    logger.error("Fallo al conectar con MySQL", error);
    res.status(500).json({ estado: "error", baseDeDatos: "sin conexión" });
  }
});
