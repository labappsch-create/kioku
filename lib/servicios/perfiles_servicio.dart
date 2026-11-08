import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/perfil.dart';

/// Guarda y lee perfiles en Firestore.
///
/// - `usuarios/{uid}`: perfil completo, solo para su dueño.
/// - `perfiles/{uid}`: lo que ven los demás.
class PerfilesServicio {
  PerfilesServicio({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _privado(String uid) =>
      _db.collection('usuarios').doc(uid);

  DocumentReference<Map<String, dynamic>> _publico(String uid) =>
      _db.collection('perfiles').doc(uid);

  Future<Perfil?> leerMiPerfil(String uid) async {
    final doc = await _privado(uid).get();
    final datos = doc.data();
    if (datos == null) return null;
    return Perfil.desdeMapa(datos);
  }

  /// Guarda el perfil completo y su versión pública a la vez.
  Future<void> guardar(String uid, Perfil perfil) async {
    final lote = _db.batch();
    lote.set(_privado(uid), perfil.aMapa());
    // set sin merge: reemplaza todo, así no quedan datos que ya no se deben ver.
    lote.set(_publico(uid), perfil.aMapaPublico(DateTime.now()));
    await lote.commit();
  }

  /// Recalcula la parte pública (por ejemplo, la edad o si cumplió 18).
  Future<void> actualizarPublico(String uid, Perfil perfil) =>
      _publico(uid).set(perfil.aMapaPublico(DateTime.now()));

  Stream<PerfilPublico?> verPublico(String uid) =>
      _publico(uid).snapshots().map((doc) {
        final datos = doc.data();
        return datos == null ? null : PerfilPublico(doc.id, datos);
      });

  /// Busca por el comienzo del nombre (sin importar tildes ni mayúsculas).
  Future<List<PerfilPublico>> buscar(String texto) async {
    final q = normalizarParaBuscar(texto);
    Query<Map<String, dynamic>> consulta =
        _db.collection('perfiles').orderBy('nombreBusqueda');
    if (q.isNotEmpty) {
      consulta = consulta.startAt([q]).endAt(['$q\uf8ff']);
    }
    final res = await consulta.limit(30).get();
    return res.docs.map((d) => PerfilPublico(d.id, d.data())).toList();
  }
}
