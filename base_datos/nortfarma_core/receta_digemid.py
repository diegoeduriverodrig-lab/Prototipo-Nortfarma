"""
Tipo de receta de cada producto según la normativa peruana (DIGEMID).

Fuentes:
- D.S. N.º 023-2001-SA, Reglamento de Estupefacientes, Psicotrópicos y otras sustancias
  sujetas a fiscalización sanitaria:
  https://www.digemid.minsa.gob.pe/Archivos/Normatividad/2001/DecretoSupremoN023-2001-SA.pdf
    Art. 23: Listas II A, III A, III B y III C -> recetario ESPECIAL numerado.
    Art. 36: Listas II B, IV A, IV B y VI -> receta RETENIDA por el establecimiento.
- DIGEMID, Catálogo de Sustancias Controladas (Anexo N.º 2 del D.S. 023-2001-SA), con las
  sustancias de cada lista:
  http://www.dirislimaeste.gob.pe/Virtual2/Otros_Link/DFCVS/CATALOGO%20SECTORIAL%20DE%20PRODUCTOS%20FARMACEUTICIOS%20-%20CATALOGO%20DE%20SUSTANCIAS%20CONTROLADAS.pdf
- DIGEMID, Listado de especialidades farmacéuticas de venta sin receta médica:
  https://www.digemid.minsa.gob.pe/webDigemid/registro-sanitario/productos-farmaceuticos/venta-sin-receta/

Criterio del prototipo (el Excel de Nortfarma trae #ERROR! en "Receta Médica"):
1. Si el principio activo está en una lista de receta especial -> ESPECIAL.
2. Si está en una lista de receta retenida -> RETENIDA.
3. Si no es un medicamento (dispositivo, cosmético, alimento, producto natural o dietético) -> NO REQUIERE.
4. Si es un medicamento del listado de venta sin receta de DIGEMID -> NO REQUIERE.
5. Inyectables -> SIMPLE. Vitaminas y suplementos orales -> NO REQUIERE (criterio propio: bajo riesgo).
6. Ansiolítico o hipnótico cuyo principio activo no aparece en el Excel -> RETENIDA (las
   benzodiacepinas y los hipnóticos están en la Lista IV B); analgésico narcótico -> ESPECIAL.
7. Cualquier otro medicamento -> SIMPLE (venta con receta médica común).
RETENIDA y ESPECIAL no se venden en la app.
"""
import re
import unicodedata

# Anexo N.º 2 del D.S. 023-2001-SA (catálogo de DIGEMID).
LISTAS = {
    "IIA": ["cocaina", "dextromoramida", "fentanilo", "levorfanol", "metadona", "morfina", "opio", "oxicodona",
            "petidina", "remifentanilo", "sufentanilo"],
    "IIB": ["codeina", "acetildihidrocodeina", "dextropropoxifeno", "difenoxilato", "difenoxina", "dihidrocodeina",
            "etilmorfina", "folcodina", "nicocodina", "nicodicodina", "norcodeina", "hidrocodona", "propiramo"],
    "IIIA": ["anfepramona", "benzfetamina", "catina", "dexanfetamina", "etinamato", "etilanfetamina", "fenetilina",
             "fenproporex", "levometanfetamina", "fentermina", "mefenorex", "mazindol", "metilfenidato", "pemolina",
             "zipeprol"],
    "IIIB": ["allobarbital", "amobarbital", "aprobarbital", "barbital", "buprenorfina", "butalbital", "ciclobarbital",
             "flunitrazepam", "glutetimida", "hexobarbital", "meprobamato", "metabarbital", "pentazocina",
             "pentobarbital", "secbutabarbital", "secobarbital", "vinilbital"],
    "IIIC": ["etclorvinol", "fenobarbital", "glucotimida", "metilfenobarbital", "metiprilona", "tiopental", "pipradrol"],
    "IVA": ["codeina", "dihidrocodeina", "hidrocodona", "dextropropoxifeno", "difenoxilato"],
    "IVB": ["alprazolam", "aminorex", "amitriptilina", "anfebutamona", "bentazepam", "bromazepam", "bromperidol",
            "brotizolam", "bupropion", "buspirona", "camazepam", "clobazam", "clomipramina", "clonazepam",
            "clorazepato", "clordiazepoxido", "clotiazepam", "cloxazolam", "clozapina", "delorazepam", "desipramina",
            "diazepam", "doxepina", "droperidol", "efedrina", "ergometrina", "ergotamina", "estazolam", "flupentixol",
            "flubentixol", "fludiazepam", "flufenazina", "fluoxetina", "flurazepam", "halazepam", "haloperidol",
            "haloxazolam", "imipramina", "ketazolam", "levomepromazina", "loprazolam", "lorazepam", "lormetazepam",
            "loxapina", "maprotilina", "medazepam", "mesocarbo", "moclobemida", "mianserina", "midazolam",
            "nefazodona", "nimetazepam", "nitrazepam", "nordazepam", "norefedrina", "nortriptilina", "opipramol",
            "oxazepam", "oxazolam", "paroxetina", "periciazina", "pimozida", "pinazepam", "pipotiazina", "prazepam",
            "pseudoefedrina", "sertralina", "sibutramina", "sulpirida", "temazepam", "tetrazepam", "tilidina",
            "tioproperazina", "tioridazina", "tramadol", "trazodona", "triazolam", "trifluoperazina",
            "trihexifenidilo", "trihexifenidil", "trimipramina", "valproato", "valproico", "veraliprida",
            "viloxacina", "zaleplon", "zopiclona", "zolpidem"],
    "VI": ["nalorfina", "levalorfan", "naloxona", "ciclazocina", "diprenorfina", "apomorfina"],
}
ESPECIAL = {s for k in ("IIA", "IIIA", "IIIB", "IIIC") for s in LISTAS[k]}
RETENIDA = {s for k in ("IIB", "IVA", "IVB", "VI") for s in LISTAS[k]} - ESPECIAL

# Listado de venta sin receta de DIGEMID: principio activo y, si aplica, la condición
# de forma o dosis con la que figura.
TOPICO = ("CREMA", "GEL", "TOPIC", "UNGUENTO", "POMADA", "PARCHE", "SPRAY", "LOCION", "OVULO", "VAGINAL")


def _dosis_mg(texto):
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*MG", texto)
    return float(m.group(1).replace(",", ".")) if m else None


SIN_RECETA = {
    "paracetamol": lambda t, f: True,
    "acetaminofen": lambda t, f: True,
    "simeticona": lambda t, f: True,
    "ambroxol": lambda t, f: True,
    "bencidamina": lambda t, f: True,
    "magaldrato": lambda t, f: True,
    "dimenhidrinato": lambda t, f: True,
    "hidroxido de magnesio": lambda t, f: True,
    "bismuto": lambda t, f: True,
    "hipromelosa": lambda t, f: True,
    "dobesilato": lambda t, f: any(x in f for x in TOPICO) or "RECTAL" in f,
    "fexofenadina": lambda t, f: (_dosis_mg(t) or 0) <= 120,
    "dextrometorfano": lambda t, f: True,
    "clotrimazol": lambda t, f: any(x in f + t for x in TOPICO),
    "terbinafina": lambda t, f: any(x in f + t for x in TOPICO),
    "diclofenaco": lambda t, f: any(x in f + t for x in TOPICO),
    "ibuprofeno": lambda t, f: any(x in f + t for x in TOPICO) or "SUSPENSION" in f or (_dosis_mg(t) or 999) <= 200,
    "naproxeno": lambda t, f: (_dosis_mg(t) or 999) <= 275,
    "acido acetilsalicilico": lambda t, f: (_dosis_mg(t) or 999) <= 500,
    "aspirina": lambda t, f: (_dosis_mg(t) or 999) <= 500,
}

NO_MEDICAMENTO = ("DIETETICO", "NATURAL", "GALENICO")
PSICOFARMACOS = ("ANSIOLITICO", "HIPNOTICO", "HIPNOPTICO")
SUPLEMENTOS = ("VITAMIN", "SUPLEMENTO", "COMPLEMENTO NUTRICIONAL", "MINERALES")


def normalizar(texto):
    texto = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return " " + re.sub(r"[^a-z0-9 ]+", " ", texto.lower()) + " "


def tipo_receta(categoria, clasificacion, forma, nombre, generico, columna_receta=""):
    """Devuelve 'NO REQUIERE', 'SIMPLE', 'RETENIDA' o 'ESPECIAL'."""
    texto = normalizar(f"{generico} {nombre}")
    cat, cla, frm = categoria.upper(), clasificacion.upper(), forma.upper()
    mayus = f"{nombre} {generico}".upper()

    if any(re.search(rf"\b{s}", texto) for s in ESPECIAL):
        return "ESPECIAL"
    if any(re.search(rf"\b{s}", texto) for s in RETENIDA):
        return "RETENIDA"
    if not cat.startswith("PRODUCTOS FARMACEUTICOS") or any(x in cat for x in NO_MEDICAMENTO):
        return "NO REQUIERE"
    if columna_receta.lower().startswith("si"):
        return "SIMPLE"
    principios = [p for p in SIN_RECETA if re.search(rf"\b{p}", texto)]
    if principios and all(SIN_RECETA[p](mayus, frm) for p in principios):
        return "NO REQUIERE"
    if "INYECTABLE" in frm or re.search(r"\bAMP", mayus):  # ampollas
        return "SIMPLE"
    if any(x in cla for x in SUPLEMENTOS):
        return "NO REQUIERE"
    if "NARCOTICO" in cla:
        return "ESPECIAL"
    if any(x in cla for x in PSICOFARMACOS):
        return "RETENIDA"
    return "SIMPLE"
