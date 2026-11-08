import 'package:flutter/material.dart';

import '../../datos/lugares.dart';
import '../../modelos/competencia.dart';
import '../../modelos/perfil.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';
import '../admin/solicitar_organizador_pantalla.dart';
import 'editar_competencia_pantalla.dart';
import 'mis_competencias_pantalla.dart';
import 'mis_inscripciones_pantalla.dart';
import 'ver_competencia_pantalla.dart';

/// Pantalla 3: buscar competencias (pestaña "Competencias").
class CompetenciasPantalla extends StatefulWidget {
  const CompetenciasPantalla({super.key, required this.uid, required this.perfil});

  final String uid;
  final Perfil perfil;

  @override
  State<CompetenciasPantalla> createState() => _CompetenciasPantallaState();
}

class _CompetenciasPantallaState extends State<CompetenciasPantalla> {
  final _servicio = CompetenciasServicio();
  String? _pais;
  String? _region;
  String? _nivel;
  EstadoCompetencia? _estado;
  bool _verFiltros = false;
  late Future<List<Competencia>> _resultados;

  @override
  void initState() {
    super.initState();
    _resultados = _servicio.buscar();
  }

  Future<void> _buscar() async {
    final f = _servicio.buscar(pais: _pais, region: _region, nivel: _nivel);
    setState(() => _resultados = f);
    await f;
  }

  int get _filtrosActivos =>
      [_pais, _region, _nivel, _estado].where((f) => f != null).length;

  List<Competencia> _ordenar(List<Competencia> lista) {
    final ahora = DateTime.now();
    var r = lista;
    if (_estado != null) r = r.where((c) => c.estado(ahora) == _estado).toList();
    final proximas = r
        .where((c) => c.estado(ahora) != EstadoCompetencia.finalizada)
        .toList()
      ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));
    final pasadas = r
        .where((c) => c.estado(ahora) == EstadoCompetencia.finalizada)
        .toList()
      ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
    return [...proximas, ...pasadas];
  }

  void _abrir(Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final pais = paisPorNombre(_pais);
    const borde = OutlineInputBorder();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Competencias'),
        actions: [
          IconButton(
            tooltip: 'Mis inscripciones',
            icon: const Icon(Icons.assignment_ind),
            onPressed: () => _abrir(
                MisInscripcionesPantalla(uid: widget.uid, perfil: widget.perfil)),
          ),
          PopupMenuButton<String>(
            tooltip: 'Organizar',
            icon: const Icon(Icons.emoji_events),
            onSelected: (v) {
              switch (v) {
                case 'crear':
                  _abrir(EditarCompetenciaPantalla(
                      uid: widget.uid, perfil: widget.perfil));
                case 'mias':
                  _abrir(MisCompetenciasPantalla(
                      uid: widget.uid, perfil: widget.perfil));
                case 'organizador':
                  _abrir(SolicitarOrganizadorPantalla(
                      uid: widget.uid, perfil: widget.perfil));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'crear', child: Text('Crear competencia')),
              PopupMenuItem(value: 'mias', child: Text('Mis competencias')),
              PopupMenuItem(value: 'organizador', child: Text('Ser organizador')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: Icon(_verFiltros ? Icons.expand_less : Icons.tune),
            label: Text(
                _filtrosActivos == 0 ? 'Filtros' : 'Filtros ($_filtrosActivos)'),
            onPressed: () => setState(() => _verFiltros = !_verFiltros),
          ),
        ),
        if (_verFiltros)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              DropdownButtonFormField<String?>(
                initialValue: _pais,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'País', border: borde),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  for (final p in paises)
                    DropdownMenuItem<String?>(value: p.nombre, child: Text(p.nombre)),
                ],
                onChanged: (v) => setState(() {
                  _pais = v;
                  _region = null;
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey('comp-region-$_pais'),
                initialValue: _region,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: pais?.tipoRegion ?? 'Región',
                  helperText: pais == null ? 'Primero elige el país' : null,
                  border: borde,
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                  for (final r in pais?.regiones ?? const <String>[])
                    DropdownMenuItem<String?>(value: r, child: Text(r)),
                ],
                onChanged: pais == null ? null : (v) => setState(() => _region = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _nivel,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Nivel', border: borde),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Todos')),
                      for (final n in niveles)
                        DropdownMenuItem<String?>(
                            value: n, child: Text(nombreNivel(n))),
                    ],
                    onChanged: (v) => setState(() => _nivel = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<EstadoCompetencia?>(
                    initialValue: _estado,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Estado', border: borde),
                    items: [
                      const DropdownMenuItem<EstadoCompetencia?>(
                          value: null, child: Text('Todos')),
                      for (final e in EstadoCompetencia.values)
                        DropdownMenuItem<EstadoCompetencia?>(
                            value: e,
                            child: Text(nombreEstado(e),
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _estado = v),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                TextButton(
                  onPressed: () => setState(() {
                    _pais = null;
                    _region = null;
                    _nivel = null;
                    _estado = null;
                  }),
                  child: const Text('Quitar filtros'),
                ),
                const Spacer(),
                FilledButton(onPressed: _buscar, child: const Text('Buscar')),
              ]),
            ]),
          ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _buscar,
            child: FutureBuilder<List<Competencia>>(
              future: _resultados,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(mensajeDeError(snap.error!),
                          textAlign: TextAlign.center),
                    ),
                  ]);
                }
                final lista = _ordenar(snap.data ?? const []);
                if (lista.isEmpty) {
                  return ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No se encontraron competencias.',
                          textAlign: TextAlign.center),
                    ),
                  ]);
                }
                final ahora = DateTime.now();
                return ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return ListTile(
                      leading: const Icon(Icons.emoji_events),
                      title: Text(c.nombre),
                      subtitle: Text('${nombreNivel(c.nivel)} · ${c.textoFechas}\n'
                          '${c.lugar}\n${nombreEstado(c.estado(ahora))}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(VerCompetenciaPantalla(
                          competenciaId: c.id,
                          uid: widget.uid,
                          perfil: widget.perfil)),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
