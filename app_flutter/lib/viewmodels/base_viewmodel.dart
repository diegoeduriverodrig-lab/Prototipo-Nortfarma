import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Estado común de las pantallas: si está cargando y el último error.
abstract class BaseViewModel extends ChangeNotifier {
  bool _cargando = false;
  String? _error;
  bool _cerrado = false;

  bool get cargando => _cargando;
  String? get error => _error;

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// No avisa a la vista si ya se cerró (por ejemplo, el usuario volvió atrás
  /// antes de que terminara una carga).
  @override
  void notifyListeners() {
    if (!_cerrado) super.notifyListeners();
  }

  /// Ejecuta una acción mostrando la carga. Devuelve true si terminó sin error.
  @protected
  Future<bool> ejecutar(Future<void> Function() accion) async {
    if (_cargando) return false;
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
      return true;
    } on AuthException catch (e) {
      _error = e.mensaje;
      return false;
    } on ApiException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
