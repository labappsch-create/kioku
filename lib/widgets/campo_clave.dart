import 'package:flutter/material.dart';

/// Campo de contraseña con un ojito para mostrarla u ocultarla.
class CampoClave extends StatefulWidget {
  const CampoClave({
    super.key,
    required this.controller,
    required this.etiqueta,
    this.ayuda,
    this.validator,
    this.alEnviar,
  });

  final TextEditingController controller;
  final String etiqueta;
  final String? ayuda;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? alEnviar;

  @override
  State<CampoClave> createState() => _CampoClaveState();
}

class _CampoClaveState extends State<CampoClave> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculta,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        helperText: widget.ayuda,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(_oculta ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
      validator: widget.validator,
      onFieldSubmitted: widget.alEnviar,
    );
  }
}
