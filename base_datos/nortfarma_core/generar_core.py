"""
Genera la base de datos SIMULADA del sistema de Nortfarma (nortfarma_core) y la
precarga de la app (Producto_App y Botica) a partir de los Excel que envió Nortfarma.

    python generar_core.py

Entrada (carpeta datos_origen/):
  - productos_nortfarma.xlsx  1400 productos reales (referencia, nombre, categoría, P.V.U., ...)
  - boticas_nortfarma.xlsx    115 boticas reales (código, departamento, zona, horarios)

Salida:
  - nortfarma_core.sql   estructura + datos del "sistema de Nortfarma" (reducido)
  - ../precarga_app.sql  carga inicial de la app: productos con su categoría y boticas

Los datos que el Excel trae vacíos se completan así:
- Tipo de receta: según la normativa de DIGEMID (ver receta_digemid.py).
- Nombre y dirección de las boticas de la app: Excel de la zona objetivo de Nortfarma
  (boticas_zona_piura.xlsx), con coordenadas de OpenStreetMap (ver COORDENADAS).
- Blíster, fracción, stock, vencimiento y descuentos: valores de prueba ("inventado").
Siempre salen iguales (semilla fija). Solo usa la biblioteca estándar de Python.
"""
import random
import re
import zipfile
import xml.etree.ElementTree as ET
from datetime import date, timedelta
import sys
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
sys.path.insert(0, str(CARPETA))
from receta_digemid import tipo_receta  # noqa: E402
ORIGEN = CARPETA / "datos_origen"
SALIDA_CORE = CARPETA / "nortfarma_core.sql"
SALIDA_PRECARGA = CARPETA.parent / "precarga_app.sql"

azar = random.Random(2026)
HOY = date(2026, 10, 15)

# ---------------------------------------------------------------------------
# Lectura de .xlsx (sin dependencias)
# ---------------------------------------------------------------------------
NS = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}


def _columna(ref):
    n = 0
    for ch in re.match(r"[A-Z]+", ref).group():
        n = n * 26 + ord(ch) - 64
    return n - 1


def leer_primera_hoja(ruta):
    z = zipfile.ZipFile(ruta)
    compartidos = []
    if "xl/sharedStrings.xml" in z.namelist():
        for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall("m:si", NS):
            compartidos.append("".join(t.text or "" for t in si.iter(f"{{{NS['m']}}}t")))
    libro = ET.fromstring(z.read("xl/workbook.xml"))
    rels = {r.get("Id"): r.get("Target") for r in ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))}
    hoja = libro.find("m:sheets", NS)[0]
    destino = rels[hoja.get(f"{{{NS['r']}}}id")].lstrip("/")
    destino = destino if destino.startswith("xl/") else "xl/" + destino
    filas = []
    for fila in ET.fromstring(z.read(destino)).iter(f"{{{NS['m']}}}row"):
        valores = {}
        for c in fila.findall("m:c", NS):
            v = c.find("m:v", NS)
            tipo = c.get("t")
            if tipo == "inlineStr":
                valor = "".join(x.text or "" for x in c.iter(f"{{{NS['m']}}}t"))
            elif v is None:
                continue
            elif tipo == "s":
                valor = compartidos[int(v.text)]
            else:
                valor = v.text
            valores[_columna(c.get("r"))] = valor.strip()
        if valores:
            filas.append([valores.get(i, "") for i in range(max(valores) + 1)])
    return filas


# ---------------------------------------------------------------------------
# Utilidades SQL
# ---------------------------------------------------------------------------
def q(valor):
    if valor is None:
        return "NULL"
    if isinstance(valor, bool):
        return "TRUE" if valor else "FALSE"
    if isinstance(valor, (int, float)):
        return repr(valor)
    if isinstance(valor, date):
        return f"'{valor.isoformat()}'"
    return "'" + str(valor).replace("\\", "\\\\").replace("'", "''") + "'"


def inserts(tabla, columnas, filas, lote=400):
    salida = []
    for i in range(0, len(filas), lote):
        valores = ",\n".join("  (" + ", ".join(q(v) for v in f) + ")" for f in filas[i:i + lote])
        salida.append(f"INSERT INTO {tabla} ({', '.join(columnas)}) VALUES\n{valores};\n")
    return "\n".join(salida)


def hora(texto):
    """'7:00:00 a.m.' -> '07:00:00'; 'NA' o vacío -> None."""
    m = re.match(r"(\d{1,2}):(\d{2})(?::\d{2})?\s*([ap])\.?\s*m", texto.strip().lower())
    if not m:
        return None
    h, minutos, ampm = int(m.group(1)), int(m.group(2)), m.group(3)
    if ampm == "p" and h != 12:
        h += 12
    if ampm == "a" and h == 12:
        h = 0
    return f"{h:02d}:{minutos:02d}:00"


# ---------------------------------------------------------------------------
# Boticas
# ---------------------------------------------------------------------------
# Boticas de la zona objetivo (Piura, Castilla y Veintiséis de Octubre): código, nombre y
# dirección vienen de datos_origen/boticas_zona_piura.xlsx, enviado por Nortfarma.
# Todas permiten recojo; la de delivery es la F24 (Galería Country, junto al BCP).
BOTICA_DELIVERY = "F24"

# Coordenadas (el Excel no las trae). Fuente: OpenStreetMap (https://www.openstreetmap.org, ODbL).
# Precisión: "exacta" = local de Felicidad ubicado en OSM; "calle" = tramo de la calle;
# "zona" = centro de la urbanización o A.H.; "estimada" = por la numeración de la avenida.
COORDENADAS = {
    "ASU": (-5.1976443, -80.6220987, "calle"), "CEN": (-5.1949600, -80.6267600, "estimada"),
    "F1": (-5.1920444, -80.6287626, "exacta"), "F2": (-5.1957869, -80.6295271, "calle"),
    "F3": (-5.1899000, -80.6289500, "estimada"), "F4": (-5.1921544, -80.6286462, "exacta"),
    "F6": (-5.1914700, -80.6544700, "zona"), "F14": (-5.1883910, -80.6599691, "zona"),
    "F20": (-5.1891369, -80.6339894, "calle"), "F22": (-5.1879959, -80.6068354, "zona"),
    "F24": (-5.1828535, -80.6312327, "exacta"), "F32": (-5.1986152, -80.6334449, "calle"),
    "F33": (-5.1847800, -80.6300400, "zona"), "F34": (-5.1940332, -80.6202086, "exacta"),
    "F35": (-5.1926300, -80.6380900, "estimada"), "F40": (-5.1903500, -80.6491800, "estimada"),
    "F43": (-5.1885133, -80.6180125, "exacta"), "F44": (-5.1915532, -80.6433587, "exacta"),
    "F49": (-5.1910800, -80.6106900, "zona"), "F52": (-5.1889281, -80.6330009, "calle"),
    "F56": (-5.1970946, -80.6479114, "zona"), "F58": (-5.1784300, -80.6392200, "zona"),
    "F59": (-5.2068668, -80.6251002, "calle"), "F62": (-5.1887200, -80.6286400, "zona"),
    "F63": (-5.1792500, -80.6743121, "zona"), "F69": (-5.1918471, -80.6568185, "exacta"),
    "F70": (-5.2006500, -80.6342700, "zona"), "F71": (-5.1872700, -80.6178600, "calle"),
    "F72": (-5.1858984, -80.6585964, "exacta"), "F75": (-5.1743700, -80.6553300, "calle"),
    "F76": (-5.2200391, -80.6268801, "calle"), "F77": (-5.1898489, -80.6335162, "zona"),
    "F80": (-5.1987149, -80.6309024, "calle"), "F81": (-5.1774100, -80.6505794, "zona"),
    "F82": (-5.1666705, -80.6618338, "zona"), "F84": (-5.1671239, -80.6592348, "zona"),
    "F85": (-5.1610100, -80.6554900, "zona"), "F90": (-5.1870370, -80.6291902, "calle"),
    "F91": (-5.2027900, -80.6417300, "zona"), "F94": (-5.1755890, -80.6316381, "zona"),
    "F95": (-5.2039300, -80.6323100, "zona"), "F97": (-5.1989000, -80.6176900, "calle"),
    "F98": (-5.1834300, -80.5924700, "zona"), "F100": (-5.1836879, -80.6328673, "zona"),
    "F101": (-5.1723684, -80.6100925, "zona"), "F102": (-5.1887006, -80.6419780, "calle"),
    "F103": (-5.1912700, -80.6448800, "zona"), "F104": (-5.1900000, -80.6190000, "estimada"),
    "F106": (-5.1656200, -80.6592300, "zona"), "F109": (-5.1882585, -80.5879125, "zona"),
    "F110": (-5.1853891, -80.6534822, "zona"), "F111": (-5.2053998, -80.6206002, "calle"),
}

PALABRAS_MINUSCULA = {"de", "del", "la", "las", "los", "y", "con", "e"}


def titulo(texto):
    """'AV GRAU NRO 244 CERCADO' -> 'Av Grau Nro 244 Cercado' (respeta 'de', 'y'...)."""
    palabras = texto.lower().split()
    return " ".join(p if (i > 0 and p in PALABRAS_MINUSCULA) else p[:1].upper() + p[1:] for i, p in enumerate(palabras))


def distrito_de(direccion):
    d = direccion.upper()
    if "VEINTISEIS" in d or "26 DE OCTUBRE" in d or "26 OCTUBRE" in d:
        return "Veintiséis de Octubre"
    if "CASTILLA" in d or "CASTLLA" in d or "MIRAFLORES" in d:
        return "Castilla"
    return "Piura"


def limpiar_direccion(direccion):
    """Deja la dirección como la envió Nortfarma, sin el sufijo 'PIURA-PIURA-...', y agrega el distrito."""
    d = direccion.replace("N�", "N°").replace("�", "-").strip()
    d = re.sub(r"[\s\-–]*((PIURA|CASTILLA|VEINTISEIS DE OCTUBRE|26 DE OCTUBRE|26 OCTUBRE|CERCADO|SEC\.? CASTILLA|PI)"
               r"[\s\-–]*)+$", "", d, flags=re.I)
    return f"{re.sub(r'\s+', ' ', d).strip(' -–')}, {distrito_de(direccion)}"


def leer_boticas_zona():
    """{codigo: (nombre, direccion, distrito)} del Excel de la zona objetivo."""
    zona = {}
    for f in leer_primera_hoja(ORIGEN / "boticas_zona_piura.xlsx")[1:]:
        if not f or not f[0].strip():
            continue
        codigo, descripcion, direccion = (f + ["", "", ""])[:3]
        nombre = "Botica " + titulo(descripcion.strip()).replace("Asuncion", "Asunción")
        zona[codigo.strip()] = (nombre, limpiar_direccion(direccion), distrito_de(direccion))
    return zona


def leer_boticas():
    filas = leer_primera_hoja(ORIGEN / "boticas_nortfarma.xlsx")[1:]
    zona_app = leer_boticas_zona()
    boticas = []
    for f in filas:
        f = f + [""] * (7 - len(f))
        codigo, departamento, zona = f[0].strip(), f[1].strip(), f[2].strip()
        # Fila final de notas ("VOLANTE PIURA | LICENCIA DE MATERNIDAD ...") no es una botica.
        if not re.fullmatch(r"[A-Z]{1,3}\d{0,3}", codigo) or not departamento or "LICENCIA" in zona:
            continue
        if codigo in zona_app:
            nombre, direccion, _ = zona_app.pop(codigo)
            lat, lng, _ = COORDENADAS[codigo]
        else:
            nombre, direccion, lat, lng = f"Botica {codigo}", None, None, None
        delivery = codigo == BOTICA_DELIVERY
        boticas.append({
            "botica_id": codigo,
            "nombre": nombre,
            "direccion": direccion,
            "departamento": departamento.title(),
            "zona": zona.title(),
            "apertura_semana": hora(f[3]),
            "cierre_semana": hora(f[4]),
            "apertura_domingo": hora(f[5]),
            "cierre_domingo": hora(f[6]),
            "latitud": lat,
            "longitud": lng,
            "delivery": delivery,
        })
    # Boticas de la zona que no figuran en el Excel de horarios (p. ej., F103): sin horario.
    for codigo, (nombre, direccion, _) in zona_app.items():
        lat, lng, _ = COORDENADAS[codigo]
        boticas.append({
            "botica_id": codigo, "nombre": nombre, "direccion": direccion, "departamento": "Piura",
            "zona": "Piura", "apertura_semana": None, "cierre_semana": None, "apertura_domingo": None,
            "cierre_domingo": None, "latitud": lat, "longitud": lng, "delivery": codigo == BOTICA_DELIVERY,
        })
    return boticas


# ---------------------------------------------------------------------------
# Productos
# ---------------------------------------------------------------------------
FORMAS_BLISTER = ("TABLETA", "COMPRIMIDO", "CAPSULA", "GRAGEA")


def unidades_por_empaque(codigo_unidad):
    m = re.fullmatch(r"U(\d+)", codigo_unidad.strip().upper())
    return max(1, int(m.group(1))) if m else 1


def texto_empaque(unidades, forma, nombre):
    if unidades <= 1:
        return "Unidad"
    f, n = forma.upper(), nombre.upper()
    if any(x in f for x in ("TABLETA", "COMPRIMIDO", "GRAGEA")):
        return f"Caja x {unidades} tabletas"
    if "CAPSULA" in f:
        return f"Caja x {unidades} cápsulas"
    if "OVULO" in f:
        return f"Caja x {unidades} óvulos"
    if "SAC" in n or "SOBRE" in n:
        return f"Caja x {unidades} sobres"
    if "INYECTABLE" in f:
        return f"Caja x {unidades} ampollas"
    return f"Paquete x {unidades} unidades"


def categoria_app(categoria, clasificacion, nombre):
    """Precarga: categoría de la app (Categoria_App) según la categoría de Nortfarma."""
    cat, cla, nom = categoria.upper(), clasificacion.upper(), nombre.upper()
    if "BEBE" in cat or "LACTANTE" in cat or "COMPLEMENTO NI" in cat or "PAÑAL" in nom:
        return 5  # Bebé
    if cat.startswith("DISPOSITIVOS MEDICOS") or "REHIDRAT" in cat or "REHIDRAT" in cla:
        return 6  # Botiquín
    if cat.startswith("COSMETICOS") or cat.startswith("OTROS PRODUCTOS"):
        return 4  # Cuidado personal
    if (cat.startswith("ALIMENTOS") or "DIETETICO" in cat or "NATURAL" in cat
            or "SUPLEMENTO" in cla or "VITAMIN" in cla):
        return 3  # Vitaminas
    if any(x in cla for x in ("ANALGESIC", "ANTIPIRET", "MIGRA", "ANTIGRIPAL")) or (
            "ANTIINFLAMATORIO" in cla and "CORTICOST" not in cla):
        return 2  # Dolor y fiebre
    return 1  # Medicinas


def especificaciones(r):
    partes = []
    if r["generico"]:
        partes.append(f"Principio activo: {r['generico'].capitalize()}.")
    if r["forma"]:
        via = f", vía {r['via'].lower()}" if r["via"] else ""
        partes.append(f"{r['forma'].capitalize()}{via}.")
    if r["clasificacion"]:
        partes.append(f"Uso: {r['clasificacion'].strip(' ,').capitalize()}.")
    partes.append(f"{r['empaque']}.")
    partes.append(f"Laboratorio: {r['linea'].title()}.")
    return " ".join(partes)


def leer_productos():
    filas = leer_primera_hoja(ORIGEN / "productos_nortfarma.xlsx")[1:]
    productos = []
    for f in filas:
        f = f + [""] * (26 - len(f))
        referencia, nombre = f[0].strip(), re.sub(r"\s+", " ", f[1]).strip()
        if not referencia or not nombre:
            continue
        forma = f[20].strip()
        unidades = unidades_por_empaque(f[8])
        fraccionable = unidades > 1 and any(x in forma.upper() for x in FORMAS_BLISTER)
        # Blíster y fracción: el Excel trae estas columnas vacías (inventado).
        blister = fraccionable and unidades >= 20 and unidades % 10 == 0
        try:
            pvu = round(float(f[9]), 2)
        except ValueError:
            pvu = 0.0
        p = {
            "referencia": referencia,
            "nombre": nombre,
            "codigo_barras": f[2].strip() or None,
            "categoria": f[3].strip(),
            "laboratorio": f[4].strip(),
            "linea": f[5].strip(),
            "unidades": unidades,
            "se_vende_blister": blister,
            "unidades_blister": 10 if blister else None,
            "se_vende_fraccion": fraccionable,
            "generico": f[18].strip(),
            "clasificacion": f[19].strip(),
            "forma": forma,
            "via": f[21].strip(),
            "refrigerado": "BIOLOGICO" in f[3].upper() or "INSULIN" in nombre.upper(),
            "receta": tipo_receta(f[3], f[19], forma, nombre, f[18], f[25]),
            "vencimiento": date(2027, 3, 1) + timedelta(days=azar.randint(0, 1000)),
            "pvu": pvu,
        }
        p["empaque"] = texto_empaque(unidades, forma, nombre)
        p["especificaciones"] = especificaciones(p)
        productos.append(p)
    return productos


def precios_de(p):
    """Precio por presentación. P.V.U. es el precio del empaque; el resto se deriva (inventado)."""
    if p["pvu"] <= 0:
        return {}
    precios = {"EMPAQUE": p["pvu"]}
    por_unidad = p["pvu"] / p["unidades"]
    if p["se_vende_blister"]:
        precios["BLISTER"] = max(0.1, round(por_unidad * p["unidades_blister"] * 1.05, 1))
    if p["se_vende_fraccion"]:
        precios["FRACCION"] = max(0.1, round(por_unidad * 1.10, 2))
    return precios


# ---------------------------------------------------------------------------
# Generación
# ---------------------------------------------------------------------------
ESQUEMA_CORE = """-- =====================================================================
-- SISTEMA DE NORTFARMA (SIMULADO, REDUCIDO) - nortfarma_core
-- Representa la base de datos de la empresa con las tablas que indicó Nortfarma.
-- La app NO lee estas tablas directamente: las consulta por la API "coreApi".
-- Generado por generar_core.py a partir de los Excel de datos_origen/.
-- Datos reales: referencia, nombre, código de barras, categoría, laboratorio,
-- unidades del empaque, P.V.U. y horarios de las boticas.
-- Tipo de receta: según DIGEMID (D.S. 023-2001-SA y listado de venta sin receta).
-- Boticas de la app: direcciones y coordenadas reales (OpenStreetMap y directorios web).
-- Datos INVENTADOS (el Excel los trae vacíos): blíster, fracción, stock,
-- vencimiento, refrigerado y descuentos.
-- =====================================================================

DROP DATABASE IF EXISTS nortfarma_core;
CREATE DATABASE nortfarma_core DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci;
USE nortfarma_core;

CREATE TABLE botica (
  botica_id              VARCHAR(10)    NOT NULL,  -- código de Nortfarma (CEN, F14, S1...)
  nombre                 VARCHAR(150)   NOT NULL,
  direccion              VARCHAR(255)   NULL,
  departamento           VARCHAR(50)    NOT NULL,
  zona                   VARCHAR(50)    NOT NULL,
  hora_apertura_semana   TIME           NULL,
  hora_cierre_semana     TIME           NULL,
  hora_apertura_domingo  TIME           NULL,      -- domingos y feriados; NULL = no abre
  hora_cierre_domingo    TIME           NULL,
  latitud                DECIMAL(10,8)  NULL,      -- NULL = sin ubicación registrada
  longitud               DECIMAL(10,8)  NULL,
  PRIMARY KEY (botica_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE producto (
  referencia         VARCHAR(20)   NOT NULL,  -- referencia interna de Nortfarma
  nombre             VARCHAR(200)  NOT NULL,
  codigo_barras      VARCHAR(20)   NULL,
  categoria          VARCHAR(120)  NOT NULL,
  laboratorio        VARCHAR(80)   NOT NULL,
  empaque            VARCHAR(60)   NOT NULL,  -- ej. 'Caja x 100 tabletas'
  unidades_empaque   INT           NOT NULL,
  se_vende_blister   BOOLEAN       NOT NULL,
  unidades_blister   INT           NULL,
  se_vende_fraccion  BOOLEAN       NOT NULL,
  fecha_vencimiento  DATE          NULL,
  refrigerado        BOOLEAN       NOT NULL,
  receta_medica      ENUM('NO REQUIERE','SIMPLE','RETENIDA','ESPECIAL') NOT NULL,
  especificaciones   TEXT          NOT NULL,
  PRIMARY KEY (referencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Stock por botica y por presentación. NULL = esa presentación no se vende.
CREATE TABLE stock (
  id_stock        INT          NOT NULL AUTO_INCREMENT,
  botica_id       VARCHAR(10)  NOT NULL,
  referencia      VARCHAR(20)  NOT NULL,
  stock_empaque   INT          NOT NULL,
  stock_blister   INT          NULL,
  stock_fraccion  INT          NULL,
  PRIMARY KEY (id_stock),
  UNIQUE KEY uq_stock (botica_id, referencia),
  CONSTRAINT fk_stock_botica   FOREIGN KEY (botica_id)  REFERENCES botica (botica_id),
  CONSTRAINT fk_stock_producto FOREIGN KEY (referencia) REFERENCES producto (referencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Un precio por presentación. Al cambiar un precio se agrega una fila nueva y la
-- anterior queda con vigente = FALSE: así la venta guarda el id_precio histórico.
CREATE TABLE precio (
  id_precio       INT            NOT NULL AUTO_INCREMENT,
  referencia      VARCHAR(20)    NOT NULL,
  tipo            ENUM('EMPAQUE','BLISTER','FRACCION') NOT NULL,
  precio          DECIMAL(10,2)  NOT NULL,
  vigente         BOOLEAN        NOT NULL,
  fecha_registro  DATETIME       NOT NULL,
  PRIMARY KEY (id_precio),
  KEY ix_precio_vigente (referencia, tipo, vigente),
  CONSTRAINT fk_precio_producto FOREIGN KEY (referencia) REFERENCES producto (referencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE descuento (
  id_descuento  INT           NOT NULL AUTO_INCREMENT,
  referencia    VARCHAR(20)   NOT NULL,
  porcentaje    DECIMAL(5,2)  NOT NULL,
  fecha_inicio  DATE          NOT NULL,
  fecha_fin     DATE          NOT NULL,
  PRIMARY KEY (id_descuento),
  CONSTRAINT fk_descuento_producto FOREIGN KEY (referencia) REFERENCES producto (referencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Ventas (las de la app llegan por la API). Serie y correlativo los asigna Nortfarma.
CREATE TABLE venta (
  id_venta                 INT            NOT NULL AUTO_INCREMENT,
  serie                    VARCHAR(4)     NOT NULL,  -- 'V' (venta); comprobante = V + correlativo de 4 dígitos (V0001)
  correlativo              INT            NOT NULL,
  botica_id                VARCHAR(10)    NOT NULL,
  precio_total             DECIMAL(10,2)  NOT NULL,  -- total de los productos
  medio_pago               VARCHAR(30)    NOT NULL,  -- TARJETA, YAPE/PLIN, POS, EFECTIVO
  tipo_pago                VARCHAR(30)    NOT NULL,  -- EN LINEA o CONTRAENTREGA
  tipo_comprobante         VARCHAR(10)    NOT NULL,  -- BOLETA o FACTURA
  ruc                      VARCHAR(11)    NULL,
  razon_social             VARCHAR(150)   NULL,
  estado                   ENUM('REGISTRADA','PAGADA','ANULADA') NOT NULL,
  pasarela                 VARCHAR(50)    NULL,
  id_transaccion_pasarela  VARCHAR(255)   NULL,
  origen                   VARCHAR(20)    NOT NULL,  -- APP o TIENDA
  referencia_origen        VARCHAR(30)    NULL,      -- número de pedido de la app
  fecha                    DATETIME       NOT NULL,
  PRIMARY KEY (id_venta),
  UNIQUE KEY uq_venta_comprobante (serie, correlativo),
  CONSTRAINT fk_venta_botica FOREIGN KEY (botica_id) REFERENCES botica (botica_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE detalle_venta (
  id_detalle            INT            NOT NULL AUTO_INCREMENT,
  id_venta              INT            NOT NULL,
  referencia            VARCHAR(20)    NOT NULL,
  id_precio             INT            NOT NULL,  -- precio vigente al vender (queda histórico)
  tipo                  ENUM('EMPAQUE','BLISTER','FRACCION') NOT NULL,
  cantidad              INT            NOT NULL,
  descuento_porcentaje  DECIMAL(5,2)   NOT NULL DEFAULT 0,
  subtotal              DECIMAL(10,2)  NOT NULL,
  PRIMARY KEY (id_detalle),
  CONSTRAINT fk_detalle_venta    FOREIGN KEY (id_venta)   REFERENCES venta (id_venta),
  CONSTRAINT fk_detalle_producto FOREIGN KEY (referencia) REFERENCES producto (referencia),
  CONSTRAINT fk_detalle_precio   FOREIGN KEY (id_precio)  REFERENCES precio (id_precio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"""

# Productos que NO van en la precarga de la app: aparecen como "nuevos" en la primera
# sincronización, para que el administrador les asigne categoría y foto.
NUEVOS_PARA_DEMO = 5


def generar():
    boticas = leer_boticas()
    productos = leer_productos()
    con_precio = [p for p in productos if p["pvu"] > 0]

    # --- precios (vigentes + algunos históricos) ---
    filas_precio = []
    for p in con_precio:
        for tipo, precio in precios_de(p).items():
            filas_precio.append([p["referencia"], tipo, precio, True, "2026-09-01 08:00:00"])
    for p in azar.sample(con_precio, 30):  # precio anterior, ya no vigente (inventado)
        filas_precio.append([p["referencia"], "EMPAQUE", round(p["pvu"] * 0.95, 2), False, "2026-06-01 08:00:00"])

    # --- descuentos (inventado): vigentes, vencidos y futuros ---
    sin_receta = [p for p in con_precio if p["receta"] == "NO REQUIERE"]
    elegidos = azar.sample(sin_receta, 65)
    filas_descuento = []
    for i, p in enumerate(elegidos):
        porcentaje = azar.choice([10, 15, 20, 25, 30])
        if i < 50:
            inicio, fin = HOY - timedelta(days=azar.randint(1, 20)), HOY + timedelta(days=azar.randint(10, 45))
        elif i < 60:
            inicio, fin = date(2026, 8, 1), date(2026, 9, 30)
        else:
            inicio, fin = date(2026, 11, 1), date(2026, 11, 30)
        filas_descuento.append([p["referencia"], porcentaje, inicio, fin])

    # --- stock (inventado) solo en las boticas que operan con la app ---
    filas_stock = []
    for b in boticas:
        if b["latitud"] is None:
            continue
        for p in con_precio:
            agotado = azar.random() < 0.06
            filas_stock.append([
                b["botica_id"], p["referencia"],
                0 if agotado else azar.randint(1, 40),
                (0 if agotado else azar.randint(0, 25)) if p["se_vende_blister"] else None,
                (0 if agotado else azar.randint(0, 150)) if p["se_vende_fraccion"] else None,
            ])

    core = [ESQUEMA_CORE, "\n-- ------------------------------------------------------------- DATOS\n"]
    core.append(inserts("botica", [
        "botica_id", "nombre", "direccion", "departamento", "zona", "hora_apertura_semana",
        "hora_cierre_semana", "hora_apertura_domingo", "hora_cierre_domingo", "latitud", "longitud",
    ], [[b["botica_id"], b["nombre"], b["direccion"], b["departamento"], b["zona"], b["apertura_semana"],
         b["cierre_semana"], b["apertura_domingo"], b["cierre_domingo"], b["latitud"], b["longitud"]]
        for b in boticas]))
    core.append(inserts("producto", [
        "referencia", "nombre", "codigo_barras", "categoria", "laboratorio", "empaque", "unidades_empaque",
        "se_vende_blister", "unidades_blister", "se_vende_fraccion", "fecha_vencimiento", "refrigerado",
        "receta_medica", "especificaciones",
    ], [[p["referencia"], p["nombre"], p["codigo_barras"], p["categoria"], p["laboratorio"], p["empaque"],
         p["unidades"], p["se_vende_blister"], p["unidades_blister"], p["se_vende_fraccion"],
         p["vencimiento"], p["refrigerado"], p["receta"], p["especificaciones"]] for p in productos]))
    core.append(inserts("precio", ["referencia", "tipo", "precio", "vigente", "fecha_registro"], filas_precio))
    core.append(inserts("descuento", ["referencia", "porcentaje", "fecha_inicio", "fecha_fin"], filas_descuento))
    core.append(inserts("stock", ["botica_id", "referencia", "stock_empaque", "stock_blister", "stock_fraccion"],
                        filas_stock, lote=1000))
    SALIDA_CORE.write_text("\n".join(core), encoding="utf-8")

    # --- precarga de la app ---
    visibles = [p for p in productos if p["receta"] not in ("RETENIDA", "ESPECIAL")]
    nuevos = {p["referencia"] for p in azar.sample(visibles, NUEVOS_PARA_DEMO)}
    app_boticas = [b for b in boticas if b["latitud"] is not None]
    orden = list(leer_boticas_zona())  # orden del Excel de Nortfarma, la de delivery primero
    app_boticas.sort(key=lambda b: (not b["delivery"], orden.index(b["botica_id"])))
    precarga = [
        "-- =====================================================================",
        "-- Precarga de la app (ejecutar después de datos_iniciales.sql)",
        "-- Copia inicial de productos y boticas desde el sistema de Nortfarma.",
        "-- La categoría de cada producto la pone la app (Nortfarma no la tiene):",
        "-- se asignó según la categoría y clasificación terapéutica de Nortfarma.",
        "-- Después, la sincronización diaria actualiza estos datos y los productos",
        "-- nuevos llegan sin categoría para que el Administrador la asigne.",
        "-- No incluye productos con receta retenida o especial (no se venden en la app).",
        "-- Generado por nortfarma_core/generar_core.py.",
        "-- =====================================================================",
        "",
        "USE nortfarma_db;",
        "",
        inserts("Botica", [
            "id_botica", "id_botica_core", "nombre", "direccion", "departamento", "zona", "latitud", "longitud",
            "hora_apertura_semana", "hora_cierre_semana", "hora_apertura_domingo", "hora_cierre_domingo",
            "hace_delivery", "fecha_sincronizacion",
        ], [[i + 1, b["botica_id"], b["nombre"], b["direccion"], b["departamento"], b["zona"], b["latitud"],
             b["longitud"], b["apertura_semana"], b["cierre_semana"], b["apertura_domingo"], b["cierre_domingo"],
             b["delivery"], "2026-10-16 03:00:00"] for i, b in enumerate(app_boticas)]),
        inserts("Producto_App", [
            "id_producto_core", "id_categoria", "nombre_comercial", "especificaciones", "empaque",
            "unidades_empaque", "se_vende_blister", "unidades_blister", "se_vende_fraccion", "apto_ecommerce",
            "requiere_receta", "fecha_sincronizacion",
        ], [[p["referencia"], categoria_app(p["categoria"], p["clasificacion"], p["nombre"]), p["nombre"],
             p["especificaciones"], p["empaque"], p["unidades"], p["se_vende_blister"], p["unidades_blister"],
             p["se_vende_fraccion"], p["pvu"] > 0, p["receta"] == "SIMPLE", "2026-10-15 03:00:00"]
            for p in visibles if p["referencia"] not in nuevos]),
    ]
    SALIDA_PRECARGA.write_text("\n".join(precarga), encoding="utf-8")

    print(f"Boticas: {len(boticas)} ({len(app_boticas)} con ubicación, operan con la app)")
    print(f"Productos: {len(productos)} ({len(con_precio)} con precio)")
    print(f"Precios: {len(filas_precio)} · Descuentos: {len(filas_descuento)} · Stock: {len(filas_stock)}")
    recetas = {}
    for p in productos:
        recetas[p["receta"]] = recetas.get(p["receta"], 0) + 1
    print(f"Receta: {recetas}")
    print(f"Precarga app: {len(visibles) - len(nuevos)} productos ({len(nuevos)} quedan como nuevos: {sorted(nuevos)})")


if __name__ == "__main__":
    generar()
