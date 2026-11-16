// Revisa el código de las funciones sin publicarlas (lo usa GitHub).
const assert = require('node:assert');
const { mensaje } = require('./mensaje');

assert.strictEqual(
  mensaje({ tipo: 'reaccion', nombre: 'Ana', claves: ['a'] }),
  'Ana reaccionó a tu publicación.');
assert.strictEqual(
  mensaje({ tipo: 'reaccion', nombre: 'Ana', claves: ['a', 'b', 'c'], muro: 'd' }),
  'Ana y 2 personas más reaccionaron a la publicación de tu dojo.');
assert.strictEqual(
  mensaje({ tipo: 'comentario', nombre: 'Beto', claves: ['b', 'c'] }),
  'Beto y 1 persona más comentaron tu publicación.');
assert.strictEqual(
  mensaje({ tipo: 'dojo_resultado', subtipo: 'aceptado', titulo: 'Dojo Uno' }),
  'Dojo Uno te aceptó como miembro ✓');
assert.strictEqual(mensaje({ tipo: 'torneo', texto: 'Hola' }), 'Hola');

// Que las funciones se puedan cargar.
const f = require('./index');
for (const n of ['sonarAviso', 'avisoPodio', 'avisoTorneo', 'avisoOrganizadorAprobado',
  'avisoOrganizadorRechazado', 'avisoDenuncia']) {
  assert.ok(f[n], `Falta la función ${n}`);
}
console.log('Funciones: sin errores ✓');
