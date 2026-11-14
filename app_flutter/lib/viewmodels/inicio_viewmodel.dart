import '../models/producto.dart';
import '../services/catalogo_service.dart';
import 'base_viewmodel.dart';

/// Pantalla de Inicio del cliente: categorías y ofertas (descuentos vigentes en Nortfarma).
/// Si no hay ofertas, muestra productos disponibles.
class InicioViewModel extends BaseViewModel {
  InicioViewModel(this._catalogo) {
    cargar();
  }

  final CatalogoService _catalogo;

  static const _cantidadDestacados = 6;

  List<Categoria> _categorias = const [];
  List<Producto> _destacados = const [];

  bool _sonOfertas = false;

  List<Categoria> get categorias => _categorias;
  List<Producto> get destacados => _destacados;

  /// true si [destacados] son productos en oferta.
  bool get sonOfertas => _sonOfertas;

  Future<void> cargar() => ejecutar(() async {
    // Las dos consultas en paralelo; si una falla se muestra ese error.
    final respuestas = await Future.wait<Object>([
      _catalogo.obtenerCategorias(),
      _catalogo.buscar(soloDisponibles: true, soloOfertas: true, limite: _cantidadDestacados),
    ], eagerError: true);
    _categorias = respuestas[0] as List<Categoria>;
    _destacados = (respuestas[1] as ResultadoCatalogo).productos;
    _sonOfertas = _destacados.isNotEmpty;
    if (!_sonOfertas) {
      _destacados = (await _catalogo.buscar(soloDisponibles: true, limite: _cantidadDestacados)).productos;
    }
  });
}
