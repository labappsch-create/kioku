"""Hace que el APK se firme siempre con android-signing/debug.keystore.

Se ejecuta en GitHub, después de `flutter create`. Sin esto, cada armado
usa una llave distinta y Android no deja instalar una versión encima de otra.
"""

from pathlib import Path

ruta = Path("android/app/build.gradle.kts")
texto = ruta.read_text()

bloque = '''    signingConfigs {
        create("kioku") {
            storeFile = rootProject.file("../android-signing/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {'''

if 'create("kioku")' not in texto:
    if texto.count("    buildTypes {") != 1:
        raise SystemExit("No encontré el bloque buildTypes en build.gradle.kts")
    texto = texto.replace("    buildTypes {", bloque, 1)

viejo = 'signingConfig = signingConfigs.getByName("debug")'
if viejo not in texto:
    raise SystemExit("No encontré la línea de firma en build.gradle.kts")
texto = texto.replace(viejo, 'signingConfig = signingConfigs.getByName("kioku")')

ruta.write_text(texto)
print("Firma configurada con android-signing/debug.keystore")
