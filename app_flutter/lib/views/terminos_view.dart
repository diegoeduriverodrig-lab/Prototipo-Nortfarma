import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Términos de servicio y Política de privacidad (texto genérico del prototipo).
/// Desde el registro se abre con [paraAceptar]: el botón "Acepto" devuelve `true`.
class TerminosView extends StatelessWidget {
  const TerminosView({super.key, this.paraAceptar = false});

  final bool paraAceptar;

  static Route<bool> ruta({bool paraAceptar = false}) =>
      MaterialPageRoute(builder: (_) => TerminosView(paraAceptar: paraAceptar));

  static const _actualizacion = '29 de octubre de 2026';

  static const _terminos = <(String, String)>[
    (
      '1. Aceptación',
      'Al crear una cuenta o usar la app Boticas Felicidad, operada por Nortfarma S.A.C., '
          'aceptas estos Términos de servicio y la Política de privacidad. Si no estás de acuerdo, '
          'no utilices la app.',
    ),
    (
      '2. Cuenta de usuario',
      'Debes ser mayor de 18 años y registrar datos verdaderos (nombre, DNI, celular y correo). '
          'Eres responsable de mantener en reserva tu contraseña y de las compras realizadas con tu cuenta. '
          'Podemos suspender cuentas con datos falsos o uso indebido.',
    ),
    (
      '3. Productos y precios',
      'Los precios, descuentos y el stock se muestran en tiempo real según la botica y pueden cambiar '
          'sin previo aviso. Las imágenes son referenciales. El precio válido es el que figura al '
          'confirmar el pedido e incluye IGV.',
    ),
    (
      '4. Medicamentos con receta',
      'Los productos que requieren receta médica solo se venden si adjuntas una receta válida, legible '
          'y vigente, conforme a la normativa de DIGEMID. La botica puede rechazar el pedido si la receta '
          'no cumple estos requisitos. La información de la app no reemplaza la consulta con un médico '
          'o químico farmacéutico.',
    ),
    (
      '5. Pedidos, delivery y recojo',
      'El delivery se atiende dentro de la zona de cobertura indicada en la app y su costo se calcula '
          'según la distancia. Los tiempos de entrega son estimados. En la modalidad de recojo, el pedido '
          'se entrega al titular presentando su DNI en la botica elegida.',
    ),
    (
      '6. Pagos',
      'Puedes pagar en línea con tarjeta o al momento de la entrega, según las opciones disponibles. '
          'Los pagos con tarjeta se procesan a través de una pasarela de pagos segura; Boticas Felicidad '
          'no almacena los datos completos de tu tarjeta.',
    ),
    (
      '7. Cancelaciones, cambios y devoluciones',
      'Puedes cancelar un pedido mientras no haya sido despachado. Si ya pagaste en línea, el monto se '
          'devuelve por el mismo medio de pago. Por seguridad sanitaria, no se aceptan devoluciones de '
          'medicamentos, salvo productos con defectos o errores en el pedido, que deberás reportar al '
          'momento de recibirlo.',
    ),
    (
      '8. Reclamos',
      'De acuerdo con el Código de Protección y Defensa del Consumidor (Ley N.° 29571), puedes registrar '
          'quejas o reclamos en el Libro de Reclamaciones de cualquiera de nuestras boticas o escribiendo '
          'a nuestros canales de atención.',
    ),
    (
      '9. Cambios en los términos',
      'Podemos actualizar estos términos. Te avisaremos en la app y la fecha de la última actualización '
          'figurará al final de este documento.',
    ),
  ];

  static const _privacidad = <(String, String)>[
    (
      'Datos que recopilamos',
      'Nombre, DNI, celular, correo, direcciones de entrega, ubicación (solo cuando marcas la dirección '
          'en el mapa), historial de pedidos e imágenes de recetas que adjuntes.',
    ),
    (
      'Para qué los usamos',
      'Para crear tu cuenta, procesar y entregar tus pedidos, validar recetas, emitir comprobantes, '
          'atender reclamos y mejorar el servicio.',
    ),
    (
      'Con quién los compartimos',
      'Solo con el personal de la botica y el repartidor que atienden tu pedido, con la pasarela de pagos '
          'y con las autoridades cuando la ley lo exija. No vendemos tus datos.',
    ),
    (
      'Tus derechos',
      'Conforme a la Ley de Protección de Datos Personales (Ley N.° 29733), puedes solicitar el acceso, '
          'rectificación, cancelación u oposición al tratamiento de tus datos escribiendo a nuestros '
          'canales de atención.',
    ),
    (
      'Seguridad',
      'Tus datos se guardan en servidores protegidos y viajan cifrados. Las recetas solo las ve el '
          'personal autorizado.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y privacidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _titulo('Términos de servicio'),
          for (final (subtitulo, texto) in _terminos) _seccion(subtitulo, texto),
          const SizedBox(height: 12),
          _titulo('Política de privacidad'),
          for (final (subtitulo, texto) in _privacidad) _seccion(subtitulo, texto),
          const SizedBox(height: 8),
          const Text(
            'Última actualización: $_actualizacion',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
          ),
        ],
      ),
      bottomNavigationBar: paraAceptar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Acepto'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.turquesa),
    ),
  );

  Widget _seccion(String subtitulo, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subtitulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(texto, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.texto)),
      ],
    ),
  );
}
