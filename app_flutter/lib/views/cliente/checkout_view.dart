import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../models/pedido.dart';
import '../../services/culqi_service.dart';
import '../../services/imagen_service.dart';
import '../../services/pedido_service.dart';
import '../../viewmodels/carrito_viewmodel.dart';
import '../../viewmodels/checkout_viewmodel.dart';
import '../../viewmodels/sesion_viewmodel.dart';
import '../widgets/aviso.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/formulario_tarjeta.dart';
import 'confirmacion_pedido_view.dart';
import 'direccion_form_view.dart';

/// Checkout: entrega, receta, comprobante, pago y resumen (RF01, RF02, RF04, RF14).
class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  static Route<void> ruta() => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => CheckoutViewModel(
        context.read<PedidoService>(),
        context.read<ImagenService>(),
        context.read<CulqiService>(),
        context.read<CarritoViewModel>(),
      ),
      child: const CheckoutView(),
    ),
  );

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _formKey = GlobalKey<FormState>();
  final _ruc = TextEditingController();
  final _razonSocial = TextEditingController();
  final _promocion = TextEditingController();
  final _tarjeta = ControladorTarjeta();

  @override
  void dispose() {
    _tarjeta.dispose();
    _ruc.dispose();
    _razonSocial.dispose();
    _promocion.dispose();
    super.dispose();
  }

  Future<void> _nuevaDireccion(CheckoutViewModel vm) async {
    final direccion = await Navigator.of(context).push(DireccionFormView.ruta());
    if (direccion != null) await vm.agregarDireccion(direccion);
  }

  Future<void> _elegirOrigenReceta(CheckoutViewModel vm) async {
    final origen = await showModalBottomSheet<OrigenImagen>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, OrigenImagen.camara),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, OrigenImagen.galeria),
            ),
          ],
        ),
      ),
    );
    if (origen != null) await vm.adjuntarReceta(origen);
  }

  Future<void> _confirmar(CheckoutViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final email = context.read<SesionViewModel>().usuario?.correo ?? '';
    final ok = await vm.confirmar(
      ruc: _ruc.text.trim(),
      razonSocial: _razonSocial.text.trim(),
      codigoPromocion: _promocion.text,
      tarjeta: vm.pedirTarjeta ? _tarjeta.datos(email) : null,
    );
    if (!ok) _tarjeta.cvv.clear();
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(ConfirmacionPedidoView.ruta(vm.pedido!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CheckoutViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.turquesa,
        foregroundColor: Colors.white,
        title: const Text('Finalizar compra'),
      ),
      body: vm.preparando
          ? const Center(child: CircularProgressIndicator())
          : vm.errorCarga != null
          ? EstadoVacio(
              icono: Icons.cloud_off_outlined,
              titulo: 'No pudimos preparar tu compra',
              mensaje: vm.errorCarga,
              accion: vm.reintentar,
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (vm.sinStock.isNotEmpty) ...[
                    Aviso(
                      titulo: 'Stock insuficiente',
                      mensaje:
                          '${vm.sinStock.join(', ')}. Vuelve al carrito y ajusta las cantidades.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Seccion(
                    numero: 1,
                    titulo: 'Entrega',
                    child: _SeccionEntrega(vm: vm, onNuevaDireccion: () => _nuevaDireccion(vm)),
                  ),
                  if (vm.carrito.requiereReceta)
                    _Seccion(
                      numero: 2,
                      titulo: 'Receta médica',
                      child: _SeccionReceta(vm: vm, onAdjuntar: () => _elegirOrigenReceta(vm)),
                    ),
                  _Seccion(
                    numero: vm.carrito.requiereReceta ? 3 : 2,
                    titulo: 'Comprobante',
                    child: _SeccionComprobante(vm: vm, ruc: _ruc, razonSocial: _razonSocial),
                  ),
                  _Seccion(
                    numero: vm.carrito.requiereReceta ? 4 : 3,
                    titulo: 'Método de pago',
                    child: _SeccionPago(vm: vm, tarjeta: _tarjeta),
                  ),
                  _Seccion(
                    numero: vm.carrito.requiereReceta ? 5 : 4,
                    titulo: 'Resumen',
                    child: _SeccionResumen(vm: vm, promocion: _promocion),
                  ),
                  if (vm.error != null) Aviso(mensaje: vm.error!),
                ],
              ),
            ),
      bottomNavigationBar: vm.preparando || vm.errorCarga != null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.borde)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vm.faltante != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          vm.faltante!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                        ),
                      ),
                    FilledButton(
                      onPressed: vm.faltante == null && !vm.enviando ? () => _confirmar(vm) : null,
                      child: vm.enviando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Confirmar pedido  ${Formato.soles(vm.total)}'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.numero, required this.titulo, required this.child});

  final int numero;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.turquesa,
                child: Text(
                  '$numero',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SeccionEntrega extends StatelessWidget {
  const _SeccionEntrega({required this.vm, required this.onNuevaDireccion});

  final CheckoutViewModel vm;
  final VoidCallback onNuevaDireccion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TipoEntrega>(
          segments: const [
            ButtonSegment(
              value: TipoEntrega.delivery,
              icon: Icon(Icons.delivery_dining_outlined),
              label: Text('Delivery'),
            ),
            ButtonSegment(
              value: TipoEntrega.recojo,
              icon: Icon(Icons.storefront_outlined),
              label: Text('Recojo en botica'),
            ),
          ],
          selected: {vm.entrega},
          onSelectionChanged: (s) => vm.elegirEntrega(s.first),
        ),
        const SizedBox(height: 12),
        if (vm.entrega == TipoEntrega.delivery) ...[
          RadioGroup<int>(
            groupValue: vm.idDireccion,
            onChanged: (id) {
              if (id != null) vm.elegirDireccion(id);
            },
            child: Column(
              children: [
                for (final d in vm.direcciones)
                  RadioListTile<int>(
                    value: d.id,
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.direccionExacta),
                    subtitle: Text(
                      [d.distrito, if (d.referencia != null) d.referencia!].join(' · '),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onNuevaDireccion,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(vm.direcciones.isEmpty ? 'Agregar dirección' : 'Agregar otra dirección'),
          ),
          if (vm.cotizando)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (vm.cotizacion != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Despacha: ${vm.cotizacion!.botica.nombre} · '
                '${vm.cotizacion!.distanciaKm.toStringAsFixed(1)} km · '
                'envío ${Formato.soles(vm.cotizacion!.costo)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario),
              ),
            ),
          if (vm.errorEnvio != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Aviso(mensaje: vm.errorEnvio!),
            ),
        ] else
          RadioGroup<int>(
            groupValue: vm.idBotica,
            onChanged: (id) {
              if (id != null) vm.elegirBotica(id);
            },
            child: Column(
              children: [
                for (final b in vm.boticas)
                  RadioListTile<int>(
                    value: b.id,
                    enabled: b.tieneStock,
                    contentPadding: EdgeInsets.zero,
                    title: Text(b.nombre),
                    subtitle: Text(
                      b.tieneStock
                          ? '${b.direccion}\n${b.horario}'
                          : '${b.direccion}\nNo tiene stock de: ${b.productosSinStock.join(', ')}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeccionReceta extends StatelessWidget {
  const _SeccionReceta({required this.vm, required this.onAdjuntar});

  final CheckoutViewModel vm;
  final VoidCallback onAdjuntar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tu pedido incluye productos que requieren receta. '
          'Adjunta una foto clara de tu receta médica.',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (vm.recetaVista != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.memory(vm.recetaVista!, height: 180, width: double.infinity, fit: BoxFit.cover),
                if (vm.subiendoReceta)
                  const CircularProgressIndicator()
                else if (vm.recetaLista)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.exito,
                      child: Icon(Icons.check, size: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: vm.subiendoReceta ? null : onAdjuntar,
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(vm.recetaVista == null ? 'Adjuntar receta' : 'Cambiar imagen'),
        ),
      ],
    );
  }
}

class _SeccionComprobante extends StatelessWidget {
  const _SeccionComprobante({required this.vm, required this.ruc, required this.razonSocial});

  final CheckoutViewModel vm;
  final TextEditingController ruc;
  final TextEditingController razonSocial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TipoComprobante>(
          segments: const [
            ButtonSegment(value: TipoComprobante.boleta, label: Text('Boleta')),
            ButtonSegment(value: TipoComprobante.factura, label: Text('Factura')),
          ],
          selected: {vm.comprobante},
          onSelectionChanged: (s) => vm.elegirComprobante(s.first),
        ),
        if (vm.comprobante == TipoComprobante.factura) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: ruc,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: const InputDecoration(labelText: 'RUC', prefixIcon: Icon(Icons.business)),
            validator: vm.validarRuc,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: razonSocial,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Razón social',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: vm.validarRazonSocial,
          ),
        ],
      ],
    );
  }
}

class _SeccionPago extends StatelessWidget {
  const _SeccionPago({required this.vm, required this.tarjeta});

  final CheckoutViewModel vm;
  final ControladorTarjeta tarjeta;

  String? _detalle(TipoPago t) => switch (t) {
    TipoPago.tarjeta => Config.culqiHabilitado ? 'Visa, Mastercard, Amex · Culqi (modo prueba)' : 'Pago simulado en el prototipo',
    TipoPago.yapePlin => 'Pago simulado en el prototipo',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _opciones(),
        if (vm.pedirTarjeta) ...[const SizedBox(height: 8), FormularioTarjeta(controlador: tarjeta)],
      ],
    );
  }

  Widget _opciones() {
    return RadioGroup<TipoPago>(
      groupValue: vm.tipoPago,
      onChanged: (t) {
        if (t != null) vm.elegirPago(t);
      },
      child: Column(
        children: [
          for (final t in TipoPago.values)
            RadioListTile<TipoPago>(
              value: t,
              contentPadding: EdgeInsets.zero,
              title: Text(t.nombre),
              subtitle: _detalle(t) == null ? null : Text(_detalle(t)!),
            ),
        ],
      ),
    );
  }
}

class _SeccionResumen extends StatelessWidget {
  const _SeccionResumen({required this.vm, required this.promocion});

  final CheckoutViewModel vm;
  final TextEditingController promocion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in vm.carrito.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text('${i.cantidad} x ${i.nombre}')),
                Text(Formato.soles(i.subtotal)),
              ],
            ),
          ),
        const Divider(height: 20),
        _Fila(etiqueta: 'Subtotal', valor: Formato.soles(vm.subtotal)),
        _Fila(
          etiqueta: 'Envío',
          valor: vm.entrega == TipoEntrega.recojo ? 'Gratis' : Formato.soles(vm.costoEnvio),
        ),
        _Fila(etiqueta: 'Total', valor: Formato.soles(vm.total), resaltado: true),
        const SizedBox(height: 12),
        TextField(
          controller: promocion,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código de promoción (opcional)',
            prefixIcon: Icon(Icons.local_offer_outlined),
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.etiqueta, required this.valor, this.resaltado = false});

  final String etiqueta;
  final String valor;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: resaltado ? 18 : 14,
      fontWeight: resaltado ? FontWeight.w800 : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}
