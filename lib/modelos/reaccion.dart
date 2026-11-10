/// Reacciones a una publicación (ver docs/decisiones.md).
/// Debe coincidir con reaccionValida en firebase/firestore.rules.
class Reaccion {
  const Reaccion(this.id, this.emoji, this.nombre);

  /// Identificador que se guarda en la base de datos. No cambiar.
  final String id;
  final String emoji;
  final String nombre;
}

const String reaccionPrincipal = 'oss';

/// Los "me gusta" de antes (sin tipo) cuentan como esta.
const String reaccionAntigua = 'megusta';

const List<Reaccion> reacciones = [
  Reaccion('oss', '👊', 'Oss'),
  Reaccion('megusta', '👍', 'Me gusta'),
  Reaccion('fuerza', '💪', 'Fuerza'),
  Reaccion('fuego', '🔥', 'Fuego'),
  Reaccion('aplausos', '👏', 'Aplausos'),
  Reaccion('divierte', '😂', 'Me divierte'),
  Reaccion('asombra', '😮', 'Me asombra'),
  Reaccion('entristece', '😢', 'Me entristece'),
];

Reaccion reaccionPorId(String? id) {
  for (final r in reacciones) {
    if (r.id == id) return r;
  }
  return reacciones[1];
}
