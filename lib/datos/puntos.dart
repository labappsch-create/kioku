/// Tabla de puntos y grupos de edad del ranking (ver docs/decisiones.md).
/// Si se cambian estos números, los rankings se recalculan solos, porque
/// los puntos se calculan al mostrar el ranking.

const List<int> puestos = [1, 2, 3, 4];

const Map<String, Map<int, int>> tablaPuntos = {
  'local': {1: 10, 2: 7, 3: 5, 4: 3},
  'regional': {1: 20, 2: 14, 3: 10, 4: 6},
  'nacional': {1: 40, 2: 28, 3: 20, 4: 12},
  'internacional': {1: 80, 2: 56, 3: 40, 4: 24},
};

int puntosDe(String nivel, int puesto) => tablaPuntos[nivel]?[puesto] ?? 0;

String nombrePuesto(int puesto) => '$puesto.º lugar';

// ---------- Grupos de edad ----------

class GrupoEdad {
  const GrupoEdad(this.id, this.nombre, this.edades);

  /// Identificador que se guarda en la base de datos. No cambiar.
  final String id;
  final String nombre;
  final String edades;
}

const List<GrupoEdad> gruposEdad = [
  GrupoEdad('infantil', 'Infantil', 'hasta 11 años'),
  GrupoEdad('juvenil', 'Juvenil', '12 a 17 años'),
  GrupoEdad('adultos', 'Adultos', '18 a 39 años'),
  GrupoEdad('senior', 'Senior', '40 años o más'),
];

/// Debe coincidir con la función grupoDe de firebase/firestore.rules.
String grupoDeEdad(int edad) {
  if (edad <= 11) return 'infantil';
  if (edad <= 17) return 'juvenil';
  if (edad <= 39) return 'adultos';
  return 'senior';
}

String nombreGrupo(String id) {
  for (final g in gruposEdad) {
    if (g.id == id) return g.nombre;
  }
  return id;
}
