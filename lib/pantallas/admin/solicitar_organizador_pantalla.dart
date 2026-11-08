import 'package:flutter/material.dart';

import '../../modelos/perfil.dart';
import '../../servicios/admin_servicio.dart';
import '../../servicios/errores.dart';

/// Pantalla 1: solicitar ser organizador aprobado.
class SolicitarOrganizadorPantalla extends StatefulWidget {
  const SolicitarOrganizadorPantalla({
    super.key,
    required this.uid,
    required this.perfil,
  });

  final String uid;
  final Perfil perfil;

  @override
  State<SolicitarOrganizadorPantalla> createState() =>
      _SolicitarOrganizadorPantallaState();
}

class _SolicitarOrganizadorPantallaState
    extends State<SolicitarOrganizadorPantalla> {
  final _servicio = AdminServicio();
  final _mensaje = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ser organizador')),
      body: StreamBuilder<bool>(
        stream: _servicio.esOrganizador(widget.uid),
        builder: (context, org) {
          if (org.hasError) {
            return Center(child: Text(mensajeDeError(org.error!)));
          }
          if (!org.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (org.data!) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ya eres organizador aprobado ✓\n\n'
                  'Puedes crear competencias regionales, nacionales e internacionales.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return StreamBuilder<Registro?>(
            stream: _servicio.miSolicitud(widget.uid),
            builder: (context, sol) {
              if (sol.hasError) {
                return Center(child: Text(mensajeDeError(sol.error!)));
              }
              if (sol.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final solicitud = sol.data;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Los torneos locales los crea el sensei de un dojo. '
                    'Para crear torneos regionales, nacionales o internacionales '
                    'necesitas que un administrador de Kioku te apruebe.',
                    style: textos.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (solicitud != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tu solicitud está pendiente',
                                style: textos.titleSmall),
                            const SizedBox(height: 8),
                            Text(solicitud.mensaje),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _enviando
                          ? null
                          : () => _hacer(
                              () => _servicio.cancelarSolicitud(widget.uid)),
                      child: const Text('Cancelar solicitud'),
                    ),
                  ] else ...[
                    TextField(
                      controller: _mensaje,
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Cuéntanos quién eres',
                        hintText: 'Ej.: Soy presidente de la asociación X',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _enviando
                          ? null
                          : () {
                              final texto = _mensaje.text.trim();
                              if (texto.isEmpty) {
                                setState(() =>
                                    _error = 'Escribe un mensaje para el administrador.');
                                return;
                              }
                              _hacer(() => _servicio.solicitar(
                                    widget.uid,
                                    widget.perfil.nombrePublico(DateTime.now()),
                                    texto,
                                  ));
                            },
                      child: const Text('Enviar solicitud'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
