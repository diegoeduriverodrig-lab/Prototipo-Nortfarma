import 'package:app_flutter/models/producto.dart';
import 'package:app_flutter/models/usuario.dart';
import 'package:app_flutter/viewmodels/completar_perfil_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _producto({int? stock, num? precio}) => {
  'idProducto': 5,
  'nombre': 'Amoxicilina Genfar 500 mg',
  'especificaciones': 'Caja x 10',
  'requiereReceta': true,
  'categoria': {'id': 1, 'nombre': 'Medicinas'},
  'imagenUrl': null,
  'precio': precio,
  'stock': stock,
  'disponible': (stock ?? 0) > 0,
};

void main() {
  group('Producto', () {
    test('lee la respuesta de la API', () {
      final p = Producto.desdeJson(_producto(stock: 14, precio: 18.9));
      expect(p.nombre, 'Amoxicilina Genfar 500 mg');
      expect(p.idCategoria, 1);
      expect(p.precio, 18.9);
      expect(p.requiereReceta, isTrue);
      expect(p.disponible, isTrue);
    });

    test('precio entero de JSON se convierte a double', () {
      expect(Producto.desdeJson(_producto(stock: 1, precio: 9)).precio, 9.0);
    });

    test('lee presentaciones y descuento', () {
      final p = Producto.desdeJson({
        ..._producto(stock: 14, precio: 15.12),
        'empaque': 'Caja x 100 tabletas',
        'precioRegular': 18.9,
        'descuento': 20,
        'presentaciones': [
          {'tipo': 'EMPAQUE', 'nombre': 'Caja x 100 tabletas', 'unidades': 100, 'precio': 15.12, 'precioRegular': 18.9, 'stock': 14},
          {'tipo': 'FRACCION', 'nombre': 'Unidad', 'unidades': 1, 'precio': 0.17, 'precioRegular': 0.21, 'stock': 0},
        ],
      });
      expect(p.conDescuento, isTrue);
      expect(p.presentaciones, hasLength(2));
      expect(p.presentacion(TipoPresentacion.empaque)!.conDescuento, isTrue);
      expect(p.presentacion(TipoPresentacion.fraccion)!.disponible, isFalse);
      expect(p.presentacion(TipoPresentacion.blister), isNull);
    });

    test('nivel de stock', () {
      expect(Producto.desdeJson(_producto(stock: 20)).nivelStock, NivelStock.disponible);
      expect(Producto.desdeJson(_producto(stock: 5)).nivelStock, NivelStock.pocasUnidades);
      expect(Producto.desdeJson(_producto(stock: 0)).nivelStock, NivelStock.agotado);
      expect(Producto.desdeJson(_producto()).nivelStock, NivelStock.desconocido);
    });
  });

  group('Usuario', () {
    test('lee el perfil y el rol de la API', () {
      final u = Usuario.desdeJson({
        'uid': 'abc',
        'correo': 'ana@test.com',
        'nombre': 'Ana María',
        'apellido': 'López',
        'rol': {'id': 'RL02', 'nombre': 'Encargado de botica'},
        'dni': '12345678',
        'telefono': '912345678',
        'idBotica': 1,
      });
      expect(u.rol, Rol.encargado);
      expect(u.primerNombre, 'Ana');
      expect(u.nombreCompleto, 'Ana María López');
      expect(u.idBotica, 1);
    });

    test('rol desconocido se trata como Cliente', () {
      expect(Rol.desdeId('XX99'), Rol.cliente);
    });
  });

  group('Separar nombre de Google', () {
    test('dos palabras', () {
      expect(CompletarPerfilViewModel.separarNombre('Ana López'), ('Ana', 'López'));
    });
    test('nombres y dos apellidos', () {
      expect(
        CompletarPerfilViewModel.separarNombre('Ana María López Pérez'),
        ('Ana María', 'López Pérez'),
      );
    });
    test('vacío o una palabra', () {
      expect(CompletarPerfilViewModel.separarNombre(null), ('', ''));
      expect(CompletarPerfilViewModel.separarNombre('Ana'), ('Ana', ''));
    });
  });
}
