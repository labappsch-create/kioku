import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/competencia.dart';
import 'notificaciones_servicio.dart';
import 'resultados_servicio.dart';

/// Guarda y lee competencias, categorías e inscripciones.
///
/// - `competencias/{id}`: datos públicos de la competencia.
/// - `competencias/{id}/categorias/{id}`: categorías y su número de inscritos.
/// - `inscripciones/{competencia_atleta_modalidad}`: las ven el atleta,
///   su sensei y el organizador.
/// - `perfiles/{uid}/historial/{id}`: competencias en las que participó.
class CompetenciasServicio {
  CompetenciasServicio({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _comps =>
      _db.collection('competencias');

  CollectionReference<Map<String, dynamic>> get _insc =>
      _db.collection('inscripciones');

  CollectionReference<Map<String, dynamic>> _cats(String cid) =>
      _comps.doc(cid).collection('categorias');

  CollectionReference<Map<String, dynamic>> _historial(String uid) =>
      _db.collection('perfiles').doc(uid).collection('historial');

  // ---------- Competencias ----------

  Future<String> crear(Map<String, Object?> datos) async {
    final ref = _comps.doc();
    await ref.set({
      ...datos,
      'cerradaAntes': false,
      'creado': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> actualizar(String id, Map<String, Object?> datos) =>
      _comps.doc(id).update(datos);

  Future<void> cerrarInscripciones(String id) => _comps.doc(id).update({
        'cerradaAntes': true,
        'actualizado': FieldValue.serverTimestamp(),
      });

  /// Identificador nuevo para cada aviso (se muestra una sola vez).
  static String _nuevoAviso() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  /// Cancelar: definitivo. Primero se borran sus resultados, para que no
  /// cuenten en los rankings.
  Future<void> cancelar(Competencia c, String motivo) async {
    await ResultadosServicio(db: _db).borrarDeCompetencia(c.id);
    await _comps.doc(c.id).update({
        'situacion': situacionCancelada,
        'motivo': motivo,
        'avisoId': _nuevoAviso(),
        'avisoTexto': 'El torneo "${c.nombre}" fue cancelado.\nMotivo: $motivo',
        'actualizado': FieldValue.serverTimestamp(),
      });
  }

  /// Suspender: queda en pausa hasta que el organizador lo reactive.
  Future<void> suspender(Competencia c, String motivo) =>
      _comps.doc(c.id).update({
        'situacion': situacionSuspendida,
        'motivo': motivo,
        'avisoId': _nuevoAviso(),
        'avisoTexto': 'El torneo "${c.nombre}" fue suspendido (postergado).\n'
            'Motivo: $motivo\n'
            'El organizador avisará las nuevas fechas.',
        'actualizado': FieldValue.serverTimestamp(),
      });

  /// Reactivar con fechas nuevas. Hasta el nuevo cierre de inscripciones,
  /// el atleta o su sensei pueden anular aunque esté confirmada.
  Future<void> reactivar(
    Competencia c, {
    required DateTime inicio,
    required DateTime fin,
    required DateTime limite,
  }) {
    final cierre = diaSiguiente(limite);
    final fechas = soloDia(inicio) == soloDia(fin)
        ? textoFecha(inicio)
        : '${textoFecha(inicio)} al ${textoFecha(fin)}';
    return _comps.doc(c.id).update({
      'situacion': situacionNormal,
      'motivo': null,
      'fechaInicio': Timestamp.fromDate(soloDia(inicio)),
      'fechaFin': Timestamp.fromDate(soloDia(fin)),
      'fechaLimite': Timestamp.fromDate(soloDia(limite)),
      'cierre': Timestamp.fromDate(cierre),
      'cerradaAntes': false,
      'anularHasta': Timestamp.fromDate(cierre),
      'avisoId': _nuevoAviso(),
      'avisoTexto': 'El torneo "${c.nombre}" se reactivó con nuevas fechas: $fechas.\n'
          'Si la nueva fecha no te sirve, puedes anular tu inscripción '
          'hasta el ${textoFecha(limite)}, aunque ya esté confirmada.',
      'actualizado': FieldValue.serverTimestamp(),
    });
  }

  /// Texto del aviso cuando el organizador cambia las fechas al editar.
  static Map<String, Object?> avisoCambioDeFecha(
      String nombre, DateTime inicio, DateTime fin) {
    final fechas = soloDia(inicio) == soloDia(fin)
        ? textoFecha(inicio)
        : '${textoFecha(inicio)} al ${textoFecha(fin)}';
    return {
      'avisoId': _nuevoAviso(),
      'avisoTexto': 'El torneo "$nombre" cambió de fecha: $fechas.',
    };
  }

  Stream<Competencia?> ver(String id) => _comps.doc(id).snapshots().map(
      (d) => d.data() == null ? null : Competencia(d.id, d.data()!));

  /// Solo filtros de igualdad: no necesita índices especiales.
  Future<List<Competencia>> buscar({
    String? pais,
    String? region,
    String? nivel,
  }) async {
    Query<Map<String, dynamic>> q = _comps;
    if (pais != null) q = q.where('pais', isEqualTo: pais);
    if (region != null) q = q.where('region', isEqualTo: region);
    if (nivel != null) q = q.where('nivel', isEqualTo: nivel);
    final r = await q.limit(300).get();
    return [for (final d in r.docs) Competencia(d.id, d.data())];
  }

  Stream<List<Competencia>> deOrganizador(String uid) => _comps
      .where('organizadorUid', isEqualTo: uid)
      .snapshots()
      .map((r) {
        final lista = [for (final d in r.docs) Competencia(d.id, d.data())];
        lista.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
        return lista;
      });

  // ---------- Categorías ----------

  Stream<List<Categoria>> categorias(String cid) =>
      _cats(cid).snapshots().map((r) {
        final lista = [for (final d in r.docs) Categoria.desdeMapa(d.id, d.data())];
        lista.sort(Categoria.comparar);
        return lista;
      });

  Future<void> guardarCategoria(String cid, Categoria c) async {
    if (c.id.isEmpty) {
      await _cats(cid).add({...c.aMapa(), 'inscritos': 0});
    } else {
      // update: no toca el número de inscritos.
      await _cats(cid).doc(c.id).update(c.aMapa());
    }
  }

  Future<void> borrarCategoria(String cid, String catId) =>
      _cats(cid).doc(catId).delete();

  // ---------- Inscripciones ----------

  Stream<Inscripcion?> verInscripcion(String id) => _insc.doc(id).snapshots().map(
      (d) => d.data() == null ? null : Inscripcion(d.id, d.data()!));

  Future<void> inscribir({
    required Competencia competencia,
    required Categoria categoria,
    required DatosAtleta atleta,
    required String dojoId,
    required String dojoNombre,
    required String senseiUid,
    required String inscritoPor,
  }) async {
    final id = idInscripcion(competencia.id, atleta.uid, categoria.modalidad);
    final lote = _db.batch();
    lote.set(_insc.doc(id), {
      'competenciaId': competencia.id,
      'competenciaNombre': competencia.nombre,
      'nivel': competencia.nivel,
      'fechaInicio': Timestamp.fromDate(competencia.fechaInicio),
      'fechaFin': Timestamp.fromDate(competencia.fechaFin),
      'organizadorUid': competencia.organizadorUid,
      'categoriaId': categoria.id,
      'categoriaNombre': categoria.nombre,
      'modalidad': categoria.modalidad,
      'atletaUid': atleta.uid,
      'atletaNombre': atleta.nombre,
      'gradoId': atleta.gradoId,
      'edad': atleta.edad,
      'pesoKg': atleta.pesoKg,
      'estaturaCm': atleta.estaturaCm,
      'sexo': atleta.sexo,
      'dojoId': dojoId,
      'dojoNombre': dojoNombre,
      'senseiUid': senseiUid,
      'estado': inscripcionPendiente,
      'inscritoPor': inscritoPor,
      'creado': FieldValue.serverTimestamp(),
    });
    lote.update(_cats(competencia.id).doc(categoria.id), {
      'inscritos': FieldValue.increment(1),
      'ultimaInscripcion': id,
    });
    await lote.commit();
    if (competencia.organizadorUid != inscritoPor) {
      unawaited(NotificacionesServicio(db: _db)
          .inscripcionNueva(inscritoPor, competencia, id, atleta.nombre));
    }
  }

  Future<void> anular(Inscripcion i) async {
    final lote = _db.batch();
    lote.delete(_insc.doc(i.id));
    lote.update(_cats(i.competenciaId).doc(i.categoriaId), {
      'inscritos': FieldValue.increment(-1),
      'ultimaInscripcion': i.id,
    });
    await lote.commit();
  }

  Future<void> confirmar(Inscripcion i) async {
    await _insc.doc(i.id).update({'estado': inscripcionConfirmada});
    final yo = i.datos['organizadorUid'] as String? ?? '';
    unawaited(NotificacionesServicio(db: _db).inscripcionConfirmada(yo, i));
  }

  Stream<List<Inscripcion>> _lista(Query<Map<String, dynamic>> q) =>
      q.snapshots().map((r) {
        final lista = [for (final d in r.docs) Inscripcion(d.id, d.data())];
        lista.sort((a, b) {
          final c = a.categoriaNombre.compareTo(b.categoriaNombre);
          return c != 0 ? c : a.atletaNombre.compareTo(b.atletaNombre);
        });
        return lista;
      });

  // ---------- Avisos al abrir la app ----------

  DocumentReference<Map<String, dynamic>> _visto(String uid, String cid) =>
      _db.collection('usuarios').doc(uid).collection('avisos_vistos').doc(cid);

  /// Avisos nuevos de las competencias donde la persona está inscrita o
  /// tiene alumnos inscritos.
  Future<List<Competencia>> avisosPendientes(String uid) async {
    final comoAtleta =
        await _insc.where('atletaUid', isEqualTo: uid).get();
    final comoSensei =
        await _insc.where('senseiUid', isEqualTo: uid).get();
    final ids = <String>{
      for (final d in [...comoAtleta.docs, ...comoSensei.docs])
        d.data()['competenciaId'] as String? ?? '',
    }..remove('');
    final pendientes = <Competencia>[];
    for (final cid in ids) {
      final d = await _comps.doc(cid).get();
      if (d.data() == null) continue;
      final c = Competencia(d.id, d.data()!);
      // El organizador no necesita aviso de sus propios cambios.
      if (c.avisoId == null || c.organizadorUid == uid) continue;
      final visto = await _visto(uid, cid).get();
      if (visto.data()?['avisoId'] == c.avisoId) continue;
      pendientes.add(c);
    }
    return pendientes;
  }

  Future<void> marcarAvisoVisto(String uid, Competencia c) =>
      _visto(uid, c.id).set({'avisoId': c.avisoId});

  Stream<List<Inscripcion>> deAtleta(String uid) =>
      _insc.where('atletaUid', isEqualTo: uid).snapshots().map((r) {
        final lista = [for (final d in r.docs) Inscripcion(d.id, d.data())];
        lista.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
        return lista;
      });

  Stream<List<Inscripcion>> paraOrganizador(String cid, String uid) => _lista(_insc
      .where('competenciaId', isEqualTo: cid)
      .where('organizadorUid', isEqualTo: uid));

  Stream<List<Inscripcion>> paraSensei(String cid, String uid) => _lista(_insc
      .where('competenciaId', isEqualTo: cid)
      .where('senseiUid', isEqualTo: uid));

  /// Ficha para competir de un miembro del dojo (solo la lee su sensei).
  Future<DatosAtleta?> fichaDeMiembro({
    required String dojoId,
    required String uid,
    required String nombre,
    required String? gradoId,
  }) async {
    final d = await _db
        .collection('dojos')
        .doc(dojoId)
        .collection('fichas')
        .doc(uid)
        .get();
    return DatosAtleta.desdeFicha(
        uid: uid, nombre: nombre, gradoId: gradoId, ficha: d.data());
  }

  // ---------- Historial ----------

  /// Pasa al historial las competencias confirmadas que ya terminaron.
  Future<void> sincronizarHistorial(String uid) async {
    final hoy = soloDia(DateTime.now());
    final r = await _insc
        .where('atletaUid', isEqualTo: uid)
        .where('estado', isEqualTo: inscripcionConfirmada)
        .get();
    Map<String, int> puestos = {};
    try {
      puestos = await ResultadosServicio(db: _db).puestosDeAtleta(uid);
    } catch (_) {}
    for (final d in r.docs) {
      final i = Inscripcion(d.id, d.data());
      // Se usan las fechas actuales de la competencia (pudieron cambiar).
      final cd = await _comps.doc(i.competenciaId).get();
      if (cd.data() == null) continue;
      final c = Competencia(cd.id, cd.data()!);
      if (c.situacion != situacionNormal) continue;
      if (!soloDia(c.fechaFin).isBefore(hoy)) continue;
      await _historial(uid).doc(i.id).set({
        'competenciaNombre': i.competenciaNombre,
        'categoriaNombre': i.categoriaNombre,
        'nivel': i.nivel,
        'fecha': Timestamp.fromDate(c.fechaInicio),
        if (puestos[i.id] != null) 'puesto': puestos[i.id],
      });
    }
  }

  Stream<List<EntradaHistorial>> historial(String uid) =>
      _historial(uid).snapshots().map((r) {
        final lista = [for (final d in r.docs) EntradaHistorial(d.data())];
        lista.sort((a, b) => b.fecha.compareTo(a.fecha));
        return lista;
      });
}
