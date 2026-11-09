import 'package:cloud_firestore/cloud_firestore.dart';

import '../datos/puntos.dart';
import 'competencia.dart';

/// Identificador fijo: un documento por puesto de cada categoría.
String idPodio(String competenciaId, String categoriaId, int puesto) =>
    '${competenciaId}_${categoriaId}_$puesto';

/// Un puesto obtenido en una categoría (colección pública `podios`).
class Podio {
  Podio(this.id, this.datos);

  final String id;
  final Map<String, dynamic> datos;

  int get puesto => (datos['puesto'] as num?)?.toInt() ?? 0;
  String get iid => datos['iid'] as String? ?? '';
  String get competenciaId => datos['competenciaId'] as String? ?? '';
  String get competenciaNombre => datos['competenciaNombre'] as String? ?? '';
  String get categoriaId => datos['categoriaId'] as String? ?? '';
  String get categoriaNombre => datos['categoriaNombre'] as String? ?? '';
  String get nivel => datos['nivel'] as String? ?? nivelLocal;
  String get modalidad => datos['modalidad'] as String? ?? modalidadKumite;
  String get atletaUid => datos['atletaUid'] as String? ?? '';
  String get atletaNombre => datos['atletaNombre'] as String? ?? '';
  String get dojoId => datos['dojoId'] as String? ?? '';
  String get dojoNombre => datos['dojoNombre'] as String? ?? '';

  int get puntos => puntosDe(nivel, puesto);

  /// Datos del puesto, tomados de la inscripción y de la competencia.
  static Map<String, Object?> mapa({
    required Competencia competencia,
    required Categoria categoria,
    required Inscripcion inscripcion,
    required int puesto,
  }) =>
      {
        'puesto': puesto,
        'iid': inscripcion.id,
        'competenciaId': competencia.id,
        'competenciaNombre': competencia.nombre,
        'categoriaId': categoria.id,
        'categoriaNombre': categoria.nombre,
        'nivel': competencia.nivel,
        'pais': competencia.pais,
        'region': competencia.region,
        'anio': competencia.fechaInicio.year,
        'fecha': Timestamp.fromDate(competencia.fechaInicio),
        'modalidad': inscripcion.modalidad,
        'sexo': inscripcion.sexo,
        'grupo': grupoDeEdad(inscripcion.edad),
        'atletaUid': inscripcion.atletaUid,
        'atletaNombre': inscripcion.atletaNombre,
        'dojoId': inscripcion.dojoId,
        'dojoNombre': inscripcion.dojoNombre,
        'actualizado': FieldValue.serverTimestamp(),
      };
}

/// Una fila del ranking (atleta o dojo).
class FilaRanking {
  FilaRanking({required this.id, required this.nombre, this.detalle = ''});

  final String id;
  String nombre;
  String detalle;
  int puntos = 0;

  /// Cantidad de 1.º, 2.º, 3.º y 4.º lugares (para desempatar).
  final Map<int, int> puestos = {for (final p in [1, 2, 3, 4]) p: 0};

  void sumar(Podio p) {
    puntos += p.puntos;
    puestos[p.puesto] = (puestos[p.puesto] ?? 0) + 1;
  }

  static int comparar(FilaRanking a, FilaRanking b) {
    final c = b.puntos.compareTo(a.puntos);
    if (c != 0) return c;
    for (final p in [1, 2, 3, 4]) {
      final d = (b.puestos[p] ?? 0).compareTo(a.puestos[p] ?? 0);
      if (d != 0) return d;
    }
    return a.nombre.compareTo(b.nombre);
  }

  String get resumenPuestos => [
        for (final p in [1, 2, 3, 4])
          if ((puestos[p] ?? 0) > 0) '${puestos[p]}× $p.º',
      ].join(' · ');
}
