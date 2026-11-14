import 'package:flutter/foundation.dart';

import '../models/pedido.dart';
import '../models/producto.dart';
import '../services/carrito_local_service.dart';

/// Resultado de intentar añadir un producto.
enum ResultadoAgregar { agregado, sinStock, superaStock }

/// Carrito de compras (RNF07): se guarda en el celular, un carrito por usuario.
/// Cada línea es un producto en una presentación (caja, blíster o unidad).
class CarritoViewModel extends ChangeNotifier {
  CarritoViewModel(this._almacen);

  final CarritoLocalService _almacen;

  String? _uid;
  List<ItemCarrito> _items = const [];

  List<ItemCarrito> get items => _items;
  bool get vacio => _items.isEmpty;
  int get cantidadTotal => _items.fold(0, (s, i) => s + i.cantidad);
  double get subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  bool get requiereReceta => _items.any((i) => i.requiereReceta);
  bool get hayProblemasDeStock => _items.any((i) => i.sinStockSuficiente);

  int cantidadDe(int idProducto, [TipoPresentacion presentacion = TipoPresentacion.empaque]) {
    final clave = ItemCarrito.claveDe(idProducto, presentacion);
    for (final i in _items) {
      if (i.clave == clave) return i.cantidad;
    }
    return 0;
  }

  /// Cambia de usuario (al iniciar o cerrar sesión) y carga su carrito.
  /// Se llama desde ProxyProvider.update (durante el build), por eso
  /// los avisos a la vista se hacen después de un `await`.
  Future<void> usarUsuario(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    _items = const [];
    final guardados = uid == null ? <ItemCarrito>[] : await _almacen.leer(uid);
    await Future<void>.value();
    if (_uid != uid) return; // cambió de usuario mientras se leía
    _items = guardados;
    notifyListeners();
  }

  /// Añade [cantidad] de la presentación elegida (por defecto, el empaque).
  ResultadoAgregar agregar(Producto producto, int cantidad, [TipoPresentacion tipo = TipoPresentacion.empaque]) {
    final presentacion = producto.presentacion(tipo);
    if (presentacion == null || !presentacion.disponible) return ResultadoAgregar.sinStock;
    final stock = presentacion.stock;

    final actual = cantidadDe(producto.idProducto, tipo);
    final nueva = actual + cantidad;
    final resultado = nueva > stock ? ResultadoAgregar.superaStock : ResultadoAgregar.agregado;
    final item = ItemCarrito(
      idProducto: producto.idProducto,
      nombre: producto.nombre,
      presentacion: tipo,
      nombrePresentacion: presentacion.nombre,
      precio: presentacion.precio,
      precioRegular: presentacion.precioRegular,
      requiereReceta: producto.requiereReceta,
      stock: stock,
      cantidad: nueva > stock ? stock : nueva,
    );
    _items = actual == 0 ? [..._items, item] : [for (final i in _items) i.clave == item.clave ? item : i];
    _guardar();
    return resultado;
  }

  void cambiarCantidad(String clave, int cantidad) {
    if (cantidad <= 0) {
      quitar(clave);
      return;
    }
    _items = [
      for (final i in _items)
        i.clave == clave ? i.copiar(cantidad: cantidad.clamp(1, i.stock < 1 ? 1 : i.stock)) : i,
    ];
    _guardar();
  }

  void quitar(String clave) {
    _items = _items.where((i) => i.clave != clave).toList();
    _guardar();
  }

  void vaciar() {
    _items = const [];
    _guardar();
  }

  /// Actualiza precios, descuentos y stock con lo que confirmó el backend.
  void aplicarValidacion(ValidacionCarrito validacion) {
    final porClave = {for (final l in validacion.lineas) l.clave: l};
    _items = [
      for (final i in _items)
        if (porClave[i.clave] case final l?)
          i.copiar(precio: l.precio ?? i.precio, precioRegular: l.precioRegular ?? l.precio, stock: l.stock)
        else
          i,
    ];
    _guardar();
  }

  void _guardar() {
    notifyListeners();
    final uid = _uid;
    if (uid != null) _almacen.guardar(uid, _items);
  }
}
