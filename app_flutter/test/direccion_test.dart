import 'package:app_flutter/models/pedido.dart';
import 'package:app_flutter/services/api_service.dart';
import 'package:app_flutter/services/pedido_service.dart';
import 'package:app_flutter/viewmodels/direccion_form_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde los distritos con delivery sin llamar al backend.
class _ApiFalsa implements ApiService {
  @override
  Future<Map<String, dynamic>> llamar(String funcion, [Map<String, dynamic> datos = const {}]) async => {
    'ubigeos': [
      {'id': '200101', 'departamento': 'Piura', 'provincia': 'Piura', 'distrito': 'Piura'},
      {'id': '200115', 'departamento': 'Piura', 'provincia': 'Piura', 'distrito': 'Veintiséis de Octubre'},
    ],
  };
}

Future<DireccionFormViewModel> _formulario() async {
  final vm = DireccionFormViewModel(PedidoService(_ApiFalsa()));
  await Future<void>.delayed(Duration.zero); // carga de distritos
  return vm;
}

UbicacionElegida _punto(String? distrito) =>
    UbicacionElegida(latitud: -5.19, longitud: -80.63, distritoSugerido: distrito);

void main() {
  test('el distrito del mapa se elige solo si tiene delivery (sin importar tildes)', () async {
    final vm = await _formulario();
    vm.usarUbicacion(_punto('Veintiseis de Octubre'));
    expect(vm.idUbigeo, '200115');
    expect(vm.avisoCobertura, isNull);
    expect(vm.distritoDelMapa, isTrue);
  });

  test('un distrito sin delivery bloquea la dirección', () async {
    final vm = await _formulario();
    vm.usarUbicacion(_punto('Sullana'));
    expect(vm.idUbigeo, isNull);
    expect(vm.avisoCobertura, contains('Sullana'));
    expect(vm.validarDistrito(null), 'Distrito sin delivery');
  });

  test('si Google no reconoce el distrito, se pide mover el pin', () async {
    final vm = await _formulario();
    vm.usarUbicacion(_punto(null));
    expect(vm.avisoCobertura, contains('Mueve el pin'));
  });

  test('con el mapa el distrito no se cambia a mano', () async {
    final vm = await _formulario();
    vm.usarUbicacion(_punto('Piura'));
    vm.elegirDistrito('200115');
    expect(vm.idUbigeo, '200101');
  });
}
