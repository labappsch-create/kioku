import 'package:flutter/foundation.dart';

import '../modelos/perfil.dart';
import 'social_servicio.dart';

/// Datos de la persona con sesión iniciada, para las pantallas de la red
/// social. Los mantiene al día la pantalla principal.
class Sesion {
  Sesion._();

  static String? uid;
  static Perfil? perfil;
  static bool esAdmin = false;
  static Relaciones? relaciones;

  /// Avisa cuando cambian las relaciones (amigos, solicitudes, etc.).
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  static void iniciar(String nuevoUid, Perfil nuevoPerfil) {
    perfil = nuevoPerfil;
    if (uid == nuevoUid && relaciones != null) return;
    cerrar();
    uid = nuevoUid;
    relaciones = Relaciones(nuevoUid)..addListener(_avisar);
  }

  static void _avisar() => cambios.value++;

  static void cerrar() {
    relaciones?.removeListener(_avisar);
    relaciones?.dispose();
    relaciones = null;
    uid = null;
    perfil = null;
    esAdmin = false;
  }
}
