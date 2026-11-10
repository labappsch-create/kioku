import 'package:cloud_firestore/cloud_firestore.dart';

/// Un aviso de la campanita (`notificaciones/{uid}/avisos/{id}`).
/// Ver docs/decisiones.md y firebase/firestore.rules.
class Aviso {
  Aviso(this.ref, this.datos);

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> datos;

  String get id => ref.id;
  String get tipo => datos['tipo'] as String? ?? '';
  String get actorUid => datos['actorUid'] as String? ?? '';
  String get nombre => datos['nombre'] as String? ?? '';
  String? get muro => datos['muro'] as String?;
  String? get duenoId => datos['duenoId'] as String?;
  String? get pid => datos['pid'] as String?;
  String? get dojoId => datos['dojoId'] as String?;
  String? get competenciaId => datos['competenciaId'] as String?;
  String get titulo => datos['titulo'] as String? ?? '';
  String get detalle => datos['detalle'] as String? ?? '';

  /// Texto de los avisos que escribe la propia app (dojo, torneos...).
  String get texto => datos['texto'] as String? ?? '';

  /// Para los avisos de dojo: aceptado, rechazado o quitado.
  String? get subtipo => datos['subtipo'] as String?;

  bool get leido => datos['leido'] as bool? ?? false;

  DateTime? get actualizado {
    final v = datos['actualizado'];
    return v is Timestamp ? v.toDate() : null;
  }

  /// Cuántas personas hay en un aviso agrupado.
  int get cantidad {
    final v = datos['claves'];
    return v is List && v.isNotEmpty ? v.length : 1;
  }

  /// "Ana", "Ana y 1 persona más", "Ana y 3 personas más".
  String get _quienes {
    final otros = cantidad - 1;
    if (otros <= 0) return nombre;
    return otros == 1 ? '$nombre y 1 persona más' : '$nombre y $otros personas más';
  }

  bool get _varios => cantidad > 1;

  String get _deQue =>
      muro == 'd' ? 'la publicación de tu dojo' : 'tu publicación';

  /// El texto que se muestra en la campanita.
  String get mensaje {
    switch (tipo) {
      case 'reaccion':
        return '$_quienes ${_varios ? 'reaccionaron' : 'reaccionó'} a $_deQue.';
      case 'comentario':
        return '$_quienes ${_varios ? 'comentaron' : 'comentó'} $_deQue.';
      case 'solicitud_amistad':
        return '$nombre te envió una solicitud de amistad.';
      case 'amistad_aceptada':
        return '$nombre aceptó tu solicitud de amistad.';
      case 'solicitud_dojo':
        return '$nombre pidió unirse a $titulo.';
      case 'inscripcion_confirmada':
        return 'Tu inscripción en $titulo fue confirmada ✓\n$detalle';
      case 'inscripcion_nueva':
        return '$_quienes ${_varios ? 'se inscribieron' : 'se inscribió'} en $titulo.';
    }
    return texto;
  }
}
