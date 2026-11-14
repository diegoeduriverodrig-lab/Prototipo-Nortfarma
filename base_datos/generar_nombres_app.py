"""Genera el "nombre en la app" de cada producto a partir del nombre abreviado de Nortfarma.
Ej.: "TINIDAZOL TABx500MGx8" -> "Tinidazol 500 mg x 8 tabletas".
Solo se propone cargar los nombres sin abreviaturas desconocidas; el resto queda para revisar.
Uso: python nombres.py nombres.tsv salida   -> salida.xlsx (para revisar) y salida.sql (carga)
"""
import re
import sys

# Formas que se cuentan por unidad: van al final ("x 30 tabletas").
CONTABLES = {
    "TAB": ("tableta", "tabletas"), "COM": ("comprimido", "comprimidos"), "CAP": ("cápsula", "cápsulas"),
    "AMP": ("ampolla", "ampollas"), "SOB": ("sobre", "sobres"), "SAC": ("sachet", "sachets"),
    "SUP": ("supositorio", "supositorios"), "OVU": ("óvulo", "óvulos"), "OVUL": ("óvulo", "óvulos"),
    "GRAG": ("gragea", "grageas"), "PARCHE": ("parche", "parches"), "OVULOS": ("óvulo", "óvulos"),
    "SOBRES": ("sobre", "sobres"), "TABLETAS": ("tableta", "tabletas"), "CAPSULAS": ("cápsula", "cápsulas"),
    "SACHET": ("sachet", "sachets"),
}
# Abreviaturas que se desarrollan (sin ambigüedad).
PALABRAS = {
    "JBE": "jarabe", "JB": "jarabe", "SUS": "suspensión", "SUSP": "suspensión", "SOL": "solución",
    "CRE": "crema", "CR": "crema", "UNG": "ungüento", "GOT": "gotas", "LOC": "loción", "FCO": "frasco",
    "TUB": "tubo", "LIQ": "líquido", "SH": "shampoo", "DEO": "desodorante", "JAB": "jabón",
    "ESPARADRA": "esparadrapo", "COLG": "Colgate", "CEP": "cepillo", "CJ": "caja", "VAG": "vaginal",
    "OFT": "oftálmica", "TOP": "tópica", "ORAL": "oral", "BEB": "bebible", "INY": "inyectable",
    "CORP": "corporal", "DENT": "dental", "MICR": "micropore", "EMULSION": "emulsión", "JABON": "jabón",
    "ACIDO": "ácido", "ALGODON": "algodón", "CHOCOLAT": "chocolate", "VAI": "vainilla", "PIÑA": "piña",
    "PEDIATRICO": "pediátrico", "BUCAL": "bucal", "TERMICO": "térmico", "DIAS": "días", "AÑ": "años",
    "NIÑOS": "niños", "BEBE": "bebé", "LIMON": "limón", "SANDIA": "sandía", "MANI": "maní",
    "SP": "spray", "RO": "roll-on", "FOLICO": "fólico", "ESTERIL": "estéril", "CROMICO": "crómico",
    "CITRICA": "cítrica", "CITRICO": "cítrico", "ASCORBICO": "ascórbico", "HIALURONICO": "hialurónico",
    "PANTOTENICO": "pantoténico", "VITAMINICO": "vitamínico", "PEDIAT": "pediátrico", "ESPARAD": "esparadrapo",
}
# Se dejan como están (siglas y marcas en mayúsculas).
SIGLAS = {"NF", "3M", "HMB", "UV", "SPF", "B12", "B1", "B6", "AP", "IM", "IV", "EC", "XR", "LP", "DHA", "ARA",
          "CKF", "BB", "OK", "PH5", "A/P", "D3", "K2", "C", "E", "B", "D", "Q10", "AZ", "AM", "PM", "TC"}
MINUSCULAS = {"DE", "DEL", "Y", "CON", "SIN", "PARA", "EN", "LA", "EL", "LAS", "LOS", "A", "AL"}
UNIDADES = {"MG": "mg", "ML": "ml", "M": "ml", "GR": "g", "G": "g", "L": "L", "LT": "L", "UI": "UI", "MCG": "mcg",
            "CM": "cm", "MM": "mm", "KG": "kg", "%": "%", "U": "unid.", "UN": "unid.", "UND": "unid.", "UNID": "unid."}
# Palabras comunes de 3 letras o menos que no son abreviaturas.
CORTAS_OK = {"MAX", "SOL", "GEL", "DUO", "SEX", "MEN", "WOM", "AZ", "OIL", "PRO", "KIT", "TIO", "MIX", "ZAID",
             "NAN", "RED", "AIR", "SKY", "ICE", "BIO", "ZEN", "ONE", "TWO", "FIT", "TOP", "PLUS", "PRE", "OPT",
             "SAL", "UVA", "MAR", "ORO", "LUZ", "SOY", "PAN", "TE", "FAN", "GO"}

MEDIDA = re.compile(r"^(\d+(?:[.,]\d+)?)(MG|ML|MCG|GR|G|LT|L|UI|CM|MM|KG|%|UND|UNID|UN|U|M)?$", re.I)
# "M" después de un número: ml en cosméticos (X250M) y metros en esparadrapos (5CMX9.1M).
METRO_O_ML = ["ml"]


def medida(tok):
    """'100MG/5ML' -> '100 mg/5 ml'; None si no es una medida."""
    partes = tok.split("/")
    salida = []
    for p in partes:
        m = MEDIDA.match(p)
        if not m:
            return None
        n, u = m.group(1).replace(",", "."), (m.group(2) or "").upper()
        unidad = METRO_O_ML[0] if u == "M" else UNIDADES.get(u, "")
        salida.append(f"{n}%" if u == "%" else (f"{n} {unidad}" if u else n))
    return "/".join(salida)


def palabra(tok):
    t = tok.strip(".").upper()
    if not t:
        return ""
    if t in PALABRAS:
        p = PALABRAS[t]
        return p[:1].upper() + p[1:]
    if t.endswith("CION") and len(t) > 5:
        t = t[:-4] + "CIÓN"
    elif t.endswith("SION") and len(t) > 5:
        t = t[:-4] + "SIÓN"
    if t in SIGLAS or any(ch.isdigit() for ch in t):
        return t
    if t in MINUSCULAS:
        return t.lower()
    # Gyno-Canesten, Ak-Trol
    return "-".join(p[:1] + p[1:].lower() for p in t.split("-"))


def generar(nombre):
    s = nombre.strip()
    s = re.sub(r"^TG\s+", "", s)                                       # prefijo interno
    s = re.sub(r"(?<=[A-Za-zÑñ])\.(?=[A-Za-zÑñ0-9])", ". ", s)         # SOL.ORAL -> SOL. ORAL
    s = re.sub(r"(?<=[A-Za-zÑñ0-9.%)])[xX](?=\s?\d)", " x ", s)        # TABX500 -> TAB x 500
    s = re.sub(r"(?:^|\s)[xX]\s*(?=\d)", " x ", s)                     # " x120ML" -> " x 120ML"
    s = re.sub(r"(?<=\w)\+(?=\w)", " + ", s)
    s = re.sub(r"\bP/(?=\w)", "PARA ", s)                               # P/INYECCION -> PARA INYECCION
    METRO_O_ML[0] = "m" if re.search(r"\d(CM|MM)\b", s, re.I) else "ml"
    toks = [t for t in s.split() if t]

    # Forma contable (tabletas, cápsulas...) y las cantidades que le siguen
    forma = None
    for i, t in enumerate(toks):
        clave = t.strip(".").upper()
        if clave in CONTABLES and i > 0:
            forma = (i, clave)
            break

    dudosas = []

    def convertir(lista):
        out = []
        for t in lista:
            if t.lower() == "x" or t == "+":
                out.append(t.lower())
                continue
            # "3M" es la marca, salvo después de una "x" (24MMX3M = 3 metros)
            m = None if t.strip(".").upper() in SIGLAS and out[-1:] != ["x"] else medida(t)
            if m:
                out.append(m)
                continue
            p = palabra(t)
            clave = t.strip(".").upper()
            if (len(clave) <= 3 and clave not in PALABRAS and clave not in SIGLAS and clave not in MINUSCULAS
                    and clave not in CORTAS_OK and clave not in CONTABLES and not any(c.isdigit() for c in clave)):
                dudosas.append(t)
            if p:
                out.append(p)
        return out

    if forma:
        i, clave = forma
        base = convertir(toks[:i])
        resto = toks[i + 1:]
        # grupos separados por "x"
        grupos, actual = [], []
        for t in resto:
            if t.lower() == "x":
                if actual:
                    grupos.append(actual)
                actual = []
            else:
                actual.append(t)
        if actual:
            grupos.append(actual)
        cantidad, extras, palabras, medidas = None, [], [], []
        for g in grupos:
            if len(g) >= 1 and re.fullmatch(r"\d+", g[0]) and cantidad is None and g is grupos[-1]:
                cantidad = int(g[0])
                extras += g[1:]
            elif all(medida(t) for t in g):
                medidas.append(" ".join(convertir(g)))
            else:  # "CAP VAGX500MG": "vaginal" va con el nombre, no como medida
                palabras += convertir(g)
        singular, plural = CONTABLES[clave]
        partes = base + palabras + ([" x ".join(medidas)] if medidas else [])
        if cantidad is not None:
            partes.append(f"x {cantidad} {singular if cantidad == 1 else plural}")
        else:
            partes.append(plural)
        partes += convertir(extras)
        texto = " ".join(partes)
    else:
        conv = convertir(toks)
        # sin forma contable: "x 850 g" -> "850 g" (medida del envase)
        texto = " ".join(conv)
        texto = re.sub(r"(^|\s)x (?=\d)", r"\1", texto, count=1)

    texto = re.sub(r"\s+", " ", texto).strip()
    texto = re.sub(r"\s+x$", "", texto)  # "3346E X" al final no es una cantidad
    texto = texto[:1].upper() + texto[1:]
    return texto[:150], dudosas


def main():
    filas = [l.rstrip("\n").split("\t") for l in open(sys.argv[1], encoding="utf-8")]
    salida = sys.argv[2]
    resultados = []
    for f in filas:
        idp, ref, nombre, lab, cat, empaque = (f + [""] * 6)[:6]
        nuevo, dudosas = generar(nombre)
        estado = "Revisar" if dudosas else "Listo"
        resultados.append((int(idp), ref, nombre, nuevo, estado, ", ".join(dudosas)))

    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment
    wb = Workbook()
    ws = wb.active
    ws.title = "Nombres en la app"
    ws.append(["id_producto", "Código Nortfarma", "Nombre en Nortfarma", "Nombre en la app (propuesto)",
               "Estado", "Abreviaturas sin reconocer"])
    for c in ws[1]:
        c.font = Font(bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor="0E8C8C")
    for r in resultados:
        ws.append(list(r))
        if r[4] == "Revisar":
            ws.cell(ws.max_row, 5).fill = PatternFill("solid", fgColor="FFE8CC")
    for col, ancho in zip("ABCDEF", (11, 16, 42, 52, 10, 26)):
        ws.column_dimensions[col].width = ancho
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions
    for fila in ws.iter_rows(min_row=2):
        for c in fila:
            c.alignment = Alignment(vertical="top")
    wb.save(salida + ".xlsx")

    listos = [r for r in resultados if r[4] == "Listo"]
    with open(salida + ".sql", "w", encoding="utf-8") as out:
        out.write("-- Carga masiva del nombre en la app (generado desde el nombre de Nortfarma).\n")
        out.write("-- Solo los nombres sin abreviaturas dudosas; el resto los completa el Administrador.\n")
        out.write("-- No toca los productos nuevos sin categoría ni los que ya tienen nombre en la app.\n")
        out.write("USE nortfarma_db;\n")
        for r in listos:
            nombre = r[3].replace("\\", "\\\\").replace("'", "''")
            out.write(f"UPDATE Producto_App SET nombre_app = '{nombre}' WHERE id_producto = {r[0]}"
                      " AND nombre_app IS NULL AND id_categoria IS NOT NULL;\n")
    print(f"{len(resultados)} productos: {len(listos)} listos, {len(resultados) - len(listos)} para revisar")


if __name__ == "__main__":
    main()
