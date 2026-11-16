import 'package:flutter/material.dart';

import '../modelos/competencia.dart';
import '../modelos/perfil.dart';
import '../servicios/cuenta_servicio.dart';
import '../servicios/errores.dart';
import '../widgets/campo_clave.dart';
import 'competencias/ver_competencia_pantalla.dart';
import 'dojos/ver_dojo_pantalla.dart';

/// Borrar mi cuenta (ver docs/decisiones.md).
class BorrarCuentaPantalla extends StatefulWidget {
  const BorrarCuentaPantalla({super.key, required this.uid, required this.perfil});

  final String uid;
  final Perfil perfil;

  @override
  State<BorrarCuentaPantalla> createState() => _BorrarCuentaPantallaState();
}

class _BorrarCuentaPantallaState extends State<BorrarCuentaPantalla> {
  final _servicio = CuentaServicio();
  final _clave = TextEditingController();
  late Future<Impedimentos> _revision;
  bool _borrando = false;
  String _progreso = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _revision = _servicio.revisar(widget.uid);
  }

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  void _abrir(Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla))
          .then((_) => setState(() => _revision = _servicio.revisar(widget.uid)));

  Future<void> _borrar() async {
    if (_clave.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña.');
      return;
    }
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar tu cuenta para siempre?'),
        content: const Text('Esto no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, borrar'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    final navegador = Navigator.of(context);
    setState(() {
      _borrando = true;
      _error = null;
    });
    try {
      await _servicio.borrar(_clave.text, (texto) {
        if (mounted) setState(() => _progreso = texto);
      });
      // La app vuelve sola a la pantalla de entrada.
      navegador.popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _borrando = false;
          _error = e is StateError ? e.message : mensajeDeError(e);
        });
      }
    }
  }

  Widget _impedimentos(Impedimentos imp) {
    final textos = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Antes de borrar tu cuenta', style: textos.titleMedium),
        const SizedBox(height: 8),
        if (imp.dojos.isNotEmpty) ...[
          const Text(
              'Eres sensei de estos dojos. Traspasa cada uno a otro entrenador del dojo: '
              'entra al dojo y toca "Traspasar dojo". Cuando acepten, vuelve aquí.'),
          for (final d in imp.dojos)
            ListTile(
              leading: const Icon(Icons.sports_martial_arts),
              title: Text(d.nombre),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrir(VerDojoPantalla(dojoId: d.id)),
            ),
          const SizedBox(height: 16),
        ],
        if (imp.torneos.isNotEmpty) ...[
          const Text(
              'Organizas estos torneos que aún no terminan. Cancélalos (escribiendo el '
              'motivo para los inscritos) o espera a que terminen.'),
          for (final c in imp.torneos)
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: Text(c.nombre),
              subtitle: Text('${c.textoFechas} · ${nombreEstado(c.estado(DateTime.now()))}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrir(VerCompetenciaPantalla(
                  competenciaId: c.id, uid: widget.uid, perfil: widget.perfil)),
            ),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Volver a revisar'),
          onPressed: () => setState(() => _revision = _servicio.revisar(widget.uid)),
        ),
      ],
    );
  }

  Widget _confirmar() {
    final textos = Theme.of(context).textTheme;
    const espacio = SizedBox(height: 8);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Se borrará para siempre:', style: textos.titleMedium),
        espacio,
        const Text('• Tu perfil, tu foto y tu portada.\n'
            '• Tus publicaciones, comentarios y reacciones.\n'
            '• Tus amistades, solicitudes y avisos.\n'
            '• Tu lugar en tu dojo y tus inscripciones.'),
        const SizedBox(height: 16),
        Text('Se mantiene, sin tu nombre:', style: textos.titleMedium),
        espacio,
        const Text('• Tus resultados en torneos terminados aparecerán como '
            '"Atleta eliminado", para que los podios y rankings no cambien.\n'
            '• Los torneos terminados que organizaste aparecerán con '
            '"Organizador eliminado".'),
        const SizedBox(height: 24),
        CampoClave(controller: _clave, etiqueta: 'Escribe tu contraseña para confirmar'),
        if (_error != null) ...[
          espacio,
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        if (_borrando) ...[
          const LinearProgressIndicator(),
          espacio,
          Text(_progreso, textAlign: TextAlign.center),
        ] else
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Borrar mi cuenta para siempre'),
            onPressed: _borrar,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_borrando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Borrar mi cuenta')),
        body: FutureBuilder<Impedimentos>(
          future: _revision,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text(mensajeDeError(snap.error!)));
            }
            final imp = snap.data!;
            return imp.hay && !_borrando ? _impedimentos(imp) : _confirmar();
          },
        ),
      ),
    );
  }
}
