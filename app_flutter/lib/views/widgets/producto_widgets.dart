import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../models/producto.dart';

/// Íconos que puede tener una categoría (el Administrador elige uno al crearla).
/// Las claves son las mismas que acepta el backend (`icono://<clave>`).
const iconosCategoria = <String, IconData>{
  'medicinas': Icons.medication_outlined,
  'dolor_fiebre': Icons.thermostat_outlined,
  'vitaminas': Icons.spa_outlined,
  'cuidado_personal': Icons.clean_hands_outlined,
  'bebe': Icons.child_care_outlined,
  'botiquin': Icons.medical_services_outlined,
  'piel': Icons.face_retouching_natural_outlined,
  'dental': Icons.sentiment_satisfied_alt_outlined,
  'nutricion': Icons.restaurant_outlined,
  'ojos': Icons.visibility_outlined,
  'corazon': Icons.favorite_border,
  'respiratorio': Icons.air,
  'digestivo': Icons.lunch_dining_outlined,
  'mujer': Icons.female,
  'adulto_mayor': Icons.elderly,
  'deporte': Icons.fitness_center,
};

/// Icono de cada categoría según su icono_url ("icono://medicinas").
IconData iconoCategoria(String iconoUrl) =>
    iconosCategoria[iconoUrl.replaceFirst('icono://', '')] ?? Icons.category_outlined;

/// Imagen del producto (foto completa sobre fondo blanco). Si el producto no tiene
/// foto en Imagen_Producto, o no carga, muestra un recuadro con un icono.
class ImagenProducto extends StatelessWidget {
  const ImagenProducto({super.key, required this.producto, this.tamanoIcono = 40});

  final Producto producto;
  final double tamanoIcono;

  @override
  Widget build(BuildContext context) {
    final url = producto.imagenUrl;
    final provisional = Container(
      color: AppColors.turquesaClaro,
      alignment: Alignment.center,
      child: Icon(Icons.medication_liquid_outlined, size: tamanoIcono, color: AppColors.turquesa),
    );
    if (url == null || url.isEmpty) return provisional;
    // contain: las fotos son del envase completo y no deben recortarse.
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.network(
          Config.urlImagen(url),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => provisional,
        ),
      ),
    );
  }
}

/// Etiqueta de disponibilidad: En stock / Pocas unidades / Agotado.
class EtiquetaStock extends StatelessWidget {
  const EtiquetaStock({super.key, required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final (String texto, Color color) = switch (producto.nivelStock) {
      NivelStock.disponible => ('En stock', AppColors.exito),
      NivelStock.pocasUnidades => ('Pocas unidades', const Color(0xFFE65100)),
      NivelStock.agotado => ('Agotado', const Color(0xFFC62828)),
      NivelStock.desconocido => ('Stock no disponible', AppColors.textoSecundario),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Etiqueta "-15%" de un producto en oferta (descuento vigente en Nortfarma).
class EtiquetaDescuento extends StatelessWidget {
  const EtiquetaDescuento({super.key, required this.porcentaje});

  final double porcentaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.rojo, borderRadius: BorderRadius.circular(6)),
      child: Text(
        '-${porcentaje.toStringAsFixed(0)}%',
        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Precio final y, si hay descuento, el precio regular tachado.
class PrecioProducto extends StatelessWidget {
  const PrecioProducto({
    super.key,
    required this.precio,
    this.precioRegular,
    this.tamano = 15,
    this.alinearDerecha = false,
  });

  final double? precio;
  final double? precioRegular;
  final double tamano;
  final bool alinearDerecha;

  @override
  Widget build(BuildContext context) {
    final regular = precioRegular;
    final conDescuento = precio != null && regular != null && regular > precio!;
    return Column(
      crossAxisAlignment: alinearDerecha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (conDescuento)
          Text(
            Formato.soles(regular),
            style: TextStyle(
              fontSize: tamano * 0.75,
              color: AppColors.textoSecundario,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          Formato.soles(precio),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: tamano,
            color: conDescuento ? AppColors.rojo : AppColors.texto,
          ),
        ),
      ],
    );
  }
}

/// Etiqueta "Requiere receta".
class EtiquetaReceta extends StatelessWidget {
  const EtiquetaReceta({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 12, color: Color(0xFFE65100)),
          SizedBox(width: 3),
          Text(
            'Requiere receta',
            style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de producto para la cuadrícula de Inicio, con botón "Comprar" si se pasa [onComprar].
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({super.key, required this.producto, required this.onTap, this.onComprar});

  final Producto producto;
  final VoidCallback onTap;
  final VoidCallback? onComprar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImagenProducto(producto: producto),
                  if (producto.conDescuento)
                    Positioned(top: 8, left: 8, child: EtiquetaDescuento(porcentaje: producto.descuento)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (producto.empaque.isNotEmpty)
                    Text(
                      producto.empaque,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
                    ),
                  const SizedBox(height: 4),
                  EtiquetaStock(producto: producto),
                  const SizedBox(height: 6),
                  PrecioProducto(precio: producto.precio, precioRegular: producto.precioRegular),
                ],
              ),
            ),
            if (onComprar != null) ...[
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: producto.disponible ? onComprar : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: Text(producto.disponible ? 'Comprar' : 'Agotado'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de producto para la lista de resultados de búsqueda.
class FilaProducto extends StatelessWidget {
  const FilaProducto({super.key, required this.producto, required this.onTap});

  final Producto producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ImagenProducto(producto: producto, tamanoIcono: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      producto.empaque.isNotEmpty ? producto.empaque : producto.especificaciones,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        EtiquetaStock(producto: producto),
                        if (producto.conDescuento) EtiquetaDescuento(porcentaje: producto.descuento),
                        if (producto.requiereReceta) const EtiquetaReceta(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PrecioProducto(precio: producto.precio, precioRegular: producto.precioRegular, alinearDerecha: true),
            ],
          ),
        ),
      ),
    );
  }
}
