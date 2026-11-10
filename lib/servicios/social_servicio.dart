import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../modelos/perfil.dart';
import '../modelos/publicacion.dart';
import '../modelos/reaccion.dart';
import 'fotos_servicio.dart';

/// Avisa cuando cambia una foto de perfil o una portada, para redibujarlas.
final ValueNotifier<int> fotosCambiadas = ValueNotifier<int>(0);

String parId(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

/// Una solicitud de amistad.
class Solicitud {
  Solicitud(this.id, this.datos);

  final String id;
  final Map<String, dynamic> datos;

  String get de => datos['de'] as String? ?? '';
  String get para => datos['para'] as String? ?? '';
  String get deNombre => datos['deNombre'] as String? ?? '';
}

/// Relaciones de la persona con sesión iniciada: amigos, solicitudes,
/// bloqueados y dojos que sigue. Se actualizan solas.
class Relaciones extends ChangeNotifier {
  Relaciones(this.uid, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance {
    _escuchar();
  }

  final String uid;
  final FirebaseFirestore _db;
  final List<StreamSubscription<Object?>> _subs = [];

  Set<String> amigos = {};
  Set<String> enviadas = {};
  List<Solicitud> recibidas = [];
  Set<String> bloqueados = {};

  /// Dojo → nombre.
  Map<String, String> siguiendo = {};
  bool suspendido = false;

  void _escuchar() {
    void cambio() => notifyListeners();
    void ignorar(Object _) {}
    _subs.add(_db
        .collection('amistades')
        .where('miembros', arrayContains: uid)
        .snapshots()
        .listen((r) {
      amigos = {
        for (final d in r.docs)
          for (final m in (d.data()['miembros'] as List? ?? const []))
            if (m is String && m != uid) m,
      };
      cambio();
    }, onError: ignorar));
    _subs.add(_db
        .collection('solicitudes_amistad')
        .where('de', isEqualTo: uid)
        .snapshots()
        .listen((r) {
      enviadas = {for (final d in r.docs) Solicitud(d.id, d.data()).para};
      cambio();
    }, onError: ignorar));
    _subs.add(_db
        .collection('solicitudes_amistad')
        .where('para', isEqualTo: uid)
        .snapshots()
        .listen((r) {
      recibidas = [for (final d in r.docs) Solicitud(d.id, d.data())];
      cambio();
    }, onError: ignorar));
    _subs.add(_db
        .collection('bloqueos')
        .where('bloqueador', isEqualTo: uid)
        .snapshots()
        .listen((r) {
      bloqueados = {for (final d in r.docs) d.data()['bloqueado'] as String? ?? ''};
      cambio();
    }, onError: ignorar));
    _subs.add(_db
        .collection('usuarios')
        .doc(uid)
        .collection('siguiendo')
        .snapshots()
        .listen((r) {
      siguiendo = {for (final d in r.docs) d.id: d.data()['nombre'] as String? ?? ''};
      cambio();
    }, onError: ignorar));
    _subs.add(_db.collection('suspendidos').doc(uid).snapshots().listen((d) {
      suspendido = d.exists;
      cambio();
    }, onError: ignorar));
  }

  bool solicitudRecibidaDe(String otro) => recibidas.any((s) => s.de == otro);

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Amigos, bloqueos, seguir dojos, publicaciones, comentarios, "me gusta",
/// denuncias y suspensiones.
class SocialServicio {
  SocialServicio({FirebaseFirestore? db, FotosServicio? fotos})
      : _db = db ?? FirebaseFirestore.instance,
        _fotos = fotos ?? FotosServicio();

  final FirebaseFirestore _db;
  final FotosServicio _fotos;

  // ---------- Amigos ----------

  Future<void> enviarSolicitud(String de, String para, String deNombre) =>
      _db.collection('solicitudes_amistad').doc('${de}_$para').set({
        'de': de,
        'para': para,
        'deNombre': deNombre,
        'creado': FieldValue.serverTimestamp(),
      });

  Future<void> cancelarSolicitud(String de, String para) =>
      _db.collection('solicitudes_amistad').doc('${de}_$para').delete();

  Future<void> aceptar(String yo, String otro) {
    final lote = _db.batch();
    lote.set(_db.collection('amistades').doc(parId(yo, otro)), {
      'miembros': [yo, otro],
      'creado': FieldValue.serverTimestamp(),
    });
    lote.delete(_db.collection('solicitudes_amistad').doc('${otro}_$yo'));
    return lote.commit();
  }

  Future<void> rechazar(String yo, String otro) =>
      _db.collection('solicitudes_amistad').doc('${otro}_$yo').delete();

  Future<void> eliminarAmigo(String yo, String otro) =>
      _db.collection('amistades').doc(parId(yo, otro)).delete();

  // ---------- Bloqueos ----------

  Future<void> bloquear(String yo, String otro, Relaciones r) async {
    await _db.collection('bloqueos').doc('${yo}_$otro').set({
      'bloqueador': yo,
      'bloqueado': otro,
      'creado': FieldValue.serverTimestamp(),
    });
    if (r.amigos.contains(otro)) await eliminarAmigo(yo, otro);
    if (r.enviadas.contains(otro)) await cancelarSolicitud(yo, otro);
    if (r.solicitudRecibidaDe(otro)) await rechazar(yo, otro);
  }

  Future<void> desbloquear(String yo, String otro) =>
      _db.collection('bloqueos').doc('${yo}_$otro').delete();

  // ---------- Seguir dojos ----------

  Future<void> seguir(String yo, String dojoId, String nombre) {
    final lote = _db.batch();
    lote.set(_db.collection('dojos').doc(dojoId).collection('seguidores').doc(yo),
        {'creado': FieldValue.serverTimestamp()});
    lote.set(_db.collection('usuarios').doc(yo).collection('siguiendo').doc(dojoId),
        {'nombre': nombre});
    return lote.commit();
  }

  Future<void> dejarDeSeguir(String yo, String dojoId) {
    final lote = _db.batch();
    lote.delete(_db.collection('dojos').doc(dojoId).collection('seguidores').doc(yo));
    lote.delete(_db.collection('usuarios').doc(yo).collection('siguiendo').doc(dojoId));
    return lote.commit();
  }

  // ---------- Publicaciones ----------

  CollectionReference<Map<String, dynamic>> muroPersona(String uid) =>
      _db.collection('muros').doc(uid).collection('publicaciones');

  CollectionReference<Map<String, dynamic>> muroDojo(String dojoId) =>
      _db.collection('muros_dojo').doc(dojoId).collection('publicaciones');

  Future<List<Foto>> _subirFotos(String carpeta, List<FotoElegida> nuevas) async {
    final subidas = <Foto>[];
    try {
      for (final f in nuevas) {
        final ruta = '$carpeta/${idViejoPrimero()}.${f.extension}';
        subidas.add(Foto(await _fotos.subir(ruta, f), ruta));
      }
    } catch (_) {
      for (final s in subidas) {
        await _fotos.borrar(s.ruta);
      }
      rethrow;
    }
    return subidas;
  }

  /// Publica en el muro de una persona.
  Future<void> publicarPersona({
    required String uid,
    required Perfil perfil,
    required String visibilidad,
    required String texto,
    required List<FotoElegida> fotos,
    TorneoCompartido? torneo,
  }) async {
    final hoy = DateTime.now();
    final ref = muroPersona(uid).doc(idNuevoPrimero());
    final subidas = await _subirFotos('publicaciones/$uid/${ref.id}', fotos);
    try {
      await ref.set({
        'autorUid': uid,
        'autorNombre': perfil.nombrePublico(hoy),
        'esMenor': perfil.esMenorDeEdad(hoy),
        'visibilidad': perfil.esMenorDeEdad(hoy) ? visibleAmigos : visibilidad,
        'texto': texto,
        'fotos': [for (final f in subidas) f.aMapa()],
        'competencia': torneo?.aMapa(),
        'creado': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      for (final s in subidas) {
        await _fotos.borrar(s.ruta);
      }
      rethrow;
    }
  }

  /// Publica a nombre de un dojo (solo su sensei).
  Future<void> publicarDojo({
    required String dojoId,
    required String dojoNombre,
    required String senseiUid,
    required String visibilidad,
    required String texto,
    required List<FotoElegida> fotos,
    TorneoCompartido? torneo,
  }) async {
    final ref = muroDojo(dojoId).doc(idNuevoPrimero());
    final subidas = await _subirFotos('publicaciones_dojo/$dojoId/${ref.id}', fotos);
    try {
      await ref.set({
        'autorUid': senseiUid,
        'autorNombre': dojoNombre,
        'esMenor': false,
        'visibilidad': visibilidad,
        'texto': texto,
        'fotos': [for (final f in subidas) f.aMapa()],
        'competencia': torneo?.aMapa(),
        'creado': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      for (final s in subidas) {
        await _fotos.borrar(s.ruta);
      }
      rethrow;
    }
  }

  /// Edita texto, visibilidad y fotos. [conservadas] son las fotos que
  /// quedan; [nuevas] se suben.
  Future<void> editar(
    Publicacion p, {
    required String texto,
    required String visibilidad,
    required List<Foto> conservadas,
    required List<FotoElegida> nuevas,
  }) async {
    final subidas = await _subirFotos(p.carpetaFotos, nuevas);
    final todas = [...conservadas, ...subidas];
    try {
      await p.ref.update({
        'texto': texto,
        'visibilidad': p.esMenor ? visibleAmigos : visibilidad,
        'fotos': [for (final f in todas) f.aMapa()],
        'editado': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      for (final s in subidas) {
        await _fotos.borrar(s.ruta);
      }
      rethrow;
    }
    final quedan = {for (final f in conservadas) f.ruta};
    for (final f in p.fotos) {
      if (!quedan.contains(f.ruta)) await _fotos.borrar(f.ruta);
    }
  }

  Future<void> borrar(Publicacion p) async {
    await p.ref.delete();
    for (final f in p.fotos) {
      await _fotos.borrar(f.ruta);
    }
  }

  List<Publicacion> _lista(QuerySnapshot<Map<String, dynamic>> r) =>
      [for (final d in r.docs) Publicacion(d.reference, d.data())];

  /// Publicaciones de una persona. Si no es amigo (ni dueño, ni su sensei),
  /// solo las "para cualquiera".
  Future<List<Publicacion>> dePersona(String uid, {required bool completo}) async {
    Query<Map<String, dynamic>> q = muroPersona(uid);
    if (!completo) q = q.where('visibilidad', isEqualTo: visibleTodos);
    return _lista(await q.limit(30).get());
  }

  /// Publicaciones de un dojo. Si no es miembro (ni sensei), solo las
  /// "para seguidores y miembros".
  Future<List<Publicacion>> deDojo(String dojoId, {required bool completo}) async {
    Query<Map<String, dynamic>> q = muroDojo(dojoId);
    if (!completo) q = q.where('visibilidad', isEqualTo: visibleSeguidores);
    return _lista(await q.limit(30).get());
  }

  /// El muro: mis publicaciones, las de mis amigos, las de mi dojo y las de
  /// los dojos que sigo. Lo más nuevo primero.
  Future<List<Publicacion>> muro({
    required String yo,
    required Set<String> amigos,
    required Set<String> bloqueados,
    String? miDojo,
    required Iterable<String> dojosSeguidos,
  }) async {
    final consultas = <Future<List<Publicacion>>>[
      dePersona(yo, completo: true),
      for (final a in amigos)
        if (!bloqueados.contains(a)) dePersona(a, completo: true),
      if (miDojo != null) deDojo(miDojo, completo: true),
      for (final d in dojosSeguidos)
        if (d != miDojo) deDojo(d, completo: false),
    ];
    Future<List<Publicacion>> seguro(Future<List<Publicacion>> f) async {
      try {
        return await f;
      } catch (_) {
        return const [];
      }
    }

    final todas = <Publicacion>[];
    for (final r in await Future.wait(consultas.map(seguro))) {
      todas.addAll(r);
    }
    // El id ordena de lo más nuevo a lo más viejo.
    todas.sort((a, b) => a.id.compareTo(b.id));
    return todas.take(80).toList();
  }

  // ---------- Comentarios y "me gusta" ----------

  Stream<List<Comentario>> comentarios(DocumentReference<Map<String, dynamic>> pub) =>
      pub.collection('comentarios').snapshots().map((r) =>
          [for (final d in r.docs) Comentario(d.reference, d.data())]);

  Future<int> cuantosComentarios(DocumentReference<Map<String, dynamic>> pub) async {
    final r = await pub.collection('comentarios').count().get();
    return r.count ?? 0;
  }

  Future<void> comentar(DocumentReference<Map<String, dynamic>> pub, String uid,
          String nombre, String texto) =>
      pub.collection('comentarios').doc(idViejoPrimero()).set({
        'autorUid': uid,
        'autorNombre': nombre,
        'texto': texto,
        'creado': FieldValue.serverTimestamp(),
      });

  Future<void> borrarComentario(Comentario c) => c.ref.delete();

  /// Reacciones: uid → tipo. Los "me gusta" de antes cuentan como 👍.
  /// (Se guardan en la subcolección `meGusta`, la misma de antes.)
  Stream<Map<String, String>> reacciones(DocumentReference<Map<String, dynamic>> pub) =>
      pub.collection('meGusta').snapshots().map((r) => {
            for (final d in r.docs)
              d.id: d.data()['tipo'] as String? ?? reaccionAntigua,
          });

  /// Pone o cambia la reacción. Con [tipo] null, la quita.
  Future<void> reaccionar(
      DocumentReference<Map<String, dynamic>> pub, String uid, String? tipo) {
    final ref = pub.collection('meGusta').doc(uid);
    if (tipo == null) return ref.delete();
    return ref.set({'tipo': tipo, 'creado': FieldValue.serverTimestamp()});
  }

  // ---------- Portadas ----------

  static final Map<String, Future<String?>> _cachePortadas = {};

  /// Enlace de la portada, o null si no tiene o no se puede ver.
  Future<String?> portada(String uid) =>
      _cachePortadas.putIfAbsent(uid, () async {
        try {
          final d = await _db.collection('portadas').doc(uid).get();
          return d.data()?['url'] as String?;
        } catch (_) {
          return null;
        }
      });

  Future<void> guardarPortada(String uid, bool esMenor, FotoElegida foto) async {
    final anterior = await _db.collection('portadas').doc(uid).get();
    final ruta = 'perfiles/$uid/portada_${idViejoPrimero()}.${foto.extension}';
    final url = await _fotos.subir(ruta, foto);
    await _db.collection('portadas').doc(uid).set({
      'url': url,
      'ruta': ruta,
      'esMenor': esMenor,
    });
    _cachePortadas.remove(uid);
    fotosCambiadas.value++;
    final rutaVieja = anterior.data()?['ruta'] as String?;
    if (rutaVieja != null) await _fotos.borrar(rutaVieja);
  }

  Future<void> quitarPortada(String uid) async {
    final d = await _db.collection('portadas').doc(uid).get();
    await _db.collection('portadas').doc(uid).delete();
    _cachePortadas.remove(uid);
    fotosCambiadas.value++;
    final ruta = d.data()?['ruta'] as String?;
    if (ruta != null) await _fotos.borrar(ruta);
  }

  // ---------- Fotos de perfil ----------

  static final Map<String, Future<String?>> _cacheFotos = {};

  /// Enlace de la foto de perfil, o null si no tiene o no se puede ver.
  Future<String?> fotoPerfil(String uid) =>
      _cacheFotos.putIfAbsent(uid, () async {
        try {
          final d = await _db.collection('fotos_perfil').doc(uid).get();
          return d.data()?['url'] as String?;
        } catch (_) {
          return null;
        }
      });

  Future<void> guardarFotoPerfil(String uid, bool esMenor, FotoElegida foto) async {
    final anterior = await _db.collection('fotos_perfil').doc(uid).get();
    final ruta = 'perfiles/$uid/${idViejoPrimero()}.${foto.extension}';
    final url = await _fotos.subir(ruta, foto);
    await _db.collection('fotos_perfil').doc(uid).set({
      'url': url,
      'ruta': ruta,
      'esMenor': esMenor,
    });
    _cacheFotos.remove(uid);
    fotosCambiadas.value++;
    final rutaVieja = anterior.data()?['ruta'] as String?;
    if (rutaVieja != null) await _fotos.borrar(rutaVieja);
  }

  Future<void> quitarFotoPerfil(String uid) async {
    final d = await _db.collection('fotos_perfil').doc(uid).get();
    await _db.collection('fotos_perfil').doc(uid).delete();
    _cacheFotos.remove(uid);
    fotosCambiadas.value++;
    final ruta = d.data()?['ruta'] as String?;
    if (ruta != null) await _fotos.borrar(ruta);
  }

  /// Mantiene al día si la foto y la portada son de un menor (al cumplir 18).
  Future<void> actualizarEdadFoto(String uid, bool esMenor) async {
    for (final coleccion in ['fotos_perfil', 'portadas']) {
      final ref = _db.collection(coleccion).doc(uid);
      final d = await ref.get();
      if (d.exists && d.data()?['esMenor'] != esMenor) {
        await ref.update({'esMenor': esMenor});
      }
    }
  }

  // ---------- Denuncias y suspensiones ----------

  Future<void> denunciar({
    required String tipo,
    required String ruta,
    required String autorUid,
    required String vistaPrevia,
    required String motivo,
    required String denuncianteUid,
  }) =>
      _db.collection('denuncias').add({
        'tipo': tipo,
        'ruta': ruta,
        'autorUid': autorUid,
        'vistaPrevia': vistaPrevia.length > 200 ? vistaPrevia.substring(0, 200) : vistaPrevia,
        'motivo': motivo,
        'denuncianteUid': denuncianteUid,
        'creado': FieldValue.serverTimestamp(),
      });

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> denuncias() =>
      _db.collection('denuncias').snapshots().map((r) => r.docs);

  Future<void> descartarDenuncia(String id) =>
      _db.collection('denuncias').doc(id).delete();

  /// Borra el contenido denunciado (publicación o comentario).
  Future<void> borrarDenunciado(String ruta) async {
    final ref = _db.doc(ruta);
    final d = await ref.get();
    if (!d.exists) return;
    if (ref.parent.id == 'publicaciones') {
      await borrar(Publicacion(ref, d.data()!));
    } else {
      await ref.delete();
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> suspendidos() =>
      _db.collection('suspendidos').snapshots().map((r) => r.docs);

  Future<void> suspender(String uid, String nombre) =>
      _db.collection('suspendidos').doc(uid).set({
        'nombre': nombre,
        'creado': FieldValue.serverTimestamp(),
      });

  Future<void> quitarSuspension(String uid) =>
      _db.collection('suspendidos').doc(uid).delete();
}
