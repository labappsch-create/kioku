import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../modelos/dojo.dart';
import '../modelos/perfil.dart';
import 'dojos_servicio.dart';
import 'social_servicio.dart';

/// Avisa a la pantalla principal que el perfil cambió desde otra pantalla
/// (por ejemplo, al crear un dojo y pasar a ser miembro), para recargarlo.
final ValueNotifier<int> perfilCambiado = ValueNotifier<int>(0);

/// Aviso que se muestra cuando un dojo rechaza o quita a la persona.
class AvisoDojo {
  const AvisoDojo({required this.dojo, required this.eraMiembro});

  final String dojo;

  /// true si ya estaba confirmada (la quitaron); false si era una solicitud.
  final bool eraMiembro;

  String get mensaje => eraMiembro
      ? 'Ya no eres miembro del dojo "$dojo". Puedes elegir otro dojo en Editar perfil.'
      : 'El dojo "$dojo" rechazó tu solicitud. Puedes elegir otro dojo en Editar perfil.';
}

/// Guarda y lee perfiles en Firestore.
///
/// - `usuarios/{uid}`: perfil completo, solo para su dueño.
/// - `perfiles/{uid}`: lo que ven los demás.
class PerfilesServicio {
  PerfilesServicio({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DojosServicio get _dojos => DojosServicio(db: _db);

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
  /// Si cambió el dojo elegido, retira la solicitud anterior y envía la nueva.
  Future<void> guardar(String uid, Perfil perfil, {Perfil? anterior}) async {
    final hoy = DateTime.now();
    final lote = _db.batch();
    var aGuardar = perfil;

    final idAnterior = anterior?.dojoId;
    if (idAnterior != perfil.dojoId) {
      if (idAnterior != null) {
        lote.delete(_dojos.miembroRef(idAnterior, uid));
        lote.delete(_dojos.fichaRef(idAnterior, uid));
      }
      if (perfil.dojoId != null) {
        // En su propio dojo, el sensei queda confirmado sin solicitud.
        final dojo = await _db.collection('dojos').doc(perfil.dojoId).get();
        final esSuyo = dojo.data()?['senseiUid'] == uid;
        final estado = esSuyo ? estadoConfirmado : estadoPendiente;
        lote.set(_dojos.miembroRef(perfil.dojoId!, uid), {
          'estado': estado,
          'nombreMostrado': perfil.nombrePublico(hoy),
          'gradoId': perfil.gradoId,
          'actualizado': FieldValue.serverTimestamp(),
        });
        aGuardar = perfil.conDojo(perfil.dojoId, perfil.dojo, estado);
      } else {
        aGuardar = perfil.conDojo(null, perfil.dojo, null);
      }
    }

    if (aGuardar.dojoId != null) {
      lote.set(_dojos.fichaRef(aGuardar.dojoId!, uid), aGuardar.fichaMapa(hoy));
    }
    lote.set(_privado(uid), aGuardar.aMapa());
    // set sin merge: reemplaza todo, así no quedan datos que ya no se deben ver.
    lote.set(_publico(uid), aGuardar.aMapaPublico(hoy));
    await lote.commit();
  }

  /// Se llama al abrir la app. Revisa la solicitud al dojo, recalcula la
  /// parte pública (edad, si cumplió 18) y devuelve un aviso si el dojo
  /// rechazó o quitó a la persona.
  Future<(Perfil, AvisoDojo?)> sincronizar(String uid, Perfil perfil) async {
    final hoy = DateTime.now();
    var actual = perfil;
    AvisoDojo? aviso;
    Map<String, dynamic>? miembro;

    if (actual.dojoId != null) {
      final ref = _dojos.miembroRef(actual.dojoId!, uid);
      miembro = (await ref.get()).data();
      if (miembro == null) {
        aviso = AvisoDojo(
          dojo: actual.dojo,
          eraMiembro: actual.dojoEstado == estadoConfirmado,
        );
        actual = actual.conDojo(null, '', null);
        await _privado(uid).set(actual.aMapa());
      } else {
        final estado = miembro['estado'] as String?;
        if (estado != actual.dojoEstado) {
          actual = actual.conDojo(actual.dojoId, actual.dojo, estado);
          await _privado(uid).set(actual.aMapa());
        }
      }
    }

    await _publico(uid).set(actual.aMapaPublico(hoy));

    // Si cumplió 18, su foto de perfil pasa a verse como la de un adulto.
    try {
      await SocialServicio(db: _db).actualizarEdadFoto(uid, actual.esMenorDeEdad(hoy));
    } catch (_) {}

    // Mantiene al día la ficha para competir (edad, peso...). Si falla,
    // no impide abrir la app.
    if (miembro != null && actual.dojoId != null) {
      try {
        await _dojos
            .fichaRef(actual.dojoId!, uid)
            .set(actual.fichaMapa(hoy));
      } catch (_) {}
    }

    // Mantiene al día el nombre y el grado que ve el dojo.
    if (miembro != null && actual.dojoId != null) {
      final nombre = actual.nombrePublico(hoy);
      if (miembro['nombreMostrado'] != nombre ||
          miembro['gradoId'] != actual.gradoId) {
        await _dojos.miembroRef(actual.dojoId!, uid).update({
          'nombreMostrado': nombre,
          'gradoId': actual.gradoId,
          'actualizado': FieldValue.serverTimestamp(),
        });
      }
    }
    return (actual, aviso);
  }

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
