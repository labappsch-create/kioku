import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/competencia.dart';
import '../modelos/resultado.dart';

/// Alcance del ranking según dónde se hizo el torneo.
enum Alcance { latinoamerica, pais, region }

/// Resultados (`podios`) y rankings.
class ResultadosServicio {
  ResultadosServicio({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _podios =>
      _db.collection('podios');

  List<Podio> _lista(QuerySnapshot<Map<String, dynamic>> r) =>
      [for (final d in r.docs) Podio(d.id, d.data())];

  /// Resultados de una competencia (todas las categorías).
  Stream<List<Podio>> deCompetencia(String cid) => _podios
      .where('competenciaId', isEqualTo: cid)
      .snapshots()
      .map(_lista);

  /// Inscritos confirmados de una categoría, para elegir los puestos.
  /// El organizador debe filtrar por su uid (lo exigen las reglas); un
  /// administrador puede verlos todos.
  Future<List<Inscripcion>> confirmados(
    String cid,
    String catId, {
    String? organizadorUid,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('inscripciones')
        .where('competenciaId', isEqualTo: cid)
        .where('categoriaId', isEqualTo: catId)
        .where('estado', isEqualTo: inscripcionConfirmada);
    if (organizadorUid != null) {
      q = q.where('organizadorUid', isEqualTo: organizadorUid);
    }
    final r = await q.get();
    final lista = [for (final d in r.docs) Inscripcion(d.id, d.data())];
    lista.sort((a, b) => a.atletaNombre.compareTo(b.atletaNombre));
    return lista;
  }

  /// Guarda los puestos de una categoría. [elegidos] va del puesto a la
  /// inscripción (o null para dejar el puesto vacío).
  Future<void> guardarCategoria({
    required Competencia competencia,
    required Categoria categoria,
    required Map<int, Inscripcion?> elegidos,
  }) async {
    final lote = _db.batch();
    for (final puesto in [1, 2, 3, 4]) {
      final ref = _podios.doc(idPodio(competencia.id, categoria.id, puesto));
      final ins = elegidos[puesto];
      if (ins == null) {
        lote.delete(ref);
      } else {
        lote.set(
          ref,
          Podio.mapa(
            competencia: competencia,
            categoria: categoria,
            inscripcion: ins,
            puesto: puesto,
          ),
        );
      }
    }
    await lote.commit();
  }

  /// Borra todos los resultados de una competencia (al cancelarla).
  Future<void> borrarDeCompetencia(String cid) async {
    final r = await _podios.where('competenciaId', isEqualTo: cid).get();
    for (final d in r.docs) {
      await d.reference.delete();
    }
  }

  /// Puestos de un atleta, por inscripción (para el historial).
  Future<Map<String, int>> puestosDeAtleta(String uid) async {
    final r = await _podios.where('atletaUid', isEqualTo: uid).get();
    return {for (final p in _lista(r)) p.iid: p.puesto};
  }

  Query<Map<String, dynamic>> _base(
      int anio, Alcance alcance, String? pais, String? region) {
    Query<Map<String, dynamic>> q = _podios.where('anio', isEqualTo: anio);
    if (alcance != Alcance.latinoamerica && pais != null) {
      q = q.where('pais', isEqualTo: pais);
    }
    if (alcance == Alcance.region && region != null) {
      q = q.where('region', isEqualTo: region);
    }
    return q;
  }

  /// Ranking de atletas: modalidad, sexo y grupo de edad.
  Future<List<FilaRanking>> rankingAtletas({
    required int anio,
    required Alcance alcance,
    String? pais,
    String? region,
    required String modalidad,
    required String sexo,
    required String grupo,
  }) async {
    final r = await _base(anio, alcance, pais, region)
        .where('modalidad', isEqualTo: modalidad)
        .where('sexo', isEqualTo: sexo)
        .where('grupo', isEqualTo: grupo)
        .get();
    final filas = <String, FilaRanking>{};
    for (final p in _lista(r)) {
      final f = filas.putIfAbsent(
          p.atletaUid, () => FilaRanking(id: p.atletaUid, nombre: p.atletaNombre));
      // Nombre y dojo más recientes que se conozcan.
      f.nombre = p.atletaNombre;
      f.detalle = p.dojoNombre;
      f.sumar(p);
    }
    return filas.values.toList()..sort(FilaRanking.comparar);
  }

  /// Ranking de dojos: total o por modalidad.
  Future<List<FilaRanking>> rankingDojos({
    required int anio,
    required Alcance alcance,
    String? pais,
    String? region,
    String? modalidad,
  }) async {
    var q = _base(anio, alcance, pais, region);
    if (modalidad != null) q = q.where('modalidad', isEqualTo: modalidad);
    final r = await q.get();
    final filas = <String, FilaRanking>{};
    for (final p in _lista(r)) {
      if (p.dojoId.isEmpty) continue;
      final f = filas.putIfAbsent(
          p.dojoId, () => FilaRanking(id: p.dojoId, nombre: p.dojoNombre));
      f.nombre = p.dojoNombre;
      f.sumar(p);
    }
    return filas.values.toList()..sort(FilaRanking.comparar);
  }
}
