import 'package:flutter/material.dart';

import '../../modelos/perfil.dart';
import '../../servicios/errores.dart';
import '../../servicios/perfiles_servicio.dart';
import '../../servicios/sesion.dart';
import '../../servicios/social_servicio.dart';
import '../../widgets/avatar.dart';
import '../../widgets/denunciar.dart';
import '../../widgets/tarjeta_publicacion.dart';

/// Pantallas 5 y 7: amigos, solicitudes y bloqueados.
class AmigosPantalla extends StatelessWidget {
  const AmigosPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Amigos'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Amigos'),
            Tab(text: 'Solicitudes'),
            Tab(text: 'Bloqueados'),
          ]),
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: Sesion.cambios,
          builder: (context, _, __) {
            final r = Sesion.relaciones;
            if (r == null) return const SizedBox.shrink();
            return TabBarView(children: [
              _ListaAmigos(uids: r.amigos.toList()),
              _Solicitudes(relaciones: r),
              _Bloqueados(uids: r.bloqueados.toList()),
            ]);
          },
        ),
      ),
    );
  }
}

Future<void> _hacer(BuildContext context, Future<void> Function() accion, String listo) async {
  final mensajes = ScaffoldMessenger.of(context);
  try {
    await accion();
    mensajes.showSnackBar(SnackBar(content: Text(listo)));
  } catch (e) {
    mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
  }
}

/// Nombre de una persona tomado de su perfil público.
class _Persona extends StatelessWidget {
  const _Persona({required this.uid, this.subtitulo, this.trailing});

  final String uid;
  final String? subtitulo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PerfilPublico?>(
      stream: PerfilesServicio().verPublico(uid),
      builder: (context, snap) {
        final nombre = snap.data?.nombre ?? '...';
        return ListTile(
          leading: Avatar(uid: uid, nombre: nombre),
          title: Text(nombre),
          subtitle: Text(subtitulo ?? snap.data?.dojo ?? ''),
          trailing: trailing,
          onTap: () => Navegacion.abrirPerfil?.call(context, uid),
        );
      },
    );
  }
}

class _ListaAmigos extends StatelessWidget {
  const _ListaAmigos({required this.uids});

  final List<String> uids;

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aún no tienes amigos.\nBúscalos en la pestaña Gente.',
              textAlign: TextAlign.center),
        ),
      );
    }
    final yo = Sesion.uid ?? '';
    return ListView(children: [
      for (final u in uids)
        _Persona(
          uid: u,
          trailing: PopupMenuButton<String>(
            onSelected: (_) async {
              if (await confirmar(context, '¿Eliminar a esta persona de tus amigos?',
                      si: 'Eliminar') &&
                  context.mounted) {
                await _hacer(context, () => SocialServicio().eliminarAmigo(yo, u),
                    'Amistad eliminada');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'eliminar', child: Text('Eliminar amigo')),
            ],
          ),
        ),
    ]);
  }
}

class _Solicitudes extends StatelessWidget {
  const _Solicitudes({required this.relaciones});

  final Relaciones relaciones;

  @override
  Widget build(BuildContext context) {
    final yo = Sesion.uid ?? '';
    final servicio = SocialServicio();
    final recibidas = relaciones.recibidas;
    final enviadas = relaciones.enviadas.toList();
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Recibidas', style: Theme.of(context).textTheme.titleSmall),
      ),
      if (recibidas.isEmpty)
        const Padding(
            padding: EdgeInsets.all(16), child: Text('No tienes solicitudes nuevas.')),
      for (final s in recibidas)
        Column(children: [
          _Persona(uid: s.de),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => _hacer(
                    context, () => servicio.rechazar(yo, s.de), 'Solicitud rechazada'),
                child: const Text('Rechazar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _hacer(
                    context, () => servicio.aceptar(yo, s.de), '¡Ahora son amigos!'),
                child: const Text('Aceptar'),
              ),
            ]),
          ),
          const Divider(),
        ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Enviadas', style: Theme.of(context).textTheme.titleSmall),
      ),
      if (enviadas.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('No has enviado solicitudes.')),
      for (final u in enviadas)
        _Persona(
          uid: u,
          subtitulo: 'Esperando respuesta',
          trailing: TextButton(
            onPressed: () => _hacer(
                context, () => servicio.cancelarSolicitud(yo, u), 'Solicitud cancelada'),
            child: const Text('Cancelar'),
          ),
        ),
    ]);
  }
}

class _Bloqueados extends StatelessWidget {
  const _Bloqueados({required this.uids});

  final List<String> uids;

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return const Center(child: Text('No has bloqueado a nadie.'));
    }
    final yo = Sesion.uid ?? '';
    return ListView(children: [
      for (final u in uids)
        _Persona(
          uid: u,
          subtitulo: 'Bloqueado',
          trailing: TextButton(
            onPressed: () => _hacer(
                context, () => SocialServicio().desbloquear(yo, u), 'Desbloqueado'),
            child: const Text('Desbloquear'),
          ),
        ),
    ]);
  }
}
