# Guía de Compilación y Despliegue - RestaurApp Print

Esta guía explica cómo generar los ejecutables para producción (macOS y Windows).

## 1. Versión macOS (Generar Localmente)

Como estás desarrollando en Mac, puedes generar esta versión directamente.

1.  Abre la terminal en la carpeta `app` del proyecto (donde está el `pubspec.yaml`).
2.  Ejecuta el comando de limpieza y compilación:
    ```bash
    flutter clean
    flutter build macos --release
    ```

3.  **Generar Instalador (.dmg):**
    Para distribuir profesionalmente, no envíes el archivo `.app`. Ejecuta este script que hemos creado para generar un imagen de disco `.dmg`:
    ```bash
    ./create_dmg.sh
    ```
    *   Esto creará el archivo `RestaurApp_Print_Installer.dmg` en la carpeta principal.
    *   Este archivo es el que debes enviar a tus usuarios de Mac.

4.  **Ubicación del Archivo Original:**
    (Solo si necesitas la app cruda)
    `build/macos/Build/Products/Release/RestaurApp Print.app`

5.  **Nota sobre Seguridad (Gatekeeper):**
    Al no tener firma digital de Apple (certificado de pago), si copias esta app a otra Mac, al intentar abrirla dará un aviso de seguridad. 
    *   **Instrucción para el usuario:** Deben hacer **Clic Derecho -> Abrir** la primera vez para autorizar la ejecución.

---

## 2. Versión Windows (Generar vía GitHub Actions)

No se puede compilar para Windows desde macOS directamente. Usaremos **GitHub Actions** para que lo haga la nube.

> **¿Es Gratis?** Sí. GitHub ofrece 2000 minutos gratuitos al mes para cuentas personales (Free Tier) en repositorios privados, y es ilimitado para repositorios públicos. Es más que suficiente para este proyecto.

### Pasos:

1.  **Subir a GitHub:** Asegúrate de que este proyecto esté en un repositorio de GitHub.
2.  **Activar la Acción:**
    *   He creado el archivo `.github/workflows/release.yml`. GitHub lo detectará automáticamente.
    *   Ve a la pestaña **"Actions"** en tu repositorio de GitHub.
    *   Selecciona el flujo **"Build & Release"** en la barra lateral.
    *   Haz clic en **"Run workflow"** (o simplemente pushea un tag como `v1.0.0`).
3.  **Descargar:**
    *   Espera unos minutos a que termine (verás iconos verdes ✅).
    *   Haz clic en la ejecución completada.
    *   Baja a la sección **"Artifacts"**.
    *   Descarga el archivo `restaurapp-print-windows.zip`.

4.  **Instalación en Windows (ZIP):**
    *   Descomprime el ZIP descargado.
    *   Verás una carpeta con el archivo `restaurapp_print.exe` y otras carpetas (`data`, etc).
    *   **Importante:** Debes mantener todos esos archivos juntos. Puedes crear un acceso directo al .exe en el escritorio del usuario.
    *   **Nota:** Al abrirlo, Windows dirá "Protegió su PC". El usuario debe dar clic en **"Más información" -> "Ejecutar de todas formas"**.

---

## 3. Notas Finales

*   **Configuración:** Recuerda que la configuración (dominio, impresoras) es local de cada PC donde se instale.
*   **Inicio Automático:** La función de inicio automático funcionará correctamente en las versiones de producción sin necesidad de trucos.
