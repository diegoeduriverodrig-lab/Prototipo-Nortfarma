import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../viewmodels/login_viewmodel.dart';
import 'recuperar_password_view.dart';
import 'registro_view.dart';
import 'widgets/aviso.dart';
import 'widgets/boton_google.dart';
import 'widgets/encabezado_marca.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  static Route<void> ruta() => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => LoginViewModel(context.read<AuthService>()),
      child: const LoginView(),
    ),
  );

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<LoginViewModel>().iniciarSesion(
      _correo.text,
      _contrasena.text,
    );
    if (ok && mounted) _volverAlInicio();
  }

  Future<void> _iniciarConGoogle() async {
    final ok = await context.read<LoginViewModel>().iniciarConGoogle();
    if (ok && mounted) _volverAlInicio();
  }

  /// La raíz (SplashView) detecta la sesión y muestra el Inicio.
  void _volverAlInicio() =>
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const EncabezadoMarca(
              titulo: 'Inicio de sesión',
              subtitulo: 'Accede para comprar medicamentos y consultar tus pedidos.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ingresa a tu cuenta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        hintText: 'cliente@dominio.com',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: vm.validarCorreo,
                      onChanged: (_) => vm.limpiarError(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contrasena,
                      obscureText: vm.ocultarContrasena,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: ExcludeFocus(
                          child: IconButton(
                            onPressed: vm.alternarContrasena,
                            tooltip: vm.ocultarContrasena ? 'Mostrar' : 'Ocultar',
                            icon: Icon(
                              vm.ocultarContrasena
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      validator: vm.validarContrasena,
                      onChanged: (_) => vm.limpiarError(),
                      onFieldSubmitted: (_) => _iniciarSesion(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: vm.cargando
                            ? null
                            : () => Navigator.of(context).push(
                                RecuperarPasswordView.ruta(correo: _correo.text),
                              ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    if (vm.error != null) ...[
                      Aviso(mensaje: vm.error!),
                      const SizedBox(height: 14),
                    ],
                    FilledButton.icon(
                      onPressed: vm.cargando ? null : _iniciarSesion,
                      icon: vm.cargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Iniciar sesión'),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o',
                            style: TextStyle(color: AppColors.textoSecundario),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BotonGoogle(onPressed: vm.cargando ? null : _iniciarConGoogle),
                    const SizedBox(height: 20),
                    const Aviso(
                      tipo: TipoAviso.info,
                      titulo: 'Acceso según tu rol',
                      mensaje:
                          'El acceso depende del rol de tu cuenta. Como cliente, '
                          'serás dirigido al Inicio y al Catálogo.',
                    ),
                    const SizedBox(height: 12),
                    const Aviso(
                      tipo: TipoAviso.exito,
                      titulo: 'Tu compra y tus datos están protegidos',
                      mensaje:
                          'Tu información se usa solo para gestionar tu cuenta, '
                          'pedidos y entregas.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿No tienes cuenta?'),
                        TextButton(
                          onPressed: vm.cargando
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                  RegistroView.ruta(),
                                ),
                          child: const Text('Crear cuenta'),
                        ),
                      ],
                    ),
                    const Text(
                      '¿Problemas para ingresar? Contacta al administrador de tu botica.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
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
