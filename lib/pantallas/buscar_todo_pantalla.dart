import 'dart:async';

import 'package:flutter/material.dart';

import '../modelos/competencia.dart';
import '../modelos/dojo.dart';
import '../modelos/perfil.dart';
import '../servicios/competencias_servicio.dart';
import '../servicios/dojos_servicio.dart';
import '../servicios/errores.dart';
import '../servicios/perfiles_servicio.dart';
import '../servicios/sesion.dart';
import '../widgets/avatar.dart';
import 'competencias/ver_competencia_pantalla.dart';
import 'dojos/ver_dojo_pantalla.dart';
import 'ver_perfil_pantalla.dart';

/// Resultados de una búsqueda.
class _Resultados {
  const _Resultados(this.personas, this.dojos, this.torneos);

  final List<PerfilPublico> personas;
  final List<DojoPublico> dojos;
  final List<Competencia> torneos;

  bool get vacio => personas.isEmpty && dojos.isEmpty && torneos.isEmpty;
}

/// Busca personas, dojos y torneos a la vez.
class BuscarTodoPantalla extends StatefulWidget {
  const BuscarTodoPantalla({super.key});

  @override
  State<BuscarTodoPantalla> createState() => _BuscarTodoPantallaState();
}

class _BuscarTodoPantallaState extends State<BuscarTodoPantalla> {
  final _texto = TextEditingController();
  Timer? _espera;
  Future<_Resultados>? _resultados;
  String _buscado = '';

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  Future<_Resultados> _buscar(String texto) async {
    final q = normalizarParaBuscar(texto);
    final bloqueados = Sesion.relaciones?.bloqueados ?? const <String>{};

    Future<List<T>> seguro<T>(Future<List<T>> f) async {
      try {
        return await f;
      } catch (_) {
        return <T>[];
      }
    }

    final r = await Future.wait([
      seguro(PerfilesServicio().buscar(texto)),
      seguro(DojosServicio().buscar(texto: texto)),
      seguro(CompetenciasServicio().buscar()),
    ]);
    final personas = [
      for (final p in r[0] as List<PerfilPublico>)
        if (!bloqueados.contains(p.id)) p,
    ];
    final dojos = r[1] as List<DojoPublico>;
    final torneos = [
      for (final c in r[2] as List<Competencia>)
        if (normalizarParaBuscar(c.nombre).contains(q)) c,
    ]..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
    return _Resultados(
      personas.take(15).toList(),
      dojos.take(15).toList(),
      torneos.take(15).toList(),
    );
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () => _ejecutar(texto));
  }

  void _ejecutar(String texto) {
    final t = texto.trim();
    if (t == _buscado) return;
    setState(() {
      _buscado = t;
      _resultados = t.isEmpty ? null : _buscar(t);
    });
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
      );

  @override
  Widget build(BuildContext context) {
    final uid = Sesion.uid ?? '';
    final perfil = Sesion.perfil;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _texto,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Buscar personas, dojos o torneos',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (t) {
            setState(() {});
            _alEscribir(t);
          },
          onSubmitted: _ejecutar,
        ),
        actions: [
          if (_texto.text.isNotEmpty)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.close),
              onPressed: () {
                _texto.clear();
                _ejecutar('');
              },
            ),
        ],
      ),
      body: _resultados == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Escribe un nombre para buscar.', textAlign: TextAlign.center),
              ),
            )
          : FutureBuilder<_Resultados>(
              future: _resultados,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text(mensajeDeError(snap.error!)));
                }
                final r = snap.data!;
                if (r.vacio) {
                  return const Center(child: Text('No se encontró nada.'));
                }
                final ahora = DateTime.now();
                return ListView(children: [
                  if (r.personas.isNotEmpty) ...[
                    _titulo('Personas'),
                    for (final p in r.personas)
                      ListTile(
                        leading: Avatar(uid: p.id, nombre: p.nombre),
                        title: Text(p.nombre),
                        subtitle: Text(p.dojo.isEmpty ? 'Sin dojo' : p.dojo),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VerPerfilPantalla(uid: p.id))),
                      ),
                  ],
                  if (r.dojos.isNotEmpty) ...[
                    _titulo('Dojos'),
                    for (final d in r.dojos)
                      ListTile(
                        leading: Avatar(
                            uid: '', nombre: d.nombre, urlFija: d.logoUrl),
                        title: Text(d.nombre),
                        subtitle: Text('${d.organizacion}\n${d.lugar}'),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VerDojoPantalla(dojoId: d.id))),
                      ),
                  ],
                  if (r.torneos.isNotEmpty) ...[
                    _titulo('Torneos'),
                    for (final c in r.torneos)
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.emoji_events)),
                        title: Text(c.nombre),
                        subtitle: Text('${nombreNivel(c.nivel)} · ${c.textoFechas}\n'
                            '${nombreEstado(c.estado(ahora))}'),
                        isThreeLine: true,
                        onTap: perfil == null
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => VerCompetenciaPantalla(
                                    competenciaId: c.id, uid: uid, perfil: perfil))),
                      ),
                  ],
                  const SizedBox(height: 24),
                ]);
              },
            ),
    );
  }
}
