import '../models/seguimiento.dart';
import '../services/seguimiento_service.dart';
import 'base_viewmodel.dart';

/// Acción disponible para el encargado según el estado del pedido.
enum AccionEncargado {
  empaquetar,
  asignarRepartidor,
  enviar,
  listoParaRecoger,
  entregarEnTienda,
  marcarEntregado,
  marcarFallido,
}

/// Detalle operativo del pedido para el Encargado de botica (RF05, RF06).
/// La receta médica solo se muestra (foto adjunta): no se valida.
/// Las reglas definitivas las valida el backend; aquí solo se decide qué botones mostrar.
class EncargadoPedidoViewModel extends BaseViewModel {
  EncargadoPedidoViewModel(this._seguimiento, this.idPedido) {
    cargar();
  }

  final SeguimientoService _seguimiento;
  final int idPedido;

  PedidoDetalle? _pedido;
  List<Repartidor> _repartidores = const [];
  String? _mensaje;

  PedidoDetalle? get pedido => _pedido;
  List<Repartidor> get repartidores => _repartidores;

  /// Confirmación de la última acción (para mostrarla y limpiarla).
  String? tomarMensaje() {
    final m = _mensaje;
    _mensaje = null;
    return m;
  }

  List<AccionEncargado> get acciones {
    final p = _pedido;
    if (p == null) return const [];
    return switch (p.estado.id) {
      EstadoPedido.procesando => [AccionEncargado.empaquetar, AccionEncargado.marcarFallido],
      EstadoPedido.empaquetado => [
        if (p.esDelivery && p.repartidor == null) AccionEncargado.asignarRepartidor,
        if (p.esDelivery && p.repartidor != null) AccionEncargado.enviar,
        if (!p.esDelivery) AccionEncargado.listoParaRecoger,
        AccionEncargado.marcarFallido,
      ],
      EstadoPedido.enCamino => [AccionEncargado.marcarEntregado, AccionEncargado.marcarFallido],
      EstadoPedido.listoRecoger => [AccionEncargado.entregarEnTienda, AccionEncargado.marcarFallido],
      _ => const [],
    };
  }

  Future<void> cargar() => ejecutar(() async => _pedido = await _seguimiento.obtenerPedido(idPedido));

  Future<void> cargarRepartidores() =>
      ejecutar(() async => _repartidores = await _seguimiento.listarRepartidores());

  Future<bool> cambiarEstado(int idEstado, String confirmacion, {String? motivo, String? dniCliente}) =>
      _accion(
        () => _seguimiento.actualizarEstado(idPedido, idEstado, motivo: motivo, dniCliente: dniCliente),
        confirmacion,
      );

  Future<bool> asignarRepartidor(Repartidor repartidor) => _accion(
    () => _seguimiento.asignarRepartidor(idPedido, repartidor.id),
    'Pedido asignado a ${repartidor.nombre}',
  );

  /// Ejecuta la acción y vuelve a cargar el pedido para mostrar el estado real.
  Future<bool> _accion(Future<void> Function() accion, String confirmacion) async {
    final ok = await ejecutar(() async {
      await accion();
      _pedido = await _seguimiento.obtenerPedido(idPedido);
    });
    if (ok) {
      _mensaje = confirmacion;
      notifyListeners();
    }
    return ok;
  }
}
