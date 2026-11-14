import 'package:flutter/foundation.dart';

/// Pestañas de la barra inferior del cliente.
enum PestanaCliente { inicio, catalogo, pedidos, carrito, perfil }

/// Pestaña activa del cliente. Compartida para que otras pantallas
/// (por ejemplo, el detalle de producto) puedan abrir el carrito.
class NavegacionClienteViewModel extends ChangeNotifier {
  PestanaCliente _actual = PestanaCliente.inicio;

  PestanaCliente get actual => _actual;

  /// Al entrar un usuario: empieza en Inicio (sin avisar, se llama al construir).
  void reiniciar() => _actual = PestanaCliente.inicio;

  void ir(PestanaCliente pestana) {
    if (pestana == _actual) return;
    _actual = pestana;
    notifyListeners();
  }
}
