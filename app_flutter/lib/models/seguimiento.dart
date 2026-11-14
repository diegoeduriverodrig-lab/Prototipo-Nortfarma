/// Modelos de consulta y gestión de pedidos (RF03, Sprint 4).
library;

double _aDouble(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime _aFecha(Object? v) => DateTime.tryParse(v as String? ?? '')?.toLocal() ?? DateTime.now();

/// Ids de la tabla Estado_Pedido.
class EstadoPedido {
  static const procesando = 1;
  static const empaquetado = 2;
  static const enCamino = 3;
  static const listoRecoger = 4;
  static const entregado = 5;
  static const fallido = 6;

  /// Todos los estados, en el orden del flujo (para filtros).
  static const todos = [
    EstadoPedido(id: procesando, nombre: 'Procesando'),
    EstadoPedido(id: empaquetado, nombre: 'Empaquetado'),
    EstadoPedido(id: enCamino, nombre: 'En camino'),
    EstadoPedido(id: listoRecoger, nombre: 'Listo para recoger'),
    EstadoPedido(id: entregado, nombre: 'Entregado'),
    EstadoPedido(id: fallido, nombre: 'Fallido'),
  ];

  const EstadoPedido({required this.id, required this.nombre});

  factory EstadoPedido.desdeJson(Map<String, dynamic> json) =>
      EstadoPedido(id: json['id'] as int, nombre: json['nombre'] as String);

  final int id;
  final String nombre;

  bool get finalizado => id == entregado || id == fallido;
}

class PedidoResumen {
  const PedidoResumen({
    required this.idPedido,
    required this.numero,
    required this.fecha,
    required this.estado,
    required this.tipoEntrega,
    required this.total,
    required this.productos,
    required this.cliente,
    this.estadoPago,
    this.tieneReceta = false,
    this.direccion,
    this.botica,
    this.tipoPago,
  });

  factory PedidoResumen.desdeJson(Map<String, dynamic> json) => PedidoResumen(
    idPedido: json['idPedido'] as int,
    numero: json['numero'] as String,
    fecha: _aFecha(json['fecha']),
    estado: EstadoPedido.desdeJson(json['estado'] as Map<String, dynamic>),
    tipoEntrega: json['tipoEntrega'] as String,
    total: _aDouble(json['total']),
    productos: json['productos'] as int? ?? 0,
    cliente: json['cliente'] as String? ?? '',
    estadoPago: json['estadoPago'] as String?,
    tieneReceta: json['tieneReceta'] as bool? ?? false,
    direccion: json['direccion'] as String?,
    botica: json['botica'] as String?,
    tipoPago: json['tipoPago'] as String?,
  );

  final int idPedido;
  final String numero;
  final DateTime fecha;
  final EstadoPedido estado;
  final String tipoEntrega;
  final double total;

  /// Cantidad de líneas del pedido (producto + presentación).
  final int productos;
  final String cliente;

  /// "Pendiente", "Aprobado" o "Fallido".
  final String? estadoPago;

  /// El cliente adjuntó la foto de una receta médica.
  final bool tieneReceta;

  /// Dirección de entrega (solo delivery).
  final String? direccion;
  final String? botica;
  final String? tipoPago;

  bool get esDelivery => tipoEntrega == 'Delivery';

  /// El repartidor o la botica debe cobrar al entregar.
  bool get cobrarAlEntregar => estadoPago == 'Pendiente';
}

/// Entregas del repartidor.
class Entregas {
  const Entregas({
    required this.activas,
    required this.recientes,
    required this.motivosFallo,
    this.tiposIncidencia = const [],
  });

  factory Entregas.desdeJson(Map<String, dynamic> json) {
    List<PedidoResumen> lista(String clave) => (json[clave] as List)
        .map((p) => PedidoResumen.desdeJson(p as Map<String, dynamic>))
        .toList();
    return Entregas(
      activas: lista('activas'),
      recientes: lista('recientes'),
      motivosFallo: (json['motivosFallo'] as List).cast<String>(),
      tiposIncidencia: (json['tiposIncidencia'] as List? ?? const []).cast<String>(),
    );
  }

  final List<PedidoResumen> activas;
  final List<PedidoResumen> recientes;
  final List<String> motivosFallo;

  /// Incidencias que no terminan la entrega (retraso, cliente no responde...).
  final List<String> tiposIncidencia;
}

class ItemPedido {
  const ItemPedido({
    required this.nombre,
    required this.cantidad,
    required this.total,
    required this.requiereReceta,
    this.presentacion = '',
    this.precioUnitario = 0,
    this.descuento = 0,
  });

  factory ItemPedido.desdeJson(Map<String, dynamic> json) => ItemPedido(
    nombre: json['nombre'] as String,
    presentacion: json['nombrePresentacion'] as String? ?? '',
    cantidad: json['cantidad'] as int,
    precioUnitario: _aDouble(json['precioUnitario']),
    descuento: _aDouble(json['descuento']),
    total: _aDouble(json['total']),
    requiereReceta: json['requiereReceta'] as bool? ?? false,
  );

  final String nombre;

  /// "Caja x 100 tabletas", "Blíster x 10" o "Unidad".
  final String presentacion;
  final int cantidad;

  /// Precio unitario pagado (histórico, ya con descuento).
  final double precioUnitario;

  /// Porcentaje de descuento aplicado (0 si no hubo).
  final double descuento;
  final double total;
  final bool requiereReceta;
}

class CambioEstado {
  const CambioEstado({required this.estado, required this.fecha, this.motivo, this.responsable});

  factory CambioEstado.desdeJson(Map<String, dynamic> json) => CambioEstado(
    estado: EstadoPedido.desdeJson(json['estado'] as Map<String, dynamic>),
    fecha: _aFecha(json['fecha']),
    motivo: json['motivo'] as String?,
    responsable: json['responsable'] as String?,
  );

  final EstadoPedido estado;
  final DateTime fecha;
  final String? motivo;
  final String? responsable;
}

class PersonaPedido {
  const PersonaPedido({required this.nombre, this.dni, this.telefono, this.id});

  factory PersonaPedido.desdeJson(Map<String, dynamic> json) => PersonaPedido(
    id: json['id'] as int?,
    nombre: json['nombre'] as String,
    dni: json['dni'] as String?,
    telefono: json['telefono'] as String?,
  );

  final int? id;
  final String nombre;
  final String? dni;
  final String? telefono;
}

/// Detalle completo del pedido.
class PedidoDetalle {
  const PedidoDetalle({
    required this.idPedido,
    required this.numero,
    required this.fecha,
    required this.estado,
    required this.tipoEntrega,
    required this.items,
    required this.historial,
    required this.costoEnvio,
    required this.total,
    required this.comprobante,
    required this.tipoPago,
    this.numeroComprobante,
    this.idTipoPago,
    this.ruc,
    this.razonSocial,
    this.boticaNombre,
    this.boticaDireccion,
    this.direccion,
    this.estadoPago,
    this.recetaRuta,
    this.cliente,
    this.repartidor,
    this.latitudDestino,
    this.longitudDestino,
    this.latitudBotica,
    this.longitudBotica,
    this.entrega,
  });

  factory PedidoDetalle.desdeJson(Map<String, dynamic> json) {
    final botica = json['botica'] as Map<String, dynamic>?;
    final direccion = json['direccion'] as Map<String, dynamic>?;
    final comprobante = json['comprobante'] as Map<String, dynamic>;
    final pago = json['pago'] as Map<String, dynamic>?;
    final receta = json['receta'] as Map<String, dynamic>?;
    final cliente = json['cliente'] as Map<String, dynamic>?;
    final repartidor = json['repartidor'] as Map<String, dynamic>?;
    final entrega = json['entrega'] as Map<String, dynamic>?;
    return PedidoDetalle(
      idPedido: json['idPedido'] as int,
      numero: json['numero'] as String,
      fecha: _aFecha(json['fecha']),
      estado: EstadoPedido.desdeJson(json['estado'] as Map<String, dynamic>),
      tipoEntrega: json['tipoEntrega'] as String,
      items: (json['items'] as List).map((i) => ItemPedido.desdeJson(i as Map<String, dynamic>)).toList(),
      historial: (json['historial'] as List)
          .map((h) => CambioEstado.desdeJson(h as Map<String, dynamic>))
          .toList(),
      costoEnvio: _aDouble(json['costoEnvio']),
      total: _aDouble(json['total']),
      comprobante: comprobante['tipo'] as String,
      numeroComprobante: comprobante['numero'] as String?,
      ruc: comprobante['ruc'] as String?,
      razonSocial: comprobante['razonSocial'] as String?,
      tipoPago: json['tipoPago'] as String,
      idTipoPago: json['idTipoPago'] as int?,
      boticaNombre: botica?['nombre'] as String?,
      boticaDireccion: botica?['direccion'] as String?,
      direccion: direccion == null
          ? null
          : [
              direccion['direccionExacta'],
              direccion['distrito'],
              if (direccion['referencia'] != null) 'Ref.: ${direccion['referencia']}',
            ].join(' · '),
      estadoPago: pago?['estado'] as String?,
      recetaRuta: receta?['ruta'] as String?,
      cliente: cliente == null ? null : PersonaPedido.desdeJson(cliente),
      repartidor: repartidor == null ? null : PersonaPedido.desdeJson(repartidor),
      latitudDestino: (direccion?['latitud'] as num?)?.toDouble(),
      longitudDestino: (direccion?['longitud'] as num?)?.toDouble(),
      latitudBotica: (botica?['latitud'] as num?)?.toDouble(),
      longitudBotica: (botica?['longitud'] as num?)?.toDouble(),
      entrega: entrega == null ? null : InfoEntrega.desdeJson(entrega),
    );
  }

  final int idPedido;
  final String numero;
  final DateTime fecha;
  final EstadoPedido estado;
  final String tipoEntrega;
  final List<ItemPedido> items;
  final List<CambioEstado> historial;
  final double costoEnvio;
  final double total;
  final String comprobante;

  /// Serie-correlativo asignado por Nortfarma (B901-00000001).
  final String? numeroComprobante;
  final String? ruc;
  final String? razonSocial;
  final String tipoPago;
  final String? boticaNombre;
  final String? boticaDireccion;

  /// Dirección de entrega en una línea (solo delivery).
  final String? direccion;
  final String? estadoPago;

  /// Foto de la receta médica (null si el pedido no la necesita).
  final String? recetaRuta;

  /// Solo lo recibe el personal (no el propio cliente).
  final PersonaPedido? cliente;
  final PersonaPedido? repartidor;

  /// Ids de Tipo_Pago: 1 tarjeta, 2 Yape/Plin (en línea), 3 POS y 4 efectivo (contraentrega).
  final int? idTipoPago;

  /// Coordenadas de la dirección de entrega (delivery) y de la botica.
  final double? latitudDestino;
  final double? longitudDestino;
  final double? latitudBotica;
  final double? longitudBotica;

  /// Datos de la entrega a domicilio (null si es recojo o aún no tiene repartidor).
  final InfoEntrega? entrega;

  bool get tieneDestino => latitudDestino != null && longitudDestino != null;

  /// El cobro en línea fue rechazado y el pedido aún espera el pago.
  bool get puedeReintentarPago =>
      (idTipoPago == 1 || idTipoPago == 2) &&
      estadoPago == 'Fallido' &&
      estado.id == EstadoPedido.procesando;

  bool get esDelivery => tipoEntrega == 'Delivery';
  double get subtotal => total - costoEnvio;

  /// Motivo del último cambio a Fallido, para mostrarlo al cliente.
  String? get motivoFallo {
    for (final c in historial.reversed) {
      if (c.estado.id == EstadoPedido.fallido) return c.motivo;
    }
    return null;
  }
}

class ConteoEstado {
  const ConteoEstado({required this.id, required this.nombre, required this.cantidad});

  factory ConteoEstado.desdeJson(Map<String, dynamic> json) => ConteoEstado(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    cantidad: json['cantidad'] as int,
  );

  final int id;
  final String nombre;
  final int cantidad;
}

class Bandeja {
  const Bandeja({required this.botica, required this.pedidos, required this.conteos});

  factory Bandeja.desdeJson(Map<String, dynamic> json) => Bandeja(
    botica: json['botica'] as String? ?? '',
    pedidos: (json['pedidos'] as List)
        .map((p) => PedidoResumen.desdeJson(p as Map<String, dynamic>))
        .toList(),
    conteos: (json['conteos'] as List)
        .map((c) => ConteoEstado.desdeJson(c as Map<String, dynamic>))
        .toList(),
  );

  final String botica;
  final List<PedidoResumen> pedidos;
  final List<ConteoEstado> conteos;
}

class Repartidor {
  const Repartidor({required this.id, required this.nombre, required this.entregasActivas, this.telefono});

  factory Repartidor.desdeJson(Map<String, dynamic> json) => Repartidor(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    telefono: json['telefono'] as String?,
    entregasActivas: json['entregasActivas'] as int? ?? 0,
  );

  final int id;
  final String nombre;
  final String? telefono;
  final int entregasActivas;

  bool get disponible => entregasActivas == 0;
}

DateTime? _aFechaOpcional(Object? v) => v == null ? null : DateTime.tryParse(v as String)?.toLocal();

/// Entrega a domicilio: horas de asignación, salida y entrega, evidencia e incidencias.
class InfoEntrega {
  const InfoEntrega({
    required this.fechaAsignacion,
    this.fechaSalida,
    this.fechaEntrega,
    this.evidencia,
    this.latitud,
    this.longitud,
    this.observacion,
    this.incidencias = const [],
  });

  factory InfoEntrega.desdeJson(Map<String, dynamic> json) => InfoEntrega(
    fechaAsignacion: _aFecha(json['fechaAsignacion']),
    fechaSalida: _aFechaOpcional(json['fechaSalida']),
    fechaEntrega: _aFechaOpcional(json['fechaEntrega']),
    evidencia: json['evidencia'] as String?,
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
    observacion: json['observacion'] as String?,
    incidencias: (json['incidencias'] as List? ?? const [])
        .map((i) => IncidenciaEntrega.desdeJson(i as Map<String, dynamic>))
        .toList(),
  );

  final DateTime fechaAsignacion;
  final DateTime? fechaSalida;
  final DateTime? fechaEntrega;

  /// Ruta de la foto de la entrega (`evidencias/<id>.jpg`).
  final String? evidencia;

  /// Ubicación GPS del repartidor al confirmar la entrega.
  final double? latitud;
  final double? longitud;
  final String? observacion;
  final List<IncidenciaEntrega> incidencias;
}

class IncidenciaEntrega {
  const IncidenciaEntrega({required this.tipo, required this.fecha, this.detalle, this.terminaEntrega = false});

  factory IncidenciaEntrega.desdeJson(Map<String, dynamic> json) => IncidenciaEntrega(
    tipo: json['tipo'] as String,
    detalle: json['detalle'] as String?,
    terminaEntrega: json['terminaEntrega'] as bool? ?? false,
    fecha: _aFecha(json['fecha']),
  );

  final String tipo;
  final String? detalle;

  /// true: por esta incidencia la entrega se marcó como fallida.
  final bool terminaEntrega;
  final DateTime fecha;
}
