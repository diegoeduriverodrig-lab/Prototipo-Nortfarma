# Configurar Google Maps y Culqi

Sin estas claves la app funciona igual: el mapa no aparece (se usa el centro del distrito)
y el pago con tarjeta es simulado. Con ellas se activan solos.

| Clave | Dónde se pone |
|---|---|
| Google Maps (`AIza...`) | `app_flutter/config/claves.json` → `MAPS_API_KEY` |
| Culqi pública (`pk_test_...`) | `app_flutter/config/claves.json` → `CULQI_PUBLIC_KEY` |
| Culqi secreta (`sk_test_...`) | `backend_nodejs/functions/.env.local` → `CULQI_SECRET_KEY` |

Las dos de Culqi van juntas: si pones una, pon también la otra.
Ninguno de estos archivos se sube a un repositorio (están en `.gitignore`).

## 1. Clave de Google Maps
1. Entra a https://console.cloud.google.com y elige el proyecto **nortfarma-a7928**
   (el mismo de Firebase).
2. Menú ☰ → **APIs y servicios → Biblioteca** → busca **Maps SDK for Android** → **Habilitar**.
   Google pide asociar una cuenta de facturación (tarjeta); el mapa en apps móviles no tiene costo.
3. **APIs y servicios → Credenciales → Crear credenciales → Clave de API**.
4. En la clave creada, **Editar** y restringirla:
   - Restricciones de aplicación: **Apps para Android** → **Agregar**
     - Paquete: `com.nortfarma.app`
     - Huella SHA-1: `8F:A5:99:69:7B:F7:C6:3B:A9:D5:5A:5C:19:01:94:BE:63:15:56:94`
   - Restricciones de API: **Maps SDK for Android**.
5. Copia la clave en `config/claves.json` (campo `MAPS_API_KEY`).

La dirección escrita a partir del pin usa el geocodificador de Android: no necesita otra clave.

## 2. Llaves de Culqi (modo prueba)
1. Crea una cuenta en https://culqi.com (botón **Regístrate**).
2. En el panel: **Desarrollo → API Keys**, sección de **integración / pruebas**.
3. Copia la **llave pública** (`pk_test_...`) en `config/claves.json` → `CULQI_PUBLIC_KEY`.
4. Copia la **llave secreta** (`sk_test_...`) en `backend_nodejs/functions/.env.local` → `CULQI_SECRET_KEY`.
   Nunca pongas la llave secreta en la app.
5. Tarjetas de prueba: https://docs.culqi.com (sección "Tarjetas de prueba"),
   por ejemplo Visa `4111 1111 1111 1111`, cualquier fecha futura y CVV `123`.

## 3. Ejecutar con las claves
- Reinicia el backend (`iniciar_emulador.bat`) para que lea `.env.local`.
- App: en VS Code pulsa **F5** (ya incluye las claves), o en la terminal:
  ```
  cd Proyecto_Nortfarma/app_flutter
  flutter run --dart-define-from-file=config/claves.json
  ```
  Al cambiar `claves.json` hay que volver a ejecutar (no basta la recarga rápida).
