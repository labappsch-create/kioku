"""Permiso para mostrar notificaciones (Android 13 o más).

Se ejecuta en GitHub, después de `flutter create`, porque el archivo
AndroidManifest.xml se genera en cada armado. Se puede repetir sin problema.
"""

from pathlib import Path

ruta = Path("android/app/src/main/AndroidManifest.xml")
texto = ruta.read_text()

permiso = '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>'

if "android.permission.POST_NOTIFICATIONS" not in texto:
    if texto.count("<application") != 1:
        raise SystemExit("No encontré <application> en AndroidManifest.xml")
    texto = texto.replace("<application", permiso + "\n    <application", 1)
    ruta.write_text(texto)

if "android.permission.POST_NOTIFICATIONS" not in ruta.read_text():
    raise SystemExit("No se pudo agregar el permiso de notificaciones")
print("Permiso de notificaciones listo")
