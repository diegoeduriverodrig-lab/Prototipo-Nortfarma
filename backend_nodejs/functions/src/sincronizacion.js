/**
 * Sincronización diaria con el Sistema de Nortfarma (datos NARANJA del documento):
 * copia productos y boticas a la base de datos de la app. Precio, descuento y stock
 * no se copian: se consultan en tiempo real.
 *
 * - Productos nuevos: llegan sin categoría y sin publicar; el Administrador les pone
 *   categoría y foto, y los activa.
 * - Productos con receta retenida o especial: no se venden en la app (se ocultan).
 * - Boticas: solo las que tienen dirección y ubicación (las necesita el delivery).
 */
const { onCall, HttpsError } = require("firebase-functions/https");
const { onSchedule } = require("firebase-functions/scheduler");
const logger = require("firebase-functions/logger");
const { obtenerPool } = require("./db");
const { ROLES, exigirRol } = require("./sesion");
const core = require("./core_cliente");

const RECETAS_OCULTAS = ["RETENIDA", "ESPECIAL"];

/** sincronizarCatalogo: el Administrador puede lanzar la sincronización a mano. */
exports.sincronizarCatalogo = onCall(async (request) => {
  await exigirRol(request, ROLES.ADMINISTRADOR);
  try {
    return await sincronizarConNortfarma();
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error al sincronizar con Nortfarma", error);
    throw new HttpsError("internal", "No se pudo sincronizar con Nortfarma.");
  }
});

/** Todos los días a las 3:00 a. m. (hora de Perú). En el emulador local no se ejecuta sola. */
exports.sincronizacionDiaria = onSchedule({ schedule: "every day 03:00", timeZone: "America/Lima" }, async () => {
  const resultado = await sincronizarConNortfarma();
  logger.info("Sincronización diaria con Nortfarma", resultado);
});

async function sincronizarConNortfarma() {
  let productos;
  let boticas;
  try {
    [productos, boticas] = await Promise.all([core.obtenerProductos(), core.obtenerBoticas()]);
  } catch (error) {
    logger.error("No se pudo leer el sistema de Nortfarma", error.message);
    throw new HttpsError("unavailable", "El sistema de Nortfarma no responde.");
  }

  const conexion = await obtenerPool().getConnection();
  try {
    await conexion.beginTransaction();
    const resultadoProductos = await sincronizarProductos(conexion, productos);
    const resultadoBoticas = await sincronizarBoticas(conexion, boticas);
    await conexion.commit();
    return { productos: resultadoProductos, boticas: resultadoBoticas };
  } catch (error) {
    await conexion.rollback();
    throw error;
  } finally {
    conexion.release();
  }
}

async function sincronizarProductos(conexion, productos) {
  const [existentes] = await conexion.query("SELECT id_producto_core FROM Producto_App FOR UPDATE");
  const yaExisten = new Set(existentes.map((e) => e.id_producto_core));
  const resultado = { recibidos: productos.length, nuevos: 0, actualizados: 0, ocultos: 0 };

  for (const p of productos) {
    const oculto = RECETAS_OCULTAS.includes(p.receta_medica);
    const datos = [p.nombre, p.especificaciones, p.empaque, p.unidades_empaque, p.se_vende_blister,
      p.unidades_blister, p.se_vende_fraccion, p.receta_medica === "SIMPLE"];
    if (yaExisten.has(p.referencia)) {
      // No se tocan categoría ni publicación (las decide el Administrador), salvo ocultar.
      const [r] = await conexion.execute(
        `UPDATE Producto_App
            SET nombre_comercial = ?, especificaciones = ?, empaque = ?, unidades_empaque = ?,
                se_vende_blister = ?, unidades_blister = ?, se_vende_fraccion = ?, requiere_receta = ?,
                apto_ecommerce = IF(?, FALSE, apto_ecommerce)
          WHERE id_producto_core = ?`,
        [...datos, oculto, p.referencia],
      );
      if (oculto) resultado.ocultos++;
      else if (r.changedRows > 0) resultado.actualizados++;
    } else if (!oculto) {
      await conexion.execute(
        `INSERT INTO Producto_App
           (id_producto_core, id_categoria, nombre_comercial, especificaciones, empaque, unidades_empaque,
            se_vende_blister, unidades_blister, se_vende_fraccion, requiere_receta, apto_ecommerce,
            fecha_sincronizacion)
         VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, FALSE, NOW())`,
        [p.referencia, ...datos],
      );
      resultado.nuevos++;
    }
  }
  await conexion.execute("UPDATE Producto_App SET fecha_sincronizacion = NOW()");
  return resultado;
}

async function sincronizarBoticas(conexion, boticas) {
  const [existentes] = await conexion.query("SELECT id_botica_core FROM Botica FOR UPDATE");
  const yaExisten = new Set(existentes.map((e) => e.id_botica_core));
  const resultado = { recibidas: boticas.length, conUbicacion: 0, nuevas: 0, actualizadas: 0 };
  for (const b of boticas) {
    if (!b.direccion || b.latitud == null || b.longitud == null) continue;
    resultado.conUbicacion++;
    const datos = [b.nombre, b.direccion, b.departamento, b.zona, b.latitud, b.longitud,
      b.hora_apertura_semana, b.hora_cierre_semana, b.hora_apertura_domingo, b.hora_cierre_domingo];
    if (yaExisten.has(b.botica_id)) {
      const [r] = await conexion.execute(
        `UPDATE Botica SET nombre = ?, direccion = ?, departamento = ?, zona = ?, latitud = ?, longitud = ?,
                hora_apertura_semana = ?, hora_cierre_semana = ?, hora_apertura_domingo = ?, hora_cierre_domingo = ?
          WHERE id_botica_core = ?`,
        [...datos, b.botica_id],
      );
      if (r.changedRows > 0) resultado.actualizadas++;
    } else {
      await conexion.execute(
        `INSERT INTO Botica (nombre, direccion, departamento, zona, latitud, longitud, hora_apertura_semana,
                             hora_cierre_semana, hora_apertura_domingo, hora_cierre_domingo, id_botica_core,
                             fecha_sincronizacion)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
        [...datos, b.botica_id],
      );
      resultado.nuevas++;
    }
  }
  await conexion.execute("UPDATE Botica SET fecha_sincronizacion = NOW()");
  return resultado;
}
