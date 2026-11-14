import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/seguimiento.dart';
import '../../viewmodels/bandeja_viewmodel.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/pedido_widgets.dart';
import 'encargado_pedido_view.dart';

/// Bandeja de pedidos de la botica (RF07), con filtro por estado y aviso de pedidos nuevos.
class BandejaView extends StatefulWidget {
  const BandejaView({super.key});

  @override
  State<BandejaView> createState() => _BandejaViewState();
}

class _BandejaViewState extends State<BandejaView> {
  late final BandejaViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<BandejaViewModel>();
    _vm.addListener(_avisarNuevos);
  }

  @override
  void dispose() {
    _vm.removeListener(_avisarNuevos);
    super.dispose();
  }

  /// Notificación simulada: aviso en pantalla cuando entra un pedido.
  void _avisarNuevos() {
    final nuevos = _vm.tomarNuevos();
    if (nuevos.isEmpty || !mounted) return;
    final texto = nuevos.length == 1
        ? 'Nuevo pedido ${nuevos.first.numero} de ${nuevos.first.cliente}'
        : '${nuevos.length} pedidos nuevos';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
        duration: const Duration(seconds: 6),
        action: nuevos.length == 1
            ? SnackBarAction(label: 'Ver', onPressed: () => _abrir(nuevos.first))
            : null,
      ),
    );
  }

  Future<void> _abrir(PedidoResumen p) async {
    await Navigator.of(context).push(EncargadoPedidoView.ruta(p.idPedido));
    _vm.cargar(silencioso: true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BandejaViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bandeja de pedidos'),
            Text(
              vm.bandeja?.botica ?? '',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: vm.cargando ? null : () => vm.cargar(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _Resumen(vm: vm),
          _Filtros(vm: vm),
          if (vm.cargando) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _Lista(vm: vm, onAbrir: _abrir)),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.vm});

  final BandejaViewModel vm;

  @override
  Widget build(BuildContext context) {
    final enOperacion = vm.cantidadEn(EstadoPedido.procesando) +
        vm.cantidadEn(EstadoPedido.empaquetado) +
        vm.cantidadEn(EstadoPedido.enCamino) +
        vm.cantidadEn(EstadoPedido.listoRecoger);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _Contador(valor: enOperacion, etiqueta: 'En operación', color: AppColors.turquesaOscuro),
          const SizedBox(width: 10),
          _Contador(
            valor: vm.cantidadEn(EstadoPedido.procesando),
            etiqueta: 'Por atender',
            color: colorEstado(EstadoPedido.procesando),
          ),
          const SizedBox(width: 10),
          _Contador(
            valor: vm.cantidadEn(EstadoPedido.entregado),
            etiqueta: 'Entregados',
            color: AppColors.exito,
          ),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.etiqueta, required this.color});

  final int valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$valor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ],
        ),
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({required this.vm});

  final BandejaViewModel vm;

  @override
  Widget build(BuildContext context) {
    final conteos = vm.bandeja?.conteos ?? const <ConteoEstado>[];
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Todos (${vm.total})'),
              selected: vm.idEstado == null,
              onSelected: (_) => vm.filtrar(null),
            ),
          ),
          for (final c in conteos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${c.nombre} (${c.cantidad})'),
                selected: vm.idEstado == c.id,
                onSelected: (_) => vm.filtrar(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.vm, required this.onAbrir});

  final BandejaViewModel vm;
  final ValueChanged<PedidoResumen> onAbrir;

  @override
  Widget build(BuildContext context) {
    if (vm.error != null && vm.bandeja == null) {
      return EstadoVacio(
        icono: Icons.cloud_off_outlined,
        titulo: 'No pudimos cargar la bandeja',
        mensaje: vm.error,
        accion: vm.cargar,
      );
    }
    if (vm.bandeja == null) return const Center(child: CircularProgressIndicator());
    if (vm.pedidos.isEmpty) {
      return const EstadoVacio(
        icono: Icons.inbox_outlined,
        titulo: 'No hay pedidos',
        mensaje: 'Los pedidos nuevos aparecerán aquí automáticamente.',
      );
    }
    return RefreshIndicator(
      onRefresh: vm.cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: vm.pedidos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = vm.pedidos[i];
          return TarjetaPedido(
            pedido: p,
            mostrarCliente: true,
            resaltar: p.estado.id == EstadoPedido.procesando,
            onTap: () => onAbrir(p),
          );
        },
      ),
    );
  }
}
