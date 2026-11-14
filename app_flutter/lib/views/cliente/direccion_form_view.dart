import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../models/pedido.dart';
import '../../services/pedido_service.dart';
import '../../viewmodels/direccion_form_viewmodel.dart';
import '../widgets/aviso.dart';
import 'direccion_mapa_view.dart';

/// Nueva dirección de entrega (RF02). Devuelve la [Direccion] creada.
class DireccionFormView extends StatefulWidget {
  const DireccionFormView({super.key});

  static Route<Direccion> ruta() => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => DireccionFormViewModel(context.read<PedidoService>()),
      child: const DireccionFormView(),
    ),
  );

  @override
  State<DireccionFormView> createState() => _DireccionFormViewState();
}

class _DireccionFormViewState extends State<DireccionFormView> {
  final _formKey = GlobalKey<FormState>();
  final _direccion = TextEditingController();
  final _referencia = TextEditingController();

  @override
  void dispose() {
    _direccion.dispose();
    _referencia.dispose();
    super.dispose();
  }

  Future<void> _marcarEnMapa(DireccionFormViewModel vm) async {
    final actual = vm.ubicacion;
    final ubicacion = await Navigator.of(context).push(
      DireccionMapaView.ruta(latitud: actual?.latitud, longitud: actual?.longitud),
    );
    if (ubicacion == null) return;
    vm.usarUbicacion(ubicacion);
    if (_direccion.text.trim().isEmpty && ubicacion.direccionSugerida != null) {
      _direccion.text = ubicacion.direccionSugerida!;
    }
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<DireccionFormViewModel>();
    final ok = await vm.guardar(_direccion.text, _referencia.text);
    if (ok && mounted) Navigator.of(context).pop(vm.guardada);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DireccionFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Nueva dirección'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (Config.mapsHabilitado) ...[
              OutlinedButton.icon(
                onPressed: () => _marcarEnMapa(vm),
                icon: Icon(vm.ubicacion == null ? Icons.map_outlined : Icons.check_circle, color: AppColors.turquesa),
                label: Text(vm.ubicacion == null ? 'Marcar en el mapa' : 'Ubicación marcada · cambiar'),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              key: ValueKey(vm.idUbigeo), // se actualiza si el mapa eligió el distrito
              initialValue: vm.idUbigeo,
              decoration: InputDecoration(
                labelText: 'Distrito',
                prefixIcon: const Icon(Icons.map_outlined),
                helperText: vm.distritoDelMapa ? 'Lo detectó Google Maps según el punto marcado' : null,
              ),
              items: [
                for (final d in vm.distritos)
                  DropdownMenuItem(value: d.id, child: Text('${d.distrito} (${d.provincia})')),
              ],
              onChanged: vm.cargandoDistritos || vm.distritoDelMapa ? null : vm.elegirDistrito,
              validator: vm.validarDistrito,
            ),
            if (vm.avisoCobertura != null) ...[
              const SizedBox(height: 10),
              Aviso(titulo: 'Fuera de la zona de delivery', mensaje: vm.avisoCobertura!),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _direccion,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Calle, número, urbanización, manzana, lote',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              validator: vm.validarDireccion,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _referencia,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                hintText: 'Ej. frente al parque, puerta verde',
                prefixIcon: Icon(Icons.info_outline),
              ),
              onFieldSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 16),
            Aviso(
              tipo: TipoAviso.info,
              mensaje: vm.ubicacion != null
                  ? 'El costo de envío se calculará desde el punto que marcaste en el mapa.'
                  : 'Sin el mapa, el costo de envío se calcula desde el centro del distrito.',
            ),
            if (vm.error != null) ...[
              const SizedBox(height: 14),
              Aviso(mensaje: vm.error!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: vm.cargando || vm.avisoCobertura != null ? null : _guardar,
              child: vm.cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar dirección'),
            ),
          ],
        ),
      ),
    );
  }
}
