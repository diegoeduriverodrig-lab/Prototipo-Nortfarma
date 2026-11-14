import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/producto.dart';
import '../services/api_service.dart';
import '../services/catalogo_service.dart';

/// Búsqueda del catálogo con filtros por categoría, disponibilidad y orden.
class CatalogoViewModel extends ChangeNotifier {
  CatalogoViewModel(this._catalogo) {
    _cargarCategorias();
    buscar();
  }

  final CatalogoService _catalogo;

  static const _esperaAlEscribir = Duration(milliseconds: 400);

  String _termino = '';
  int? _idCategoria;
  bool _soloDisponibles = false;
  OrdenCatalogo _orden = OrdenCatalogo.relevancia;

  List<Categoria> _categorias = const [];
  List<Producto> _productos = const [];
  bool _cargando = false;
  bool _coreDisponible = true;
  String? _error;

  Timer? _espera;
  int _peticion = 0;
  bool _cerrado = false;

  String get termino => _termino;
  int? get idCategoria => _idCategoria;
  bool get soloDisponibles => _soloDisponibles;
  OrdenCatalogo get orden => _orden;
  List<Categoria> get categorias => _categorias;
  List<Producto> get productos => _productos;
  bool get cargando => _cargando;
  bool get coreDisponible => _coreDisponible;
  String? get error => _error;

  String? get nombreCategoria {
    for (final c in _categorias) {
      if (c.id == _idCategoria) return c.nombre;
    }
    return null;
  }

  /// Al escribir: espera a que el usuario deje de teclear para no saturar la API.
  void cambiarTermino(String termino) {
    _termino = termino;
    _espera?.cancel();
    _espera = Timer(_esperaAlEscribir, buscar);
  }

  void cambiarCategoria(int? idCategoria) {
    _idCategoria = idCategoria;
    buscar();
  }

  void cambiarSoloDisponibles(bool valor) {
    _soloDisponibles = valor;
    buscar();
  }

  void cambiarOrden(OrdenCatalogo orden) {
    _orden = orden;
    buscar();
  }

  /// Usado desde Inicio (buscador o categoría) para abrir el catálogo ya filtrado.
  void aplicar({String termino = '', int? idCategoria}) {
    _termino = termino;
    _idCategoria = idCategoria;
    _versionExterna++;
    buscar();
  }

  /// Cambia cuando los filtros se fijan desde fuera, para que la vista
  /// actualice el texto del buscador.
  int get versionExterna => _versionExterna;
  int _versionExterna = 0;

  Future<void> buscar() async {
    _espera?.cancel();
    final peticion = ++_peticion;
    _cargando = true;
    _error = null;
    _notificar();
    try {
      final resultado = await _catalogo.buscar(
        termino: _termino,
        idCategoria: _idCategoria,
        soloDisponibles: _soloDisponibles,
        orden: _orden,
      );
      if (peticion != _peticion) return;
      _productos = resultado.productos;
      _coreDisponible = resultado.coreDisponible;
    } on ApiException catch (e) {
      if (peticion != _peticion) return;
      _error = e.mensaje;
    } finally {
      if (peticion == _peticion) {
        _cargando = false;
        _notificar();
      }
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      _categorias = await _catalogo.obtenerCategorias();
      _notificar();
    } on ApiException {
      // Sin categorías se puede seguir buscando por nombre.
    }
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _espera?.cancel();
    super.dispose();
  }
}
