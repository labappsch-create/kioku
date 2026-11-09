import 'package:flutter/material.dart';

import '../../modelos/competencia.dart' show nombreNivel;
import '../../modelos/publicacion.dart';
import '../../servicios/errores.dart';
import '../../servicios/fotos_servicio.dart';
import '../../servicios/sesion.dart';
import '../../servicios/social_servicio.dart';

const int maxFotos = 4;

/// A nombre de qué dojo se publica (solo para el sensei).
class DojoQuePublica {
  const DojoQuePublica(this.id, this.nombre);
  final String id;
  final String nombre;
}

/// Crear o editar una publicación (de una persona o de un dojo).
class CrearPublicacionPantalla extends StatefulWidget {
  const CrearPublicacionPantalla({
    super.key,
    this.editar,
    this.dojo,
    this.torneo,
  });

  /// Si no es null, se edita esta publicación.
  final Publicacion? editar;

  /// Si no es null, se publica a nombre de este dojo.
  final DojoQuePublica? dojo;

  /// Torneo compartido (botón "Compartir en el muro").
  final TorneoCompartido? torneo;

  @override
  State<CrearPublicacionPantalla> createState() => _CrearPublicacionPantallaState();
}

class _CrearPublicacionPantallaState extends State<CrearPublicacionPantalla> {
  final _servicio = SocialServicio();
  final _fotosServicio = FotosServicio();
  late final TextEditingController _texto;
  late String _visibilidad;
  late List<Foto> _conservadas;
  final List<FotoElegida> _nuevas = [];
  bool _guardando = false;
  String? _error;

  bool get _deDojo => widget.dojo != null || (widget.editar?.deDojo ?? false);

  bool get _esMenor =>
      !_deDojo &&
      (widget.editar?.esMenor ??
          (Sesion.perfil?.esMenorDeEdad(DateTime.now()) ?? true));

  TorneoCompartido? get _torneo => widget.editar?.torneo ?? widget.torneo;

  int get _totalFotos => _conservadas.length + _nuevas.length;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    _texto = TextEditingController(text: e?.texto ?? '');
    _conservadas = [...?e?.fotos];
    _visibilidad = e?.visibilidad ?? (_deDojo ? visibleSeguidores : visibleAmigos);
    if (_esMenor) _visibilidad = visibleAmigos;
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _agregarFotos() async {
    final mensajes = ScaffoldMessenger.of(context);
    try {
      final nuevas = await _fotosServicio.elegirVarias(maxFotos - _totalFotos);
      if (nuevas.isNotEmpty) setState(() => _nuevas.addAll(nuevas));
    } catch (_) {
      mensajes.showSnackBar(const SnackBar(content: Text('No se pudieron abrir las fotos.')));
    }
  }

  Future<void> _publicar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty && _totalFotos == 0 && _torneo == null) {
      setState(() => _error = 'Escribe algo o agrega una foto.');
      return;
    }
    final uid = Sesion.uid;
    final perfil = Sesion.perfil;
    if (uid == null || perfil == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final navegador = Navigator.of(context);
      final mensajes = ScaffoldMessenger.of(context);
      if (widget.editar != null) {
        await _servicio.editar(widget.editar!,
            texto: texto,
            visibilidad: _visibilidad,
            conservadas: _conservadas,
            nuevas: _nuevas);
      } else if (widget.dojo != null) {
        await _servicio.publicarDojo(
          dojoId: widget.dojo!.id,
          dojoNombre: widget.dojo!.nombre,
          senseiUid: uid,
          visibilidad: _visibilidad,
          texto: texto,
          fotos: _nuevas,
          torneo: _torneo,
        );
      } else {
        await _servicio.publicarPersona(
          uid: uid,
          perfil: perfil,
          visibilidad: _visibilidad,
          texto: texto,
          fotos: _nuevas,
          torneo: _torneo,
        );
      }
      mensajes.showSnackBar(SnackBar(
          content: Text(widget.editar != null ? 'Publicación editada' : 'Publicado')));
      navegador.pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _miniatura({required Widget imagen, required VoidCallback quitar}) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 90, height: 90, child: imagen),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton.filledTonal(
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              tooltip: 'Quitar',
              icon: const Icon(Icons.close),
              onPressed: quitar,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final opciones = _deDojo
        ? const [visibleSeguidores, visibleMiembros]
        : const [visibleAmigos, visibleTodos];
    final titulo = widget.editar != null
        ? 'Editar publicación'
        : (widget.dojo != null ? 'Publicar como ${widget.dojo!.nombre}' : 'Nueva publicación');

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (Sesion.relaciones?.suspendido ?? false)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Tu cuenta está suspendida: no puedes publicar.'),
              ),
            ),
          TextField(
            controller: _texto,
            maxLines: 6,
            minLines: 3,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: '¿Qué quieres compartir?',
              border: OutlineInputBorder(),
            ),
          ),
          if (_torneo != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.emoji_events),
                title: Text(_torneo!.nombre),
                subtitle: Text('${nombreNivel(_torneo!.nivel)} · ${_torneo!.fechas}\n'
                    '${_torneo!.lugar}'),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _conservadas.length; i++)
              _miniatura(
                imagen: Image.network(_conservadas[i].url, fit: BoxFit.cover),
                quitar: () => setState(() => _conservadas.removeAt(i)),
              ),
            for (var i = 0; i < _nuevas.length; i++)
              _miniatura(
                imagen: Image.memory(_nuevas[i].bytes, fit: BoxFit.cover),
                quitar: () => setState(() => _nuevas.removeAt(i)),
              ),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Agregar fotos ($_totalFotos de $maxFotos)'),
              onPressed: _totalFotos >= maxFotos || _guardando ? null : _agregarFotos,
            ),
          ),
          const SizedBox(height: 16),
          Text('¿Quién puede verla?', style: Theme.of(context).textTheme.titleSmall),
          if (_esMenor)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Como eres menor de 18, tus publicaciones son solo para tus amigos.'),
            )
          else
            RadioGroup<String>(
              groupValue: _visibilidad,
              onChanged: (v) => setState(() => _visibilidad = v ?? _visibilidad),
              child: Column(children: [
                for (final o in opciones)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: o,
                    title: Text(nombreVisibilidad(o)),
                  ),
              ]),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _guardando ? null : _publicar,
            child: _guardando
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.editar != null ? 'Guardar cambios' : 'Publicar'),
          ),
        ],
      ),
    );
  }
}
