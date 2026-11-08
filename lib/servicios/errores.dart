import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Convierte errores de Firebase en mensajes simples en español.
String mensajeDeError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no es válido. Revisa que esté bien escrito.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo. Prueba iniciar sesión.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'El correo o la contraseña no son correctos.';
      case 'user-disabled':
        return 'Esta cuenta está desactivada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos y vuelve a probar.';
      case 'network-request-failed':
        return 'No hay conexión a internet. Revisa tu conexión.';
      case 'operation-not-allowed':
        return 'El inicio con correo y contraseña no está activado en Firebase.';
    }
    return 'No se pudo completar (${error.code}).';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'No hay permiso para esta acción. Puede que falten las reglas de seguridad en Firebase.';
      case 'unavailable':
        return 'No se pudo conectar con el servidor. Revisa tu conexión.';
      case 'not-found':
        return 'No se encontró la base de datos. Puede que falte crearla en Firebase.';
      case 'failed-precondition':
        return 'Firebase no está listo para esta acción (${error.message ?? error.code}).';
    }
    return 'Ocurrió un error (${error.code}).';
  }
  return 'Ocurrió un error inesperado.';
}
