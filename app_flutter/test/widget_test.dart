import 'package:app_flutter/core/validadores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validadores', () {
    test('correo', () {
      expect(Validadores.correo(''), isNotNull);
      expect(Validadores.correo('cliente@'), isNotNull);
      expect(Validadores.correo(' cliente@dominio.com '), isNull);
    });

    test('DNI de 8 dígitos', () {
      expect(Validadores.dni('1234567'), isNotNull);
      expect(Validadores.dni('1234567a'), isNotNull);
      expect(Validadores.dni('01234567'), isNull);
    });

    test('celular de 9 dígitos que empieza con 9', () {
      expect(Validadores.celular('812345678'), isNotNull);
      expect(Validadores.celular('91234567'), isNotNull);
      expect(Validadores.celular('912345678'), isNull);
    });

    test('contraseña y confirmación', () {
      expect(Validadores.contrasena('12345'), isNotNull);
      expect(Validadores.contrasena('123456'), isNull);
      expect(Validadores.confirmarContrasena('123456', '123457'), isNotNull);
      expect(Validadores.confirmarContrasena('123456', '123456'), isNull);
    });
  });
}
