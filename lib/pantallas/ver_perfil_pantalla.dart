import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../modelos/perfil.dart';
import '../modelos/publicacion.dart';
import '../servicios/errores.dart';
import '../servicios/perfiles_servicio.dart';
import '../servicios/sesion.dart';
import '../servicios/social_servicio.dart';
import '../widgets/avatar.dart';
import '../widgets/denunciar.dart';
import '../widgets/tarjeta_perfil.dart';
import '../widgets/tarjeta_publicacion.dart';

/// Pantalla 6: perfil público de una persona, con amistad, bloqueo,
/// denuncia y sus publicaciones.
class VerPerfilPantalla extends StatelessWidget {
  const VerPerfilPantalla({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: StreamBuilder<PerfilPublico?>(
        stream: PerfilesServicio().verPublico(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return const Center(child: Text('Este perfil no existe.'));
          }
          return ValueListenableBuilder<int>(
            valueListenable: Sesion.cambios,
            builder: (context, _, __) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(child: Avatar(uid: uid, nombre: p.nombre, radio: 44)),
                const SizedBox(height: 12),
                if (uid != Sesion.uid) _Relacion(perfil: p),
                const SizedBox(height: 8),
                TarjetaPerfil(perfil: p),
                const SizedBox(height: 24),
                Text('Publicaciones', style: Theme.of(context).textTheme.titleMedium),
                _Publicaciones(uid: uid),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Relacion extends StatelessWidget {
  const _Relacion({required this.perfil});

  final PerfilPublico perfil;

  Future<void> _hacer(BuildContext context, Future<void> Function() accion, String listo,
      {String? siNoSePuede}) async {
    final mensajes = ScaffoldMessenger.of(context);
    try {
      await accion();
      mensajes.showSnackBar(SnackBar(content: Text(listo)));
    } on FirebaseException catch (e) {
      mensajes.showSnackBar(SnackBar(
          content: Text(e.code == 'permission-denied' && siNoSePuede != null
              ? siNoSePuede
              : mensajeDeError(e))));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final yo = Sesion.uid ?? '';
    final r = Sesion.relaciones;
    final miPerfil = Sesion.perfil;
    if (r == null || miPerfil == null) return const SizedBox.shrink();
    final otro = perfil.id;
    final servicio = SocialServicio();
    final hoy = DateTime.now();

    final bloqueado = r.bloqueados.contains(otro);
    final yoMenor = miPerfil.esMenorDeEdad(hoy);
    final mismoDojo = miPerfil.dojoId != null && miPerfil.dojoId == perfil.dojoId;
    final puedeSerAmigo = (!yoMenor && !perfil.esMenor) || mismoDojo;

    Widget boton;
    if (bloqueado) {
      boton = OutlinedButton.icon(
        icon: const Icon(Icons.block),
        label: const Text('Desbloquear'),
        onPressed: () =>
            _hacer(context, () => servicio.desbloquear(yo, otro), 'Desbloqueado'),
      );
    } else if (r.amigos.contains(otro)) {
      boton = OutlinedButton.icon(
        icon: const Icon(Icons.check),
        label: const Text('Amigos'),
        onPressed: () async {
          if (await confirmar(context, '¿Eliminar a ${perfil.nombre} de tus amigos?',
                  si: 'Eliminar') &&
              context.mounted) {
            await _hacer(
                context, () => servicio.eliminarAmigo(yo, otro), 'Amistad eliminada');
          }
        },
      );
    } else if (r.solicitudRecibidaDe(otro)) {
      boton = FilledButton.icon(
        icon: const Icon(Icons.person_add),
        label: const Text('Aceptar solicitud'),
        onPressed: () =>
            _hacer(context, () => servicio.aceptar(yo, otro), '¡Ahora son amigos!'),
      );
    } else if (r.enviadas.contains(otro)) {
      boton = OutlinedButton.icon(
        icon: const Icon(Icons.hourglass_top),
        label: const Text('Solicitud enviada (cancelar)'),
        onPressed: () => _hacer(
            context, () => servicio.cancelarSolicitud(yo, otro), 'Solicitud cancelada'),
      );
    } else if (puedeSerAmigo) {
      boton = FilledButton.icon(
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar amigo'),
        onPressed: r.suspendido
            ? null
            : () => _hacer(
                  context,
                  () => servicio.enviarSolicitud(yo, otro, miPerfil.nombrePublico(hoy)),
                  'Solicitud enviada',
                  siNoSePuede: 'No se pudo enviar. Los menores de 18 solo pueden ser '
                      'amigos de personas de su mismo dojo confirmado.',
                ),
      );
    } else {
      boton = const Text(
        'Los menores de 18 solo pueden ser amigos de personas de su mismo dojo.',
        textAlign: TextAlign.center,
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        boton,
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          onSelected: (v) async {
            if (v == 'bloquear') {
              if (await confirmar(
                      context,
                      '¿Bloquear a ${perfil.nombre}? No verás sus publicaciones ni '
                      'comentarios, y no podrá enviarte solicitudes. Si eran amigos, '
                      'se elimina la amistad.',
                      si: 'Bloquear') &&
                  context.mounted) {
                await _hacer(context, () => servicio.bloquear(yo, otro, r), 'Bloqueado');
              }
            } else if (v == 'denunciar') {
              await denunciar(context,
                  tipo: 'perfil',
                  ruta: 'perfiles/$otro',
                  autorUid: otro,
                  vistaPrevia: perfil.nombre);
            }
          },
          itemBuilder: (_) => [
            if (!bloqueado) const PopupMenuItem(value: 'bloquear', child: Text('Bloquear')),
            const PopupMenuItem(value: 'denunciar', child: Text('Denunciar perfil')),
          ],
        ),
      ],
    );
  }
}

class _Publicaciones extends StatefulWidget {
  const _Publicaciones({required this.uid});

  final String uid;

  @override
  State<_Publicaciones> createState() => _PublicacionesState();
}

class _PublicacionesState extends State<_Publicaciones> {
  late Future<List<Publicacion>> _carga;

  bool get _completo =>
      widget.uid == Sesion.uid || (Sesion.relaciones?.amigos.contains(widget.uid) ?? false);

  @override
  void initState() {
    super.initState();
    _carga = _cargar();
  }

  Future<List<Publicacion>> _cargar() =>
      SocialServicio().dePersona(widget.uid, completo: _completo);

  @override
  Widget build(BuildContext context) {
    if (Sesion.relaciones?.bloqueados.contains(widget.uid) ?? false) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Bloqueaste a esta persona.'),
      );
    }
    return FutureBuilder<List<Publicacion>>(
      future: _carga,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(mensajeDeError(snap.error!)),
          );
        }
        final lista = snap.data ?? const <Publicacion>[];
        if (lista.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_completo
                ? 'Aún no hay publicaciones.'
                : 'No hay publicaciones que puedas ver. Las que son solo para '
                    'amigos aparecen cuando son amigos.'),
          );
        }
        return Column(children: [
          for (final p in lista)
            TarjetaPublicacion(
              publicacion: p,
              alCambiar: () => setState(() => _carga = _cargar()),
            ),
        ]);
      },
    );
  }
}
