import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/usuario.dart';
import '../services/perfil_service.dart';
import '../viewmodels/completar_perfil_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import 'widgets/aviso.dart';
import 'widgets/encabezado_marca.dart';

/// Para cuentas sin perfil (por ejemplo, el primer ingreso con Google).
class CompletarPerfilView extends StatelessWidget {
  const CompletarPerfilView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CompletarPerfilViewModel(context.read<PerfilService>()),
      child: const _Formulario(),
    );
  }
}

class _Formulario extends StatefulWidget {
  const _Formulario();

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombres;
  late final TextEditingController _apellidos;
  final _dni = TextEditingController();
  final _celular = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cuenta = context.read<SesionViewModel>().cuenta;
    final (nombres, apellidos) = CompletarPerfilViewModel.separarNombre(cuenta?.nombreVisible);
    _nombres = TextEditingController(text: nombres);
    _apellidos = TextEditingController(text: apellidos);
  }

  @override
  void dispose() {
    for (final c in [_nombres, _apellidos, _dni, _celular]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<CompletarPerfilViewModel>();
    final ok = await vm.guardar(
      DatosPerfil(
        nombres: _nombres.text,
        apellidos: _apellidos.text,
        dni: _dni.text,
        celular: _celular.text,
      ),
    );
    if (ok && mounted) context.read<SesionViewModel>().establecerUsuario(vm.usuario!);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompletarPerfilViewModel>();
    final sesion = context.read<SesionViewModel>();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const EncabezadoMarca(
              titulo: 'Completa tu perfil',
              subtitulo: 'Necesitamos estos datos para tus pedidos y comprobantes.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      sesion.cuenta?.correo ?? '',
                      style: const TextStyle(color: AppColors.textoSecundario),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombres,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombres',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: vm.validarNombres,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _apellidos,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: vm.validarApellidos,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _dni,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'DNI',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: vm.validarDni,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _celular,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Celular',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      validator: vm.validarCelular,
                      onFieldSubmitted: (_) => _guardar(),
                    ),
                    const SizedBox(height: 16),
                    if (vm.error != null) ...[
                      Aviso(mensaje: vm.error!),
                      const SizedBox(height: 14),
                    ],
                    FilledButton(
                      onPressed: vm.cargando ? null : _guardar,
                      child: vm.cargando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar y continuar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: vm.cargando ? null : sesion.cerrarSesion,
                      child: const Text('Usar otra cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
