import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

// Visibilidad de publicaciones de personas.
const String visibleAmigos = 'amigos';
const String visibleTodos = 'todos';

// Visibilidad de publicaciones de dojos.
const String visibleSeguidores = 'seguidores';
const String visibleMiembros = 'miembros';

String nombreVisibilidad(String v) {
  switch (v) {
    case visibleAmigos:
      return 'Solo amigos';
    case visibleTodos:
      return 'Cualquiera';
    case visibleSeguidores:
      return 'Seguidores y miembros';
    case visibleMiembros:
      return 'Solo miembros';
  }
  return v;
}

final _azar = Random();

String _sufijo() =>
    List.generate(6, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[_azar.nextInt(32)])
        .join();

/// Identificador que ordena de la más nueva a la más vieja (así las
/// consultas traen primero lo reciente sin índices especiales).
String idNuevoPrimero() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  return '${(9999999999999 - ms).toString().padLeft(13, '0')}_${_sufijo()}';
}

/// Identificador que ordena de la más vieja a la más nueva (comentarios).
String idViejoPrimero() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  return '${ms.toString().padLeft(13, '0')}_${_sufijo()}';
}

/// Una foto subida: su enlace y su ubicación en el almacenamiento.
class Foto {
  const Foto(this.url, this.ruta);

  final String url;
  final String ruta;

  Map<String, Object?> aMapa() => {'url': url, 'ruta': ruta};

  static Foto desdeMapa(Object? v) {
    final m = v is Map ? v : const {};
    return Foto(m['url'] as String? ?? '', m['ruta'] as String? ?? '');
  }
}

/// Torneo compartido en una publicación.
class TorneoCompartido {
  const TorneoCompartido({
    required this.id,
    required this.nombre,
    required this.fechas,
    required this.lugar,
    required this.nivel,
  });

  final String id;
  final String nombre;
  final String fechas;
  final String lugar;
  final String nivel;

  Map<String, Object?> aMapa() =>
      {'id': id, 'nombre': nombre, 'fechas': fechas, 'lugar': lugar, 'nivel': nivel};

  static TorneoCompartido? desdeMapa(Object? v) {
    if (v is! Map) return null;
    return TorneoCompartido(
      id: v['id'] as String? ?? '',
      nombre: v['nombre'] as String? ?? '',
      fechas: v['fechas'] as String? ?? '',
      lugar: v['lugar'] as String? ?? '',
      nivel: v['nivel'] as String? ?? '',
    );
  }
}

/// Una publicación de una persona (`muros/{uid}/publicaciones`) o de un
/// dojo (`muros_dojo/{dojoId}/publicaciones`).
class Publicacion {
  Publicacion(this.ref, this.datos);

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> datos;

  String get id => ref.id;

  /// true si es de un dojo.
  bool get deDojo => ref.parent.parent?.parent.id == 'muros_dojo';

  /// uid de la persona, o id del dojo.
  String get duenoId => ref.parent.parent?.id ?? '';

  String get autorUid => datos['autorUid'] as String? ?? '';
  String get autorNombre => datos['autorNombre'] as String? ?? '';
  bool get esMenor => datos['esMenor'] as bool? ?? false;
  String get visibilidad => datos['visibilidad'] as String? ?? visibleAmigos;
  String get texto => datos['texto'] as String? ?? '';

  List<Foto> get fotos {
    final v = datos['fotos'];
    if (v is! List) return const [];
    return [for (final f in v) Foto.desdeMapa(f)];
  }

  TorneoCompartido? get torneo => TorneoCompartido.desdeMapa(datos['competencia']);

  DateTime? get creado {
    final v = datos['creado'];
    return v is Timestamp ? v.toDate() : null;
  }

  bool get editado => datos['editado'] != null;

  String get carpetaFotos =>
      deDojo ? 'publicaciones_dojo/$duenoId/$id' : 'publicaciones/$duenoId/$id';
}

/// Un comentario de una publicación.
class Comentario {
  Comentario(this.ref, this.datos);

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> datos;

  String get autorUid => datos['autorUid'] as String? ?? '';
  String get autorNombre => datos['autorNombre'] as String? ?? '';
  String get texto => datos['texto'] as String? ?? '';

  DateTime? get creado {
    final v = datos['creado'];
    return v is Timestamp ? v.toDate() : null;
  }
}

/// Texto corto de cuánto tiempo pasó ("hace 5 min").
String haceCuanto(DateTime? fecha) {
  if (fecha == null) return 'ahora';
  final d = DateTime.now().difference(fecha);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  if (d.inDays < 7) return 'hace ${d.inDays} d';
  return '${fecha.day}/${fecha.month}/${fecha.year}';
}
