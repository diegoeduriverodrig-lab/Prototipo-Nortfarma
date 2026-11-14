import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/perfil_service.dart';
import '../viewmodels/registro_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import 'login_view.dart';
import 'terminos_view.dart';
import 'widgets/aviso.dart';
import 'widgets/encabezado_marca.dart';

class RegistroView extends StatefulWidget {
  const RegistroView({super.key});

  static Route<void> ruta() => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => RegistroViewModel(
        context.read<AuthService>(),
        context.read<PerfilService>(),
      ),
      child: const RegistroView(),
    ),
  );

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _formKey = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _dni = TextEditingController();
  final _celular = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _nombres,
      _apellidos,
      _dni,
      _celular,
      _correo,
      _contrasena,
      _confirmacion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Abre los términos; si el cliente toca "Acepto", se marca la casilla.
  Future<void> _leerTerminos() async {
    final vm = context.read<RegistroViewModel>();
    final acepto = await Navigator.of(context).push(TerminosView.ruta(paraAceptar: true));
    if (acepto == true) vm.cambiarTerminos(true);
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<RegistroViewModel>();
    final ok = await vm.registrar(
      DatosRegistro(
        perfil: DatosPerfil(
          nombres: _nombres.text,
          apellidos: _apellidos.text,
          dni: _dni.text,
          celular: _celular.text,
        ),
        correo: _correo.text,
        contrasena: _contrasena.text,
      ),
    );
    if (!ok || !mounted) return;

    final sesion = context.read<SesionViewModel>();
    final usuario = vm.usuarioRegistrado;
    if (usuario != null) {
      sesion.establecerUsuario(usuario);
    } else {
      // La cuenta existe pero falta el perfil: la raíz mostrará "Completa tu perfil".
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.avisoPerfil ?? 'Completa tu perfil para continuar.')),
      );
      sesion.recargarPerfil();
    }
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegistroViewModel>();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const EncabezadoMarca(
              titulo: 'Registro de cliente',
              subtitulo: 'Crea tu cuenta para hacer pedidos en línea.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _campo(
                      controller: _nombres,
                      etiqueta: 'Nombres',
                      icono: Icons.person_outline,
                      validator: vm.validarNombres,
                      capitalizacion: TextCapitalization.words,
                    ),
                    _campo(
                      controller: _apellidos,
                      etiqueta: 'Apellidos',
                      icono: Icons.person_outline,
                      validator: vm.validarApellidos,
                      capitalizacion: TextCapitalization.words,
                    ),
                    _campo(
                      controller: _dni,
                      etiqueta: 'DNI',
                      icono: Icons.badge_outlined,
                      validator: vm.validarDni,
                      teclado: TextInputType.number,
                      formato: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                    ),
                    _campo(
                      controller: _celular,
                      etiqueta: 'Celular',
                      icono: Icons.phone_android,
                      validator: vm.validarCelular,
                      teclado: TextInputType.phone,
                      formato: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                    ),
                    _campo(
                      controller: _correo,
                      etiqueta: 'Correo electrónico',
                      icono: Icons.mail_outline,
                      validator: vm.validarCorreo,
                      teclado: TextInputType.emailAddress,
                    ),
                    _campo(
                      controller: _contrasena,
                      etiqueta: 'Contraseña',
                      icono: Icons.lock_outline,
                      validator: vm.validarContrasena,
                      oculto: vm.ocultarContrasena,
                      onAlternar: vm.alternarContrasena,
                    ),
                    _campo(
                      controller: _confirmacion,
                      etiqueta: 'Confirmar contraseña',
                      icono: Icons.lock_outline,
                      validator: (v) => vm.validarConfirmacion(v, _contrasena.text),
                      oculto: vm.ocultarContrasena,
                      onAlternar: vm.alternarContrasena,
                      ultimo: true,
                    ),
                    CheckboxListTile(
                      value: vm.aceptaTerminos,
                      onChanged: (v) => vm.cambiarTerminos(v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.turquesa,
                      title: const Text(
                        'Acepto los Términos de servicio y la Política de privacidad',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: vm.mostrarAvisoTerminos
                          ? const Text(
                              'Debes aceptar los términos para continuar',
                              style: TextStyle(color: AppColors.rojo, fontSize: 12),
                            )
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: vm.cargando ? null : _leerTerminos,
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Leer términos y política de privacidad'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (vm.error != null) ...[
                      Aviso(mensaje: vm.error!),
                      const SizedBox(height: 14),
                    ],
                    FilledButton(
                      onPressed: vm.cargando ? null : _registrar,
                      child: vm.cargando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Ya tienes cuenta?'),
                        TextButton(
                          onPressed: vm.cargando
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                  LoginView.ruta(),
                                ),
                          child: const Text('Inicia sesión'),
                        ),
                      ],
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

  Widget _campo({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    required FormFieldValidator<String> validator,
    TextInputType? teclado,
    List<TextInputFormatter>? formato,
    TextCapitalization capitalizacion = TextCapitalization.none,
    bool? oculto,
    VoidCallback? onAlternar,
    bool ultimo = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: teclado,
        inputFormatters: formato,
        textCapitalization: capitalizacion,
        obscureText: oculto ?? false,
        textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          // ExcludeFocus: "Siguiente" del teclado pasa al próximo campo, no al ojo.
          suffixIcon: oculto == null
              ? null
              : ExcludeFocus(
                  child: IconButton(
                    onPressed: onAlternar,
                    icon: Icon(
                      oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
        ),
        validator: validator,
      ),
    );
  }
}
