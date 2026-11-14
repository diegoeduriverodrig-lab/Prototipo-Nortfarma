const mysql = require("mysql2/promise");

// Las credenciales vienen de variables de entorno:
// en local, del archivo functions/.env.local (no se sube al repositorio).
let pool;

/** Pool de conexiones a nortfarma_db, compartido entre invocaciones. */
function obtenerPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 3306),
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      connectionLimit: 5,
      charset: "utf8mb4",
      timezone: "-05:00",
      // DECIMAL como número (montos, coordenadas) en lugar de texto.
      decimalNumbers: true,
    });
  }
  return pool;
}

module.exports = { obtenerPool };
