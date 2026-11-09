import 'package:flutter/material.dart';

import '../modelos/competencia.dart' show nombreNivel;
import '../modelos/publicacion.dart';
import '../servicios/errores.dart';
import '../servicios/sesion.dart';
import '../servicios/social_servicio.dart';
import 'avatar.dart';
import 'denunciar.dart';

/// Abre pantallas de otras partes de la app sin importarlas aquí
/// (las conecta la pantalla principal).
class Navegacion {
  static void Function(BuildContext, String uid)? abrirPerfil;
  static void Function(BuildContext, String dojoId)? abrirDojo;
  static void Function(BuildContext, String competenciaId)? abrirCompetencia;
  static Future<void> Function(BuildContext, Publicacion, bool puedeModerar)?
      abrirPublicacion;
  static Future<void> Function(BuildContext, Publicacion)? editarPublicacion;
}

/// Una publicación en el muro.
class TarjetaPublicacion extends StatelessWidget {
  const TarjetaPublicacion({
    super.key,
    required this.publicacion,
    this.alCambiar,
    this.puedeModerar = false,
    this.enDetalle = false,
  });

  final Publicacion publicacion;

  /// Se llama al borrar o editar, para recargar la lista.
  final VoidCallback? alCambiar;

  /// true para el sensei de un menor o un administrador.
  final bool puedeModerar;

  /// true en la pantalla de la publicación (no se abre otra vez al tocarla).
  final bool enDetalle;

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    final yo = Sesion.uid ?? '';
    final esMia = p.autorUid == yo;
    final puedeBorrar = esMia || puedeModerar || Sesion.esAdmin;
    final textos = Theme.of(context).textTheme;

    Future<void> borrar() async {
      final mensajes = ScaffoldMessenger.of(context);
      if (!await confirmar(context, '¿Borrar esta publicación?', si: 'Borrar')) return;
      try {
        await SocialServicio().borrar(p);
        mensajes.showSnackBar(const SnackBar(content: Text('Publicación borrada')));
        alCambiar?.call();
      } catch (e) {
        mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: enDetalle
            ? null
            : () => Navegacion.abrirPublicacion?.call(context, p, puedeModerar),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                InkWell(
                  onTap: () => p.deDojo
                      ? Navegacion.abrirDojo?.call(context, p.duenoId)
                      : Navegacion.abrirPerfil?.call(context, p.autorUid),
                  child: p.deDojo
                      ? const CircleAvatar(child: Icon(Icons.sports_martial_arts))
                      : Avatar(uid: p.autorUid, nombre: p.autorNombre),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.autorNombre, style: textos.titleSmall),
                      Text(
                        '${haceCuanto(p.creado)}${p.editado ? ' · editada' : ''}'
                        ' · ${nombreVisibilidad(p.visibilidad)}',
                        style: textos.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'editar':
                        await Navegacion.editarPublicacion?.call(context, p);
                        alCambiar?.call();
                      case 'borrar':
                        await borrar();
                      case 'denunciar':
                        await denunciar(context,
                            tipo: 'publicacion',
                            ruta: p.ref.path,
                            autorUid: p.autorUid,
                            vistaPrevia: p.texto);
                    }
                  },
                  itemBuilder: (_) => [
                    if (esMia) const PopupMenuItem(value: 'editar', child: Text('Editar')),
                    if (puedeBorrar)
                      const PopupMenuItem(value: 'borrar', child: Text('Borrar')),
                    if (!esMia)
                      const PopupMenuItem(value: 'denunciar', child: Text('Denunciar')),
                  ],
                ),
              ]),
              if (p.texto.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(p.texto),
                ),
              ],
              if (p.fotos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Fotos(fotos: p.fotos),
                ),
              ],
              if (p.torneo != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.emoji_events),
                      title: Text(p.torneo!.nombre),
                      subtitle: Text('${nombreNivel(p.torneo!.nivel)} · '
                          '${p.torneo!.fechas}\n${p.torneo!.lugar}'),
                      isThreeLine: true,
                      onTap: () =>
                          Navegacion.abrirCompetencia?.call(context, p.torneo!.id),
                    ),
                  ),
                ),
              ],
              _Acciones(publicacion: p, enDetalle: enDetalle, puedeModerar: puedeModerar),
            ],
          ),
        ),
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.publicacion,
    required this.enDetalle,
    required this.puedeModerar,
  });

  final Publicacion publicacion;
  final bool enDetalle;
  final bool puedeModerar;

  @override
  Widget build(BuildContext context) {
    final yo = Sesion.uid ?? '';
    final servicio = SocialServicio();
    return Row(children: [
      StreamBuilder<Set<String>>(
        stream: servicio.meGusta(publicacion.ref),
        builder: (context, snap) {
          final gustan = snap.data ?? const <String>{};
          final mio = gustan.contains(yo);
          return TextButton.icon(
            icon: Icon(mio ? Icons.thumb_up : Icons.thumb_up_outlined),
            label: Text('${gustan.length}'),
            onPressed: () async {
              final mensajes = ScaffoldMessenger.of(context);
              try {
                await servicio.cambiarMeGusta(publicacion.ref, yo, !mio);
              } catch (e) {
                mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
              }
            },
          );
        },
      ),
      if (!enDetalle)
        FutureBuilder<int>(
          future: servicio.cuantosComentarios(publicacion.ref),
          builder: (context, snap) => TextButton.icon(
            icon: const Icon(Icons.mode_comment_outlined),
            label: Text('${snap.data ?? ''}'),
            onPressed: () =>
                Navegacion.abrirPublicacion?.call(context, publicacion, puedeModerar),
          ),
        ),
    ]);
  }
}

class _Fotos extends StatelessWidget {
  const _Fotos({required this.fotos});

  final List<Foto> fotos;

  void _ver(BuildContext context, int inicio) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: PageView(
          controller: PageController(initialPage: inicio),
          children: [
            for (final f in fotos)
              InteractiveViewer(child: Center(child: Image.network(f.url))),
          ],
        ),
      ),
    ));
  }

  Widget _foto(BuildContext context, int i, {double? alto}) => GestureDetector(
        onTap: () => _ver(context, i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            fotos[i].url,
            height: alto,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: alto ?? 120,
              color: Colors.black12,
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (fotos.length == 1) return _foto(context, 0, alto: 260);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [for (var i = 0; i < fotos.length; i++) _foto(context, i)],
    );
  }
}
