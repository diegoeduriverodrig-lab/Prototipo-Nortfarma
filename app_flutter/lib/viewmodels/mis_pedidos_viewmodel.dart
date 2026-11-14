import '../models/seguimiento.dart';
import '../services/seguimiento_service.dart';
import 'base_viewmodel.dart';

/// Historial de pedidos del cliente (RF03).
class MisPedidosViewModel extends BaseViewModel {
  MisPedidosViewModel(this._seguimiento);

  final SeguimientoService _seguimiento;

  List<PedidoResumen> _pedidos = const [];
  bool _cargadoAlgunaVez = false;

  List<PedidoResumen> get pedidos => _pedidos;
  bool get cargadoAlgunaVez => _cargadoAlgunaVez;

  Future<void> cargar() async {
    await ejecutar(() async => _pedidos = await _seguimiento.misPedidos());
    _cargadoAlgunaVez = true;
    notifyListeners();
  }
}

/// Detalle de un pedido (cliente). Solo lectura.
class PedidoDetalleViewModel extends BaseViewModel {
  PedidoDetalleViewModel(this._seguimiento, this.idPedido) {
    cargar();
  }

  final SeguimientoService _seguimiento;
  final int idPedido;

  PedidoDetalle? _pedido;
  PedidoDetalle? get pedido => _pedido;

  Future<void> cargar() => ejecutar(() async => _pedido = await _seguimiento.obtenerPedido(idPedido));
}
