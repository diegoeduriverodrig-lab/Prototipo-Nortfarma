/// Categoría del catálogo (tabla Categoria_App).
class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    required this.iconoUrl,
    this.cantidad = 0,
  });

  factory Categoria.desdeJson(Map<String, dynamic> json) => Categoria(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    iconoUrl: json['iconoUrl'] as String? ?? '',
    cantidad: json['cantidad'] as int? ?? 0,
  );

  final int id;
  final String nombre;
  final String iconoUrl;

  /// Productos a la venta en esta categoría.
  final int cantidad;
}

enum NivelStock { disponible, pocasUnidades, agotado, desconocido }

/// Forma de venta de un producto (mismos valores que la API).
enum TipoPresentacion {
  empaque('EMPAQUE'),
  blister('BLISTER'),
  fraccion('FRACCION');

  const TipoPresentacion(this.valor);
  final String valor;

  static TipoPresentacion desde(String? valor) =>
      values.firstWhere((t) => t.valor == valor, orElse: () => empaque);
}

/// Presentación a la venta (caja, blíster o unidad) con su precio y stock en tiempo real.
class Presentacion {
  const Presentacion({
    required this.tipo,
    required this.nombre,
    required this.unidades,
    required this.precio,
    required this.precioRegular,
    required this.stock,
  });

  factory Presentacion.desdeJson(Map<String, dynamic> json) => Presentacion(
    tipo: TipoPresentacion.desde(json['tipo'] as String?),
    nombre: json['nombre'] as String,
    unidades: json['unidades'] as int? ?? 1,
    precio: (json['precio'] as num).toDouble(),
    precioRegular: (json['precioRegular'] as num? ?? json['precio'] as num).toDouble(),
    stock: json['stock'] as int? ?? 0,
  );

  final TipoPresentacion tipo;

  /// "Caja x 100 tabletas", "Blíster x 10" o "Unidad".
  final String nombre;
  final int unidades;

  /// Precio final (con descuento si hay).
  final double precio;
  final double precioRegular;
  final int stock;

  bool get disponible => stock > 0;
  bool get conDescuento => precioRegular > precio;
}

/// Producto del catálogo: datos de MySQL (copia diaria de Nortfarma) + precio,
/// descuento y stock en tiempo real del sistema de Nortfarma.
class Producto {
  const Producto({
    required this.idProducto,
    required this.nombre,
    required this.especificaciones,
    required this.requiereReceta,
    required this.idCategoria,
    required this.categoria,
    this.empaque = '',
    this.imagenUrl,
    this.imagenes = const [],
    this.precio,
    this.precioRegular,
    this.stock,
    this.descuento = 0,
    this.presentaciones = const [],
    this.disponible = false,
  });

  factory Producto.desdeJson(Map<String, dynamic> json) {
    final categoria = json['categoria'] as Map<String, dynamic>;
    return Producto(
      idProducto: json['idProducto'] as int,
      nombre: json['nombre'] as String,
      especificaciones: json['especificaciones'] as String? ?? '',
      empaque: json['empaque'] as String? ?? '',
      requiereReceta: json['requiereReceta'] as bool? ?? false,
      idCategoria: categoria['id'] as int,
      categoria: categoria['nombre'] as String,
      imagenUrl: json['imagenUrl'] as String?,
      imagenes: (json['imagenes'] as List?)?.cast<String>() ?? const [],
      precio: (json['precio'] as num?)?.toDouble(),
      precioRegular: (json['precioRegular'] as num?)?.toDouble(),
      stock: json['stock'] as int?,
      descuento: (json['descuento'] as num?)?.toDouble() ?? 0,
      presentaciones: (json['presentaciones'] as List?)
              ?.map((p) => Presentacion.desdeJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      disponible: json['disponible'] as bool? ?? false,
    );
  }

  static const umbralPocasUnidades = 5;

  final int idProducto;
  final String nombre;
  final String especificaciones;
  final bool requiereReceta;
  final int idCategoria;
  final String categoria;

  /// Presentación principal: "Caja x 100 tabletas", "Unidad"...
  final String empaque;
  final String? imagenUrl;
  final List<String> imagenes;

  /// Precio y stock del empaque. null si el sistema de Nortfarma no respondió.
  final double? precio;
  final double? precioRegular;
  final int? stock;

  /// Porcentaje de descuento vigente (0 si no hay).
  final double descuento;
  final List<Presentacion> presentaciones;

  /// Hay stock de alguna presentación.
  final bool disponible;

  bool get conDescuento => descuento > 0;

  Presentacion? presentacion(TipoPresentacion tipo) {
    for (final p in presentaciones) {
      if (p.tipo == tipo) return p;
    }
    return null;
  }

  NivelStock get nivelStock {
    final s = stock;
    if (s == null) return NivelStock.desconocido;
    if (!disponible) return NivelStock.agotado;
    if (s > 0 && s <= umbralPocasUnidades) return NivelStock.pocasUnidades;
    return NivelStock.disponible;
  }
}

/// Orden de los resultados (mismos valores que espera la API).
enum OrdenCatalogo {
  relevancia('relevancia', 'Relevancia'),
  nombre('nombre', 'Nombre (A-Z)'),
  precioAsc('precio_asc', 'Menor precio'),
  precioDesc('precio_desc', 'Mayor precio');

  const OrdenCatalogo(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;
}

/// Resultado de una búsqueda en el catálogo.
class ResultadoCatalogo {
  const ResultadoCatalogo({required this.productos, required this.coreDisponible});

  final List<Producto> productos;

  /// false si el sistema de Nortfarma no respondió: no hay precios ni stock.
  final bool coreDisponible;
}
