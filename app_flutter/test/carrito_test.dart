import 'package:app_flutter/models/pedido.dart';
import 'package:app_flutter/models/producto.dart';
import 'package:app_flutter/services/carrito_local_service.dart';
import 'package:app_flutter/viewmodels/carrito_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda en memoria en lugar del celular.
class _AlmacenEnMemoria extends CarritoLocalService {
  final datos = <String, List<ItemCarrito>>{};

  @override
  Future<List<ItemCarrito>> leer(String uid) async => [...?datos[uid]];

  @override
  Future<void> guardar(String uid, List<ItemCarrito> items) async => datos[uid] = [...items];
}

/// Producto con caja (y opcionalmente unidad suelta).
Producto _producto(
  int id, {
  int stock = 10,
  double precio = 5,
  double? precioRegular,
  bool receta = false,
  int stockUnidad = 0,
}) => Producto(
  idProducto: id,
  nombre: 'Producto $id',
  especificaciones: '',
  requiereReceta: receta,
  idCategoria: 1,
  categoria: 'Medicinas',
  precio: precio,
  stock: stock,
  disponible: stock > 0 || stockUnidad > 0,
  presentaciones: [
    Presentacion(
      tipo: TipoPresentacion.empaque,
      nombre: 'Caja x 10 tabletas',
      unidades: 10,
      precio: precio,
      precioRegular: precioRegular ?? precio,
      stock: stock,
    ),
    if (stockUnidad > 0)
      Presentacion(
        tipo: TipoPresentacion.fraccion,
        nombre: 'Unidad',
        unidades: 1,
        precio: precio / 10,
        precioRegular: precio / 10,
        stock: stockUnidad,
      ),
  ],
);

void main() {
  late _AlmacenEnMemoria almacen;
  late CarritoViewModel carrito;

  setUp(() async {
    almacen = _AlmacenEnMemoria();
    carrito = CarritoViewModel(almacen);
    await carrito.usarUsuario('ana');
  });

  test('agrega, suma cantidades y calcula el subtotal', () {
    expect(carrito.agregar(_producto(1, precio: 8.9), 2), ResultadoAgregar.agregado);
    expect(carrito.agregar(_producto(1, precio: 8.9), 1), ResultadoAgregar.agregado);
    expect(carrito.cantidadDe(1), 3);
    expect(carrito.subtotal, closeTo(26.7, 0.001));
    expect(almacen.datos['ana']!.single.cantidad, 3);
    expect(almacen.datos['ana']!.single.nombrePresentacion, 'Caja x 10 tabletas');
  });

  test('caja y unidad del mismo producto son líneas distintas', () {
    final p = _producto(1, precio: 20, stockUnidad: 50);
    carrito.agregar(p, 1);
    carrito.agregar(p, 3, TipoPresentacion.fraccion);
    expect(carrito.items, hasLength(2));
    expect(carrito.cantidadDe(1), 1);
    expect(carrito.cantidadDe(1, TipoPresentacion.fraccion), 3);
    expect(carrito.subtotal, closeTo(26, 0.001));

    carrito.quitar(ItemCarrito.claveDe(1, TipoPresentacion.empaque));
    expect(carrito.items.single.presentacion, TipoPresentacion.fraccion);
  });

  test('no se puede agregar una presentación que el producto no tiene', () {
    expect(carrito.agregar(_producto(1), 1, TipoPresentacion.blister), ResultadoAgregar.sinStock);
    expect(carrito.vacio, isTrue);
  });

  test('no supera el stock', () {
    expect(carrito.agregar(_producto(1, stock: 4), 3), ResultadoAgregar.agregado);
    expect(carrito.agregar(_producto(1, stock: 4), 3), ResultadoAgregar.superaStock);
    expect(carrito.cantidadDe(1), 4);
    expect(carrito.agregar(_producto(2, stock: 0), 1), ResultadoAgregar.sinStock);
    expect(carrito.cantidadDe(2), 0);
  });

  test('guarda el precio con descuento y el precio regular', () {
    carrito.agregar(_producto(1, precio: 8, precioRegular: 10), 1);
    expect(carrito.items.single.precio, 8);
    expect(carrito.items.single.conDescuento, isTrue);
  });

  test('cantidad cero quita el producto', () {
    carrito.agregar(_producto(1), 2);
    carrito.cambiarCantidad(carrito.items.single.clave, 0);
    expect(carrito.vacio, isTrue);
  });

  test('detecta productos con receta', () {
    carrito.agregar(_producto(1), 1);
    expect(carrito.requiereReceta, isFalse);
    carrito.agregar(_producto(2, receta: true), 1);
    expect(carrito.requiereReceta, isTrue);
  });

  test('aplica precio y stock confirmados por el backend', () {
    carrito.agregar(_producto(1, stock: 10, precio: 5), 6);
    carrito.aplicarValidacion(
      const ValidacionCarrito(
        lineas: [LineaValidada(idProducto: 1, precio: 6.5, stock: 4)],
        sinStock: ['Producto 1'],
      ),
    );
    expect(carrito.items.single.precio, 6.5);
    expect(carrito.hayProblemasDeStock, isTrue);
  });

  test('cada usuario tiene su propio carrito', () async {
    carrito.agregar(_producto(1), 2);
    await carrito.usarUsuario('luis');
    expect(carrito.vacio, isTrue);
    await carrito.usarUsuario('ana');
    expect(carrito.cantidadDe(1), 2);
  });

  test('un carrito guardado por una versión anterior se lee como caja', () {
    final item = ItemCarrito.desdeJson({
      'idProducto': 3,
      'nombre': 'Panadol',
      'precio': 8.9,
      'requiereReceta': false,
      'stock': 5,
      'cantidad': 1,
    });
    expect(item.presentacion, TipoPresentacion.empaque);
    expect(item.precioRegular, 8.9);
  });
}
