import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';

/// Mapa pequeño con el destino de la entrega (y la botica de salida) y botón
/// "Cómo llegar", que abre Google Maps con la ruta. El botón funciona aunque no
/// haya clave de Maps; el mapa solo se muestra si está configurada.
class MapaDestino extends StatelessWidget {
  const MapaDestino({
    super.key,
    required this.latitud,
    required this.longitud,
    this.latitudBotica,
    this.longitudBotica,
  });

  final double latitud;
  final double longitud;
  final double? latitudBotica;
  final double? longitudBotica;

  Future<void> _comoLlegar(BuildContext context) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitud,$longitud&travelmode=driving',
    );
    final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Google Maps.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final destino = LatLng(latitud, longitud);
    final hayBotica = latitudBotica != null && longitudBotica != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (Config.mapsHabilitado)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: destino, zoom: 15),
                liteModeEnabled: true, // imagen estática, liviana y sin gestos
                markers: {
                  Marker(
                    markerId: const MarkerId('destino'),
                    position: destino,
                    infoWindow: const InfoWindow(title: 'Entrega'),
                  ),
                  if (hayBotica)
                    Marker(
                      markerId: const MarkerId('botica'),
                      position: LatLng(latitudBotica!, longitudBotica!),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      infoWindow: const InfoWindow(title: 'Botica'),
                    ),
                },
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _comoLlegar(context),
          icon: const Icon(Icons.directions),
          label: const Text('Cómo llegar (Google Maps)'),
        ),
      ],
    );
  }
}
