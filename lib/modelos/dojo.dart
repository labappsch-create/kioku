import 'package:cloud_firestore/cloud_firestore.dart';

import '../datos/organizaciones.dart';
import 'perfil.dart' show normalizarParaBuscar;

const List<String> diasSemana = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];

const String grupoOtro = 'Otro';

const List<String> gruposClase = [
  'Niños', 'Juveniles', 'Adultos', 'Todas las edades', 'Competidores',
  grupoOtro,
];

int _entre(int valor, int min, int max) =>
    valor < min ? min : (valor > max ? max : valor);

/// Una clase del horario del dojo.
class Clase {
  const Clase({
    required this.dia,
    required this.inicio,
    required this.fin,
    required this.grupo,
    this.grupoEscrito,
  });

  /// 0 = lunes ... 6 = domingo.
  final int dia;

  /// Formato "HH:MM".
  final String inicio;
  final String fin;
  final String grupo;

  /// Solo si [grupo] es "Otro".
  final String? grupoEscrito;

  String get nombreGrupo =>
      grupo == grupoOtro && (grupoEscrito?.trim().isNotEmpty ?? false)
          ? grupoEscrito!.trim()
          : grupo;

  String get texto => '${diasSemana[dia]} · $inicio a $fin · $nombreGrupo';

  Map<String, Object?> aMapa() => {
        'dia': dia,
        'inicio': inicio,
        'fin': fin,
        'grupo': grupo,
        if (grupo == grupoOtro) 'grupoEscrito': grupoEscrito?.trim(),
      };

  static Clase desdeMapa(Map<String, dynamic> m) => Clase(
        dia: _entre((m['dia'] as num?)?.toInt() ?? 0, 0, 6),
        inicio: m['inicio'] as String? ?? '00:00',
        fin: m['fin'] as String? ?? '00:00',
        grupo: m['grupo'] as String? ?? grupoOtro,
        grupoEscrito: m['grupoEscrito'] as String?,
      );

  static int comparar(Clase a, Clase b) {
    final d = a.dia.compareTo(b.dia);
    return d != 0 ? d : a.inicio.compareTo(b.inicio);
  }
}

List<Clase> _clasesDesde(Object? valor) {
  if (valor is! List) return [];
  final lista = <Clase>[];
  for (final e in valor) {
    if (e is Map) lista.add(Clase.desdeMapa(Map<String, dynamic>.from(e)));
  }
  lista.sort(Clase.comparar);
  return lista;
}

String? _textoOpcional(Object? valor) {
  final t = (valor as String?)?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Datos completos del dojo. Solo los lee y escribe su sensei
/// (colección privada `dojos_privados`).
class Dojo {
  Dojo({
    required this.senseiUid,
    required this.senseiNombre,
    required this.nombre,
    required this.organizacionId,
    this.organizacionOtra,
    required this.pais,
    required this.region,
    required this.ciudad,
    required this.direccion,
    required this.horarios,
    required this.telefono,
    required this.correo,
    this.instagram,
    this.facebook,
    required this.descripcion,
    this.mostrarDireccion = true,
    this.mostrarHorarios = true,
    this.mostrarTelefono = true,
    this.mostrarCorreo = true,
    this.mostrarRedes = true,
    this.mostrarDescripcion = true,
    this.mostrarMiembros = true,
  });

  final String senseiUid;
  final String senseiNombre;
  final String nombre;
  final String organizacionId;
  final String? organizacionOtra;
  final String pais;
  final String region;
  final String ciudad;
  final String direccion;
  final List<Clase> horarios;
  final String telefono;
  final String correo;
  final String? instagram;
  final String? facebook;
  final String descripcion;

  final bool mostrarDireccion;
  final bool mostrarHorarios;
  final bool mostrarTelefono;
  final bool mostrarCorreo;
  final bool mostrarRedes;
  final bool mostrarDescripcion;
  final bool mostrarMiembros;

  String get organizacion => nombreOrganizacion(organizacionId, organizacionOtra);

  Map<String, Object?> aMapa() => {
        'senseiUid': senseiUid,
        'senseiNombre': senseiNombre,
        'nombre': nombre,
        'organizacionId': organizacionId,
        'organizacionOtra': organizacionOtra,
        'pais': pais,
        'region': region,
        'ciudad': ciudad,
        'direccion': direccion,
        'horarios': [for (final c in horarios) c.aMapa()],
        'telefono': telefono,
        'correo': correo,
        'instagram': instagram,
        'facebook': facebook,
        'descripcion': descripcion,
        'mostrarDireccion': mostrarDireccion,
        'mostrarHorarios': mostrarHorarios,
        'mostrarTelefono': mostrarTelefono,
        'mostrarCorreo': mostrarCorreo,
        'mostrarRedes': mostrarRedes,
        'mostrarDescripcion': mostrarDescripcion,
        'mostrarMiembros': mostrarMiembros,
        'actualizado': FieldValue.serverTimestamp(),
      };

  static Dojo desdeMapa(Map<String, dynamic> m) => Dojo(
        senseiUid: m['senseiUid'] as String? ?? '',
        senseiNombre: m['senseiNombre'] as String? ?? '',
        nombre: m['nombre'] as String? ?? '',
        organizacionId: m['organizacionId'] as String? ?? idOrganizacionOtra,
        organizacionOtra: m['organizacionOtra'] as String?,
        pais: m['pais'] as String? ?? '',
        region: m['region'] as String? ?? '',
        ciudad: m['ciudad'] as String? ?? '',
        direccion: m['direccion'] as String? ?? '',
        horarios: _clasesDesde(m['horarios']),
        telefono: m['telefono'] as String? ?? '',
        correo: m['correo'] as String? ?? '',
        instagram: _textoOpcional(m['instagram']),
        facebook: _textoOpcional(m['facebook']),
        descripcion: m['descripcion'] as String? ?? '',
        mostrarDireccion: m['mostrarDireccion'] as bool? ?? true,
        mostrarHorarios: m['mostrarHorarios'] as bool? ?? true,
        mostrarTelefono: m['mostrarTelefono'] as bool? ?? true,
        mostrarCorreo: m['mostrarCorreo'] as bool? ?? true,
        mostrarRedes: m['mostrarRedes'] as bool? ?? true,
        mostrarDescripcion: m['mostrarDescripcion'] as bool? ?? true,
        mostrarMiembros: m['mostrarMiembros'] as bool? ?? true,
      );

  /// Lo que ven los demás (colección pública `dojos`).
  Map<String, Object?> aMapaPublico() => {
        'senseiUid': senseiUid,
        'senseiNombre': senseiNombre,
        'nombre': nombre,
        'nombreBusqueda': normalizarParaBuscar(nombre),
        'organizacionId': organizacionId,
        'organizacion': organizacion,
        'pais': pais,
        'region': region,
        'ciudad': ciudad,
        if (mostrarDireccion) 'direccion': direccion,
        if (mostrarHorarios) 'horarios': [for (final c in horarios) c.aMapa()],
        if (mostrarTelefono) 'telefono': telefono,
        if (mostrarCorreo) 'correo': correo,
        if (mostrarRedes && instagram != null) 'instagram': instagram,
        if (mostrarRedes && facebook != null) 'facebook': facebook,
        if (mostrarDescripcion) 'descripcion': descripcion,
        'mostrarMiembros': mostrarMiembros,
        'actualizado': FieldValue.serverTimestamp(),
      };
}

/// Lo que se ve de un dojo (colección pública `dojos`).
class DojoPublico {
  DojoPublico(this.id, this.datos);

  final String id;
  final Map<String, dynamic> datos;

  String get senseiUid => datos['senseiUid'] as String? ?? '';
  String get senseiNombre => datos['senseiNombre'] as String? ?? '';
  String get nombre => datos['nombre'] as String? ?? '';
  String get nombreBusqueda => datos['nombreBusqueda'] as String? ?? '';
  String get organizacion => datos['organizacion'] as String? ?? '';
  String get pais => datos['pais'] as String? ?? '';
  String get region => datos['region'] as String? ?? '';
  String get ciudad => datos['ciudad'] as String? ?? '';
  String? get direccion => _textoOpcional(datos['direccion']);
  List<Clase>? get horarios =>
      datos.containsKey('horarios') ? _clasesDesde(datos['horarios']) : null;
  String? get telefono => _textoOpcional(datos['telefono']);
  String? get correo => _textoOpcional(datos['correo']);
  String? get instagram => _textoOpcional(datos['instagram']);
  String? get facebook => _textoOpcional(datos['facebook']);
  String? get descripcion => _textoOpcional(datos['descripcion']);
  bool get mostrarMiembros => datos['mostrarMiembros'] as bool? ?? false;

  String get lugar =>
      [ciudad, region, pais].where((t) => t.isNotEmpty).join(', ');
}

/// Estado de un practicante en un dojo.
const String estadoPendiente = 'pendiente';
const String estadoConfirmado = 'confirmado';

/// Un practicante dentro de un dojo (subcolección `dojos/{id}/miembros`).
class Miembro {
  Miembro(this.uid, this.datos);

  final String uid;
  final Map<String, dynamic> datos;

  String get estado => datos['estado'] as String? ?? estadoPendiente;
  String get nombre => datos['nombreMostrado'] as String? ?? '';
  String? get gradoId => datos['gradoId'] as String?;
}
