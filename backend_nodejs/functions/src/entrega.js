const { onCall, HttpsError } = require("firebase-functions/https");
const { obtenerPool } = require("./db");
const { ROLES, exigirSesion, exigirRol } = require("./sesion");
const { prepararLineas, faltantesEn } = require("./carrito");

// Tarifa de delivery: base hasta 2 km, luego por km adicional. Fuera del radio no se atiende.
const TARIFA_BASE = 5.0;
const KM_INCLUIDOS = 2;
const TARIFA_POR_KM = 1.5;
const RADIO_MAXIMO_KM = 15;

/**
 * Coordenadas aproximadas del centro de cada distrito. Solo se usan si la app no
 * envía la ubicación de Google Maps (por ejemplo, si no hay clave de Maps).
 */
const CENTRO_DISTRITO = {
  200101: { latitud: -5.19449, longitud: -80.63282 }, // Piura
  200104: { latitud: -5.20030, longitud: -80.61750 }, // Castilla
  200115: { latitud: -5.18000, longitud: -80.66500 }, // Veintiséis de Octubre
};

/**
 * obtenerBoticas: sucursales para "Recojo en tienda". Si se envía el carrito (items),
 * cada botica indica si tiene stock de todos los productos.
 */
exports.obtenerBoticas = onCall(async (request) => {
  exigirSesion(request);
  const boticas = await listarBoticas();
  if (!Array.isArray(request.data?.items) || request.data.items.length === 0) {
    return { boticas: boticas.map(boticaAJson) };
  }
  const { lineas } = await prepararLineas(request.data.items);
  return {
    boticas: boticas.map((b) => {
      const faltan = faltantesEn(lineas, b.id_botica_core);
      return { ...boticaAJson(b), tieneStock: faltan.length === 0, productosSinStock: faltan.map((l) => l.nombre) };
    }),
  };
});

/** obtenerUbigeos: distritos atendidos, para el formulario de dirección. */
exports.obtenerUbigeos = onCall(async (request) => {
  exigirSesion(request);
  const [filas] = await obtenerPool().query(
    "SELECT id_ubigeo, departamento, provincia, distrito FROM Ubigeo ORDER BY distrito",
  );
  return {
    ubigeos: filas.map((f) => ({
      id: f.id_ubigeo,
      departamento: f.departamento,
      provincia: f.provincia,
      distrito: f.distrito,
    })),
  };
});

/** listarDirecciones (RF02): direcciones guardadas del cliente. */
exports.listarDirecciones = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.CLIENTE);
  const [filas] = await obtenerPool().query(
    `${SELECT_DIRECCION} WHERE d.id_usuario = ? ORDER BY d.id_direccion DESC`,
    [perfil.idUsuario],
  );
  return { direcciones: filas.map(direccionAJson) };
});

/** guardarDireccion (RF02): nueva dirección de entrega. */
exports.guardarDireccion = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.CLIENTE);
  const data = request.data || {};
  const idUbigeo = typeof data.idUbigeo === "string" ? data.idUbigeo : "";
  const direccionExacta = typeof data.direccionExacta === "string" ? data.direccionExacta.trim() : "";
  const referencia = typeof data.referencia === "string" ? data.referencia.trim() : "";

  if (direccionExacta.length < 5 || direccionExacta.length > 255) {
    throw new HttpsError("invalid-argument", "Escribe la dirección completa (calle, número, urbanización).");
  }
  if (referencia.length > 255) {
    throw new HttpsError("invalid-argument", "La referencia es demasiado larga.");
  }

  // Si la app envía coordenadas (Google Maps), se usan; si no, el centro del distrito.
  const coordenadas = coordenadasValidas(data.latitud, data.longitud)
    ? { latitud: data.latitud, longitud: data.longitud }
    : CENTRO_DISTRITO[idUbigeo];
  if (!coordenadas) {
    throw new HttpsError("invalid-argument", "Elige un distrito de la lista.");
  }

  const [r] = await obtenerPool().execute(
    `INSERT INTO Direccion_Cliente (id_usuario, id_ubigeo, direccion_exacta, referencia, latitud, longitud)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [perfil.idUsuario, idUbigeo, direccionExacta, referencia || null,
      coordenadas.latitud, coordenadas.longitud],
  );
  const [filas] = await obtenerPool().query(`${SELECT_DIRECCION} WHERE d.id_direccion = ?`, [r.insertId]);
  return { direccion: direccionAJson(filas[0]) };
});

/**
 * cotizarEnvio: costo de delivery y botica que despacha, para mostrarlo antes de confirmar.
 * Todos los deliverys salen de una sola botica; con el carrito (items) se revisa que
 * esa botica tenga todos los productos.
 */
exports.cotizarEnvio = onCall(async (request) => {
  const perfil = await exigirRol(request, ROLES.CLIENTE);
  const direccion = await buscarDireccionDelCliente(Number(request.data?.idDireccion), perfil.idUsuario);
  const items = request.data?.items;
  const lineas = Array.isArray(items) && items.length > 0 ? (await prepararLineas(items)).lineas : null;
  const envio = await calcularEnvio(direccion, lineas);
  return { costoEnvio: envio.costo, distanciaKm: envio.distanciaKm, botica: boticaAJson(envio.botica) };
});

const SELECT_DIRECCION = `
  SELECT d.id_direccion, d.id_usuario, d.id_ubigeo, d.direccion_exacta, d.referencia,
         d.latitud, d.longitud, u.distrito, u.provincia
    FROM Direccion_Cliente d
    JOIN Ubigeo u ON u.id_ubigeo = d.id_ubigeo`;

/** La dirección debe existir y ser del cliente que llama. */
async function buscarDireccionDelCliente(idDireccion, idUsuario, conexion = obtenerPool()) {
  if (!Number.isInteger(idDireccion) || idDireccion <= 0) {
    throw new HttpsError("invalid-argument", "Elige una dirección de entrega.");
  }
  const [filas] = await conexion.query(
    `${SELECT_DIRECCION} WHERE d.id_direccion = ? AND d.id_usuario = ?`,
    [idDireccion, idUsuario],
  );
  if (filas.length === 0) throw new HttpsError("not-found", "La dirección no existe.");
  return filas[0];
}

const COLUMNAS_BOTICA = `id_botica, id_botica_core, nombre, direccion, zona, latitud, longitud,
  hora_apertura_semana, hora_cierre_semana, hora_apertura_domingo, hora_cierre_domingo, hace_delivery`;

async function listarBoticas(conexion = obtenerPool()) {
  const [filas] = await conexion.query(`SELECT ${COLUMNAS_BOTICA} FROM Botica ORDER BY nombre`);
  return filas;
}

async function buscarBotica(idBotica, conexion = obtenerPool()) {
  const [filas] = await conexion.query(`SELECT ${COLUMNAS_BOTICA} FROM Botica WHERE id_botica = ?`, [idBotica]);
  return filas[0] ?? null;
}

/**
 * Botica que despacha el delivery (la única marcada con hace_delivery) y costo de
 * envío según la distancia. Si se pasan las líneas, esa botica debe tener todo el carrito.
 */
async function calcularEnvio(direccion, lineas = null, conexion = obtenerPool()) {
  const [filas] = await conexion.query(`SELECT ${COLUMNAS_BOTICA} FROM Botica WHERE hace_delivery = TRUE LIMIT 1`);
  const botica = filas[0];
  if (!botica) throw new HttpsError("unavailable", "El delivery no está disponible por ahora. Elige recojo en tienda.");
  const km = distanciaEnKm(direccion.latitud, direccion.longitud, botica.latitud, botica.longitud);
  if (km > RADIO_MAXIMO_KM) {
    throw new HttpsError("failed-precondition", "Tu dirección está fuera de nuestra zona de delivery.");
  }
  const faltan = lineas ? faltantesEn(lineas, botica.id_botica_core) : [];
  if (faltan.length > 0) {
    throw new HttpsError("failed-precondition",
      `Para delivery no hay stock de: ${faltan.map((l) => l.nombre).join(", ")}. Quita esos productos o elige recojo en tienda.`);
  }
  const extra = Math.max(0, km - KM_INCLUIDOS) * TARIFA_POR_KM;
  const costo = Math.round((TARIFA_BASE + extra) * 10) / 10; // redondeo a S/ 0.10
  return { costo, distanciaKm: Math.round(km * 10) / 10, botica };
}

/** Distancia en línea recta entre dos coordenadas (fórmula de Haversine). */
function distanciaEnKm(lat1, lon1, lat2, lon2) {
  const rad = (g) => (g * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLon = rad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function coordenadasValidas(lat, lon) {
  return typeof lat === "number" && typeof lon === "number" &&
    Math.abs(lat) <= 90 && Math.abs(lon) <= 180;
}

function boticaAJson(b) {
  return {
    id: b.id_botica,
    codigo: b.id_botica_core,
    nombre: b.nombre,
    direccion: b.direccion,
    latitud: b.latitud,
    longitud: b.longitud,
    horario: textoHorario(b),
    haceDelivery: Boolean(b.hace_delivery),
  };
}

/** "Lun-Sáb 7:00 a. m. - 11:00 p. m. · Dom y feriados 8:00 a. m. - 10:00 p. m." */
function textoHorario(b) {
  if (!b.hora_apertura_semana && !b.hora_apertura_domingo) return "Horario por confirmar";
  const tramo = (abre, cierra) => (abre && cierra ? `${hora12(abre)} - ${hora12(cierra)}` : "cerrado");
  return `Lun-Sáb ${tramo(b.hora_apertura_semana, b.hora_cierre_semana)} · `
    + `Dom y feriados ${tramo(b.hora_apertura_domingo, b.hora_cierre_domingo)}`;
}

/** "22:30:00" -> "10:30 p. m." */
function hora12(texto) {
  const [h, m] = String(texto).split(":").map(Number);
  const sufijo = h < 12 ? "a. m." : "p. m.";
  return `${h % 12 === 0 ? 12 : h % 12}:${String(m).padStart(2, "0")} ${sufijo}`;
}

function direccionAJson(d) {
  return {
    id: d.id_direccion,
    idUbigeo: d.id_ubigeo,
    distrito: d.distrito,
    direccionExacta: d.direccion_exacta,
    referencia: d.referencia,
    latitud: d.latitud,
    longitud: d.longitud,
  };
}

module.exports.buscarDireccionDelCliente = buscarDireccionDelCliente;
module.exports.calcularEnvio = calcularEnvio;
module.exports.buscarBotica = buscarBotica;
module.exports.boticaAJson = boticaAJson;
module.exports.textoHorario = textoHorario;
