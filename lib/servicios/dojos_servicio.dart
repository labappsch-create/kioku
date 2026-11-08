import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/dojo.dart';
import '../modelos/perfil.dart' show normalizarParaBuscar;

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
