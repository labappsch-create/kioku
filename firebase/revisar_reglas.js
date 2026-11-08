// Revisa que firebase/firestore.rules esté bien escrito, usando el
// emulador de Firestore. Se ejecuta en GitHub, no en el teléfono.
const fs = require('fs');

async function main() {
  const reglas = fs.readFileSync('firebase/firestore.rules', 'utf8');
  const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  const r = await fetch(
    `http://${host}/emulator/v1/projects/demo-kioku:securityRules`,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        rules: { files: [{ name: 'firestore.rules', content: reglas }] },
      }),
    },
  );
  const texto = await r.text();
  if (!r.ok) {
    console.error(`Las reglas tienen errores (HTTP ${r.status}):`);
    console.error(texto);
    process.exit(1);
  }
  console.log('Reglas de Firebase: sin errores ✓');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
