import '../models/producto.dart';
import 'api_service.dart';

/// Catálogo de productos (Sprint 2). Precio, descuento y stock llegan en tiempo real desde la API.
class CatalogoService {
  CatalogoService(this._api);

  final ApiService _api;

  Future<List<Categoria>> obtenerCategorias() async {
    final r = await _api.llamar('obtenerCategorias');
    return (r['categorias'] as List)
        .map((c) => Categoria.desdeJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<ResultadoCatalogo> buscar({
    String termino = '',
    int? idCategoria,
    bool soloDisponibles = false,
    bool soloOfertas = false,
    OrdenCatalogo orden = OrdenCatalogo.relevancia,
    int? limite,
  }) async {
    final r = await _api.llamar('consultarCatalogo', {
      if (termino.trim().isNotEmpty) 'termino': termino.trim(),
      'idCategoria': ?idCategoria,
      'soloDisponibles': soloDisponibles,
      if (soloOfertas) 'soloOfertas': true,
      'orden': orden.valor,
      'limite': ?limite,
    });
    return ResultadoCatalogo(
      productos: (r['productos'] as List)
          .map((p) => Producto.desdeJson(p as Map<String, dynamic>))
          .toList(),
      coreDisponible: r['coreDisponible'] as bool? ?? false,
    );
  }

  Future<Producto> obtenerProducto(int idProducto) async {
    final r = await _api.llamar('obtenerProducto', {'idProducto': idProducto});
    return Producto.desdeJson(r['producto'] as Map<String, dynamic>);
  }
}
