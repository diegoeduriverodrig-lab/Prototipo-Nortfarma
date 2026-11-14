import '../models/producto.dart';
import '../services/catalogo_service.dart';
import 'base_viewmodel.dart';

/// Detalle de un producto: vuelve a consultar precio, descuento y stock en tiempo real.
/// El cliente elige la presentación (caja, blíster o unidad) y la cantidad.
class ProductoDetalleViewModel extends BaseViewModel {
  ProductoDetalleViewModel(this._catalogo, this.idProducto, {Producto? inicial})
    : _producto = inicial {
    _elegirPresentacionInicial();
    cargar();
  }

  final CatalogoService _catalogo;
  final int idProducto;

  Producto? _producto;
  TipoPresentacion _tipo = TipoPresentacion.empaque;
  bool _eligioCliente = false;
  int _cantidad = 1;

  /// Mientras carga se muestra el producto que venía de la lista.
  Producto? get producto => _producto;
  int get cantidad => _cantidad;
  TipoPresentacion get tipo => _tipo;

  /// Presentación elegida (null si el sistema de Nortfarma no dio precios).
  Presentacion? get presentacion => _producto?.presentacion(_tipo);

  bool get puedeComprar => presentacion?.disponible ?? false;
  bool get puedeSumar => _cantidad < (presentacion?.stock ?? 0);
  bool get puedeRestar => _cantidad > 1;

  double? get subtotal {
    final precio = presentacion?.precio;
    return precio == null ? null : precio * _cantidad;
  }

  Future<void> cargar() => ejecutar(() async {
    _producto = await _catalogo.obtenerProducto(idProducto);
    _elegirPresentacionInicial();
    _ajustarCantidad();
  });

  void elegirPresentacion(TipoPresentacion tipo) {
    if (_producto?.presentacion(tipo) == null) return;
    _tipo = tipo;
    _eligioCliente = true;
    _cantidad = 1;
    notifyListeners();
  }

  void sumar() {
    if (!puedeSumar) return;
    _cantidad++;
    notifyListeners();
  }

  void restar() {
    if (!puedeRestar) return;
    _cantidad--;
    notifyListeners();
  }

  /// Respeta la presentación que eligió el cliente; si no eligió, la primera con stock.
  void _elegirPresentacionInicial() {
    final p = _producto;
    if (p == null || p.presentaciones.isEmpty) return;
    final actual = p.presentacion(_tipo);
    if (actual != null && (_eligioCliente || actual.disponible)) return;
    _tipo = p.presentaciones
        .firstWhere((x) => x.disponible, orElse: () => p.presentaciones.first)
        .tipo;
  }

  /// Si el stock bajó mientras tanto, la cantidad no puede superarlo.
  void _ajustarCantidad() {
    final stock = presentacion?.stock ?? 0;
    if (_cantidad > stock) _cantidad = stock < 1 ? 1 : stock;
  }
}
