# Llave de firma para versiones de prueba

`debug.keystore` sirve para firmar las versiones de prueba que GitHub arma automáticamente.

Como todas las versiones usan la misma llave, cada versión nueva se instala encima de la anterior sin tener que desinstalarla.

**Importante:** esta llave es pública y **solo sirve para pruebas**. Antes de publicar en la Play Store se debe crear una llave privada nueva, que nunca se sube al repositorio.

Datos (los estándar de Android para pruebas): alias `androiddebugkey`, contraseñas `android`.
