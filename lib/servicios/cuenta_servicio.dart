import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modelos/competencia.dart';
import '../modelos/dojo.dart';
import '../modelos/publicacion.dart';
import 'admin_servicio.dart' show esAdminPrincipal;
import 'competencias_servicio.dart';
import 'dojos_servicio.dart';
import 'perfiles_servicio.dart';
import 'push_servicio.dart';
import 'social_servicio.dart';

/// Lo que impide borrar la cuenta (ver docs/decisiones.md).
class Impedimentos {
  const Impedimentos({required this.dojos, required this.torneos});

  /// Dojos donde es sensei: hay que traspasarlos.
  final List<DojoPublico> dojos;

  /// Torneos que organiza y no han terminado: hay que cancelarlos.
  final List<Competencia> torneos;

  bool get hay => dojos.isNotEmpty || torneos.isNotEmpty;
}

/// Borra la cuenta y sus datos.
class CuentaServicio {
  CuentaServicio({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<Impedimentos> revisar(String uid) async {
    final dojos = await DojosServicio(db: _db).misDojos(uid).first;
    final torneos = await CompetenciasServicio(db: _db).deOrganizador(uid).first;
    final ahora = DateTime.now();
    return Impedimentos(
      dojos: dojos,
      torneos: [
        for (final c in torneos)
          if (c.estado(ahora) != EstadoCompetencia.finalizada &&
              c.estado(ahora) != EstadoCompetencia.cancelada)
            c,
      ],
    );
  }

  Future<void> _borrarTodos(Query<Map<String, dynamic>> q) async {
    final r = await q.get();
    for (final d in r.docs) {
      await d.reference.delete();
    }
  }

  /// Confirma la contraseña y borra todo. [progreso] recibe qué está haciendo.
  Future<void> borrar(String contrasena, void Function(String) progreso) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null || usuario.email == null) {
      throw StateError('No hay sesión iniciada.');
    }
    if (esAdminPrincipal(usuario.email)) {
      throw StateError('El administrador principal no puede borrar su cuenta.');
    }
    final uid = usuario.uid;
    final credencial =
        EmailAuthProvider.credential(email: usuario.email!, password: contrasena);

    progreso('Confirmando tu contraseña…');
    await usuario.reauthenticateWithCredential(credencial);

    progreso('Revisando…');
    if ((await revisar(uid)).hay) {
      throw StateError('Todavía tienes dojos o torneos pendientes.');
    }

    final social = SocialServicio(db: _db);
    final competencias = CompetenciasServicio(db: _db);
    final dojos = DojosServicio(db: _db);
    final perfil = await PerfilesServicio(db: _db).leerMiPerfil(uid);
    final usuarios = _db.collection('usuarios').doc(uid);

    // Marca el borrado (lo exigen las reglas para quitar inscripciones).
    await _db.collection('eliminaciones').doc(uid).set({'creado': FieldValue.serverTimestamp()});

    // Cada paso sigue aunque falle algo, para borrar lo más posible.
    Future<void> paso(String texto, Future<void> Function() hacer) async {
      progreso(texto);
      try {
        await hacer();
      } catch (_) {}
    }

    await paso('Borrando tus publicaciones…', () async {
      final r = await social.muroPersona(uid).get();
      for (final d in r.docs) {
        await social.borrar(Publicacion(d.reference, d.data()));
      }
    });

    await paso('Borrando tus comentarios y reacciones…', () async {
      final r = await usuarios.collection('actividad').get();
      for (final d in r.docs) {
        final ruta = d.data()['ruta'] as String?;
        if (ruta != null) {
          try {
            await _db.doc(ruta).delete();
          } catch (_) {}
        }
        await d.reference.delete();
      }
    });

    await paso('Borrando tus amistades…', () async {
      await _borrarTodos(
          _db.collection('amistades').where('miembros', arrayContains: uid));
      await _borrarTodos(
          _db.collection('solicitudes_amistad').where('de', isEqualTo: uid));
      await _borrarTodos(
          _db.collection('solicitudes_amistad').where('para', isEqualTo: uid));
      await _borrarTodos(_db.collection('bloqueos').where('bloqueador', isEqualTo: uid));
    });

    await paso('Dejando de seguir dojos…', () async {
      final r = await usuarios.collection('siguiendo').get();
      for (final d in r.docs) {
        await social.dejarDeSeguir(uid, d.id);
      }
    });

    await paso('Saliendo de tu dojo…', () async {
      final dojoId = perfil?.dojoId;
      if (dojoId == null) return;
      await dojos.miembroRef(dojoId, uid).delete();
      await dojos.fichaRef(dojoId, uid).delete();
    });

    await paso('Borrando tus inscripciones…', () async {
      final r = await _db.collection('inscripciones').where('atletaUid', isEqualTo: uid).get();
      final ahora = DateTime.now();
      for (final d in r.docs) {
        final i = Inscripcion(d.id, d.data());
        try {
          final cd = await _db.collection('competencias').doc(i.competenciaId).get();
          final c = cd.data() == null ? null : Competencia(cd.id, cd.data()!);
          final activa = c != null &&
              !c.cancelada &&
              ahora.isBefore(diaSiguiente(c.fechaFin));
          if (activa) {
            // Si el torneo sigue activo, se descuenta de la categoría.
            final lote = _db.batch();
            lote.delete(d.reference);
            lote.update(
              _db
                  .collection('competencias')
                  .doc(i.competenciaId)
                  .collection('categorias')
                  .doc(i.categoriaId),
              {'inscritos': FieldValue.increment(-1), 'ultimaInscripcion': i.id},
            );
            await lote.commit();
          } else {
            await d.reference.delete();
          }
        } catch (_) {}
      }
    });

    await paso('Actualizando tus resultados…', () async {
      final r = await _db.collection('podios').where('atletaUid', isEqualTo: uid).get();
      for (final d in r.docs) {
        if (d.data()['atletaNombre'] == 'Atleta eliminado') continue;
        await d.reference.update({'atletaNombre': 'Atleta eliminado'});
      }
      await _borrarTodos(
          _db.collection('perfiles').doc(uid).collection('historial'));
    });

    await paso('Actualizando tus torneos…', () async {
      final mias = await competencias.deOrganizador(uid).first;
      for (final c in mias) {
        try {
          if (c.cancelada) {
            await competencias.borrarTorneo(c, uid);
          } else {
            await competencias.actualizar(c.id, {'organizadorNombre': 'Organizador eliminado'});
          }
        } catch (_) {}
      }
    });

    await paso('Quitando permisos…', () async {
      for (final ref in [
        _db.collection('organizadores').doc(uid),
        _db.collection('admins').doc(uid),
        _db.collection('solicitudes_organizador').doc(uid),
      ]) {
        try {
          await ref.delete();
        } catch (_) {}
      }
      await _borrarTodos(_db.collection('traspasos').where('paraUid', isEqualTo: uid));
    });

    await paso('Borrando tus avisos…', () async {
      // Este teléfono deja de recibir avisos de la cuenta.
      await PushServicio.olvidarTelefono(uid);
      final base = _db.collection('notificaciones').doc(uid);
      await _borrarTodos(base.collection('avisos'));
      await base.delete();
      await _borrarTodos(usuarios.collection('avisos_vistos'));
      await _borrarTodos(usuarios.collection('ocultos'));
      await _borrarTodos(usuarios.collection('actividad'));
      await _borrarTodos(usuarios.collection('tokens'));
      await _borrarTodos(usuarios.collection('ajustes'));
    });

    await paso('Borrando tus fotos…', () async {
      try {
        await social.quitarFotoPerfil(uid);
      } catch (_) {}
      try {
        await social.quitarPortada(uid);
      } catch (_) {}
    });

    await paso('Borrando tu perfil…', () async {
      try {
        await _db.collection('perfiles').doc(uid).delete();
      } catch (_) {}
      await usuarios.delete();
    });

    try {
      await _db.collection('eliminaciones').doc(uid).delete();
    } catch (_) {}

    progreso('Borrando tu cuenta…');
    try {
      await usuario.delete();
    } on FirebaseAuthException catch (e) {
      // Si pasó mucho rato, Google pide confirmar la contraseña de nuevo.
      if (e.code != 'requires-recent-login') rethrow;
      await usuario.reauthenticateWithCredential(credencial);
      await usuario.delete();
    }
  }
}
