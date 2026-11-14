import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../viewmodels/admin_viewmodels.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/pedido_widgets.dart';

/// Panel administrativo: indicadores del día, pedidos por estado, usuarios y catálogo.
class PanelAdminView extends StatelessWidget {
  const PanelAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PanelAdminViewModel>();
    final r = vm.resumen;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Panel administrativo'),
        actions: [
          IconButton(
            onPressed: vm.cargando ? null : vm.cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: r == null
          ? (vm.error != null
                ? EstadoVacio(
                    icono: Icons.cloud_off_outlined,
                    titulo: 'No pudimos cargar el panel',
                    mensaje: vm.error,
                    accion: vm.cargar,
                  )
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: vm.cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _Indicador(valor: '${r.pedidosHoy}', etiqueta: 'Pedidos hoy', icono: Icons.receipt_long),
                      const SizedBox(width: 10),
                      _Indicador(
                        valor: Formato.soles(r.ventasHoy),
                        etiqueta: 'Ventas hoy',
                        icono: Icons.payments_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SeccionTarjeta(
                    titulo: 'Pedidos por estado',
                    icono: Icons.pie_chart_outline,
                    child: Column(
                      children: [
                        for (final e in r.pedidosPorEstado)
                          _Barra(
                            etiqueta: e.nombre,
                            cantidad: e.cantidad,
                            maximo: r.pedidosPorEstado.fold(1, (m, x) => x.cantidad > m ? x.cantidad : m),
                            color: colorEstado(int.parse(e.id)),
                          ),
                      ],
                    ),
                  ),
                  SeccionTarjeta(
                    titulo: 'Usuarios',
                    icono: Icons.group_outlined,
                    child: Column(
                      children: [
                        for (final u in r.usuariosPorRol)
                          FilaDato(etiqueta: u.nombre, valor: '${u.cantidad}'),
                      ],
                    ),
                  ),
                  SeccionTarjeta(
                    titulo: 'Catálogo',
                    icono: Icons.inventory_2_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilaDato(etiqueta: 'Productos', valor: '${r.productosTotal}'),
                        FilaDato(etiqueta: 'A la venta', valor: '${r.productosAVenta}'),
                        const SizedBox(height: 10),
                        const Text(
                          'Copia productos y boticas del sistema de Nortfarma (en producción se hace '
                          'sola cada día a las 3:00 a. m.). Los productos nuevos llegan sin categoría: '
                          'asígnasela en Productos para publicarlos.',
                          style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: vm.cargando
                              ? null
                              : () async {
                                  final ok = await vm.sincronizar();
                                  final s = vm.sincronizacion;
                                  if (ok && s != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Productos: ${s.nuevos} nuevos, ${s.actualizados} actualizados '
                                          '(${s.recibidos} revisados). Boticas: ${s.boticasNuevas} nuevas, '
                                          '${s.boticasActualizadas} actualizadas.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.sync),
                          label: const Text('Sincronizar con Nortfarma'),
                        ),
                      ],
                    ),
                  ),
                  if (vm.error != null) Aviso(mensaje: vm.error!),
                ],
              ),
            ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.valor, required this.etiqueta, required this.icono});

  final String valor;
  final String etiqueta;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icono, color: AppColors.turquesa, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra horizontal proporcional a la cantidad.
class _Barra extends StatelessWidget {
  const _Barra({required this.etiqueta, required this.cantidad, required this.maximo, required this.color});

  final String etiqueta;
  final int cantidad;
  final int maximo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(etiqueta, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maximo == 0 ? 0 : cantidad / maximo,
                minHeight: 10,
                color: color,
                backgroundColor: AppColors.fondo,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('$cantidad', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
