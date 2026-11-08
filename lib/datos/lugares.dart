/// Países incluidos en Kioku y sus divisiones (regiones).
/// Ver docs/decisiones.md.
class Pais {
  const Pais(this.nombre, this.tipoRegion, this.regiones);

  final String nombre;

  /// Cómo se llama la división en ese país: Estado, Provincia, etc.
  final String tipoRegion;
  final List<String> regiones;
}

const List<Pais> paises = [
  Pais('Argentina', 'Provincia', [
    'Buenos Aires', 'Catamarca', 'Chaco', 'Chubut',
    'Ciudad Autónoma de Buenos Aires', 'Córdoba', 'Corrientes', 'Entre Ríos',
    'Formosa', 'Jujuy', 'La Pampa', 'La Rioja', 'Mendoza', 'Misiones',
    'Neuquén', 'Río Negro', 'Salta', 'San Juan', 'San Luis', 'Santa Cruz',
    'Santa Fe', 'Santiago del Estero', 'Tierra del Fuego', 'Tucumán',
  ]),
  Pais('Bolivia', 'Departamento', [
    'Beni', 'Chuquisaca', 'Cochabamba', 'La Paz', 'Oruro', 'Pando',
    'Potosí', 'Santa Cruz', 'Tarija',
  ]),
  Pais('Brasil', 'Estado', [
    'Acre', 'Alagoas', 'Amapá', 'Amazonas', 'Bahia', 'Ceará',
    'Distrito Federal', 'Espírito Santo', 'Goiás', 'Maranhão', 'Mato Grosso',
    'Mato Grosso do Sul', 'Minas Gerais', 'Pará', 'Paraíba', 'Paraná',
    'Pernambuco', 'Piauí', 'Rio de Janeiro', 'Rio Grande do Norte',
    'Rio Grande do Sul', 'Rondônia', 'Roraima', 'Santa Catarina',
    'São Paulo', 'Sergipe', 'Tocantins',
  ]),
  Pais('Chile', 'Región', [
    'Arica y Parinacota', 'Tarapacá', 'Antofagasta', 'Atacama', 'Coquimbo',
    'Valparaíso', 'Metropolitana de Santiago', "O'Higgins", 'Maule', 'Ñuble',
    'Biobío', 'La Araucanía', 'Los Ríos', 'Los Lagos', 'Aysén', 'Magallanes',
  ]),
  Pais('Colombia', 'Departamento', [
    'Amazonas', 'Antioquia', 'Arauca', 'Atlántico', 'Bogotá D.C.', 'Bolívar',
    'Boyacá', 'Caldas', 'Caquetá', 'Casanare', 'Cauca', 'Cesar', 'Chocó',
    'Córdoba', 'Cundinamarca', 'Guainía', 'Guaviare', 'Huila', 'La Guajira',
    'Magdalena', 'Meta', 'Nariño', 'Norte de Santander', 'Putumayo',
    'Quindío', 'Risaralda', 'San Andrés y Providencia', 'Santander', 'Sucre',
    'Tolima', 'Valle del Cauca', 'Vaupés', 'Vichada',
  ]),
  Pais('Costa Rica', 'Provincia', [
    'Alajuela', 'Cartago', 'Guanacaste', 'Heredia', 'Limón', 'Puntarenas',
    'San José',
  ]),
  Pais('Cuba', 'Provincia', [
    'Pinar del Río', 'Artemisa', 'La Habana', 'Mayabeque', 'Matanzas',
    'Cienfuegos', 'Villa Clara', 'Sancti Spíritus', 'Ciego de Ávila',
    'Camagüey', 'Las Tunas', 'Holguín', 'Granma', 'Santiago de Cuba',
    'Guantánamo', 'Isla de la Juventud',
  ]),
  Pais('Ecuador', 'Provincia', [
    'Azuay', 'Bolívar', 'Cañar', 'Carchi', 'Chimborazo', 'Cotopaxi', 'El Oro',
    'Esmeraldas', 'Galápagos', 'Guayas', 'Imbabura', 'Loja', 'Los Ríos',
    'Manabí', 'Morona Santiago', 'Napo', 'Orellana', 'Pastaza', 'Pichincha',
    'Santa Elena', 'Santo Domingo de los Tsáchilas', 'Sucumbíos',
    'Tungurahua', 'Zamora Chinchipe',
  ]),
  Pais('El Salvador', 'Departamento', [
    'Ahuachapán', 'Cabañas', 'Chalatenango', 'Cuscatlán', 'La Libertad',
    'La Paz', 'La Unión', 'Morazán', 'San Miguel', 'San Salvador',
    'San Vicente', 'Santa Ana', 'Sonsonate', 'Usulután',
  ]),
  Pais('Guatemala', 'Departamento', [
    'Alta Verapaz', 'Baja Verapaz', 'Chimaltenango', 'Chiquimula',
    'El Progreso', 'Escuintla', 'Guatemala', 'Huehuetenango', 'Izabal',
    'Jalapa', 'Jutiapa', 'Petén', 'Quetzaltenango', 'Quiché', 'Retalhuleu',
    'Sacatepéquez', 'San Marcos', 'Santa Rosa', 'Sololá', 'Suchitepéquez',
    'Totonicapán', 'Zacapa',
  ]),
  Pais('Honduras', 'Departamento', [
    'Atlántida', 'Choluteca', 'Colón', 'Comayagua', 'Copán', 'Cortés',
    'El Paraíso', 'Francisco Morazán', 'Gracias a Dios', 'Intibucá',
    'Islas de la Bahía', 'La Paz', 'Lempira', 'Ocotepeque', 'Olancho',
    'Santa Bárbara', 'Valle', 'Yoro',
  ]),
  Pais('México', 'Estado', [
    'Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche',
    'Chiapas', 'Chihuahua', 'Ciudad de México', 'Coahuila', 'Colima',
    'Durango', 'Estado de México', 'Guanajuato', 'Guerrero', 'Hidalgo',
    'Jalisco', 'Michoacán', 'Morelos', 'Nayarit', 'Nuevo León', 'Oaxaca',
    'Puebla', 'Querétaro', 'Quintana Roo', 'San Luis Potosí', 'Sinaloa',
    'Sonora', 'Tabasco', 'Tamaulipas', 'Tlaxcala', 'Veracruz', 'Yucatán',
    'Zacatecas',
  ]),
  Pais('Nicaragua', 'Departamento', [
    'Boaco', 'Carazo', 'Chinandega', 'Chontales', 'Estelí', 'Granada',
    'Jinotega', 'León', 'Madriz', 'Managua', 'Masaya', 'Matagalpa',
    'Nueva Segovia', 'Río San Juan', 'Rivas',
    'Región Autónoma de la Costa Caribe Norte',
    'Región Autónoma de la Costa Caribe Sur',
  ]),
  Pais('Panamá', 'Provincia', [
    'Bocas del Toro', 'Chiriquí', 'Coclé', 'Colón', 'Darién', 'Herrera',
    'Los Santos', 'Panamá', 'Panamá Oeste', 'Veraguas',
    'Comarca Emberá-Wounaan', 'Comarca Guna Yala', 'Comarca Naso Tjër Di',
    'Comarca Ngäbe-Buglé',
  ]),
  Pais('Paraguay', 'Departamento', [
    'Alto Paraguay', 'Alto Paraná', 'Amambay', 'Asunción', 'Boquerón',
    'Caaguazú', 'Caazapá', 'Canindeyú', 'Central', 'Concepción', 'Cordillera',
    'Guairá', 'Itapúa', 'Misiones', 'Ñeembucú', 'Paraguarí',
    'Presidente Hayes', 'San Pedro',
  ]),
  Pais('Perú', 'Departamento', [
    'Amazonas', 'Áncash', 'Apurímac', 'Arequipa', 'Ayacucho', 'Cajamarca',
    'Callao', 'Cusco', 'Huancavelica', 'Huánuco', 'Ica', 'Junín',
    'La Libertad', 'Lambayeque', 'Lima', 'Loreto', 'Madre de Dios',
    'Moquegua', 'Pasco', 'Piura', 'Puno', 'San Martín', 'Tacna', 'Tumbes',
    'Ucayali',
  ]),
  Pais('Puerto Rico', 'Municipio', [
    'Adjuntas', 'Aguada', 'Aguadilla', 'Aguas Buenas', 'Aibonito', 'Añasco',
    'Arecibo', 'Arroyo', 'Barceloneta', 'Barranquitas', 'Bayamón',
    'Cabo Rojo', 'Caguas', 'Camuy', 'Canóvanas', 'Carolina', 'Cataño',
    'Cayey', 'Ceiba', 'Ciales', 'Cidra', 'Coamo', 'Comerío', 'Corozal',
    'Culebra', 'Dorado', 'Fajardo', 'Florida', 'Guánica', 'Guayama',
    'Guayanilla', 'Guaynabo', 'Gurabo', 'Hatillo', 'Hormigueros', 'Humacao',
    'Isabela', 'Jayuya', 'Juana Díaz', 'Juncos', 'Lajas', 'Lares',
    'Las Marías', 'Las Piedras', 'Loíza', 'Luquillo', 'Manatí', 'Maricao',
    'Maunabo', 'Mayagüez', 'Moca', 'Morovis', 'Naguabo', 'Naranjito',
    'Orocovis', 'Patillas', 'Peñuelas', 'Ponce', 'Quebradillas', 'Rincón',
    'Río Grande', 'Sabana Grande', 'Salinas', 'San Germán', 'San Juan',
    'San Lorenzo', 'San Sebastián', 'Santa Isabel', 'Toa Alta', 'Toa Baja',
    'Trujillo Alto', 'Utuado', 'Vega Alta', 'Vega Baja', 'Vieques',
    'Villalba', 'Yabucoa', 'Yauco',
  ]),
  Pais('República Dominicana', 'Provincia', [
    'Azua', 'Bahoruco', 'Barahona', 'Dajabón', 'Distrito Nacional', 'Duarte',
    'El Seibo', 'Elías Piña', 'Espaillat', 'Hato Mayor', 'Hermanas Mirabal',
    'Independencia', 'La Altagracia', 'La Romana', 'La Vega',
    'María Trinidad Sánchez', 'Monseñor Nouel', 'Monte Cristi', 'Monte Plata',
    'Pedernales', 'Peravia', 'Puerto Plata', 'Samaná', 'San Cristóbal',
    'San José de Ocoa', 'San Juan', 'San Pedro de Macorís',
    'Sánchez Ramírez', 'Santiago', 'Santiago Rodríguez', 'Santo Domingo',
    'Valverde',
  ]),
  Pais('Uruguay', 'Departamento', [
    'Artigas', 'Canelones', 'Cerro Largo', 'Colonia', 'Durazno', 'Flores',
    'Florida', 'Lavalleja', 'Maldonado', 'Montevideo', 'Paysandú',
    'Río Negro', 'Rivera', 'Rocha', 'Salto', 'San José', 'Soriano',
    'Tacuarembó', 'Treinta y Tres',
  ]),
  Pais('Venezuela', 'Estado', [
    'Amazonas', 'Anzoátegui', 'Apure', 'Aragua', 'Barinas', 'Bolívar',
    'Carabobo', 'Cojedes', 'Delta Amacuro', 'Distrito Capital', 'Falcón',
    'Guárico', 'La Guaira', 'Lara', 'Mérida', 'Miranda', 'Monagas',
    'Nueva Esparta', 'Portuguesa', 'Sucre', 'Táchira', 'Trujillo', 'Yaracuy',
    'Zulia', 'Dependencias Federales',
  ]),
];

Pais? paisPorNombre(String? nombre) {
  for (final p in paises) {
    if (p.nombre == nombre) return p;
  }
  return null;
}
