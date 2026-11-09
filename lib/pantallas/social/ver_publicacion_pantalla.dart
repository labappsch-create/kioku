import 'package:flutter/material.dart';

import '../../modelos/publicacion.dart';
import '../../servicios/errores.dart';
import '../../servicios/sesion.dart';
import '../../servicios/social_servicio.dart';
import '../../widgets/avatar.dart';
import '../../widgets/denunciar.dart';
import '../../widgets/tarjeta_publicacion.dart';

/// Una publicación con sus comentarios.
class VerPublicacionPantalla extends StatefulWidget {
  const VerPublicacionPantalla({
    super.key,
    required this.publicacion,
    this.puedeModerar = false,
  });

  final Publicacion publicacion;
  final bool puedeModerar;

  @override
  State<VerPublicacionPantalla> createState() => _VerPublicacionPantallaState();
}

class _VerPublicacionPantallaState extends State<VerPublicacionPantalla> {
  final _servicio = SocialServicio();
  final _texto = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _comentar() async {
    final texto = _texto.text.trim();
    final uid = Sesion.uid;
    final perfil = Sesion.perfil;
    if (texto.isEmpty || uid == null || perfil == null) return;
    final mensajes = ScaffoldMessenger.of(context);
    setState(() => _enviando = true);
    try {
      await _servicio.comentar(
          widget.publicacion.ref, uid, perfil.nombrePublico(DateTime.now()), texto);
      _texto.clear();
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.publicacion;
    final yo = Sesion.uid ?? '';
    final bloqueados = Sesion.relaciones?.bloqueados ?? const <String>{};
    // Dueño de la publicación (o sensei del dojo que publicó).
    final esDueno = p.autorUid == yo;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicación')),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<Comentario>>(
            stream: _servicio.comentarios(p.ref),
            builder: (context, snap) {
              final comentarios = [
                for (final c in snap.data ?? const <Comentario>[])
                  if (!bloqueados.contains(c.autorUid)) c,
              ];
              return ListView(children: [
                TarjetaPublicacion(
                  publicacion: p,
                  enDetalle: true,
                  puedeModerar: widget.puedeModerar,
                  alCambiar: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Comentarios', style: Theme.of(context).textTheme.titleSmall),
                ),
                if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(mensajeDeError(snap.error!)),
                  )
                else if (comentarios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aún no hay comentarios.'),
                  ),
                for (final c in comentarios)
                  ListTile(
                    leading: Avatar(uid: c.autorUid, nombre: c.autorNombre, radio: 16),
                    title: Text(c.autorNombre),
                    subtitle: Text('${c.texto}\n${haceCuanto(c.creado)}'),
                    isThreeLine: true,
                    onTap: () => Navegacion.abrirPerfil?.call(context, c.autorUid),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        final mensajes = ScaffoldMessenger.of(context);
                        if (v == 'borrar') {
                          if (!await confirmar(context, '¿Borrar este comentario?',
                              si: 'Borrar')) {
                            return;
                          }
                          try {
                            await _servicio.borrarComentario(c);
                          } catch (e) {
                            mensajes.showSnackBar(
                                SnackBar(content: Text(mensajeDeError(e))));
                          }
                        } else if (v == 'denunciar' && context.mounted) {
                          await denunciar(context,
                              tipo: 'comentario',
                              ruta: c.ref.path,
                              autorUid: c.autorUid,
                              vistaPrevia: c.texto);
                        }
                      },
                      itemBuilder: (_) => [
                        if (c.autorUid == yo ||
                            esDueno ||
                            widget.puedeModerar ||
                            Sesion.esAdmin)
                          const PopupMenuItem(value: 'borrar', child: Text('Borrar')),
                        if (c.autorUid != yo)
                          const PopupMenuItem(value: 'denunciar', child: Text('Denunciar')),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _texto,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un comentario',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Enviar',
                icon: const Icon(Icons.send),
                onPressed: _enviando ? null : _comentar,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
