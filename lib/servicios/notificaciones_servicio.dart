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

  // ---------- Ajustes: qué avisos suenan en el teléfono ----------

  DocumentReference<Map<String, dynamic>> _ajustes(String uid) =>
      _db.collection('usuarios').doc(uid).collection('ajustes').doc('avisos');

  /// Tipos de aviso apagados por la persona ({tipo: false}). Lo que no
  /// aparece está encendido.
  Stream<Map<String, bool>> ajustes(String uid) => _ajustes(uid).snapshots().map((d) => {
        for (final e in (d.data() ?? {}).entries)
          if (e.value is bool) e.key: e.value as bool,
      });

  Future<void> guardarAjuste(String uid, String tipo, bool encendido) =>
      _ajustes(uid).set({tipo: encendido}, SetOptions(merge: true));

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

  Future<void> traspasoDojo(
      String yo, String para, String dojoId, String dojoNombre) async {
    final nombre = await _miNombre(yo);
    if (nombre == null) return;
    await _paraOtro(yo, para, 'trasp_$dojoId', {
      'tipo': 'traspaso_dojo',
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

  /// El sensei avisa a la persona que su solicitud al dojo fue aceptada,
  /// rechazada, o que la quitó. [subtipo]: aceptado, rechazado o quitado.
  /// Se llama DESPUÉS de cambiar el miembro (las reglas lo comprueban).
  Future<void> dojoResultado(
          String yo, String dest, String dojoId, String dojoNombre, String subtipo) =>
      _paraOtro(yo, dest, 'dojo_res_$dojoId', {
        'tipo': 'dojo_resultado',
        'subtipo': subtipo,
        'dojoId': dojoId,
        'titulo': dojoNombre,
      });

  // Los avisos de torneos, podio, organizador y denuncias los crea el
  // servidor (functions/index.js).
}
