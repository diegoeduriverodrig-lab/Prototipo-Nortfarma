import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Datos de la tarjeta tal como los escribe el cliente.
class DatosTarjeta {
  const DatosTarjeta({
    required this.numero,
    required this.mesVencimiento,
    required this.anioVencimiento,
    required this.cvv,
    required this.email,
  });

  final String numero;
  final int mesVencimiento;

  /// Año completo (2027).
  final int anioVencimiento;
  final String cvv;
  final String email;
}

class CulqiException implements Exception {
  const CulqiException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Convierte la tarjeta en un token de Culqi (RF10) usando la llave PÚBLICA.
/// Los datos de la tarjeta van directo de la app a Culqi: nunca pasan por nuestro backend.
class CulqiService {
  CulqiService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  static final _url = Uri.parse('https://secure.culqi.com/v2/tokens');

  bool get habilitado => Config.culqiHabilitado;

  /// Devuelve el id del token (tkn_test_...).
  Future<String> crearToken(DatosTarjeta tarjeta) async {
    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .post(
            _url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Config.culqiLlavePublica}',
            },
            body: jsonEncode({
              'card_number': tarjeta.numero.replaceAll(RegExp(r'\D'), ''),
              'cvv': tarjeta.cvv,
              'expiration_month': tarjeta.mesVencimiento.toString().padLeft(2, '0'),
              'expiration_year': tarjeta.anioVencimiento.toString(),
              'email': tarjeta.email,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const CulqiException('No se pudo conectar con la pasarela de pagos. Revisa tu conexión.');
    }

    Object? cuerpo;
    try {
      cuerpo = jsonDecode(respuesta.body);
    } on FormatException {
      cuerpo = null; // respuesta inesperada: se muestra el mensaje genérico
    }
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300 && cuerpo is Map && cuerpo['id'] is String) {
      return cuerpo['id'] as String;
    }
    // user_message es para el cliente; merchant_message es técnico (para el comercio).
    final mensaje = cuerpo is Map ? cuerpo['user_message'] : null;
    if (cuerpo is Map && cuerpo['merchant_message'] != null) {
      debugPrint('Culqi (comercio): ${cuerpo['merchant_message']}');
    }
    throw CulqiException(
      mensaje is String ? mensaje : 'No pudimos procesar tu tarjeta. Revisa los datos o inténtalo más tarde.',
    );
  }
}
