/** El texto del aviso. Debe coincidir con lib/modelos/aviso.dart. */
function mensaje(d) {
  const n = Array.isArray(d.claves) && d.claves.length ? d.claves.length : 1;
  const otros = n - 1;
  const varios = otros > 0;
  const quienes = varios
    ? `${d.nombre} y ${otros === 1 ? '1 persona más' : `${otros} personas más`}`
    : d.nombre || '';
  const deQue = d.muro === 'd' ? 'la publicación de tu dojo' : 'tu publicación';
  switch (d.tipo) {
    case 'reaccion':
      return `${quienes} ${varios ? 'reaccionaron' : 'reaccionó'} a ${deQue}.`;
    case 'comentario':
      return `${quienes} ${varios ? 'comentaron' : 'comentó'} ${deQue}.`;
    case 'solicitud_amistad':
      return `${d.nombre} te envió una solicitud de amistad.`;
    case 'amistad_aceptada':
      return `${d.nombre} aceptó tu solicitud de amistad.`;
    case 'solicitud_dojo':
      return `${d.nombre} pidió unirse a ${d.titulo}.`;
    case 'traspaso_dojo':
      return `${d.nombre} quiere traspasarte ${d.titulo}.`;
    case 'inscripcion_confirmada':
      return `Tu inscripción en ${d.titulo} fue confirmada ✓`;
    case 'inscripcion_nueva':
      return `${quienes} ${varios ? 'se inscribieron' : 'se inscribió'} en ${d.titulo}.`;
    case 'dojo_resultado':
      if (d.texto) return d.texto;
      if (d.subtipo === 'aceptado') return `${d.titulo} te aceptó como miembro ✓`;
      if (d.subtipo === 'quitado') return `Ya no eres miembro de ${d.titulo}.`;
      return `${d.titulo} rechazó tu solicitud.`;
  }
  return d.texto || 'Tienes una novedad en Kioku.';
}

module.exports = { mensaje };
