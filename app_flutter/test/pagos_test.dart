import 'package:app_flutter/core/validadores.dart';
import 'package:app_flutter/models/pedido.dart';
import 'package:app_flutter/models/seguimiento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tarjeta', () {
    test('número válido por algoritmo de Luhn', () {
      expect(Validadores.numeroTarjeta('4111 1111 1111 1111'), isNull);
      expect(Validadores.numeroTarjeta('4111 1111 1111 1112'), isNotNull);
      expect(Validadores.numeroTarjeta('4111'), isNotNull);
      expect(Validadores.numeroTarjeta(''), isNotNull);
    });

    test('vencimiento MM/AA y no vencida', () {
      final hoy = DateTime(2026, 10, 11);
      expect(Validadores.vencimiento('10/26', hoy: hoy), isNull);
      expect(Validadores.vencimiento('09/26', hoy: hoy), 'La tarjeta está vencida');
      expect(Validadores.vencimiento('13/27', hoy: hoy), 'Mes no válido');
      expect(Validadores.vencimiento('1227', hoy: hoy), 'Usa el formato MM/AA');
    });

    test('CVV de 3 o 4 dígitos', () {
      expect(Validadores.cvv('123'), isNull);
      expect(Validadores.cvv('1234'), isNull);
      expect(Validadores.cvv('12'), isNotNull);
    });
  });

  test('pedido registrado con pago rechazado', () {
    final p = PedidoRegistrado.desdeJson({
      'idPedido': 7,
      'numero': '#00007',
      'estadoPedido': 'Procesando',
      'estadoPago': 'Fallido',
      'mensajePago': 'Fondos insuficientes',
      'tipoEntrega': 'Retiro en Botica',
      'botica': {'id': 2, 'nombre': 'Castilla', 'direccion': 'Av. Guardia Civil'},
      'subtotal': 9.5,
      'costoEnvio': 0,
      'total': 9.5,
    });
    expect(p.pagoRechazado, isTrue);
    expect(p.mensajePago, 'Fondos insuficientes');
  });

  test('se puede reintentar el pago solo si fue en línea, rechazado y sigue en proceso', () {
    PedidoDetalle detalle({required int idTipoPago, required String estadoPago, int estado = 1}) =>
        PedidoDetalle.desdeJson({
          'idPedido': 7,
          'numero': '#00007',
          'fecha': '2026-10-11T18:00:00Z',
          'estado': {'id': estado, 'nombre': 'X'},
          'tipoEntrega': 'Delivery',
          'direccion': {'direccionExacta': 'Av. Grau 123', 'distrito': 'Castilla', 'latitud': -5.2, 'longitud': -80.6},
          'comprobante': {'tipo': 'Boleta'},
          'tipoPago': 'En línea (tarjeta)',
          'idTipoPago': idTipoPago,
          'pago': {'estado': estadoPago},
          'items': [],
          'costoEnvio': 5,
          'total': 14.5,
          'historial': [],
        });
    expect(detalle(idTipoPago: 1, estadoPago: 'Fallido').puedeReintentarPago, isTrue);
    expect(detalle(idTipoPago: 1, estadoPago: 'Aprobado').puedeReintentarPago, isFalse);
    expect(detalle(idTipoPago: 4, estadoPago: 'Fallido').puedeReintentarPago, isFalse);
    expect(detalle(idTipoPago: 1, estadoPago: 'Fallido', estado: 6).puedeReintentarPago, isFalse);
    expect(detalle(idTipoPago: 1, estadoPago: 'Fallido').tieneDestino, isTrue);
  });
}
