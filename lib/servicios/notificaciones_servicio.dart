import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/aviso.dart';
import '../modelos/competencia.dart';
import '../modelos/publicacion.dart';

/// Los avisos se guardan 30 días.
const Duration duracionAvisos = Duration(days: 30);

/// Campanita: crea, lee y borra avisos.
///
/// - `notificaciones/{uid}`: hasta cuándo vio la campanita (`vistoHasta`).
/// - `notificaciones/{uid}/avisos/{id}`: cada aviso.
///
/// Los avisos de otra persona se dejan después de la acción (reaccionar,
/// comentar...). Si fallan, la acción ya quedó hecha: por eso los errores se
/// ignoran.
class NotificacionesServicio {
  NotificacionesServicio({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _base(String uid) =>
      _db.collection('notificaciones').doc(uid);

  CollectionReference<Map<String, dynamic>> _avisos(String uid) =>
      _base(uid).collection('avisos');

  // ---------- Leer ----------

  Stream<List<Aviso>> lista(String uid) => _avisos(uid)
      .orderBy('actualizado', descending: true)
      .limit(60)
      .snapshots()
      .map((r) => [for (final d in r.docs) Aviso(d.reference, d.data())]);

  /// Cantidad de avisos nuevos desde la última vez que abrió la campanita.
  Stream<int> sinVer(String uid) {
    StreamSubscription<Object?>? base;
    StreamSubscription<Object?>? avisos;
    late final StreamController<int> salida;
    salida = StreamController<int>(
      onListen: () {
        base = _base(uid).snapshots().listen((doc) {
          final visto = doc.data()?['vistoHasta'];
          avisos?.cancel();
          Query<Map<String, dynamic>> q = _avisos(uid);
          if (visto is Timestamp) q = q.where('actualizado', isGreaterThan: visto);
          avisos = q.limit(99).snapshots().listen(
                (r) => salida.add(r.docs.length),
                onError: (_) {},
              );
        }, onError: (_) {});
      },
      onCancel: () {
        base?.cancel();
        avisos?.cancel();
      },
    );
    return salida.stream;
  }

  /// Al abrir la lista: el número rojo vuelve a cero.
  Future<void> marcarVisto(String uid) =>
      _base(uid).set({'vistoHasta': Timestamp.now()}, SetOptions(merge: true));

  Future<void> marcarLeido(Aviso a) => a.ref.update({'leido': true});

  Future<void> borrar(Aviso a) => a.ref.delete();

  /// Borra los avisos de más de 30 días.
  Future<void> limpiarViejos(String uid) async {
    try {
      final limite = Timestamp.fromDate(DateTime.now().subtract(duracionAvisos));
      final r = await _avisos(uid).where('actualizado', isLessThan: limite).get();
      for (final d in r.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
  }

  // ---------- Avisos para otra persona ----------

  Future<String?> _miNombre(String uid) async {
    final d = await _db.collection('perfiles').doc(uid).get();
    return d.data()?['nombreMostrado'] as String?;
  }

  /// Deja un aviso en la campanita de [dest]. Con [clave], se suma a un
  /// aviso agrupado.
  Future<void> _paraOtro(
    String yo,
    String dest,
    String id,
    Map<String, Object?> datos, {
    String? clave,
  }) async {
    if (dest.isEmpty || dest == yo) return;
    try {
      final ref = _avisos(dest).doc(id);
      final todo = <String, Object?>{
        ...datos,
        'actorUid': yo,
        'leido': false,
        'actualizado': FieldValue.serverTimestamp(),
      };
      if (clave == null) {
        await ref.set(todo);
      } else {
        todo['claves'] = FieldValue.arrayUnion([clave]);
        todo['ultimaClave'] = clave;
        await ref.set(todo, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> reaccion(String yo, Publicacion p) async {
    if (p.autorUid == yo) return;
    final nombre = await _miNombre(yo);
    if (nombre == null) return;
    final muro = p.deDojo ? 'd' : 'p';
    await _paraOtro(
      yo,
      p.autorUid,
      'reac_${muro}_${p.duenoId}_${p.id}',
      {'tipo': 'reaccion', 'nombre': nombre, 'muro': muro, 'duenoId': p.duenoId, 'pid': p.id},
      clave: yo,
    );
  }

  Future<void> comentario(String yo, Publicacion p, String comentarioId) async {
    if (p.autorUid == yo) return;
    final nombre = await _miNombre(yo);
    if (nombre == null) return;
    final muro = p.deDojo ? 'd' : 'p';
    await _paraOtro(
      yo,
      p.autorUid,
      'com_${muro}_${p.duenoId}_${p.id}',
      {
        'tipo': 'comentario',
        'nombre': nombre,
        'muro': muro,
        'duenoId': p.duenoId,
        'pid': p.id,
        'cid': comentarioId,
      },
      clave: yo,
    );
  }

  Future<void> solicitudAmistad(String yo, String para) async {
    final nombre = await _miNombre(yo);
    if (nombre == null) return;
    await _paraOtro(yo, para, 'amig_sol_$yo', {'tipo': 'solicitud_amistad', 'nombre': nombre});
  }

  Future<void> amistadAceptada(String yo, String otro) async {
    final nombre = await _miNombre(yo);
    if (nombre == null) return;
    await _paraOtro(yo, otro, 'amig_ok_$yo', {'tipo': 'amistad_aceptada', 'nombre': nombre});
  }

  Future<void> solicitudDojo(
      String yo, String dojoId, String senseiUid, String dojoNombre) async {
    final nombre = await _miNombre(yo);
    if (nombre == null) return;
    await _paraOtro(yo, senseiUid, 'dojo_sol_${dojoId}_$yo', {
      'tipo': 'solicitud_dojo',
      'nombre': nombre,
      'dojoId': dojoId,
      'titulo': dojoNombre,
    });
  }

  Future<void> inscripcionConfirmada(String yo, Inscripcion i) =>
      _paraOtro(yo, i.atletaUid, 'insc_ok_${i.id}', {
        'tipo': 'inscripcion_confirmada',
        'iid': i.id,
        'competenciaId': i.competenciaId,
        'titulo': i.competenciaNombre,
        'detalle': i.categoriaNombre,
      });

  Future<void> inscripcionNueva(
          String yo, Competencia c, String iid, String atletaNombre) =>
      _paraOtro(
        yo,
        c.organizadorUid,
        'insc_new_${c.id}',
        {
          'tipo': 'inscripcion_nueva',
          'nombre': atletaNombre,
          'competenciaId': c.id,
          'titulo': c.nombre,
        },
        clave: iid,
      );

  // ---------- Avisos que detecta la propia app ----------

  Future<void> _propio(String uid, String id, Map<String, Object?> datos) async {
    try {
      await _avisos(uid).doc(id).set({
        ...datos,
        'leido': false,
        'actualizado': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Crea el aviso solo si no existe (para no repetirlo cada vez).
  Future<void> _propioUnaVez(String uid, String id, Map<String, Object?> datos) async {
    try {
      final d = await _avisos(uid).doc(id).get();
      if (d.exists) return;
    } catch (_) {
      return;
    }
    await _propio(uid, id, datos);
  }

  /// El dojo aceptó, rechazó o quitó a la persona.
  Future<void> resultadoDojo(String uid,
          {required String dojoId, required String subtipo, required String texto}) =>
      _propio(uid, 'dojo_res_$dojoId', {
        'tipo': 'dojo_resultado',
        'subtipo': subtipo,
        'dojoId': dojoId,
        'texto': texto,
      });

  /// Torneo cancelado, suspendido, reactivado o con fecha nueva.
  Future<void> torneo(String uid, Competencia c) => _propio(uid, 'torneo_${c.id}', {
        'tipo': 'torneo',
        'competenciaId': c.id,
        'texto': c.avisoTexto ?? 'Hay novedades en el torneo "${c.nombre}".',
      });

  Future<void> organizadorRechazado(String uid, String motivo) =>
      _propio(uid, 'organizador', {
        'tipo': 'organizador',
        'texto': 'Tu solicitud para ser organizador fue rechazada.\nMotivo: $motivo\n'
            'Puedes enviar otra desde Torneos → 🏆 → Ser organizador.',
      });

  /// Si un administrador la aprobó hace poco, avisa una sola vez.
  Future<void> revisarOrganizador(String uid) async {
    try {
      final d = await _db.collection('organizadores').doc(uid).get();
      final aprobado = d.data()?['aprobado'];
      if (aprobado is! Timestamp) return;
      if (DateTime.now().difference(aprobado.toDate()) > duracionAvisos) return;
      await _propioUnaVez(uid, 'organizador_ok', {
        'tipo': 'organizador',
        'texto': 'Tu solicitud para ser organizador fue aprobada ✓\n'
            'Ya puedes crear torneos regionales, nacionales e internacionales.',
      });
    } catch (_) {}
  }

  /// Avisa de los podios nuevos (una vez por cada uno).
  Future<void> revisarPodios(String uid) async {
    try {
      final r = await _db.collection('podios').where('atletaUid', isEqualTo: uid).get();
      for (final d in r.docs) {
        final p = d.data();
        final cuando = p['actualizado'];
        if (cuando is Timestamp &&
            DateTime.now().difference(cuando.toDate()) > duracionAvisos) {
          continue;
        }
        final puesto = (p['puesto'] as num?)?.toInt() ?? 0;
        await _propioUnaVez(uid, 'podio_${d.id}', {
          'tipo': 'podio',
          'competenciaId': p['competenciaId'],
          'texto': '¡Quedaste en el $puesto.º lugar en ${p['competenciaNombre'] ?? ''}!\n'
              '${p['categoriaNombre'] ?? ''}',
        });
      }
    } catch (_) {}
  }

  static final Set<String> _denunciasVistas = {};

  /// (Administradores) Avisa de las denuncias nuevas, una vez por cada una.
  Future<void> revisarDenuncias(
      String uid, List<QueryDocumentSnapshot<Map<String, dynamic>>> denuncias) async {
    for (final d in denuncias) {
      if (!_denunciasVistas.add(d.id)) continue;
      final datos = d.data();
      final creado = datos['creado'];
      if (creado is Timestamp &&
          DateTime.now().difference(creado.toDate()) > duracionAvisos) {
        continue;
      }
      final tipo = switch (datos['tipo']) {
        'publicacion' => 'una publicación',
        'comentario' => 'un comentario',
        _ => 'un perfil',
      };
      await _propioUnaVez(uid, 'denuncia_${d.id}', {
        'tipo': 'denuncia',
        'texto': 'Nueva denuncia sobre $tipo: ${datos['motivo'] ?? ''}',
      });
    }
  }
}
