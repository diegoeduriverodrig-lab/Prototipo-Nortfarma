import 'package:app_flutter/models/admin.dart';
import 'package:app_flutter/models/seguimiento.dart';
import 'package:app_flutter/models/usuario.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _resumen({String? estadoPago, String? direccion}) => {
  'idPedido': 1,
  'numero': '#00001',
  'fecha': '2026-10-11T17:10:00Z',
  'estado': {'id': 3, 'nombre': 'En camino'},
  'tipoEntrega': 'Delivery',
  'total': 32.3,
  'unidades': 3,
  'cliente': 'Ana López',
  'estadoPago': estadoPago,
  'direccion': direccion,
  'tipoPago': 'Contraentrega efectivo',
};

void main() {
  test('entregas del repartidor y si debe cobrar', () {
    final e = Entregas.desdeJson({
      'activas': [_resumen(estadoPago: 'Pendiente', direccion: 'Av. Grau 123, Castilla')],
      'recientes': [_resumen(estadoPago: 'Aprobado')],
      'motivosFallo': ['Cliente ausente', 'Otro'],
    });
    expect(e.activas.single.direccion, 'Av. Grau 123, Castilla');
    expect(e.activas.single.cobrarAlEntregar, isTrue);
    expect(e.recientes.single.cobrarAlEntregar, isFalse);
    expect(e.motivosFallo, contains('Otro'));
  });

  test('miembro del personal con su rol y botica', () {
    final m = MiembroPersonal.desdeJson({
      'idUsuario': 2,
      'rol': {'id': 'RL02', 'nombre': 'Encargado de botica'},
      'idBotica': 2,
      'botica': 'Castilla',
      'nombre': 'Carla',
      'apellido': 'Pérez',
      'dni': '41234567',
      'telefono': '911222333',
      'correo': 'carla@test.com',
    });
    expect(m.rol, Rol.encargado);
    expect(m.nombreCompleto, 'Carla Pérez');
  });

  test('datos de personal: al editar no se envían DNI, correo ni contraseña', () {
    const editar = DatosPersonal(nombres: ' Luis ', apellidos: 'Torres', celular: '933444555', rol: Rol.repartidor);
    expect(editar.aJson(), {'nombres': 'Luis', 'apellidos': 'Torres', 'celular': '933444555', 'idRol': 'RL03'});

    const crear = DatosPersonal(
      nombres: 'Luis',
      apellidos: 'Torres',
      celular: '933444555',
      rol: Rol.encargado,
      idBotica: 1,
      dni: '43456789',
      correo: 'luis@test.com',
      contrasena: 'clave123',
    );
    expect(crear.aJson()['idBotica'], 1);
    expect(crear.aJson()['contrasena'], 'clave123');
  });

  test('resumen del administrador', () {
    final r = ResumenAdmin.desdeJson({
      'pedidosPorEstado': [
        {'id': 1, 'nombre': 'Procesando', 'cantidad': 2},
      ],
      'pedidosHoy': 4,
      'ventasHoy': 146.4,
      'usuariosPorRol': [
        {'id': 'RL04', 'nombre': 'Cliente', 'cantidad': 1},
      ],
      'productos': {'total': 11, 'aVenta': 10},
    });
    expect(r.pedidosPorEstado.single.id, '1');
    expect(r.ventasHoy, 146.4);
    expect(r.productosAVenta, 10);
  });
}
