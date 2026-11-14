import 'package:app_flutter/models/admin.dart';
import 'package:app_flutter/models/seguimiento.dart';
import 'package:app_flutter/views/widgets/producto_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nombre en la app', () {
    test('el producto muestra el nombre de la app y guarda el de Nortfarma', () {
      final p = ProductoAdmin.desdeJson({
        'idProducto': 66,
        'idProductoCore': 'C1234',
        'nombre': 'Ensure Advance Vainilla 850 g',
        'nombreNortfarma': 'ENSURE ADVANCE X850GR VAINILLA',
        'nombreApp': 'Ensure Advance Vainilla 850 g',
        'aptoEcommerce': true,
        'requiereReceta': false,
        'idCategoria': 3,
      });
      expect(p.nombre, 'Ensure Advance Vainilla 850 g');
      expect(p.nombreNortfarma, 'ENSURE ADVANCE X850GR VAINILLA');
      expect(p.esNuevo, isFalse);
    });

    test('sin nombre en la app, el de Nortfarma es el nombre', () {
      final p = ProductoAdmin.desdeJson({
        'idProducto': 1,
        'idProductoCore': 'A5623',
        'nombre': 'GRAVOL A/P CAPX84',
        'aptoEcommerce': true,
        'requiereReceta': false,
      });
      expect(p.nombreApp, isNull);
      expect(p.nombreNortfarma, 'GRAVOL A/P CAPX84');
      expect(p.esNuevo, isTrue);
    });
  });

  group('Categorías', () {
    test('lee la categoría del administrador con su ícono sin prefijo', () {
      final c = CategoriaAdmin.desdeJson({
        'id': 5,
        'nombre': 'Bebé',
        'iconoUrl': 'icono://bebe',
        'activa': false,
        'productos': 91,
      });
      expect(c.icono, 'bebe');
      expect(c.activa, isFalse);
      expect(c.productos, 91);
    });

    test('cada ícono conocido tiene dibujo y uno desconocido usa el genérico', () {
      expect(iconoCategoria('icono://bebe'), Icons.child_care_outlined);
      expect(iconoCategoria('icono://deporte'), Icons.fitness_center);
      expect(iconoCategoria('icono://no_existe'), Icons.category_outlined);
      expect(iconosCategoria.length, 16);
    });
  });

  group('Entrega a domicilio', () {
    test('lee horas, evidencia, ubicación e incidencias', () {
      final e = InfoEntrega.desdeJson({
        'fechaAsignacion': '2026-11-05T16:26:24.000Z',
        'fechaSalida': '2026-11-05T16:28:39.000Z',
        'fechaEntrega': null,
        'evidencia': 'evidencias/1b2c.jpg',
        'latitud': -5.19449,
        'longitud': -80.63282,
        'observacion': null,
        'incidencias': [
          {'tipo': 'Retraso por tráfico', 'detalle': null, 'terminaEntrega': false, 'fecha': '2026-11-05T16:30:00.000Z'},
          {'tipo': 'Cliente ausente', 'detalle': 'No abrió', 'terminaEntrega': true, 'fecha': '2026-11-05T16:45:00.000Z'},
        ],
      });
      expect(e.fechaSalida, isNotNull);
      expect(e.fechaEntrega, isNull);
      expect(e.evidencia, 'evidencias/1b2c.jpg');
      expect(e.latitud, closeTo(-5.19449, 1e-9));
      expect(e.incidencias, hasLength(2));
      expect(e.incidencias.last.terminaEntrega, isTrue);
      expect(e.incidencias.last.detalle, 'No abrió');
    });

    test('las entregas traen los tipos de incidencia (y funcionan sin ellos)', () {
      final conTipos = Entregas.desdeJson({
        'activas': [],
        'recientes': [],
        'motivosFallo': ['Cliente ausente'],
        'tiposIncidencia': ['Retraso por tráfico', 'Otro'],
      });
      expect(conTipos.tiposIncidencia, ['Retraso por tráfico', 'Otro']);
      final sinTipos = Entregas.desdeJson({'activas': [], 'recientes': [], 'motivosFallo': []});
      expect(sinTipos.tiposIncidencia, isEmpty);
    });
  });
}
