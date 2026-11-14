import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formato.dart';
import '../../services/culqi_service.dart';
import '../../services/pedido_service.dart';
import '../../viewmodels/pagar_pedido_viewmodel.dart';
import '../../viewmodels/sesion_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/formulario_tarjeta.dart';

/// Pagar con otra tarjeta un pedido cuyo cobro fue rechazado. Devuelve true si se pagó.
class PagarPedidoView extends StatefulWidget {
  const PagarPedidoView({super.key, this.motivoRechazo});

  final String? motivoRechazo;

  static Route<bool> ruta({
    required int idPedido,
    required String numero,
    required double total,
    String? motivoRechazo,
  }) => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => PagarPedidoViewModel(
        context.read<PedidoService>(),
        context.read<CulqiService>(),
        idPedido: idPedido,
        numero: numero,
        total: total,
      ),
      child: PagarPedidoView(motivoRechazo: motivoRechazo),
    ),
  );

  @override
  State<PagarPedidoView> createState() => _PagarPedidoViewState();
}

class _PagarPedidoViewState extends State<PagarPedidoView> {
  final _formKey = GlobalKey<FormState>();
  final _tarjeta = ControladorTarjeta();

  @override
  void dispose() {
    _tarjeta.dispose();
    super.dispose();
  }

  Future<void> _pagar(PagarPedidoViewModel vm) async {
    FocusScope.of(context).unfocus();
    if (vm.pedirTarjeta && !_formKey.currentState!.validate()) return;
    final email = context.read<SesionViewModel>().usuario?.correo ?? '';
    final ok = await vm.pagar(vm.pedirTarjeta ? _tarjeta.datos(email) : null);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Pago aprobado!')));
      Navigator.of(context).pop(true);
    } else {
      _tarjeta.cvv.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagarPedidoViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: Text('Pagar pedido ${vm.numero}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.motivoRechazo != null && vm.resultado == null) ...[
              Aviso(titulo: 'Tu pago anterior fue rechazado', mensaje: widget.motivoRechazo!),
              const SizedBox(height: 16),
            ],
            Text('Total a pagar', style: const TextStyle(color: AppColors.textoSecundario)),
            Text(Formato.soles(vm.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            if (vm.pedirTarjeta)
              FormularioTarjeta(controlador: _tarjeta)
            else
              const Aviso(
                tipo: TipoAviso.info,
                mensaje: 'Pago simulado: configura la llave de Culqi para pagar con tarjeta de prueba.',
              ),
            if (vm.errorTarjeta != null) ...[const SizedBox(height: 16), Aviso(mensaje: vm.errorTarjeta!)],
            if (vm.error != null) ...[const SizedBox(height: 16), Aviso(mensaje: vm.error!)],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: vm.cargando ? null : () => _pagar(vm),
              icon: vm.cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text('Pagar ${Formato.soles(vm.total)}'),
            ),
          ],
        ),
      ),
    );
  }
}
