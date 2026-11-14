const { setGlobalOptions } = require("firebase-functions");

// Límite de instancias para controlar costos.
setGlobalOptions({ maxInstances: 10 });

/**
 * Registra solo las Cloud Functions de un módulo (las que tienen __endpoint);
 * los módulos también exportan funciones auxiliares que no son API.
 */
function registrar(modulo) {
  for (const [nombre, valor] of Object.entries(modulo)) {
    if (valor && valor.__endpoint) exports[nombre] = valor;
  }
}

// Cada módulo agrupa las funciones de un tema (una por sprint o requisito).
registrar(require("./src/salud"));
registrar(require("./src/perfil")); // Sprint 1: perfil y rol del usuario
registrar(require("./src/catalogo")); // Sprint 2: catálogo y búsqueda
registrar(require("./src/entrega")); // Sprint 3: boticas, direcciones y envío
registrar(require("./src/recetas")); // Sprint 3: recetas médicas (RF14)
registrar(require("./src/imagenes")); // Fotos de productos y evidencias de entrega
registrar(require("./src/pedidos")); // Sprint 3: carrito y registro de pedidos
registrar(require("./src/seguimiento")); // RF03: mis pedidos y detalle de pedido
registrar(require("./src/encargado")); // Sprint 4: bandeja, estados y repartidor
registrar(require("./src/repartidor")); // Sprint 4: entregas del repartidor
registrar(require("./src/admin")); // Sprint 4: panel, personal y catálogo del administrador
registrar(require("./src/sincronizacion")); // Copia diaria de productos y boticas desde Nortfarma
registrar(require("./src/core_mock")); // Mock API del Sistema de Nortfarma (solo prototipo)
