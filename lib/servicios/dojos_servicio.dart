import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/dojo.dart';
import '../modelos/perfil.dart' show normalizarParaBuscar;
import 'notificaciones_servicio.dart';

/// Traspaso pendiente de un dojo (colección `traspasos/{dojoId}`).
class Traspaso {
  Traspaso(this.datos);

  final Map<String, dynamic> datos;

  String get dojoId => datos['dojoId'] as String? ?? '';
  String get dojoNombre => datos['dojoNombre'] as String? ?? '';
  String get deUid => datos['deUid'] as String? ?? '';
  String get deNombre => datos['deNombre'] as String? ?? '';
  String get paraUid => datos['paraUid'] as String? ?? '';
  String get paraNombre => datos['paraNombre'] as String? ?? '';
}

/// Guarda y lee dojos en Firestore.
///
/// - `dojos/{id}`: lo que ven los demás.
/// - `dojos_privados/{id}`: datos completos, solo para el sensei.
/// - `dojos/{id}/miembros/{uid}`: solicitudes y miembros.
class DojosServicio {
  DojosServicio({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _publicos =>
      _db.collection('dojos');

  DocumentReference<Map<String, dynamic>> _privado(String id) =>
      _db.collection('dojos_privados').doc(id);

  DocumentReference<Map<String, dynamic>> miembroRef(String dojoId, String uid) =>
      _publicos.doc(dojoId).collection('miembros').doc(uid);

  /// Datos para competir de un practicante. Solo los ven él y el sensei.
  DocumentReference<Map<String, dynamic>> fichaRef(String dojoId, String uid) =>
      _publicos.doc(dojoId).collection('fichas').doc(uid);

  // ---------- Traspaso ----------

  CollectionReference<Map<String, dynamic>> get _traspasos =>
      _db.collection('traspasos');

  /// Traspaso pendiente del dojo (solo lo leen el sensei y el destinatario).
  Stream<Traspaso?> traspaso(String dojoId) => _traspasos.doc(dojoId).snapshots().map(
      (d) => d.data() == null ? null : Traspaso(d.data()!));

  /// Traspasos que esperan que esta persona acepte.
  Stream<List<Traspaso>> traspasosParaMi(String uid) => _traspasos
      .where('paraUid', isEqualTo: uid)
      .snapshots()
      .map((r) => [for (final d in r.docs) Traspaso(d.data())]);

  Future<void> proponerTraspaso({
    required String dojoId,
    required String dojoNombre,
    required String deUid,
    required String deNombre,
    required String paraUid,
    required String paraNombre,
  }) async {
    await _traspasos.doc(dojoId).set({
      'dojoId': dojoId,
      'dojoNombre': dojoNombre,
      'deUid': deUid,
      'deNombre': deNombre,
      'paraUid': paraUid,
      'paraNombre': paraNombre,
      'creado': FieldValue.serverTimestamp(),
    });
    unawaited(NotificacionesServicio(db: _db)
        .traspasoDojo(deUid, paraUid, dojoId, dojoNombre));
  }

  /// Cancelar (el sensei) o rechazar (el destinatario).
  Future<void> quitarTraspaso(String dojoId) => _traspasos.doc(dojoId).delete();

  /// Acepta el traspaso: queda como sensei a cargo, y los torneos locales
  /// del dojo (con sus inscripciones) pasan a su nombre.
  Future<void> aceptarTraspaso(Traspaso t, String uid, String nombre) async {
    final cambios = {
      'senseiUid': uid,
      'senseiNombre': nombre,
      'actualizado': FieldValue.serverTimestamp(),
    };
    final lote = _db.batch();
    lote.update(_publicos.doc(t.dojoId), cambios);
    lote.update(_privado(t.dojoId), cambios);
    lote.delete(_traspasos.doc(t.dojoId));
    await lote.commit();
    await pasarTorneosLocales(t.dojoId, uid, nombre);
  }

  Future<void> _enLotes(
      List<(DocumentReference<Map<String, dynamic>>, Map<String, Object?>)> cambios) async {
    // De a 400 (Firebase acepta hasta 500 cambios juntos).
    for (var i = 0; i < cambios.length; i += 400) {
      final lote = _db.batch();
      for (final (ref, datos) in cambios.skip(i).take(400)) {
        lote.update(ref, datos);
      }
      await lote.commit();
    }
  }

  /// Pasa al sensei actual los torneos locales del dojo y las inscripciones
  /// relacionadas. Se puede repetir sin problema.
  Future<void> pasarTorneosLocales(String dojoId, String uid, String nombre) async {
    final comps =
        await _db.collection('competencias').where('dojoId', isEqualTo: dojoId).get();
    await _enLotes([
      for (final c in comps.docs)
        if (c.data()['organizadorUid'] != uid)
          (c.reference, {'organizadorUid': uid, 'organizadorNombre': nombre}),
    ]);
    final insc = _db.collection('inscripciones');
    for (final c in comps.docs) {
      final r = await insc.where('competenciaId', isEqualTo: c.id).get();
      await _enLotes([
        for (final d in r.docs)
          if (d.data()['organizadorUid'] != uid)
            (d.reference, {
              'organizadorUid': uid,
              if (d.data()['dojoId'] == dojoId && d.data()['senseiUid'] != uid) 'senseiUid': uid,
            }),
      ]);
    }
    // Atletas del dojo inscritos en torneos de otros: su sensei ahora es otro.
    final delDojo = await insc.where('dojoId', isEqualTo: dojoId).get();
    await _enLotes([
      for (final d in delDojo.docs)
        if (d.data()['senseiUid'] != uid) (d.reference, {'senseiUid': uid}),
    ]);
  }

  /// Crea un dojo y devuelve su identificador.
  Future<String> crear(Dojo dojo) async {
    final ref = _publicos.doc();
    final lote = _db.batch();
    lote.set(_privado(ref.id), dojo.aMapa());
    lote.set(ref, dojo.aMapaPublico());
    await lote.commit();
    return ref.id;
  }

  Future<void> actualizar(String id, Dojo dojo) async {
    final lote = _db.batch();
    lote.set(_privado(id), dojo.aMapa());
    // set sin merge: así desaparece lo que el sensei decidió ocultar.
    lote.set(_publicos.doc(id), dojo.aMapaPublico());
    await lote.commit();
  }

  Future<Dojo?> leerPrivado(String id) async {
    final datos = (await _privado(id).get()).data();
    return datos == null ? null : Dojo.desdeMapa(datos);
  }

  Stream<DojoPublico?> ver(String id) => _publicos.doc(id).snapshots().map(
      (d) => d.data() == null ? null : DojoPublico(d.id, d.data()!));

  Stream<List<DojoPublico>> misDojos(String uid) => _publicos
      .where('senseiUid', isEqualTo: uid)
      .snapshots()
      .map((r) {
        final lista = [for (final d in r.docs) DojoPublico(d.id, d.data())];
        lista.sort((a, b) => a.nombreBusqueda.compareTo(b.nombreBusqueda));
        return lista;
      });

  /// Busca por nombre, con filtros opcionales.
  Future<List<DojoPublico>> buscar({
    String texto = '',
    String? pais,
    String? region,
    String? organizacionId,
  }) async {
    final q = normalizarParaBuscar(texto);
    final hayFiltros = pais != null || region != null || organizacionId != null;
    List<DojoPublico> lista;

    if (hayFiltros) {
      // Solo filtros de igualdad: no necesita índices especiales.
      Query<Map<String, dynamic>> consulta = _publicos;
      if (pais != null) consulta = consulta.where('pais', isEqualTo: pais);
      if (region != null) consulta = consulta.where('region', isEqualTo: region);
      if (organizacionId != null) {
        consulta = consulta.where('organizacionId', isEqualTo: organizacionId);
      }
      final r = await consulta.limit(300).get();
      lista = [for (final d in r.docs) DojoPublico(d.id, d.data())];
      if (q.isNotEmpty) {
        lista = lista.where((d) => d.nombreBusqueda.contains(q)).toList();
      }
    } else {
      Query<Map<String, dynamic>> consulta = _publicos.orderBy('nombreBusqueda');
      if (q.isNotEmpty) consulta = consulta.startAt([q]).endAt(['$q\uf8ff']);
      final r = await consulta.limit(50).get();
      lista = [for (final d in r.docs) DojoPublico(d.id, d.data())];
    }
    lista.sort((a, b) => a.nombreBusqueda.compareTo(b.nombreBusqueda));
    return lista;
  }

  Stream<List<Miembro>> miembros(String dojoId, String estado) => _publicos
      .doc(dojoId)
      .collection('miembros')
      .where('estado', isEqualTo: estado)
      .snapshots()
      .map((r) {
        final lista = [for (final d in r.docs) Miembro(d.id, d.data())];
        lista.sort((a, b) => normalizarParaBuscar(a.nombre)
            .compareTo(normalizarParaBuscar(b.nombre)));
        return lista;
      });

  /// Estado de una persona en un dojo: pendiente, confirmado o null.
  Stream<String?> estadoMiembro(String dojoId, String uid) =>
      miembroRef(dojoId, uid)
          .snapshots()
          .map((d) => d.data()?['estado'] as String?);

  Future<void> aceptar(String dojoId, String uid) =>
      miembroRef(dojoId, uid).update({
        'estado': estadoConfirmado,
        'actualizado': FieldValue.serverTimestamp(),
      });

  /// Rechazar una solicitud o quitar a un miembro.
  Future<void> quitar(String dojoId, String uid) {
    final lote = _db.batch();
    lote.delete(miembroRef(dojoId, uid));
    lote.delete(fichaRef(dojoId, uid));
    return lote.commit();
  }
}
