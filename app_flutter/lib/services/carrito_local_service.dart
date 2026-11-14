import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido.dart';

/// Guarda el carrito en el celular (RNF07): no se pierde si se cierra la app
/// o no hay internet. Hay un carrito por usuario.
class CarritoLocalService {
  CarritoLocalService({SharedPreferencesAsync? preferencias}) : _instancia = preferencias;

  SharedPreferencesAsync? _instancia;

  /// Se crea al primer uso (permite reemplazar este servicio en las pruebas).
  SharedPreferencesAsync get _preferencias => _instancia ??= SharedPreferencesAsync();

  String _clave(String uid) => 'carrito_$uid';

  Future<List<ItemCarrito>> leer(String uid) async {
    final texto = await _preferencias.getString(_clave(uid));
    if (texto == null) return [];
    try {
      return (jsonDecode(texto) as List)
          .map((i) => ItemCarrito.desdeJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Datos dañados o de una versión anterior: se empieza con el carrito vacío.
      return [];
    }
  }

  Future<void> guardar(String uid, List<ItemCarrito> items) =>
      _preferencias.setString(_clave(uid), jsonEncode([for (final i in items) i.aJson()]));
}
