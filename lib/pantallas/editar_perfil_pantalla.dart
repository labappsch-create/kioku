import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../datos/grados.dart';
import '../datos/lugares.dart';
import '../modelos/dojo.dart';
import '../modelos/perfil.dart';
import '../servicios/errores.dart';
import '../servicios/perfiles_servicio.dart';
import '../widgets/tarjeta_perfil.dart';
import 'dojos/buscar_dojos_pantalla.dart';

/// Pantalla 3: llenar o editar mi perfil.
class EditarPerfilPantalla extends StatefulWidget {
  const EditarPerfilPantalla({
    super.key,
    this.perfil,
    this.alGuardar,
  });

  /// Perfil actual, o null si es la primera vez.
  final Perfil? perfil;

  /// Se llama después de guardar con éxito.
  final VoidCallback? alGuardar;

  @override
  State<EditarPerfilPantalla> createState() => _EditarPerfilPantallaState();
}

class _EditarPerfilPantallaState extends State<EditarPerfilPantalla> {
  final _form = GlobalKey<FormState>();
  final _servicio = PerfilesServicio();

  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _dojo;
  late final TextEditingController _ciudad;
  late final TextEditingController _peso;
  late final TextEditingController _estatura;
  late final TextEditingController _anos;
  late final TextEditingController _sobreMi;

  String? _gradoId;

  /// Dojo elegido de la lista de Kioku. Null si se escribe a mano.
  String? _dojoId;
  String? _pais;
  String? _region;
  DateTime? _nacimiento;
  Rol? _rol;
  bool _mostrarRol = true;
  bool _mostrarAnos = true;
  bool _mostrarSobreMi = true;
  bool _mostrarHistorial = true;

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.perfil;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _apellido = TextEditingController(text: p?.apellido ?? '');
    _dojo = TextEditingController(text: p?.dojo ?? '');
    _dojoId = p?.dojoId;
    _ciudad = TextEditingController(text: p?.ciudad ?? '');
    _peso = TextEditingController(
        text: p == null ? '' : _textoPeso(p.pesoKg));
    _estatura =
        TextEditingController(text: p == null ? '' : '${p.estaturaCm}');
    _anos = TextEditingController(
        text: p?.anosPractica == null ? '' : '${p!.anosPractica}');
    _sobreMi = TextEditingController(text: p?.sobreMi ?? '');
    if (p != null) {
      _gradoId = gradoPorId(p.gradoId)?.id;
      _pais = paisPorNombre(p.pais)?.nombre;
      if (_pais != null && paisPorNombre(_pais)!.regiones.contains(p.region)) {
        _region = p.region;
      }
      _nacimiento = p.fechaNacimiento;
      _rol = p.rol;
      _mostrarRol = p.mostrarRol;
      _mostrarAnos = p.mostrarAnosPractica;
      _mostrarSobreMi = p.mostrarSobreMi;
      _mostrarHistorial = p.mostrarHistorial;
    }
  }

  static String _textoPeso(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : '$kg';

  @override
  void dispose() {
    for (final c in [
      _nombre, _apellido, _dojo, _ciudad, _peso, _estatura, _anos, _sobreMi,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool? get _esMenor => _nacimiento == null
      ? null
      : calcularEdad(_nacimiento!, DateTime.now()) < 18;

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(hoy.year - 18, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: hoy,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Fecha de nacimiento',
    );
    if (elegida != null) setState(() => _nacimiento = elegida);
  }

  double? _leerNumero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    setState(() => _error = null);
    final valido = _form.currentState!.validate();
    if (_nacimiento == null) {
      setState(() => _error = 'Falta la fecha de nacimiento.');
      return;
    }
    if (!valido) {
      setState(() => _error = 'Revisa los datos marcados en rojo.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final perfil = Perfil(
      nombre: _nombre.text.trim(),
      apellido: _apellido.text.trim(),
      gradoId: _gradoId!,
      dojo: _dojo.text.trim(),
      dojoId: _dojoId,
      dojoEstado: _dojoId == widget.perfil?.dojoId ? widget.perfil?.dojoEstado : null,
      pais: _pais!,
      region: _region!,
      ciudad: _ciudad.text.trim(),
      fechaNacimiento: _nacimiento!,
      pesoKg: _leerNumero(_peso.text)!,
      estaturaCm: _leerNumero(_estatura.text)!.round(),
      rol: _rol,
      anosPractica: _anos.text.trim().isEmpty
          ? null
          : _leerNumero(_anos.text)!.round(),
      sobreMi: _sobreMi.text.trim().isEmpty ? null : _sobreMi.text.trim(),
      mostrarRol: _mostrarRol,
      mostrarAnosPractica: _mostrarAnos,
      mostrarSobreMi: _mostrarSobreMi,
      mostrarHistorial: _mostrarHistorial,
    );

    setState(() => _guardando = true);
    try {
      await _servicio.guardar(uid, perfil, anterior: widget.perfil);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil guardado')));
      widget.alGuardar?.call();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _obligatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;

  String? Function(String?) _numeroEntre(num min, num max, String unidad) =>
      (v) {
        final n = _leerNumero(v ?? '');
        if (n == null) return 'Escribe un número';
        if (n < min || n > max) return 'Debe estar entre $min y $max $unidad';
        return null;
      };

  Future<void> _buscarDojo() async {
    final elegido = await Navigator.of(context).push<DojoPublico>(
      MaterialPageRoute(
          builder: (_) => const BuscarDojosPantalla(seleccionar: true)),
    );
    if (elegido != null) {
      setState(() {
        _dojoId = elegido.id;
        _dojo.text = elegido.nombre;
      });
    }
  }

  Widget _seccionDojo(InputBorder borde) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_dojoId != null) {
      final esElActual = _dojoId == widget.perfil?.dojoId;
      return InputDecorator(
        decoration: InputDecoration(labelText: 'Dojo', border: borde),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_dojo.text, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            if (esElActual && uid != null)
              EstadoDojo(dojoId: _dojoId!, uid: uid)
            else
              const Text('Al guardar, se enviará tu solicitud al dojo.',
                  style: TextStyle(fontSize: 12)),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: _buscarDojo, child: const Text('Cambiar de dojo')),
              TextButton(
                onPressed: () => setState(() {
                  _dojoId = null;
                  _dojo.clear();
                }),
                child: Text(esElActual ? 'Salir de este dojo' : 'Quitar'),
              ),
            ]),
          ],
        ),
      );
    }
    final saliendo = widget.perfil?.dojoId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _dojo,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Dojo',
            helperText: saliendo
                ? 'Al guardar, saldrás de tu dojo anterior. Busca otro o escribe su nombre.'
                : 'Si tu dojo está en Kioku, búscalo para enviarle tu solicitud. '
                    'Si no, escribe su nombre: aparecerá como "Sin confirmar".',
            helperMaxLines: 3,
            border: borde,
          ),
          validator: _obligatorio,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Buscar mi dojo en Kioku'),
          onPressed: _buscarDojo,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pais = paisPorNombre(_pais);
    final textos = Theme.of(context).textTheme;
    const espacio = SizedBox(height: 12);
    const borde = OutlineInputBorder();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.perfil == null ? 'Crea tu perfil' : 'Editar perfil'),
        actions: [
          if (widget.perfil == null)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Datos obligatorios', style: textos.titleMedium),
              espacio,
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Nombre', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              TextFormField(
                controller: _apellido,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Apellido', border: borde),
                validator: _obligatorio,
              ),
              espacio,
              DropdownButtonFormField<String>(
                initialValue: _gradoId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Grado y cinturón', border: borde),
                items: [
                  for (final g in grados)
                    DropdownMenuItem(
                      value: g.id,
                      child: Row(children: [
                        Cinturon(grado: g),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(g.descripcion,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                ],
                onChanged: (v) => setState(() => _gradoId = v),
                validator: (v) => v == null ? 'Elige tu grado' : null,
              ),
              espacio,
              _seccionDojo(borde),
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
                validator: (v) => v == null ? 'Elige tu país' : null,
              ),
              espacio,
              DropdownButtonFormField<String>(
                // La key cambia con el país para reiniciar la lista.
                key: ValueKey('region-$_pais'),
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
                onChanged: pais == null
                    ? null
                    : (v) => setState(() => _region = v),
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
              InkWell(
                onTap: _elegirFecha,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    helperText: 'No se muestra a nadie. Solo se usa para la edad.',
                    border: borde,
                    suffixIcon: const Icon(Icons.calendar_month),
                    errorText: _error == 'Falta la fecha de nacimiento.'
                        ? 'Obligatorio'
                        : null,
                  ),
                  child: Text(_nacimiento == null
                      ? 'Tocar para elegir'
                      : '${_nacimiento!.day}/${_nacimiento!.month}/${_nacimiento!.year}'
                          '  (${calcularEdad(_nacimiento!, DateTime.now())} años)'),
                ),
              ),
              espacio,
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _peso,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Peso', suffixText: 'kg', border: borde),
                    validator: _numeroEntre(10, 250, 'kg'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _estatura,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Estatura', suffixText: 'cm', border: borde),
                    validator: _numeroEntre(50, 250, 'cm'),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Text('Datos opcionales', style: textos.titleMedium),
              espacio,
              DropdownButtonFormField<Rol?>(
                initialValue: _rol,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Rol', border: borde),
                items: [
                  const DropdownMenuItem<Rol?>(
                      value: null, child: Text('Sin indicar')),
                  for (final r in Rol.values)
                    DropdownMenuItem<Rol?>(
                        value: r, child: Text(nombreDelRol(r))),
                ],
                onChanged: (v) => setState(() => _rol = v),
              ),
              espacio,
              TextFormField(
                controller: _anos,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Años de práctica', border: borde),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? null
                    : _numeroEntre(0, 90, 'años')(v),
              ),
              espacio,
              TextFormField(
                controller: _sobreMi,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Sobre mí', border: borde),
              ),
              const SizedBox(height: 12),
              _SeccionPrivacidad(
                esMenor: _esMenor,
                mostrarRol: _mostrarRol,
                mostrarAnos: _mostrarAnos,
                mostrarSobreMi: _mostrarSobreMi,
                mostrarHistorial: _mostrarHistorial,
                alCambiarRol: (v) => setState(() => _mostrarRol = v),
                alCambiarAnos: (v) => setState(() => _mostrarAnos = v),
                alCambiarSobreMi: (v) => setState(() => _mostrarSobreMi = v),
                alCambiarHistorial: (v) =>
                    setState(() => _mostrarHistorial = v),
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
                    : const Text('Guardar perfil'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeccionPrivacidad extends StatelessWidget {
  const _SeccionPrivacidad({
    required this.esMenor,
    required this.mostrarRol,
    required this.mostrarAnos,
    required this.mostrarSobreMi,
    required this.mostrarHistorial,
    required this.alCambiarRol,
    required this.alCambiarAnos,
    required this.alCambiarSobreMi,
    required this.alCambiarHistorial,
  });

  final bool? esMenor;
  final bool mostrarRol;
  final bool mostrarAnos;
  final bool mostrarSobreMi;
  final bool mostrarHistorial;
  final ValueChanged<bool> alCambiarRol;
  final ValueChanged<bool> alCambiarAnos;
  final ValueChanged<bool> alCambiarSobreMi;
  final ValueChanged<bool> alCambiarHistorial;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    if (esMenor == true) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Como eres menor de 18 años, los demás solo verán tu nombre de pila, '
            'tu dojo y tu grado. El resto de tus datos queda oculto.',
            style: textos.bodyMedium,
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('¿Qué quieres mostrar?', style: textos.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                esMenor == null
                    ? 'Elige tu fecha de nacimiento primero. Si eres menor de 18, '
                        'solo se mostrará tu nombre de pila, dojo y grado.'
                    : 'Tu nombre, edad, dojo, grado, peso, estatura y lugar '
                        'siempre se muestran. Esto lo eliges tú:',
                style: textos.bodySmall,
              ),
            ),
            SwitchListTile(
                title: const Text('Rol'),
                value: mostrarRol,
                onChanged: alCambiarRol),
            SwitchListTile(
                title: const Text('Años de práctica'),
                value: mostrarAnos,
                onChanged: alCambiarAnos),
            SwitchListTile(
                title: const Text('Sobre mí'),
                value: mostrarSobreMi,
                onChanged: alCambiarSobreMi),
            SwitchListTile(
                title: const Text('Historial de competencias'),
                value: mostrarHistorial,
                onChanged: alCambiarHistorial),
          ],
        ),
      ),
    );
  }
}
