import 'package:app_flutter/models/producto.dart';
import 'package:app_flutter/views/widgets/producto_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Producto _oferta({int stock = 8}) => Producto.desdeJson({
  'idProducto': 66,
  'nombre': 'ENSURE ADVANCE X850GR VAINILLA CON UN NOMBRE MUY LARGO',
  'especificaciones': 'Lata',
  'empaque': 'Lata x 850 g',
  'requiereReceta': false,
  'categoria': {'id': 3, 'nombre': 'Vitaminas'},
  'imagenUrl': null,
  'precio': 120.5,
  'precioRegular': 150.0,
  'descuento': 20,
  'stock': stock,
  'disponible': stock > 0,
});

/// Celda de la cuadrícula de Inicio en un celular pequeño (360 dp de ancho).
Future<void> _mostrar(WidgetTester tester, Producto producto, VoidCallback onComprar) {
  const ancho = (360 - 32 - 12) / 2;
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            height: ancho / 0.52,
            child: TarjetaProducto(producto: producto, onTap: () {}, onComprar: onComprar),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('la tarjeta de oferta muestra "Comprar" sin desbordarse', (tester) async {
    var compras = 0;
    await _mostrar(tester, _oferta(), () => compras++);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Comprar'));
    expect(compras, 1);
  });

  testWidgets('si está agotado, el botón dice "Agotado" y no compra', (tester) async {
    var compras = 0;
    await _mostrar(tester, _oferta(stock: 0), () => compras++);
    expect(find.text('Agotado'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Agotado'));
    expect(compras, 0);
  });
}
