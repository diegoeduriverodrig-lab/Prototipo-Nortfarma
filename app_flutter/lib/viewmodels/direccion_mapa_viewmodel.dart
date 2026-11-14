import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/pedido.dart';
import 'base_viewmodel.dart';

/// Selección del punto exacto de entrega en el mapa (RF02).
/// El pin queda fijo en el centro; al soltar el mapa se traduce la posición
/// a una dirección legible (geocodificación inversa).
class DireccionMapaViewModel extends BaseViewModel {
  DireccionMapaViewModel({double? latitudInicial, double? longitudInicial})
    : _latitud = latitudInicial ?? centroPiura.$1,
      _longitud = longitudInicial ?? centroPiura.$2;

  /// Plaza de Armas de Piura: punto de partida si no hay otra referencia.
  static const centroPiura = (-5.19449, -80.63282);

  double _latitud;
  double _longitud;
  String? _direccion;
  String? _distrito;
  bool _buscandoDireccion = false;
  bool _ubicando = false;
  String? _avisoUbicacion;
  int _consulta = 0;

  /// Geocodificador del sistema (Android); se crea al primer uso.
  Geocoding? _geocoding;

  double get latitud => _latitud;
  double get longitud => _longitud;
  String? get direccion => _direccion;
  String? get distrito => _distrito;
  bool get buscandoDireccion => _buscandoDireccion;
  bool get ubicando => _ubicando;

  /// Motivo por el que no se pudo usar "Mi ubicación".
  String? get avisoUbicacion => _avisoUbicacion;

  /// Mientras el usuario arrastra el mapa solo se guarda la posición.
  void alMoverMapa(double latitud, double longitud) {
    _latitud = latitud;
    _longitud = longitud;
  }

  /// Al soltar el mapa: busca la dirección del punto central.
  Future<void> alDetenerMapa() async {
    final consulta = ++_consulta;
    _buscandoDireccion = true;
    notifyListeners();
    try {
      final lugares = await (_geocoding ??= Geocoding()).placemarkFromCoordinates(
        _latitud,
        _longitud,
        locale: const Locale('es', 'PE'),
      );
      if (consulta != _consulta) return; // ya se movió a otro punto
      final lugar = lugares.isEmpty ? null : lugares.first;
      _direccion = _armarDireccion(lugar);
      _distrito = lugar?.locality?.isNotEmpty == true ? lugar!.locality : lugar?.subAdministrativeArea;
    } catch (_) {
      // Sin geocodificador (o sin internet) igual se puede confirmar el punto.
      if (consulta == _consulta) {
        _direccion = null;
        _distrito = null;
      }
    } finally {
      if (consulta == _consulta) {
        _buscandoDireccion = false;
        notifyListeners();
      }
    }
  }

  /// Centra el mapa en la ubicación del celular. Devuelve la posición o null.
  Future<(double, double)?> miUbicacion() async {
    _ubicando = true;
    _avisoUbicacion = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _avisoUbicacion = 'Activa la ubicación (GPS) del celular.';
        return null;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        _avisoUbicacion = 'Sin permiso de ubicación. Mueve el mapa para marcar tu dirección.';
        return null;
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      _latitud = posicion.latitude;
      _longitud = posicion.longitude;
      return (_latitud, _longitud);
    } catch (_) {
      _avisoUbicacion = 'No pudimos obtener tu ubicación. Mueve el mapa para marcarla.';
      return null;
    } finally {
      _ubicando = false;
      notifyListeners();
    }
  }

  UbicacionElegida confirmar() => UbicacionElegida(
    latitud: _latitud,
    longitud: _longitud,
    direccionSugerida: _direccion,
    distritoSugerido: _distrito,
  );

  /// "Av. Grau 123" a partir de calle y número; si no hay, el nombre de la vía.
  static String? _armarDireccion(Placemark? lugar) {
    if (lugar == null) return null;
    final calle = lugar.thoroughfare?.trim() ?? '';
    final numero = lugar.subThoroughfare?.trim() ?? '';
    final texto = calle.isNotEmpty ? '$calle $numero'.trim() : (lugar.street?.trim() ?? '');
    return texto.isEmpty ? null : texto;
  }
}
