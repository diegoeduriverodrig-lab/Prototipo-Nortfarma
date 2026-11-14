import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../viewmodels/recuperar_viewmodel.dart';
import 'widgets/aviso.dart';
import 'widgets/encabezado_marca.dart';

class RecuperarPasswordView extends StatefulWidget {
  const RecuperarPasswordView({super.key, this.correoInicial = ''});

  final String correoInicial;

  static Route<void> ruta({String correo = ''}) => MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (context) => RecuperarViewModel(context.read<AuthService>()),
      child: RecuperarPasswordView(correoInicial: correo),
    ),
  );

  @override
  State<RecuperarPasswordView> createState() => _RecuperarPasswordViewState();
}

class _RecuperarPasswordViewState extends State<RecuperarPasswordView> {
  final _formKey = GlobalKey<FormState>();
  late final _correo = TextEditingController(text: widget.correoInicial.trim());

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await context.read<RecuperarViewModel>().enviar(_correo.text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecuperarViewModel>();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const EncabezadoMarca(
              titulo: 'Recuperar contraseña',
              subtitulo: 'Te enviaremos un enlace para crear una nueva.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: vm.correoEnviado != null
                  ? _Enviado(correo: vm.correoEnviado!, onReintentar: vm.volverAIntentar)
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ingresa el correo con el que te registraste.',
                            style: TextStyle(fontSize: 15, color: AppColors.texto),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _correo,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.send,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: vm.validarCorreo,
                            onChanged: (_) => vm.limpiarError(),
                            onFieldSubmitted: (_) => _enviar(),
                          ),
                          const SizedBox(height: 16),
                          if (vm.error != null) ...[
                            Aviso(mensaje: vm.error!),
                            const SizedBox(height: 14),
                          ],
                          FilledButton(
                            onPressed: vm.cargando ? null : _enviar,
                            child: vm.cargando
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Enviar enlace'),
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

class _Enviado extends StatelessWidget {
  const _Enviado({required this.correo, required this.onReintentar});

  final String correo;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Aviso(
          tipo: TipoAviso.exito,
          titulo: 'Revisa tu correo',
          // Firebase no revela si el correo existe, por seguridad.
          mensaje:
              'Si $correo tiene una cuenta, recibirás un enlace para crear una '
              'nueva contraseña. Revisa también la carpeta de spam.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver a iniciar sesión'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onReintentar,
          child: const Text('Usar otro correo'),
        ),
      ],
    );
  }
}
