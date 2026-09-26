// Genera usernames/{username} = { email } a partir de los perfiles en usuarios/.
//
// Uso (desde appmovilsnack/scripts, tras `npm install`):
//   node migrar_usernames.mjs                 -> simulación: solo muestra qué haría
//   node migrar_usernames.mjs --aplicar       -> escribe en Firestore
//   node migrar_usernames.mjs --project otro  -> otro proyecto (por defecto snack-estadio)
//
// Credenciales: `gcloud auth application-default login` o la variable
// GOOGLE_APPLICATION_CREDENTIALS con una cuenta de servicio. Con
// FIRESTORE_EMULATOR_HOST definido escribe en el emulador.
//
// Es idempotente: nunca sobrescribe un username existente. Los conflictos se
// informan y se resuelven a mano desde la consola.
//
// También revisa usernames/ con id sin normalizar (p. ej. "Paz" creado a mano en
// la consola): el login solo busca el id normalizado ("paz"), así que crea ese
// documento con el mismo email. El original no se borra; se lista para borrarlo
// a mano.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const args = process.argv.slice(2);
const aplicar = args.includes('--aplicar');
const iProject = args.indexOf('--project');
const projectId = iProject >= 0 ? args[iProject + 1] : 'snack-estadio';

// Igual que AuthManager.normalizarUsername y normalizarUsername en firestore.rules.
const normalizarUsername = (u) => u.trim().toLowerCase().replace(/\s+/g, '');

const esIdValido = (id) =>
  id.length > 0 && !id.includes('/') && id !== '.' && id !== '..' &&
  !(id.startsWith('__') && id.endsWith('__'));

// Sin credenciales, firebase-admin se queda esperando en vez de fallar.
const rutaAdc = process.platform === 'win32'
  ? join(process.env.APPDATA ?? '', 'gcloud', 'application_default_credentials.json')
  : join(homedir(), '.config', 'gcloud', 'application_default_credentials.json');
if (!process.env.FIRESTORE_EMULATOR_HOST
    && !process.env.GOOGLE_APPLICATION_CREDENTIALS
    && !existsSync(rutaAdc)) {
  console.error(`No hay credenciales de Google configuradas.

Opción 1 (sin instalar nada):
  1. Consola de Firebase > Configuración del proyecto > Cuentas de servicio
     > "Generar nueva clave privada". Guarde el .json en esta carpeta (scripts/).
  2. En PowerShell:
       $env:GOOGLE_APPLICATION_CREDENTIALS = "$PWD\\<archivo>.json"
       node migrar_usernames.mjs
  3. Al terminar, borre el .json: da acceso total al proyecto.

Opción 2: instale Google Cloud CLI y ejecute
  gcloud auth application-default login`);
  process.exit(1);
}

initializeApp({ projectId });
const db = getFirestore();

console.log(`Proyecto: ${projectId}${process.env.FIRESTORE_EMULATOR_HOST ? ' (emulador)' : ''}`);
console.log(aplicar ? 'Modo: APLICAR\n' : 'Modo: simulación (use --aplicar para escribir)\n');

const usuarios = await db.collection('usuarios').get();

// usernameId -> [{ perfilId, username, email }]
const porUsername = new Map();
const omitidos = [];

for (const doc of usuarios.docs) {
  const data = doc.data();
  const username = typeof data.username === 'string' ? data.username : '';
  const email = typeof data.email === 'string' ? data.email.trim() : '';
  const id = normalizarUsername(username);

  if (!username.trim()) {
    omitidos.push(`${doc.id}: sin username`);
    continue;
  }
  if (!email) {
    omitidos.push(`${doc.id} (${username}): sin email`);
    continue;
  }
  if (!esIdValido(id)) {
    omitidos.push(`${doc.id} (${username}): username no válido como id ("${id}")`);
    continue;
  }
  const lista = porUsername.get(id) ?? [];
  lista.push({ perfilId: doc.id, username, email });
  porUsername.set(id, lista);
}

const conflictos = [];
let creados = 0;
let yaExistian = 0;
// Ids normalizados que existen o que esta ejecución crea (o crearía en simulación).
const normalizados = new Map(); // id -> email

async function crear(id, email) {
  console.log(`${aplicar ? 'Crear' : 'Crearía'}: usernames/${id} -> ${email}`);
  if (aplicar) {
    try {
      await db.collection('usernames').doc(id).create({ email });
    } catch (e) {
      // 6 = ALREADY_EXISTS: alguien lo creó mientras corría el script.
      if (e.code === 6) {
        conflictos.push(`"${id}" se creó durante la migración; revisar a mano`);
        return;
      }
      throw e;
    }
  }
  normalizados.set(id, email);
  creados++;
}

for (const [id, perfiles] of porUsername) {
  const emails = new Set(perfiles.map((p) => p.email.toLowerCase()));
  if (emails.size > 1) {
    const detalle = perfiles.map((p) => `${p.perfilId} "${p.username}" <${p.email}>`).join(', ');
    conflictos.push(`"${id}" lo usan varios perfiles con correos distintos: ${detalle}`);
    continue;
  }

  const email = perfiles[0].email;
  const ref = db.collection('usernames').doc(id);
  const existente = await ref.get();
  if (existente.exists) {
    const actual = existente.get('email');
    if (typeof actual === 'string' && actual.toLowerCase() === email.toLowerCase()) {
      normalizados.set(id, actual);
      yaExistian++;
    } else {
      conflictos.push(`"${id}" ya existe con <${actual}>, el perfil ${perfiles[0].perfilId} tiene <${email}>`);
    }
    continue;
  }

  await crear(id, email);
}

// Documentos usernames/ con id sin normalizar.
const sinNormalizar = [];
for (const doc of (await db.collection('usernames').get()).docs) {
  const id = normalizarUsername(doc.id);
  if (id === doc.id) continue;
  const email = doc.get('email');
  sinNormalizar.push(`usernames/${doc.id} (debe ser usernames/${id})`);
  if (typeof email !== 'string' || !email.trim() || !esIdValido(id)) continue;

  let existente = normalizados.get(id);
  if (existente === undefined) {
    const snap = await db.collection('usernames').doc(id).get();
    if (snap.exists) existente = snap.get('email');
  }
  if (existente === undefined) {
    await crear(id, email.trim());
  } else if (String(existente).toLowerCase() !== email.trim().toLowerCase()) {
    conflictos.push(`usernames/${doc.id} <${email}> choca con usernames/${id} <${existente}>`);
  }
}

console.log('\nResumen');
console.log(`  Perfiles leídos:      ${usuarios.size}`);
console.log(`  ${aplicar ? 'Creados' : 'A crear'}:              ${creados}`);
console.log(`  Ya existían:          ${yaExistian}`);
console.log(`  Omitidos:             ${omitidos.length}`);
omitidos.forEach((o) => console.log(`    - ${o}`));
console.log(`  Ids sin normalizar:   ${sinNormalizar.length} (borrar a mano tras migrar)`);
sinNormalizar.forEach((d) => console.log(`    - ${d}`));
console.log(`  Conflictos:           ${conflictos.length}`);
conflictos.forEach((c) => console.log(`    - ${c}`));

if (conflictos.length > 0) process.exitCode = 1;
