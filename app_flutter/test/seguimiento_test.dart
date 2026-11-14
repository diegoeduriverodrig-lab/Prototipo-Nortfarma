import 'package:app_flutter/models/seguimiento.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _detalle({int estado = 1, bool receta = false, List<Map<String, dynamic>>? historial}) => {
  'idPedido': 2,
  'numero': '#00002',
  'fecha': '2026-10-11T17:10:00.000Z',
  'estado': {'id': estado, 'nombre': 'X'},
  'tipoEntrega': 'Retiro en Botica',
  'botica': {'id': 2, 'nombre': 'Botica Castilla', 'direccion': 'Av. Guardia Civil 210', 'horario': ''},
  'direccion': null,
  'comprobante': {'tipo': 'Factura', 'numero': 'F901-00000001', 'ruc': '20123456789', 'razonSocial': 'Clínica SAC'},
  'tipoPago': 'Contraentrega efectivo',
  'pago': {'idEstado': 1, 'estado': 'Pendiente', 'monto': 18.9},
  'receta': receta ? {'ruta': 'recetas/a.png', 'fecha': '2026-10-11T17:10:00.000Z'} : null,
  'items': [
    {
      'idProducto': 5,
      'nombre': 'Amoxicilina',
      'presentacion': 'BLISTER',
      'nombrePresentacion': 'Blíster x 10',
      'cantidad': 2,
      'precioUnitario': 9.45,
      'descuento': 0,
      'total': 18.9,
      'requiereReceta': true,
    },
  ],
  'costoEnvio': 0,
  'total': 18.9,
  'cliente': {'nombre': 'Ana López', 'dni': '45678912', 'telefono': '987654321'},
  'repartidor': null,
  'historial': historial ?? [],
};

void main() {
  test('lee el detalle del pedido', () {
    final p = PedidoDetalle.desdeJson(_detalle(receta: true));
    expect(p.esDelivery, isFalse);
    expect(p.recetaRuta, 'recetas/a.png');
    expect(p.numeroComprobante, 'F901-00000001');
    expect(p.items.single.presentacion, 'Blíster x 10');
    expect(p.items.single.precioUnitario, 9.45);
    expect(p.subtotal, 18.9);
    expect(p.cliente!.dni, '45678912');
    expect(p.ruc, '20123456789');
    expect(p.items.single.requiereReceta, isTrue);
  });

  test('la fecha llega en UTC y se muestra en hora local', () {
    final p = PedidoDetalle.desdeJson(_detalle());
    expect(p.fecha.isUtc, isFalse);
    expect(p.fecha.toUtc(), DateTime.utc(2026, 10, 11, 17, 10));
  });

  test('motivo de cancelación: el último cambio a Fallido', () {
    final p = PedidoDetalle.desdeJson(
      _detalle(
        estado: EstadoPedido.fallido,
        historial: [
          {'estado': {'id': 1, 'nombre': 'Procesando'}, 'fecha': '2026-10-11T17:10:00Z', 'motivo': null},
          {
            'estado': {'id': 6, 'nombre': 'Fallido'},
            'fecha': '2026-10-11T17:20:00Z',
            'motivo': 'Cliente ausente',
          },
        ],
      ),
    );
    expect(p.estado.finalizado, isTrue);
    expect(p.motivoFallo, 'Cliente ausente');
    expect(p.recetaRuta, isNull);
  });

  test('repartidor disponible si no tiene entregas activas', () {
    expect(Repartidor.desdeJson({'id': 3, 'nombre': 'Carlos', 'entregasActivas': 0}).disponible, isTrue);
    expect(Repartidor.desdeJson({'id': 3, 'nombre': 'Carlos', 'entregasActivas': 2}).disponible, isFalse);
  });
}
