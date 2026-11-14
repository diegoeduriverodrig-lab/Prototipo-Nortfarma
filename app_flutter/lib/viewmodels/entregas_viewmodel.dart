import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/seguimiento.dart';
import '../services/imagen_service.dart';
import '../services/seguimiento_service.dart';
import 'base_viewmodel.dart';

/// Entregas asignadas al repartidor (RF06, RF22). Se actualiza sola para
/// mostrar las nuevas asignaciones.
class EntregasViewModel extends BaseViewModel {
  EntregasViewModel(this._seguimiento, {Duration intervalo = const Duration(seconds: 30)}) {
    cargar();
    _temporizador = Timer.periodic(intervalo, (_) => cargar());
  }

  final SeguimientoService _seguimiento;
  late final Timer _temporizador;

  Entregas? _entregas;
  Entregas? get entregas => _entregas;

  Future<void> cargar() => ejecutar(() async => _entregas = await _seguimiento.misEntregas());

  @override
  void dispose() {
    _temporizador.cancel();
    super.dispose();
  }
}

/// Una entrega: detalle y acciones del repartidor (RF07).
/// Al entregar se toma una foto de evidencia (obligatoria) y, si se puede, la ubicación GPS.
class EntregaViewModel extends BaseViewModel {
  EntregaViewModel(
    this._seguimiento,
    this._imagenes,
    this.idPedido, {
    required this.motivosFallo,
    this.tiposIncidencia = const [],
  }) {
    cargar();
  }

  final SeguimientoService _seguimiento;
  final ImagenService _imagenes;
  final int idPedido;
  final List<String> motivosFallo;
  final List<String> tiposIncidencia;

  PedidoDetalle? _pedido;
  String? _mensaje;
  ImagenElegida? _foto;

  PedidoDetalle? get pedido => _pedido;

  /// Foto de la entrega tomada por el repartidor (aún sin subir).
  ImagenElegida? get foto => _foto;

  String? tomarMensaje() {
    final m = _mensaje;
    _mensaje = null;
    return m;
  }

  bool get puedeIniciar => _pedido?.estado.id == EstadoPedido.empaquetado;
  bool get enCamino => _pedido?.estado.id == EstadoPedido.enCamino;

  /// Monto a cobrar al entregar (contraentrega); null si ya está pagado.
  double? get montoACobrar => _pedido?.estadoPago == 'Pendiente' ? _pedido!.total : null;

  Future<void> cargar() => ejecutar(() async => _pedido = await _seguimiento.obtenerPedido(idPedido));

  Future<bool> iniciar() => _accion(EstadoPedido.enCamino, 'Entrega iniciada: en camino');

  /// Abre la cámara para la foto de evidencia. Devuelve false si se canceló.
  Future<bool> tomarFoto() async {
    final foto = await _imagenes.elegir(OrigenImagen.camara, anchoMaximo: 1200);
    if (foto == null) return false;
    _foto = foto;
    notifyListeners();
    return true;
  }

  /// Sube la foto, toma la ubicación GPS (si hay permiso) y marca el pedido como entregado.
  Future<bool> entregar({String? observacion}) async {
    final foto = _foto;
    if (foto == null) return false;
    final ok = await ejecutar(() async {
      final ruta = await _seguimiento.subirEvidencia(foto.bytes, foto.tipo);
      final ubicacion = await _ubicacionActual();
      await _seguimiento.actualizarEntrega(
        idPedido,
        EstadoPedido.entregado,
        evidenciaRuta: ruta,
        latitud: ubicacion?.$1,
        longitud: ubicacion?.$2,
        observacion: observacion?.trim().isEmpty ?? true ? null : observacion!.trim(),
      );
      _pedido = await _seguimiento.obtenerPedido(idPedido);
    });
    if (ok) {
      _foto = null;
      _mensaje = 'Pedido entregado';
      notifyListeners();
    }
    return ok;
  }

  Future<bool> reportarFallo(String motivo, String detalle) => _accion(
    EstadoPedido.fallido,
    'Entrega reportada como fallida',
    motivo: motivo,
    detalle: detalle.trim().isEmpty ? null : detalle.trim(),
  );

  /// Incidencia que no termina la entrega: queda registrada y la entrega sigue en curso.
  Future<bool> reportarIncidencia(String tipo, String detalle) async {
    final ok = await ejecutar(() async {
      await _seguimiento.reportarIncidencia(idPedido, tipo, detalle: detalle.trim().isEmpty ? null : detalle.trim());
      _pedido = await _seguimiento.obtenerPedido(idPedido);
    });
    if (ok) {
      _mensaje = 'Incidencia registrada';
      notifyListeners();
    }
    return ok;
  }

  Future<bool> _accion(int idEstado, String confirmacion, {String? motivo, String? detalle}) async {
    final ok = await ejecutar(() async {
      await _seguimiento.actualizarEntrega(idPedido, idEstado, motivo: motivo, detalle: detalle);
      _pedido = await _seguimiento.obtenerPedido(idPedido);
    });
    if (ok) {
      _mensaje = confirmacion;
      notifyListeners();
    }
    return ok;
  }

  /// Ubicación actual del celular; null si el GPS está apagado, sin permiso o tarda mucho.
  /// La entrega se registra igual: la ubicación es un dato de apoyo.
  Future<(double, double)?> _ubicacionActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      return (p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
