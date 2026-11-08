import 'package:flutter/material.dart';

import '../../datos/lugares.dart';
import '../../datos/organizaciones.dart';
import '../../modelos/dojo.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import 'ver_dojo_pantalla.dart';

/// Pantalla 6: buscar dojos por nombre, con filtros.
///
/// Si [seleccionar] es true, al tocar un dojo se devuelve a quien la abrió
/// (se usa en "Editar perfil" para elegir mi dojo).
class BuscarDojosPantalla extends StatefulWidget {
  const BuscarDojosPantalla({
    super.key,
    this.seleccionar = false,
    this.conAppBar = true,
    this.acciones,
  });

  final bool seleccionar;
  final bool conAppBar;
  final List<Widget>? acciones;

  @override
  State<BuscarDojosPantalla> createState() => _BuscarDojosPantallaState();
}

class _BuscarDojosPantallaState extends State<BuscarDojosPantalla> {
  final _servicio = DojosServicio();
  final _texto = TextEditingController();
  String? _pais;
  String? _region;
  String? _organizacionId;
  bool _verFiltros = false;
  late Future<List<DojoPublico>> _resultados;

  @override
  void initState() {
    super.initState();
    _resultados = _servicio.buscar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _buscar() {
    FocusScope.of(context).unfocus();
    setState(() {
      _resultados = _servicio.buscar(
        texto: _texto.text,
        pais: _pais,
        region: _region,
        organizacionId: _organizacionId,
      );
    });
  }

  int get _filtrosActivos =>
      [_pais, _region, _organizacionId].where((f) => f != null).length;

  @override
  Widget build(BuildContext context) {
    final pais = paisPorNombre(_pais);
    const borde = OutlineInputBorder();

    final cuerpo = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _texto,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _buscar(),
            decoration: InputDecoration(
              labelText: 'Nombre del dojo',
              border: borde,
              suffixIcon:
                  IconButton(icon: const Icon(Icons.search), onPressed: _buscar),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: Icon(_verFiltros ? Icons.expand_less : Icons.tune),
            label: Text(_filtrosActivos == 0
                ? 'Filtros'
                : 'Filtros ($_filtrosActivos)'),
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
                key: ValueKey('filtro-region-$_pais'),
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
                onChanged:
                    pais == null ? null : (v) => setState(() => _region = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _organizacionId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Organización', border: borde),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                  for (final o in organizaciones)
                    DropdownMenuItem<String?>(
                        value: o.id,
                        child: Text(o.nombre, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _organizacionId = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                TextButton(
                  onPressed: () => setState(() {
                    _pais = null;
                    _region = null;
                    _organizacionId = null;
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
          child: FutureBuilder<List<DojoPublico>>(
            future: _resultados,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(mensajeDeError(snap.error!),
                        textAlign: TextAlign.center),
                  ),
                );
              }
              final lista = snap.data ?? const <DojoPublico>[];
              if (lista.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.seleccionar
                          ? 'No se encontró ningún dojo.\nSi tu dojo aún no está en Kioku, vuelve atrás y escribe su nombre.'
                          : 'No se encontró ningún dojo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = lista[i];
                  return ListTile(
                    leading: const Icon(Icons.sports_martial_arts),
                    title: Text(d.nombre),
                    subtitle: Text('${d.organizacion}\n${d.lugar}'),
                    isThreeLine: true,
                    trailing: Icon(widget.seleccionar
                        ? Icons.check_circle_outline
                        : Icons.chevron_right),
                    onTap: () {
                      if (widget.seleccionar) {
                        Navigator.of(context).pop(d);
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VerDojoPantalla(dojoId: d.id)));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (!widget.conAppBar) return cuerpo;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seleccionar ? 'Elige tu dojo' : 'Buscar dojos'),
        actions: widget.acciones,
      ),
      body: cuerpo,
    );
  }
}
