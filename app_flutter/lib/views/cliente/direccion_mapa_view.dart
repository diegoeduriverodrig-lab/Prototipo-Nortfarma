import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/pedido.dart';
import '../../viewmodels/direccion_mapa_viewmodel.dart';
import '../widgets/aviso.dart';

/// Mapa con un pin fijo en el centro para marcar el punto exacto de entrega (RF02).
/// Devuelve la [UbicacionElegida].
class DireccionMapaView extends StatefulWidget {
  const DireccionMapaView({super.key});

  static Route<UbicacionElegida> ruta({double? latitud, double? longitud}) => MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (_) => DireccionMapaViewModel(latitudInicial: latitud, longitudInicial: longitud),
      child: const DireccionMapaView(),
    ),
  );

  @override
  State<DireccionMapaView> createState() => _DireccionMapaViewState();
}

class _DireccionMapaViewState extends State<DireccionMapaView> {
  GoogleMapController? _mapa;

  @override
  void dispose() {
    _mapa?.dispose();
    super.dispose();
  }

  Future<void> _irAMiUbicacion(DireccionMapaViewModel vm) async {
    final posicion = await vm.miUbicacion();
    if (posicion != null) {
      await _mapa?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(posicion.$1, posicion.$2), 17));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DireccionMapaViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Marca tu dirección'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(vm.latitud, vm.longitud), zoom: 16),
            onMapCreated: (c) {
              _mapa = c;
              vm.alDetenerMapa();
            },
            onCameraMove: (posicion) => vm.alMoverMapa(posicion.target.latitude, posicion.target.longitude),
            onCameraIdle: vm.alDetenerMapa,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          // Pin fijo: la punta queda exactamente en el centro del mapa.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: AppColors.rojo),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: FloatingActionButton.small(
              heroTag: 'mi-ubicacion',
              tooltip: 'Mi ubicación',
              onPressed: vm.ubicando ? null : () => _irAMiUbicacion(vm),
              child: vm.ubicando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mueve el mapa hasta que el pin quede en tu puerta.',
                style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColors.turquesa),
                  const SizedBox(width: 8),
                  Expanded(
                    child: vm.buscandoDireccion
                        ? const LinearProgressIndicator(minHeight: 2)
                        : Text(
                            [
                              vm.direccion ?? 'Punto marcado en el mapa',
                              if (vm.distrito != null) vm.distrito!,
                            ].join(', '),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                  ),
                ],
              ),
              if (vm.avisoUbicacion != null) ...[
                const SizedBox(height: 8),
                Aviso(tipo: TipoAviso.info, mensaje: vm.avisoUbicacion!),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(vm.confirmar()),
                icon: const Icon(Icons.check),
                label: const Text('Confirmar ubicación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
