import 'package:flutter/material.dart';

import '../modelos/competencia.dart' show nombreNivel;
import '../modelos/publicacion.dart';
import '../modelos/reaccion.dart';
import '../servicios/errores.dart';
import '../servicios/sesion.dart';
import '../servicios/social_servicio.dart';
import '../tema.dart';
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

    final contenido = Material(
      color: Colors.white,
      child: InkWell(
        onTap: enDetalle
            ? null
            : () => Navegacion.abrirPublicacion?.call(context, p, puedeModerar),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 0, 0),
              child: Row(children: [
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
                      Text(p.autorNombre,
                          style: textos.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Row(children: [
                        Text(
                          '${haceCuanto(p.creado)}${p.editado ? ' · editada' : ''} · ',
                          style: textos.bodySmall,
                        ),
                        Icon(
                          p.visibilidad == visibleTodos
                              ? Icons.public
                              : (p.visibilidad == visibleMiembros
                                  ? Icons.lock
                                  : Icons.group),
                          size: 14,
                          color: textos.bodySmall?.color,
                        ),
                      ]),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
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
            ),
            if (p.texto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(p.texto, style: textos.bodyLarge),
              ),
            if (p.fotos.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Fotos(fotos: p.fotos),
            ],
            if (p.torneo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Material(
                  color: grisSeparador,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events, color: rojoKioku),
                    title: Text(p.torneo!.nombre),
                    subtitle: Text('${nombreNivel(p.torneo!.nivel)} · '
                        '${p.torneo!.fechas}\n${p.torneo!.lugar}'),
                    isThreeLine: true,
                    onTap: () =>
                        Navegacion.abrirCompetencia?.call(context, p.torneo!.id),
                  ),
                ),
              ),
            _Acciones(publicacion: p, enDetalle: enDetalle, puedeModerar: puedeModerar),
          ],
        ),
      ),
    );

    // Franja gris de separación (no en la pantalla de la publicación).
    if (enDetalle) return contenido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [contenido, const SizedBox(height: 8, child: ColoredBox(color: grisSeparador))],
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

  Future<void> _reaccionar(BuildContext context, String? tipo) async {
    final mensajes = ScaffoldMessenger.of(context);
    try {
      await SocialServicio().reaccionar(publicacion.ref, Sesion.uid ?? '', tipo);
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  /// Fila con las 8 reacciones, sobre el botón (como en Facebook).
  Future<void> _elegir(BuildContext context, String? actual) async {
    final caja = context.findRenderObject() as RenderBox?;
    final arriba = caja == null ? 300.0 : caja.localToGlobal(Offset.zero).dy;
    final elegida = await showDialog<String>(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => Stack(children: [
        Positioned(
          left: 8,
          right: 8,
          top: (arriba - 64).clamp(8.0, double.infinity),
          child: Center(
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(32),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final r in reacciones)
                    Tooltip(
                      message: r.nombre,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(ctx).pop(r.id),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: r.id == actual
                              ? BoxDecoration(
                                  color: grisSeparador,
                                  borderRadius: BorderRadius.circular(24))
                              : null,
                          child: Text(r.emoji, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
    if (elegida != null && context.mounted) await _reaccionar(context, elegida);
  }

  @override
  Widget build(BuildContext context) {
    final yo = Sesion.uid ?? '';
    final servicio = SocialServicio();
    final textos = Theme.of(context).textTheme;
    return StreamBuilder<Map<String, String>>(
      stream: servicio.reacciones(publicacion.ref),
      builder: (context, snap) {
        final todas = snap.data ?? const <String, String>{};
        final mia = todas[yo];
        final miReaccion = mia == null ? null : reaccionPorId(mia);

        // Las 3 reacciones más usadas y el total.
        final conteo = <String, int>{};
        for (final t in todas.values) {
          conteo[t] = (conteo[t] ?? 0) + 1;
        }
        final top = conteo.keys.toList()
          ..sort((a, b) => conteo[b]!.compareTo(conteo[a]!));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (todas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  '${top.take(3).map((t) => reaccionPorId(t).emoji).join()}  ${todas.length}',
                  style: textos.bodySmall?.copyWith(fontSize: 14),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 12),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    // Toque: pone 👊 Oss o quita la reacción. Mantener: elegir.
                    onTap: () =>
                        _reaccionar(context, mia == null ? reaccionPrincipal : null),
                    onLongPress: () => _elegir(context, mia),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(miReaccion?.emoji ?? '👊',
                            style: TextStyle(
                                fontSize: 18,
                                color: miReaccion == null ? Colors.black54 : null)),
                        const SizedBox(width: 6),
                        Text(
                          miReaccion?.nombre ?? 'Oss',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: miReaccion == null ? Colors.black54 : rojoKioku,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                if (!enDetalle)
                  Expanded(
                    child: FutureBuilder<int>(
                      future: servicio.cuantosComentarios(publicacion.ref),
                      builder: (context, c) => InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navegacion.abrirPublicacion
                            ?.call(context, publicacion, puedeModerar),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.mode_comment_outlined,
                                size: 18, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              (c.data ?? 0) == 0 ? 'Comentar' : 'Comentar (${c.data})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: Colors.black54),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        );
      },
    );
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
      );

  @override
  Widget build(BuildContext context) {
    if (fotos.length == 1) return _foto(context, 0, alto: 320);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: [for (var i = 0; i < fotos.length; i++) _foto(context, i)],
    );
  }
}
