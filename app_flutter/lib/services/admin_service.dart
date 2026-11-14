import 'dart:convert';
import 'dart:typed_data';

import '../models/admin.dart';
import '../models/seguimiento.dart';
import 'api_service.dart';

/// Funciones del Administrador: panel, pedidos, personal (RF17) y catálogo.
class AdminService {
  AdminService(this._api);

  final ApiService _api;

  Future<ResumenAdmin> resumen() async => ResumenAdmin.desdeJson(await _api.llamar('resumenAdmin'));

  Future<List<PedidoResumen>> pedidos({int? idEstado, int? idBotica}) async {
    final r = await _api.llamar('todosLosPedidos', {'idEstado': ?idEstado, 'idBotica': ?idBotica});
    return (r['pedidos'] as List)
        .map((p) => PedidoResumen.desdeJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<(List<MiembroPersonal>, List<BoticaSimple>)> personal() async {
    final r = await _api.llamar('listarPersonal');
    return (
      (r['personal'] as List).map((p) => MiembroPersonal.desdeJson(p as Map<String, dynamic>)).toList(),
      (r['boticas'] as List).map((b) => BoticaSimple.desdeJson(b as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> crearPersonal(DatosPersonal datos) => _api.llamar('crearPersonal', datos.aJson());

  Future<void> actualizarPersonal(int idUsuario, DatosPersonal datos) =>
      _api.llamar('actualizarPersonal', {'idUsuario': idUsuario, ...datos.aJson()});

  Future<void> quitarAcceso(int idUsuario) =>
      _api.llamar('quitarAccesoPersonal', {'idUsuario': idUsuario});

  Future<List<ProductoAdmin>> productos() async {
    final r = await _api.llamar('listarProductosAdmin');
    return (r['productos'] as List)
        .map((p) => ProductoAdmin.desdeJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> actualizarProducto({
    required int idProducto,
    required int idCategoria,
    required bool aptoEcommerce,
    required String imagenUrl,
    String nombreApp = '',
  }) => _api.llamar('actualizarProducto', {
    'idProducto': idProducto,
    'idCategoria': idCategoria,
    'aptoEcommerce': aptoEcommerce,
    'imagenUrl': imagenUrl.trim(),
    'nombreApp': nombreApp.trim(),
  });

  /// Sube la foto de un producto y devuelve su ruta (`productos/<id>.jpg`).
  Future<String> subirImagenProducto(Uint8List bytes, String tipo) async {
    final r = await _api.llamar('subirImagenProducto', {'imagenBase64': base64Encode(bytes), 'tipo': tipo});
    return r['ruta'] as String;
  }

  /// Categorías (también las ocultas) y las claves de íconos disponibles.
  Future<(List<CategoriaAdmin>, List<String>)> categorias() async {
    final r = await _api.llamar('listarCategoriasAdmin');
    return (
      (r['categorias'] as List).map((c) => CategoriaAdmin.desdeJson(c as Map<String, dynamic>)).toList(),
      (r['iconos'] as List).cast<String>(),
    );
  }

  /// Crea la categoría si [idCategoria] es null; si no, la edita.
  Future<void> guardarCategoria({int? idCategoria, required String nombre, required String icono, required bool activa}) =>
      _api.llamar('guardarCategoria', {
        'idCategoria': ?idCategoria,
        'nombre': nombre.trim(),
        'icono': icono,
        'activa': activa,
      });

  Future<void> eliminarCategoria(int idCategoria) =>
      _api.llamar('eliminarCategoria', {'idCategoria': idCategoria});

  Future<ResultadoSincronizacion> sincronizarCatalogo() async =>
      ResultadoSincronizacion.desdeJson(await _api.llamar('sincronizarCatalogo'));
}
