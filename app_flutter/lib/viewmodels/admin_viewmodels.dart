import '../core/validadores.dart';
import '../models/admin.dart';
import '../models/seguimiento.dart';
import '../models/usuario.dart';
import '../services/admin_service.dart';
import '../services/imagen_service.dart';
import 'base_viewmodel.dart';

/// Panel administrativo: indicadores y sincronización del catálogo.
class PanelAdminViewModel extends BaseViewModel {
  PanelAdminViewModel(this._admin) {
    cargar();
  }

  final AdminService _admin;

  ResumenAdmin? _resumen;
  ResultadoSincronizacion? _sincronizacion;

  ResumenAdmin? get resumen => _resumen;
  ResultadoSincronizacion? get sincronizacion => _sincronizacion;

  Future<void> cargar() => ejecutar(() async => _resumen = await _admin.resumen());

  Future<bool> sincronizar() => ejecutar(() async {
    _sincronizacion = await _admin.sincronizarCatalogo();
    _resumen = await _admin.resumen();
  });
}

/// Consulta de pedidos de todas las boticas.
class PedidosAdminViewModel extends BaseViewModel {
  PedidosAdminViewModel(this._admin) {
    cargar();
  }

  final AdminService _admin;

  List<PedidoResumen> _pedidos = const [];
  int? _idEstado;
  bool _cargado = false;

  List<PedidoResumen> get pedidos => _pedidos;
  int? get idEstado => _idEstado;
  bool get cargado => _cargado;

  void filtrar(int? idEstado) {
    _idEstado = idEstado;
    cargar();
  }

  Future<void> cargar() async {
    await ejecutar(() async => _pedidos = await _admin.pedidos(idEstado: _idEstado));
    _cargado = true;
    notifyListeners();
  }
}

/// Gestión del personal (RF17): crear, editar y quitar acceso.
class PersonalViewModel extends BaseViewModel {
  PersonalViewModel(this._admin) {
    cargar();
  }

  final AdminService _admin;

  List<MiembroPersonal> _personal = const [];
  List<BoticaSimple> _boticas = const [];
  bool _cargado = false;

  List<MiembroPersonal> get personal => _personal;
  List<BoticaSimple> get boticas => _boticas;
  bool get cargado => _cargado;

  Future<void> cargar() async {
    await ejecutar(_recargarPersonal);
    _cargado = true;
    notifyListeners();
  }

  String? validarNombres(String? v) => Validadores.requerido(v, 'nombre');
  String? validarApellidos(String? v) => Validadores.requerido(v, 'apellido');
  String? validarDni(String? v) => Validadores.dni(v);
  String? validarCelular(String? v) => Validadores.celular(v);
  String? validarCorreo(String? v) => Validadores.correo(v);
  String? validarContrasena(String? v) => Validadores.contrasena(v);
  String? validarBotica(Rol rol, int? idBotica) =>
      rol == Rol.encargado && idBotica == null ? 'Elige la botica del encargado' : null;

  /// Crea o actualiza; recarga la lista si salió bien.
  Future<bool> guardar(DatosPersonal datos, {MiembroPersonal? existente}) async {
    final ok = await ejecutar(() async {
      if (existente == null) {
        await _admin.crearPersonal(datos);
      } else {
        await _admin.actualizarPersonal(existente.idUsuario, datos);
      }
      await _recargarPersonal();
    });
    return ok;
  }

  Future<void> _recargarPersonal() async {
    final (personal, boticas) = await _admin.personal();
    _personal = personal;
    _boticas = boticas;
  }

  Future<bool> quitarAcceso(MiembroPersonal miembro) => ejecutar(() async {
    await _admin.quitarAcceso(miembro.idUsuario);
    await _recargarPersonal();
  });
}

/// Catálogo del Administrador: nombre en la app, categoría, venta en línea y foto de cada producto.
class ProductosAdminViewModel extends BaseViewModel {
  ProductosAdminViewModel(this._admin, this._imagenes) {
    cargar();
  }

  final AdminService _admin;
  final ImagenService _imagenes;

  List<ProductoAdmin> _productos = const [];
  List<CategoriaAdmin> _categorias = const [];
  String _filtro = '';
  bool _cargado = false;
  bool _subiendoFoto = false;

  /// Todas las categorías, también las ocultas (un producto puede estar en una).
  List<CategoriaAdmin> get categorias => _categorias;
  bool get cargado => _cargado;
  bool get subiendoFoto => _subiendoFoto;

  List<ProductoAdmin> get productos {
    final f = _filtro.trim().toLowerCase();
    if (f.isEmpty) return _productos;
    return _productos
        .where((p) =>
            p.nombre.toLowerCase().contains(f) ||
            p.nombreNortfarma.toLowerCase().contains(f) ||
            p.idProductoCore.toLowerCase().contains(f))
        .toList();
  }

  void filtrar(String texto) {
    _filtro = texto;
    notifyListeners();
  }

  Future<void> cargar() async {
    await ejecutar(() async {
      _productos = await _admin.productos();
      _categorias = (await _admin.categorias()).$1;
    });
    _cargado = true;
    notifyListeners();
  }

  /// Acepta un enlace http(s) o la ruta de una foto subida (productos/...).
  String? validarImagen(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty || t.startsWith('productos/')) return null;
    final uri = Uri.tryParse(t);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      return 'Debe ser un enlace http:// o https://';
    }
    return null;
  }

  String? validarNombreApp(String? v) {
    final t = v?.trim() ?? '';
    if (t.isNotEmpty && t.length < 3) return 'Escribe al menos 3 letras o déjalo vacío';
    return null;
  }

  /// Toma o elige la foto y la sube. Devuelve su ruta (o null si se canceló o falló).
  Future<String?> subirFoto(OrigenImagen origen) async {
    final imagen = await _imagenes.elegir(origen, anchoMaximo: 900);
    if (imagen == null) return null;
    String? ruta;
    _subiendoFoto = true;
    notifyListeners();
    await ejecutar(() async => ruta = await _admin.subirImagenProducto(imagen.bytes, imagen.tipo));
    _subiendoFoto = false;
    notifyListeners();
    return ruta;
  }

  Future<bool> guardar(ProductoAdmin producto, {
    required int idCategoria,
    required bool aptoEcommerce,
    required String imagenUrl,
    required String nombreApp,
  }) => ejecutar(() async {
    await _admin.actualizarProducto(
      idProducto: producto.idProducto,
      idCategoria: idCategoria,
      aptoEcommerce: aptoEcommerce,
      imagenUrl: imagenUrl,
      nombreApp: nombreApp,
    );
    _productos = await _admin.productos();
  });
}

/// Gestión de categorías: crear, editar, ocultar y eliminar (solo si no tienen productos).
class CategoriasAdminViewModel extends BaseViewModel {
  CategoriasAdminViewModel(this._admin) {
    cargar();
  }

  final AdminService _admin;

  List<CategoriaAdmin> _categorias = const [];
  List<String> _iconos = const [];
  bool _cargado = false;

  List<CategoriaAdmin> get categorias => _categorias;
  List<String> get iconos => _iconos;
  bool get cargado => _cargado;

  Future<void> cargar() async {
    await ejecutar(_recargar);
    _cargado = true;
    notifyListeners();
  }

  String? validarNombre(String? v, {int? idActual}) {
    final t = v?.trim() ?? '';
    if (t.length < 3) return 'Escribe al menos 3 letras';
    final repetida = _categorias.any((c) => c.id != idActual && c.nombre.toLowerCase() == t.toLowerCase());
    return repetida ? 'Ya existe una categoría con ese nombre' : null;
  }

  Future<bool> guardar({int? idCategoria, required String nombre, required String icono, required bool activa}) =>
      ejecutar(() async {
        await _admin.guardarCategoria(idCategoria: idCategoria, nombre: nombre, icono: icono, activa: activa);
        await _recargar();
      });

  /// Mostrar u ocultar al cliente sin cambiar lo demás.
  Future<bool> cambiarVisible(CategoriaAdmin c, bool activa) =>
      guardar(idCategoria: c.id, nombre: c.nombre, icono: c.icono, activa: activa);

  Future<bool> eliminar(CategoriaAdmin c) => ejecutar(() async {
    await _admin.eliminarCategoria(c.id);
    await _recargar();
  });

  Future<void> _recargar() async {
    final (categorias, iconos) = await _admin.categorias();
    _categorias = categorias;
    _iconos = iconos;
  }
}
