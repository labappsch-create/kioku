import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../modelos/aviso.dart';
import '../modelos/publicacion.dart';
import '../servicios/errores.dart';
import '../servicios/notificaciones_servicio.dart';
import '../servicios/sesion.dart';
import '../widgets/avatar.dart';
import '../widgets/tarjeta_publicacion.dart';
import 'admin/admin_pantalla.dart';
import 'competencias/ver_competencia_pantalla.dart';
import 'dojos/miembros_pantalla.dart';
import 'dojos/ver_dojo_pantalla.dart';
import 'social/amigos_pantalla.dart';

/// Fondo de los avisos que todavía no se abren.
const Color celesteSinLeer = Color(0xFFE7F3FF);

/// La campanita con el número rojo de avisos nuevos.
class BotonAvisos extends StatefulWidget {
  const BotonAvisos({super.key});

  @override
  State<BotonAvisos> createState() => _BotonAvisosState();
}

class _BotonAvisosState extends State<BotonAvisos> {
  Stream<int>? _sinVer;

  @override
  void initState() {
    super.initState();
    final uid = Sesion.uid;
    if (uid != null) _sinVer = NotificacionesServicio().sinVer(uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _sinVer,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return IconButton(
          tooltip: 'Notificaciones',
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n >= 99 ? '99+' : '$n'),
            child: const Icon(Icons.notifications_none),
          ),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const NotificacionesPantalla())),
        );
      },
    );
  }
}

/// Lista de avisos.
class NotificacionesPantalla extends StatefulWidget {
  const NotificacionesPantalla({super.key});

  @override
  State<NotificacionesPantalla> createState() => _NotificacionesPantallaState();
}

class _NotificacionesPantallaState extends State<NotificacionesPantalla> {
  final _servicio = NotificacionesServicio();

  @override
  void initState() {
    super.initState();
    final uid = Sesion.uid;
    // Al abrir la lista, el número rojo vuelve a cero.
    if (uid != null) _servicio.marcarVisto(uid).catchError((_) {});
  }

  void _abrir(Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  Future<void> _verTexto(Aviso a) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(a.mensaje),
          actions: [
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendido')),
          ],
        ),
      );

  Future<void> _tocar(Aviso a) async {
    if (!a.leido) _servicio.marcarLeido(a).catchError((_) {});
    final mensajes = ScaffoldMessenger.of(context);
    final uid = Sesion.uid ?? '';
    final perfil = Sesion.perfil;

    switch (a.tipo) {
      case 'reaccion':
      case 'comentario':
        final ref = (a.muro == 'd'
                ? FirebaseFirestore.instance.collection('muros_dojo')
                : FirebaseFirestore.instance.collection('muros'))
            .doc(a.duenoId)
            .collection('publicaciones')
            .doc(a.pid);
        try {
          final d = await ref.get();
          if (!mounted) return;
          if (d.data() == null) {
            mensajes.showSnackBar(
                const SnackBar(content: Text('Esa publicación ya no existe.')));
            return;
          }
          await Navegacion.abrirPublicacion
              ?.call(context, Publicacion(d.reference, d.data()!), false);
        } catch (e) {
          mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
        }
      case 'solicitud_amistad':
      case 'amistad_aceptada':
        _abrir(const AmigosPantalla());
      case 'solicitud_dojo':
        if (a.dojoId != null) {
          _abrir(MiembrosPantalla(dojoId: a.dojoId!, nombreDojo: a.titulo));
        }
      case 'dojo_resultado':
        if (a.subtipo == 'aceptado' && a.dojoId != null) {
          _abrir(VerDojoPantalla(dojoId: a.dojoId!));
        } else {
          await _verTexto(a);
        }
      case 'inscripcion_confirmada':
      case 'inscripcion_nueva':
      case 'torneo':
      case 'podio':
        if (a.competenciaId != null && perfil != null) {
          _abrir(VerCompetenciaPantalla(
              competenciaId: a.competenciaId!, uid: uid, perfil: perfil));
        }
      case 'denuncia':
        _abrir(const AdminPantalla());
      default:
        await _verTexto(a);
    }
  }

  Widget _imagen(Aviso a) {
    const conPersona = [
      'reaccion', 'comentario', 'solicitud_amistad', 'amistad_aceptada', 'solicitud_dojo',
    ];
    if (conPersona.contains(a.tipo) && a.actorUid.isNotEmpty) {
      return Avatar(uid: a.actorUid, nombre: a.nombre, radio: 24);
    }
    final IconData icono = switch (a.tipo) {
      'dojo_resultado' => Icons.sports_martial_arts,
      'inscripcion_confirmada' => Icons.how_to_reg,
      'inscripcion_nueva' => Icons.group_add,
      'torneo' => Icons.event,
      'podio' => Icons.emoji_events,
      'organizador' => Icons.workspace_premium,
      'denuncia' => Icons.flag,
      _ => Icons.notifications,
    };
    return CircleAvatar(radius: 24, child: Icon(icono));
  }

  @override
  Widget build(BuildContext context) {
    final uid = Sesion.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Aviso>>(
              stream: _servicio.lista(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(mensajeDeError(snap.error!)));
                }
                final lista = snap.data;
                if (lista == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (lista.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No tienes notificaciones.', textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final a = lista[i];
                    return Container(
                      color: a.leido ? Colors.white : celesteSinLeer,
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                        leading: _imagen(a),
                        title: Text(a.mensaje),
                        subtitle: Text(haceCuanto(a.actualizado)),
                        onTap: () => _tocar(a),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz),
                          onSelected: (_) => _servicio.borrar(a).catchError((_) {}),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'borrar', child: Text('Borrar')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
