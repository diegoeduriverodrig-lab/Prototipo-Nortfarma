import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/validadores.dart';
import '../../services/culqi_service.dart';

/// Campos de la tarjeta. Se guardan en este controlador (no en un ViewModel)
/// porque los datos de la tarjeta solo viajan de la pantalla a Culqi.
class ControladorTarjeta {
  final numero = TextEditingController();
  final vencimiento = TextEditingController();
  final cvv = TextEditingController();

  /// Datos listos para tokenizar. Llamar después de validar el formulario.
  DatosTarjeta datos(String email) {
    final partes = vencimiento.text.split('/');
    return DatosTarjeta(
      numero: numero.text,
      mesVencimiento: int.parse(partes[0]),
      anioVencimiento: 2000 + int.parse(partes[1]),
      cvv: cvv.text.trim(),
      email: email,
    );
  }

  void limpiar() {
    numero.clear();
    vencimiento.clear();
    cvv.clear();
  }

  void dispose() {
    numero.dispose();
    vencimiento.dispose();
    cvv.dispose();
  }
}

/// Formulario de tarjeta (debe ir dentro de un Form).
class FormularioTarjeta extends StatelessWidget {
  const FormularioTarjeta({super.key, required this.controlador});

  final ControladorTarjeta controlador;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controlador.numero,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.creditCardNumber],
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(19),
            _AgruparDeCuatro(),
          ],
          decoration: const InputDecoration(
            labelText: 'Número de tarjeta',
            prefixIcon: Icon(Icons.credit_card),
          ),
          validator: Validadores.numeroTarjeta,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: controlador.vencimiento,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.creditCardExpirationDate],
          textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, _FormatoVencimiento()],
                decoration: const InputDecoration(labelText: 'Vence (MM/AA)'),
                validator: (v) => Validadores.vencimiento(v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controlador.cvv,
                keyboardType: TextInputType.number,
                obscureText: true,
                autofillHints: const [AutofillHints.creditCardSecurityCode],
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'CVV'),
                validator: Validadores.cvv,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textoSecundario),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Pago seguro con Culqi (modo prueba). No guardamos los datos de tu tarjeta.',
                style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "4111111111111111" -> "4111 1111 1111 1111"
class _AgruparDeCuatro extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    final digitos = nuevo.text.replaceAll(' ', '');
    final grupos = [
      for (var i = 0; i < digitos.length; i += 4) digitos.substring(i, i + 4 > digitos.length ? digitos.length : i + 4),
    ];
    final texto = grupos.join(' ');
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

/// "1227" -> "12/27"
class _FormatoVencimiento extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    var digitos = nuevo.text.replaceAll('/', '');
    if (digitos.length > 4) digitos = digitos.substring(0, 4);
    final texto = digitos.length > 2 ? '${digitos.substring(0, 2)}/${digitos.substring(2)}' : digitos;
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
