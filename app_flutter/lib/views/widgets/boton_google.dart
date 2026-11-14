import 'package:flutter/material.dart';

class BotonGoogle extends StatelessWidget {
  const BotonGoogle({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "G" en el azul de Google, sin depender de una imagen.
          Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 10),
          Text('Continuar con Google'),
        ],
      ),
    );
  }
}
