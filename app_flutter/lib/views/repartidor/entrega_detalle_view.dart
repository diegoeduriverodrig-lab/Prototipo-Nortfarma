import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../services/imagen_service.dart';
import '../../services/seguimiento_service.dart';
import '../../viewmodels/entregas_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/detalle_pedido_secciones.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/mapa_destino.dart';

/// Detalle de una entrega con las acciones del repartidor (RF07).
class EntregaDetalleView extends StatefulWidget {
  const EntregaDetalleView({super.key});

  static Route<void> ruta(
    int idPedido, {
    required List<String> motivosFallo,
    List<String> tiposIncidencia = const [],
  }) => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => EntregaViewModel(
        context.read<SeguimientoService>(),
        context.read<ImagenService>(),
        idPedido,
        motivosFallo: motivosFallo,
        tiposIncidencia: tiposIncidencia,
      ),
      child: const EntregaDetalleView(),
    ),
  );

  @override
  State<EntregaDetalleView> createState() => _EntregaDetalleViewState();
}

class _EntregaDetalleViewState extends State<EntregaDetalleView> {
  void _mostrarMensaje(EntregaViewModel vm) {
    final m = vm.tomarMensaje();
    if (m != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Primero la foto de evidencia (cámara); luego se confirma con la observación opcional.
  Future<void> _entregar(EntregaViewModel vm) async {
    if (vm.foto == null && !await vm.tomarFoto()) return;
    if (!mounted) return;
    final entregado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const _HojaEntrega()),
    );
    if (entregado == true) _mostrarMensaje(vm);
  }

  Future<void> _reportarFallo(EntregaViewModel vm) async {
    final resultado = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HojaMotivo(
        motivos: vm.motivosFallo,
        titulo: '¿Por qué no se pudo entregar?',
        explicacion: 'El pedido se marcará como fallido y los productos volverán a la botica.',
        boton: 'Reportar entrega fallida',
        colorBoton: const Color(0xFFC62828),
      ),
    );
    if (resultado != null) {
      await vm.reportarFallo(resultado.$1, resultado.$2);
      _mostrarMensaje(vm);
    }
  }

  Future<void> _reportarIncidencia(EntregaViewModel vm) async {
    final resultado = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HojaMotivo(
        motivos: vm.tiposIncidencia,
        titulo: 'Reportar una incidencia',
        explicacion: 'Queda registrada y la entrega sigue en curso. '
            'Si ya no se puede entregar, usa "No se pudo".',
        boton: 'Registrar incidencia',
        colorBoton: const Color(0xFFE65100),
      ),
    );
    if (resultado != null) {
      await vm.reportarIncidencia(resultado.$1, resultado.$2);
      _mostrarMensaje(vm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EntregaViewModel>();
    final p = vm.pedido;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Detalle de entrega'),
        actions: [
          if (p != null && (vm.puedeIniciar || vm.enCamino) && vm.tiposIncidencia.isNotEmpty)
            IconButton(
              tooltip: 'Reportar incidencia',
              icon: const Icon(Icons.report_problem_outlined),
              onPressed: vm.cargando ? null : () => _reportarIncidencia(vm),
            ),
        ],
      ),
      body: p == null
          ? (vm.error != null
                ? EstadoVacio(
                    icono: Icons.error_outline,
                    titulo: 'No pudimos cargar la entrega',
                    mensaje: vm.error,
                    accion: vm.cargar,
                  )
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: vm.cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CabeceraPedido(pedido: p),
                  if (vm.cargando) const LinearProgressIndicator(minHeight: 2),
                  if (vm.error != null) ...[Aviso(mensaje: vm.error!), const SizedBox(height: 12)],
                  if (vm.montoACobrar != null && !p.estado.finalizado) ...[
                    Aviso(
                      tipo: TipoAviso.info,
                      titulo: 'Cobrar ${Formato.soles(vm.montoACobrar)}',
                      mensaje: '${p.tipoPago}. Cobra al entregar el pedido.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (p.tieneDestino && !p.estado.finalizado) ...[
                    MapaDestino(
                      latitud: p.latitudDestino!,
                      longitud: p.longitudDestino!,
                      latitudBotica: p.latitudBotica,
                      longitudBotica: p.longitudBotica,
                    ),
                    const SizedBox(height: 12),
                  ],
                  SeccionesDetallePedido(pedido: p, paraPersonal: true),
                ],
              ),
            ),
      bottomNavigationBar: p == null || !(vm.puedeIniciar || vm.enCamino)
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.borde)),
                ),
                child: vm.puedeIniciar
                    ? FilledButton.icon(
                        onPressed: vm.cargando
                            ? null
                            : () async {
                                await vm.iniciar();
                                _mostrarMensaje(vm);
                              },
                        icon: const Icon(Icons.delivery_dining),
                        label: const Text('Iniciar entrega'),
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                              onPressed: vm.cargando ? null : () => _reportarFallo(vm),
                              child: const Text('No se pudo'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: FilledButton.icon(
                              onPressed: vm.cargando ? null : () => _entregar(vm),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Entregado'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
    );
  }
}

/// Confirmar la entrega: foto de evidencia, cobro (si es contraentrega) y observación.
class _HojaEntrega extends StatefulWidget {
  const _HojaEntrega();

  @override
  State<_HojaEntrega> createState() => _HojaEntregaState();
}

class _HojaEntregaState extends State<_HojaEntrega> {
  final _observacion = TextEditingController();

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _confirmar(EntregaViewModel vm) async {
    final ok = await vm.entregar(observacion: _observacion.text);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EntregaViewModel>();
    final foto = vm.foto;
    final monto = vm.montoACobrar;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Confirmar entrega', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                monto == null
                    ? 'Foto del pedido entregado (evidencia). También se guarda tu ubicación.'
                    : 'Cobra ${Formato.soles(monto)} y toma la foto del pedido entregado. '
                          'También se guarda tu ubicación.',
                style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (foto != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(foto.bytes, height: 220, fit: BoxFit.cover),
                ),
              TextButton.icon(
                onPressed: vm.cargando ? null : vm.tomarFoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(foto == null ? 'Tomar foto' : 'Tomar otra foto'),
              ),
              TextField(
                controller: _observacion,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Observación (opcional)', hintText: 'Ej. Recibió el portero'),
              ),
              if (vm.error != null) ...[Aviso(mensaje: vm.error!), const SizedBox(height: 8)],
              FilledButton.icon(
                onPressed: foto == null || vm.cargando ? null : () => _confirmar(vm),
                icon: vm.cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(monto == null ? 'Sí, entregado' : 'Entregado y cobrado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elegir un motivo de una lista (entrega fallida o incidencia) y agregar detalles.
class _HojaMotivo extends StatefulWidget {
  const _HojaMotivo({
    required this.motivos,
    required this.titulo,
    required this.explicacion,
    required this.boton,
    required this.colorBoton,
  });

  final List<String> motivos;
  final String titulo;
  final String explicacion;
  final String boton;
  final Color colorBoton;

  @override
  State<_HojaMotivo> createState() => _HojaMotivoState();
}

class _HojaMotivoState extends State<_HojaMotivo> {
  String? _motivo;
  final _detalle = TextEditingController();

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  bool get _valido =>
      _motivo != null && (_motivo != 'Otro' || _detalle.text.trim().length >= 3);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(widget.explicacion, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
              RadioGroup<String>(
                groupValue: _motivo,
                onChanged: (m) => setState(() => _motivo = m),
                child: Column(
                  children: [
                    for (final m in widget.motivos)
                      RadioListTile<String>(value: m, title: Text(m), contentPadding: EdgeInsets.zero),
                  ],
                ),
              ),
              TextField(
                controller: _detalle,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: _motivo == 'Otro' ? 'Describe qué pasó' : 'Detalles (opcional)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: widget.colorBoton),
                onPressed: _valido ? () => Navigator.pop(context, (_motivo!, _detalle.text)) : null,
                child: Text(widget.boton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
