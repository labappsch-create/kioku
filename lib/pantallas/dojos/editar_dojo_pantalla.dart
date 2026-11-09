import 'package:flutter/material.dart';

import '../../datos/lugares.dart';
import '../../datos/organizaciones.dart';
import '../../modelos/dojo.dart';
import '../../modelos/perfil.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/fotos_servicio.dart';
import '../../servicios/perfiles_servicio.dart';

/// Pantalla 1: crear o editar un dojo (solo entrenadores).
class EditarDojoPantalla extends StatefulWidget {
  const EditarDojoPantalla({
    super.key,
    required this.perfilSensei,
    required this.uid,
    this.dojoId,
    this.dojo,
  });

  final Perfil perfilSensei;
  final String uid;

  /// Null al crear uno nuevo.
  final String? dojoId;
  final Dojo? dojo;

  @override
  State<EditarDojoPantalla> createState() => _EditarDojoPantallaState();
}

class _EditarDojoPantallaState extends State<EditarDojoPantalla> {
  final _form = GlobalKey<FormState>();
  final _servicio = DojosServicio();

  late final TextEditingController _nombre;
  late final TextEditingController _orgOtra;
  late final TextEditingController _ciudad;
  late final TextEditingController _direccion;
  late final TextEditingController _telefono;
  late final TextEditingController _correo;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _descripcion;

  String? _organizacionId;
  String? _pais;
  String? _region;
  late List<Clase> _horarios;
  bool _mDireccion = true;
  bool _mHorarios = true;
  bool _mTelefono = true;
  bool _mCorreo = true;
  bool _mRedes = true;
  bool _mDescripcion = true;
  bool _mMiembros = true;

  bool _guardando = false;
  String? _error;

  // Logo (opcional).
  FotoElegida? _logoNuevo;
  bool _quitarLogo = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dojo;
    _nombre = TextEditingController(text: d?.nombre ?? '');
    _orgOtra = TextEditingController(text: d?.organizacionOtra ?? '');
    _ciudad = TextEditingController(text: d?.ciudad ?? '');
    _direccion = TextEditingController(text: d?.direccion ?? '');
    _telefono = TextEditingController(text: d?.telefono ?? '');
    _correo = TextEditingController(text: d?.correo ?? '');
    _instagram = TextEditingController(text: d?.instagram ?? '');
    _facebook = TextEditingController(text: d?.facebook ?? '');
    _descripcion = TextEditingController(text: d?.descripcion ?? '');
    _horarios = [...?d?.horarios];
    if (d != null) {
      _organizacionId =
          organizaciones.any((o) => o.id == d.organizacionId) ? d.organizacionId : null;
      _pais = paisPorNombre(d.pais)?.nombre;
      if (_pais != null && paisPorNombre(_pais)!.regiones.contains(d.region)) {
        _region = d.region;
      }
      _mDireccion = d.mostrarDireccion;
      _mHorarios = d.mostrarHorarios;
      _mTelefono = d.mostrarTelefono;
      _mCorreo = d.mostrarCorreo;
      _mRedes = d.mostrarRedes;
      _mDescripcion = d.mostrarDescripcion;
      _mMiembros = d.mostrarMiembros;
    } else {
      // Al crear, se propone el mismo lugar del sensei.
      _pais = paisPorNombre(widget.perfilSensei.pais)?.nombre;
      if (_pais != null &&
          paisPorNombre(_pais)!.regiones.contains(widget.perfilSensei.region)) {
        _region = widget.perfilSensei.region;
      }
      _ciudad.text = widget.perfilSensei.ciudad;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nombre, _orgOtra, _ciudad, _direccion, _telefono, _correo, _instagram,
      _facebook, _descripcion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obligatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;

  String? _texto(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _editarClase({int? indice}) async {
    final clase = await showDialog<Clase>(
      context: context,
      builder: (_) =>
          _DialogoClase(inicial: indice == null ? null : _horarios[indice]),
    );
    if (clase == null) return;
    setState(() {
      if (indice == null) {
        _horarios.add(clase);
      } else {
        _horarios[indice] = clase;
      }
      _horarios.sort(Clase.comparar);
    });
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    final valido = _form.currentState!.validate();
    if (_horarios.isEmpty) {
      setState(() => _error = 'Agrega al menos una clase al horario.');
      return;
    }
    if (!valido) {
      setState(() => _error = 'Revisa los datos marcados en rojo.');
      return;
    }

    final dojo = Dojo(
      senseiUid: widget.uid,
      senseiNombre: widget.perfilSensei.nombrePublico(DateTime.now()),
      nombre: _nombre.text.trim(),
      organizacionId: _organizacionId!,
      organizacionOtra:
          _organizacionId == idOrganizacionOtra ? _orgOtra.text.trim() : null,
      pais: _pais!,
      region: _region!,
      ciudad: _ciudad.text.trim(),
      direccion: _direccion.text.trim(),
      horarios: _horarios,
      telefono: _telefono.text.trim(),
      correo: _correo.text.trim(),
      instagram: _texto(_instagram),
      facebook: _texto(_facebook),
      descripcion: _descripcion.text.trim(),
      mostrarDireccion: _mDireccion,
      mostrarHorarios: _mHorarios,
      mostrarTelefono: _mTelefono,
      mostrarCorreo: _mCorreo,
      mostrarRedes: _mRedes,
      mostrarDescripcion: _mDescripcion,
      mostrarMiembros: _mMiembros,
      logoUrl: _quitarLogo ? null : widget.dojo?.logoUrl,
      logoRuta: _quitarLogo ? null : widget.dojo?.logoRuta,
    );

    setState(() => _guardando = true);
    try {
      final fotos = FotosServicio();
      String id;
      if (widget.dojoId == null) {
        id = await _servicio.crear(dojo);
        await _unirseComoSensei(id, dojo.nombre);
      } else {
        id = widget.dojoId!;
        await _servicio.actualizar(id, dojo);
      }
      final rutaVieja = widget.dojo?.logoRuta;
      if (_logoNuevo != null) {
        final ruta = 'dojos/$id/logo_${DateTime.now().millisecondsSinceEpoch}.${_logoNuevo!.extension}';
        final url = await fotos.subir(ruta, _logoNuevo!);
        await _servicio.actualizar(id, dojo.conLogo(url, ruta));
        if (rutaVieja != null) await fotos.borrar(rutaVieja);
      } else if (_quitarLogo && rutaVieja != null) {
        await fotos.borrar(rutaVieja);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Dojo guardado')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// El sensei pasa a ser miembro confirmado de su dojo nuevo. Si ya tenía
  /// otro dojo, se le pregunta antes.
  Future<void> _unirseComoSensei(String dojoId, String nombreDojo) async {
    final perfiles = PerfilesServicio();
    final perfil = await perfiles.leerMiPerfil(widget.uid);
    if (perfil == null || !mounted) return;
    final tieneDojo = perfil.dojoId != null || perfil.dojo.trim().isNotEmpty;
    if (tieneDojo) {
      final si = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Pasar a tu nuevo dojo?'),
          content: Text(
              '¿Quieres pasar a ser miembro de "$nombreDojo"? '
              'Saldrás de "${perfil.dojo}".\n\n'
              'Puedes cambiarlo después en Editar perfil.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No, seguir donde estoy')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, pasarme')),
          ],
        ),
      );
      if (si != true) return;
    }
    await perfiles.guardar(
      widget.uid,
      perfil.conDojo(dojoId, nombreDojo, null),
      anterior: perfil,
    );
    perfilCambiado.value++;
  }

  @override
  Widget build(BuildContext context) {
    final pais = paisPorNombre(_pais);
    final textos = Theme.of(context).textTheme;
    const espacio = SizedBox(height: 12);
    const borde = OutlineInputBorder();

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.dojoId == null ? 'Crear dojo' : 'Editar dojo')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SeccionLogo(
                urlActual: _quitarLogo ? null : widget.dojo?.logoUrl,
                nuevo: _logoNuevo,
                alElegir: () async {
                  final f = await FotosServicio().elegirUna(lado: 600);
                  if (f != null) {
                    setState(() {
                      _logoNuevo = f;
                      _quitarLogo = false;
                    });
                  }
                },
                alQuitar: () => setState(() {
                  _logoNuevo = null;
                  _quitarLogo = true;
                }),
              ),
              const SizedBox(height: 16),
              Text('Datos obligatorios', style: textos.titleMedium),
              espacio,
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Nombre del dojo', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              DropdownButtonFormField<String>(
                initialValue: _organizacionId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Organización', border: borde),
                items: [
                  for (final o in organizaciones)
                    DropdownMenuItem(
                        value: o.id,
                        child: Text(o.nombre, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _organizacionId = v),
                validator: (v) => v == null ? 'Elige la organización' : null,
              ),
              if (_organizacionId == idOrganizacionOtra) ...[
                espacio,
                TextFormField(
                  controller: _orgOtra,
                  decoration: const InputDecoration(
                      labelText: 'Nombre de la organización', border: borde),
                  validator: _obligatorio,
                ),
              ],
              espacio,
              DropdownButtonFormField<String>(
                initialValue: _pais,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'País', border: borde),
                items: [
                  for (final p in paises)
                    DropdownMenuItem(value: p.nombre, child: Text(p.nombre)),
                ],
                onChanged: (v) => setState(() {
                  _pais = v;
                  _region = null;
                }),
                validator: (v) => v == null ? 'Elige el país' : null,
              ),
              espacio,
              DropdownButtonFormField<String>(
                key: ValueKey('dojo-region-$_pais'),
                initialValue: _region,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: pais?.tipoRegion ?? 'Región',
                  helperText: pais == null ? 'Primero elige el país' : null,
                  border: borde,
                ),
                items: [
                  for (final r in pais?.regiones ?? const <String>[])
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged:
                    pais == null ? null : (v) => setState(() => _region = v),
                validator: (v) => v == null ? 'Obligatorio' : null,
              ),
              espacio,
              TextFormField(
                controller: _ciudad,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Ciudad', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              TextFormField(
                controller: _direccion,
                decoration:
                    const InputDecoration(labelText: 'Dirección', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Teléfono o WhatsApp', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Correo de contacto', border: borde),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Escribe un correo válido'
                    : null,
              ),
              espacio,
              TextFormField(
                controller: _descripcion,
                maxLines: 4,
                maxLength: 800,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Descripción del dojo', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              Text('Horarios de clases', style: textos.titleSmall),
              const SizedBox(height: 4),
              if (_horarios.isEmpty)
                const Text('Aún no hay clases. Agrega al menos una.'),
              for (var i = 0; i < _horarios.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_horarios[i].texto),
                  onTap: () => _editarClase(indice: i),
                  trailing: IconButton(
                    tooltip: 'Borrar clase',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _horarios.removeAt(i)),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar clase'),
                  onPressed: () => _editarClase(),
                ),
              ),
              const SizedBox(height: 24),
              Text('Datos opcionales', style: textos.titleMedium),
              espacio,
              TextFormField(
                controller: _instagram,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Instagram',
                    hintText: '@midojo',
                    border: borde),
              ),
              espacio,
              TextFormField(
                controller: _facebook,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Facebook',
                    hintText: 'Nombre o enlace de la página',
                    border: borde),
              ),
              espacio,
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('¿Qué quieres mostrar?',
                            style: textos.titleSmall),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'El nombre, la organización, el lugar y el sensei '
                          'siempre se muestran. Esto lo eliges tú:',
                          style: textos.bodySmall,
                        ),
                      ),
                      SwitchListTile(
                          title: const Text('Dirección'),
                          value: _mDireccion,
                          onChanged: (v) => setState(() => _mDireccion = v)),
                      SwitchListTile(
                          title: const Text('Horarios'),
                          value: _mHorarios,
                          onChanged: (v) => setState(() => _mHorarios = v)),
                      SwitchListTile(
                          title: const Text('Teléfono o WhatsApp'),
                          value: _mTelefono,
                          onChanged: (v) => setState(() => _mTelefono = v)),
                      SwitchListTile(
                          title: const Text('Correo'),
                          value: _mCorreo,
                          onChanged: (v) => setState(() => _mCorreo = v)),
                      SwitchListTile(
                          title: const Text('Redes sociales'),
                          value: _mRedes,
                          onChanged: (v) => setState(() => _mRedes = v)),
                      SwitchListTile(
                          title: const Text('Descripción'),
                          value: _mDescripcion,
                          onChanged: (v) => setState(() => _mDescripcion = v)),
                      SwitchListTile(
                          title: const Text('Lista de miembros'),
                          value: _mMiembros,
                          onChanged: (v) => setState(() => _mMiembros = v)),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar dojo'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo del dojo (opcional).
class _SeccionLogo extends StatelessWidget {
  const _SeccionLogo({
    required this.urlActual,
    required this.nuevo,
    required this.alElegir,
    required this.alQuitar,
  });

  final String? urlActual;
  final FotoElegida? nuevo;
  final VoidCallback alElegir;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? imagen = nuevo != null
        ? MemoryImage(nuevo!.bytes)
        : (urlActual != null ? NetworkImage(urlActual!) : null);
    return Row(children: [
      CircleAvatar(
        radius: 36,
        foregroundImage: imagen,
        child: const Icon(Icons.sports_martial_arts, size: 32),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.image),
            label: Text(imagen == null ? 'Agregar logo' : 'Cambiar logo'),
            onPressed: alElegir,
          ),
          if (imagen != null)
            TextButton(onPressed: alQuitar, child: const Text('Quitar')),
        ]),
      ),
    ]);
  }
}

/// Ventana para agregar o cambiar una clase del horario.
class _DialogoClase extends StatefulWidget {
  const _DialogoClase({this.inicial});

  final Clase? inicial;

  @override
  State<_DialogoClase> createState() => _DialogoClaseState();
}

class _DialogoClaseState extends State<_DialogoClase> {
  late int _dia;
  TimeOfDay? _inicio;
  TimeOfDay? _fin;
  String? _grupo;
  late final TextEditingController _grupoEscrito;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.inicial;
    _dia = c?.dia ?? 0;
    _inicio = c == null ? null : _leerHora(c.inicio);
    _fin = c == null ? null : _leerHora(c.fin);
    _grupo = c?.grupo;
    _grupoEscrito = TextEditingController(text: c?.grupoEscrito ?? '');
  }

  @override
  void dispose() {
    _grupoEscrito.dispose();
    super.dispose();
  }

  static TimeOfDay? _leerHora(String texto) {
    final partes = texto.split(':');
    if (partes.length != 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _hora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirHora(bool esInicio) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: (esInicio ? _inicio : _fin) ??
          (esInicio
              ? const TimeOfDay(hour: 19, minute: 0)
              : const TimeOfDay(hour: 20, minute: 30)),
      helpText: esInicio ? 'Hora de inicio' : 'Hora de término',
    );
    if (elegida == null) return;
    setState(() => esInicio ? _inicio = elegida : _fin = elegida);
  }

  void _aceptar() {
    if (_inicio == null || _fin == null) {
      setState(() => _error = 'Elige la hora de inicio y la de término.');
      return;
    }
    if (_hora(_fin!).compareTo(_hora(_inicio!)) <= 0) {
      setState(() => _error = 'La hora de término debe ser después del inicio.');
      return;
    }
    if (_grupo == null) {
      setState(() => _error = 'Elige el grupo.');
      return;
    }
    if (_grupo == grupoOtro && _grupoEscrito.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre del grupo.');
      return;
    }
    Navigator.of(context).pop(Clase(
      dia: _dia,
      inicio: _hora(_inicio!),
      fin: _hora(_fin!),
      grupo: _grupo!,
      grupoEscrito: _grupo == grupoOtro ? _grupoEscrito.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    const borde = OutlineInputBorder();
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Agregar clase' : 'Cambiar clase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _dia,
              decoration: const InputDecoration(labelText: 'Día', border: borde),
              items: [
                for (var i = 0; i < diasSemana.length; i++)
                  DropdownMenuItem(value: i, child: Text(diasSemana[i])),
              ],
              onChanged: (v) => setState(() => _dia = v ?? 0),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _elegirHora(true),
                  child: Text(_inicio == null ? 'Inicio' : _hora(_inicio!)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('a'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _elegirHora(false),
                  child: Text(_fin == null ? 'Término' : _hora(_fin!)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _grupo,
              decoration: const InputDecoration(labelText: 'Grupo', border: borde),
              items: [
                for (final g in gruposClase)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _grupo = v),
            ),
            if (_grupo == grupoOtro) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _grupoEscrito,
                decoration: const InputDecoration(
                    labelText: 'Nombre del grupo',
                    hintText: 'Ej.: Infantil 6 a 10 años',
                    border: borde),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _aceptar, child: const Text('Listo')),
      ],
    );
  }
}
