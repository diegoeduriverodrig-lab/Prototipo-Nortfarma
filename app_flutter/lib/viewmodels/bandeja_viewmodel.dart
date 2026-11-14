import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/seguimiento.dart';
import '../services/api_service.dart';
import '../services/seguimiento_service.dart';

/// Bandeja del Encargado de botica (RF07). Se actualiza sola cada cierto tiempo
/// y avisa cuando entra un pedido nuevo (notificación simulada).
class BandejaViewModel extends ChangeNotifier {
  BandejaViewModel(this._seguimiento, {Duration intervalo = const Duration(seconds: 20)}) {
    cargar();
    _temporizador = Timer.periodic(intervalo, (_) => cargar(silencioso: true));
  }

  final SeguimientoService _seguimiento;
  late final Timer _temporizador;

  Bandeja? _bandeja;
  int? _idEstado;
  bool _cargando = false;
  String? _error;
  bool _cerrado = false;

  /// Ids ya vistos, para detectar pedidos nuevos.
  Set<int>? _conocidos;
  final List<PedidoResumen> _nuevos = [];

  Bandeja? get bandeja => _bandeja;
  int? get idEstado => _idEstado;
  bool get cargando => _cargando;
  String? get error => _error;
  List<PedidoResumen> get pedidos => _bandeja?.pedidos ?? const [];

  int cantidadEn(int idEstado) =>
      _bandeja?.conteos.where((c) => c.id == idEstado).firstOrNull?.cantidad ?? 0;

  int get total => _bandeja?.conteos.fold<int>(0, (s, c) => s + c.cantidad) ?? 0;

  /// Pedidos nuevos detectados desde la última vez que la vista los leyó.
  List<PedidoResumen> tomarNuevos() {
    final lista = List<PedidoResumen>.of(_nuevos);
    _nuevos.clear();
    return lista;
  }

  void filtrar(int? idEstado) {
    _idEstado = idEstado;
    cargar();
  }

  Future<void> cargar({bool silencioso = false}) async {
    if (_cargando) return;
    _cargando = true;
    if (!silencioso) {
      _error = null;
      _notificar();
    }
    try {
      final bandeja = await _seguimiento.bandeja(idEstado: _idEstado);
      _detectarNuevos(bandeja);
      _bandeja = bandeja;
      _error = null;
    } on ApiException catch (e) {
      if (!silencioso) _error = e.mensaje;
    } finally {
      _cargando = false;
      _notificar();
    }
  }

  void _detectarNuevos(Bandeja bandeja) {
    final ids = bandeja.pedidos.map((p) => p.idPedido).toSet();
    final conocidos = _conocidos;
    if (conocidos != null) {
      _nuevos.addAll(
        bandeja.pedidos.where(
          (p) => !conocidos.contains(p.idPedido) && p.estado.id == EstadoPedido.procesando,
        ),
      );
    }
    _conocidos = {...?conocidos, ...ids};
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _temporizador.cancel();
    super.dispose();
  }
}
