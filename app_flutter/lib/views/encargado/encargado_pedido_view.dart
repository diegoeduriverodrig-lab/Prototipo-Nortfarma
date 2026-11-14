import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/seguimiento.dart';
import '../../services/seguimiento_service.dart';
import '../../viewmodels/encargado_pedido_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/detalle_pedido_secciones.dart';
import '../widgets/estado_vacio.dart';

/// Detalle operativo del pedido para el Encargado de botica.
class EncargadoPedidoView extends StatefulWidget {
  const EncargadoPedidoView({super.key});

  static Route<void> ruta(int idPedido) => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => EncargadoPedidoViewModel(context.read<SeguimientoService>(), idPedido),
      child: const EncargadoPedidoView(),
    ),
  );

  @override
  State<EncargadoPedidoView> createState() => _EncargadoPedidoViewState();
}

class _EncargadoPedidoViewState extends State<EncargadoPedidoView> {
  EncargadoPedidoViewModel get _vm => context.read<EncargadoPedidoViewModel>();

  void _mostrarConfirmacion() {
    final mensaje = _vm.tomarMensaje();
    if (mensaje != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _ejecutar(AccionEncargado accion) async {
    final vm = _vm;
    switch (accion) {
      case AccionEncargado.empaquetar:
        if (await _confirmar('¿Confirmas que el pedido está empaquetado?')) {
          await vm.cambiarEstado(EstadoPedido.empaquetado, 'Pedido empaquetado');
        }
      case AccionEncargado.asignarRepartidor:
        await _elegirRepartidor(vm);
      case AccionEncargado.enviar:
        if (await _confirmar('¿El repartidor ya salió con el pedido?')) {
          await vm.cambiarEstado(EstadoPedido.enCamino, 'Pedido en camino');
        }
      case AccionEncargado.listoParaRecoger:
        await vm.cambiarEstado(EstadoPedido.listoRecoger, 'Pedido listo para recoger');
      case AccionEncargado.entregarEnTienda:
        final dni = await _pedirTexto(
          titulo: 'Confirmar entrega',
          mensaje: 'Pide al cliente su DNI y escríbelo para confirmar la entrega.',
          etiqueta: 'DNI del cliente',
          soloNumeros: true,
          largoMaximo: 8,
        );
        if (dni != null) {
          await vm.cambiarEstado(EstadoPedido.entregado, 'Pedido entregado', dniCliente: dni);
        }
      case AccionEncargado.marcarEntregado:
        if (await _confirmar('¿Confirmas que el cliente recibió el pedido?')) {
          await vm.cambiarEstado(EstadoPedido.entregado, 'Pedido entregado');
        }
      case AccionEncargado.marcarFallido:
        final motivo = await _pedirTexto(
          titulo: 'Marcar como fallido',
          mensaje: 'El pedido se cancelará y los productos volverán al inventario.',
          etiqueta: 'Motivo',
        );
        if (motivo != null) {
          await vm.cambiarEstado(EstadoPedido.fallido, 'Pedido marcado como fallido', motivo: motivo);
        }
    }
    _mostrarConfirmacion();
  }

  Future<void> _elegirRepartidor(EncargadoPedidoViewModel vm) async {
    await vm.cargarRepartidores();
    if (!mounted) return;
    final elegido = await showModalBottomSheet<Repartidor>(
      context: context,
      builder: (context) => SafeArea(
        child: vm.repartidores.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay repartidores registrados. Pide al administrador que cree uno.'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Seleccionar repartidor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final r in vm.repartidores)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(r.nombre),
                      subtitle: Text(
                        r.disponible ? 'Disponible' : '${r.entregasActivas} entrega(s) en curso',
                        style: TextStyle(
                          color: r.disponible ? AppColors.exito : const Color(0xFFE65100),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, r),
                    ),
                ],
              ),
      ),
    );
    if (elegido != null) await vm.asignarRepartidor(elegido);
  }

  Future<bool> _confirmar(String pregunta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(pregunta),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> _pedirTexto({
    required String titulo,
    required String mensaje,
    required String etiqueta,
    bool soloNumeros = false,
    int largoMaximo = 200,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _DialogoTexto(
        titulo: titulo,
        mensaje: mensaje,
        etiqueta: etiqueta,
        soloNumeros: soloNumeros,
        largoMaximo: largoMaximo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EncargadoPedidoViewModel>();
    final p = vm.pedido;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Detalle operativo'),
      ),
      body: p == null
          ? (vm.error != null
                ? EstadoVacio(
                    icono: Icons.error_outline,
                    titulo: 'No pudimos cargar el pedido',
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
                  SeccionesDetallePedido(pedido: p, paraPersonal: true),
                ],
              ),
            ),
      bottomNavigationBar: p == null || vm.acciones.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.borde)),
                ),
                child: Row(
                  children: [
                    for (final a in vm.acciones) ...[
                      if (a != vm.acciones.first) const SizedBox(width: 10),
                      Expanded(
                        flex: a == AccionEncargado.marcarFallido ? 2 : 3,
                        child: _BotonAccion(
                          accion: a,
                          habilitado: !vm.cargando,
                          onPressed: () => _ejecutar(a),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.accion, required this.habilitado, required this.onPressed});

  final AccionEncargado accion;
  final bool habilitado;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (String texto, IconData icono) = switch (accion) {
      AccionEncargado.empaquetar => ('Empaquetado', Icons.inventory_2_outlined),
      AccionEncargado.asignarRepartidor => ('Asignar repartidor', Icons.person_add_alt),
      AccionEncargado.enviar => ('Enviar', Icons.delivery_dining_outlined),
      AccionEncargado.listoParaRecoger => ('Listo para recoger', Icons.storefront_outlined),
      AccionEncargado.entregarEnTienda => ('Entregar', Icons.how_to_reg_outlined),
      AccionEncargado.marcarEntregado => ('Entregado', Icons.check_circle_outline),
      AccionEncargado.marcarFallido => ('Fallido', Icons.cancel_outlined),
    };
    if (accion == AccionEncargado.marcarFallido) {
      return OutlinedButton(
        onPressed: habilitado ? onPressed : null,
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
        child: Text(texto),
      );
    }
    return FilledButton.icon(
      onPressed: habilitado ? onPressed : null,
      icon: Icon(icono),
      label: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Diálogo con un campo de texto obligatorio.
class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.mensaje,
    required this.etiqueta,
    required this.soloNumeros,
    required this.largoMaximo,
  });

  final String titulo;
  final String mensaje;
  final String etiqueta;
  final bool soloNumeros;
  final int largoMaximo;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.mensaje),
          const SizedBox(height: 12),
          TextField(
            controller: _texto,
            autofocus: true,
            keyboardType: widget.soloNumeros ? TextInputType.number : TextInputType.text,
            inputFormatters: [
              if (widget.soloNumeros) FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.largoMaximo),
            ],
            decoration: InputDecoration(labelText: widget.etiqueta),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: _texto.text.trim().length < 3
              ? null
              : () => Navigator.pop(context, _texto.text.trim()),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
