/// Organizaciones de Kyokushin (ver docs/decisiones.md).
class Organizacion {
  const Organizacion(this.id, this.nombre);

  /// Identificador que se guarda en la base de datos. No cambiar.
  final String id;
  final String nombre;
}

const String idOrganizacionOtra = 'otra';

const List<Organizacion> organizaciones = [
  Organizacion('iko', 'IKO Kyokushinkaikan (Matsui)'),
  Organizacion('wko', 'WKO Shinkyokushinkai'),
  Organizacion('kwf', 'KWF – Kyokushin World Federation'),
  Organizacion('ifk', 'IFK – International Federation of Karate'),
  Organizacion('iko3', 'IKO3 (Matsushima)'),
  Organizacion('kyokushinkan', 'Kyokushin-kan (Royama)'),
  Organizacion('sokyokushin', 'So-Kyokushin (Oishi)'),
  Organizacion('kwu', 'KWU – Kyokushin World Union'),
  Organizacion('independiente', 'Independiente'),
  Organizacion(idOrganizacionOtra, 'Otra'),
];

/// Nombre para mostrar. Si es "Otra", usa lo que se escribió a mano.
String nombreOrganizacion(String? id, String? otra) {
  if (id == idOrganizacionOtra) {
    final texto = otra?.trim() ?? '';
    return texto.isEmpty ? 'Otra' : texto;
  }
  for (final o in organizaciones) {
    if (o.id == id) return o.nombre;
  }
  return '';
}
