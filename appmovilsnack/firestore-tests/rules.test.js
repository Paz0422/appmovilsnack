// Tests de firestore.rules contra el emulador.
// Ejecutar: npm test (levanta el emulador, corre los tests y lo apaga).
// Cada escenario replica las escrituras que hace la app en lib/.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-snack-estadio';
const EVENTO = 'eventos/ev1';
const SECTOR = `${EVENTO}/sectores/s1`;
const SECTOR_2 = `${EVENTO}/sectores/s2`;

let env;

const db = (uid) => env.authenticatedContext(uid).firestore();
const vendedor = () => db('vend1');
const admin = () => db('admin1');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'usuarios/admin1'), { rol: 'admin', username: 'admin', auth_uid: 'admin1' });
    await setDoc(doc(f, 'usuarios/admin2'), { rol: ' Administrador ', username: 'admin2' });
    await setDoc(doc(f, 'usuarios/vend1'), {
      rol: 'vendedor', username: 'vend1', email: 'v1@test.cl', auth_uid: 'vend1',
      totalvendido: 0, itemsvendidos: 0,
    });
    // Perfil antiguo: id del documento distinto del uid de Auth.
    await setDoc(doc(f, 'usuarios/perfilViejo'), { rol: 'vendedor', username: 'vend2', auth_uid: 'vend2' });
    await setDoc(doc(f, 'usernames/vend1'), { email: 'v1@test.cl' });
    await setDoc(doc(f, 'productos/p1'), { nombre: 'Bebida', precio: 1500, categoria: 'Bebidas' });
    await setDoc(doc(f, 'categorias/c1'), { nombre: 'Bebidas', orden: 0 });
    await setDoc(doc(f, 'empleados/e1'), { nombre: 'Juan', rut: '1-9' });
    await setDoc(doc(f, EVENTO), { nombre: 'Partido', activo: true });
    for (const s of [SECTOR, SECTOR_2]) {
      await setDoc(doc(f, s), { nombre: s, totalVendido: 0, productosVendidos: 0, vendedoresasignados: [] });
      await setDoc(doc(f, `${s}/stock/p1`), { productoId: 'p1', nombre: 'Bebida', precio: 1500, cantidad: 20 });
    }
  });
});

// Replica VendedorVentasService.registrarCierreTurno.
async function registrarCierreTurno(f, perfilId, cierreId) {
  const usuarioRef = doc(f, `usuarios/${perfilId}`);
  const contabRef = doc(f, `usuarios/${perfilId}/cierres_contabilizados/${cierreId}`);
  await runTransaction(f, async (tx) => {
    const contab = await tx.get(contabRef);
    if (contab.exists()) return;
    const user = await tx.get(usuarioRef);
    const data = user.data() ?? {};
    tx.set(contabRef, {
      cierreId, monto: 10000, unidades: 5, anio: 2026,
      fecha: serverTimestamp(), eventoId: 'ev1', sectorId: 's1', tipo: 'cierre_turno',
    });
    tx.set(usuarioRef, {
      ventasAcumuladas: { anio: 2026, monto: 10000, unidades: 5, cierres: 1, actualizadoEn: serverTimestamp() },
      totalvendido: (data.totalvendido ?? 0) + 10000,
      itemsvendidos: (data.itemsvendidos ?? 0) + 5,
    }, { merge: true });
  });
}

describe('usuarios', () => {
  test('un usuario nuevo se registra como vendedor', async () => {
    await assertSucceeds(setDoc(doc(db('nuevo'), 'usuarios/nuevo'), {
      auth_uid: 'nuevo', email: 'n@test.cl', username: 'nuevo', rol: 'vendedor',
      fechaRegistro: serverTimestamp(), itemsvendidos: 0, totalvendido: 0,
    }));
  });

  test('no se puede registrar como admin', async () => {
    await assertFails(setDoc(doc(db('nuevo'), 'usuarios/nuevo'), { auth_uid: 'nuevo', rol: 'admin' }));
  });

  test('no se puede crear el perfil de otro uid', async () => {
    await assertFails(setDoc(doc(db('nuevo'), 'usuarios/otro'), { rol: 'vendedor' }));
  });

  test('sin sesión no se lee ni escribe nada', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'usuarios/vend1')));
    await assertFails(getDoc(doc(anon, 'productos/p1')));
    await assertFails(setDoc(doc(anon, 'usuarios/x'), { rol: 'vendedor' }));
  });

  test('un vendedor NO puede hacerse admin', async () => {
    const f = vendedor();
    await assertFails(updateDoc(doc(f, 'usuarios/vend1'), { rol: 'admin' }));
    await assertFails(updateDoc(doc(f, 'usuarios/vend1'), { rol: 'Administrador' }));
    await assertFails(setDoc(doc(f, 'usuarios/vend1'), { rol: 'admin' }, { merge: true }));
    await assertFails(setDoc(doc(f, 'usuarios/vend1'), { rol: 'admin', username: 'vend1' }));
  });

  test('un vendedor no puede cambiar su username ni auth_uid', async () => {
    await assertFails(updateDoc(doc(vendedor(), 'usuarios/vend1'), { username: 'admin' }));
    await assertFails(updateDoc(doc(vendedor(), 'usuarios/vend1'), { auth_uid: 'admin1' }));
  });

  test('un vendedor no puede editar el perfil de otro', async () => {
    await assertFails(updateDoc(doc(vendedor(), 'usuarios/perfilViejo'), { totalvendido: 999 }));
    await assertFails(deleteDoc(doc(vendedor(), 'usuarios/admin1')));
  });

  test('el admin puede cambiar roles', async () => {
    await assertSucceeds(updateDoc(doc(admin(), 'usuarios/vend1'), { rol: 'admin' }));
  });

  test('rol "Administrador" (con mayúsculas/espacios) cuenta como admin', async () => {
    await assertSucceeds(updateDoc(doc(db('admin2'), 'productos/p1'), { precio: 1 }));
  });

  test('cualquier autenticado lee perfiles (ranking)', async () => {
    await assertSucceeds(getDocs(collection(vendedor(), 'usuarios')));
  });
});

describe('usernames', () => {
  const anonimo = () => env.unauthenticatedContext().firestore();
  // Usuario recién creado en Auth, aún sin perfil en Firestore.
  const nuevo = (uid = 'nuevo', email = 'n@test.cl') =>
    env.authenticatedContext(uid, { email }).firestore();

  // Replica register_screen.dart: perfil + username en un batch.
  function registrar(f, uid, username, usernameId, email) {
    const batch = writeBatch(f);
    batch.set(doc(f, `usuarios/${uid}`), {
      auth_uid: uid, email, username, rol: 'vendedor',
      fechaRegistro: serverTimestamp(), itemsvendidos: 0, totalvendido: 0,
    });
    batch.set(doc(f, `usernames/${usernameId}`), { email });
    return batch.commit();
  }

  test('sin sesión se puede hacer get de un username', async () => {
    const snap = await assertSucceeds(getDoc(doc(anonimo(), 'usernames/vend1')));
    if (snap.data().email !== 'v1@test.cl') throw new Error('email incorrecto');
    await assertSucceeds(getDoc(doc(anonimo(), 'usernames/noexiste')));
  });

  test('sin sesión (ni con sesión) no se puede listar usernames', async () => {
    await assertFails(getDocs(collection(anonimo(), 'usernames')));
    await assertFails(getDocs(collection(vendedor(), 'usernames')));
    await assertFails(getDocs(collection(admin(), 'usernames')));
  });

  test('sin sesión no se puede leer usuarios (el login ya no lo necesita)', async () => {
    await assertFails(getDocs(collection(anonimo(), 'usuarios')));
  });

  test('registro: crea perfil y username normalizado', async () => {
    await assertSucceeds(registrar(nuevo(), 'nuevo', ' Juan  Perez ', 'juanperez', 'n@test.cl'));
  });

  test('no se puede reclamar un username ajeno (ya existente)', async () => {
    // Otro usuario con el mismo username en su perfil no puede pisar usernames/vend1.
    await assertFails(registrar(nuevo(), 'nuevo', 'VEND1', 'vend1', 'n@test.cl'));
    await assertFails(setDoc(doc(vendedor(), 'usernames/vend1'), { email: 'v1@test.cl' }));
  });

  test('no se puede reclamar un username distinto al del propio perfil', async () => {
    const f = nuevo();
    await setDoc(doc(f, 'usuarios/nuevo'), { auth_uid: 'nuevo', username: 'pedro', rol: 'vendedor' });
    await assertFails(setDoc(doc(f, 'usernames/juan'), { email: 'n@test.cl' }));
    await assertSucceeds(setDoc(doc(f, 'usernames/pedro'), { email: 'n@test.cl' }));
  });

  test('no se puede apuntar un username al correo de otro', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', 'nuevo', 'nuevo', 'v1@test.cl'));
  });

  test('solo se guarda el campo email', async () => {
    const f = nuevo();
    const batch = writeBatch(f);
    batch.set(doc(f, 'usuarios/nuevo'), { auth_uid: 'nuevo', username: 'nuevo', rol: 'vendedor' });
    batch.set(doc(f, 'usernames/nuevo'), { email: 'n@test.cl', uid: 'nuevo' });
    await assertFails(batch.commit());
  });

  test('no se puede crear un username con id sin normalizar, ni siquiera el admin', async () => {
    const f = nuevo('paz', 'paz@test.cl');
    const batch = writeBatch(f);
    batch.set(doc(f, 'usuarios/paz'), { auth_uid: 'paz', username: 'Paz', rol: 'vendedor' });
    batch.set(doc(f, 'usernames/Paz'), { email: 'paz@test.cl' });
    await assertFails(batch.commit());
    await assertFails(setDoc(doc(admin(), 'usernames/Paz'), { email: 'paz@test.cl' }));
    await assertFails(setDoc(doc(admin(), 'usernames/ paz'), { email: 'paz@test.cl' }));
  });

  test('"Paz", "paz" y " PAZ " resuelven al mismo documento (registro como "Paz")', async () => {
    await assertSucceeds(registrar(nuevo('paz', 'paz@test.cl'), 'paz', 'Paz', 'paz', 'paz@test.cl'));
    // Misma normalización que AuthManager.normalizarUsername.
    const normalizar = (u) => u.trim().toLowerCase().replace(/\s+/g, '');
    for (const escrito of ['Paz', 'paz', ' PAZ ']) {
      const snap = await getDoc(doc(anonimo(), `usernames/${normalizar(escrito)}`));
      if (snap.data()?.email !== 'paz@test.cl') throw new Error(`"${escrito}" no encontró la cuenta`);
    }
  });

  test('sin sesión no se puede crear un username', async () => {
    await assertFails(setDoc(doc(anonimo(), 'usernames/libre'), { email: 'x@test.cl' }));
  });

  test('el dueño no puede cambiar ni borrar su username; el admin sí', async () => {
    await assertFails(updateDoc(doc(vendedor(), 'usernames/vend1'), { email: 'otro@test.cl' }));
    await assertFails(deleteDoc(doc(vendedor(), 'usernames/vend1')));
    await assertSucceeds(setDoc(doc(admin(), 'usernames/manual'), { email: 'm@test.cl' }));
    await assertSucceeds(updateDoc(doc(admin(), 'usernames/vend1'), { email: 'nuevo@test.cl' }));
    await assertSucceeds(deleteDoc(doc(admin(), 'usernames/vend1')));
  });
});

describe('cierre de turno', () => {
  // Replica CierreTurnoService.cerrarTurno: transacción que relee el sector y el
  // stock, y si no cambió escribe el conteo y cierra; luego el ranking.
  test('un vendedor puede cerrar su turno', async () => {
    const f = vendedor();
    await assertSucceeds(getDocs(collection(f, `${SECTOR}/stock`)));
    await assertSucceeds(runTransaction(f, async (tx) => {
      const sector = await tx.get(doc(f, SECTOR));
      const stock = await tx.get(doc(f, `${SECTOR}/stock/p1`));
      if (sector.data().turnoCerrado || stock.data().cantidad !== 20) throw new Error('cambió');
      tx.set(doc(f, `${SECTOR}/stock/p1`), { cantidad: 3, cantidadFinal: 3 }, { merge: true });
      tx.set(doc(f, SECTOR), {
        ultimoCierre: { cierreId: 'ev1_s1_1', vendedorUid: 'vend1', totalEstimado: 10000, productos: [] },
        turnoCerrado: true,
        turnoCerradoAt: serverTimestamp(),
        totalVendido: increment(10000),
        borradorCierreTurno: deleteField(),
        vendedoresasignados: [],
      }, { merge: true });
    }));

    await assertSucceeds(registrarCierreTurno(f, 'vend1', 'ev1_s1_1'));
    await assertSucceeds(getDoc(doc(f, 'usuarios/vend1/cierres_contabilizados/ev1_s1_1')));
  });

  test('guardar borrador de cierre con el stock al iniciar el conteo', async () => {
    await assertSucceeds(setDoc(doc(vendedor(), SECTOR), {
      borradorCierreTurno: {
        enResumen: false,
        stockAlIniciar: { p1: 20 },
        productos: [{ productoId: 'p1', cantidadFinal: 7 }],
        actualizadoEn: serverTimestamp(),
      },
    }, { merge: true }));
  });

  test('el ranking funciona con perfiles antiguos (id != uid, enlazado por auth_uid)', async () => {
    await assertSucceeds(registrarCierreTurno(db('vend2'), 'perfilViejo', 'ev1_s1_2'));
  });

  test('un vendedor no puede sumar ventas al perfil de otro', async () => {
    await assertFails(registrarCierreTurno(vendedor(), 'perfilViejo', 'ev1_s1_3'));
    await assertFails(setDoc(doc(vendedor(), 'usuarios/perfilViejo/cierres_contabilizados/x'), {
      cierreId: 'x', tipo: 'cierre_turno',
    }));
  });

  test('un cierre contabilizado no se puede modificar ni borrar', async () => {
    const f = vendedor();
    await registrarCierreTurno(f, 'vend1', 'c1');
    await assertFails(updateDoc(doc(f, 'usuarios/vend1/cierres_contabilizados/c1'), { monto: 1 }));
    await assertFails(deleteDoc(doc(f, 'usuarios/vend1/cierres_contabilizados/c1')));
  });

  test('un vendedor no puede reabrir un turno; el admin sí', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), SECTOR), { turnoCerrado: true, stockInicialIngresado: true }));
    const reabrir = { turnoCerrado: false, turnoCerradoAt: deleteField(), stockInicialIngresado: false };
    await assertFails(updateDoc(doc(vendedor(), SECTOR), reabrir));
    await assertSucceeds(updateDoc(doc(admin(), SECTOR), reabrir));
  });

  test('un vendedor no puede renombrar, crear ni borrar sectores', async () => {
    const f = vendedor();
    await assertFails(updateDoc(doc(f, SECTOR), { nombre: 'Otro' }));
    await assertFails(setDoc(doc(f, `${EVENTO}/sectores/nuevo`), { nombre: 'Nuevo' }));
    await assertFails(setDoc(doc(f, `${EVENTO}/sectores/nuevo`), { turnoCerrado: true }, { merge: true }));
    await assertFails(deleteDoc(doc(f, SECTOR)));
  });
});

describe('configuración (solo admin)', () => {
  test('el admin puede gestionar productos', async () => {
    const f = admin();
    const ref = await assertSucceeds(addDoc(collection(f, 'productos'), { nombre: 'Completo', precio: 3000 }));
    await assertSucceeds(updateDoc(ref, { precio: 3500 }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('un vendedor lee productos pero no los modifica', async () => {
    const f = vendedor();
    await assertSucceeds(getDoc(doc(f, 'productos/p1')));
    await assertFails(addDoc(collection(f, 'productos'), { nombre: 'X', precio: 1 }));
    await assertFails(updateDoc(doc(f, 'productos/p1'), { precio: 1 }));
    await assertFails(deleteDoc(doc(f, 'productos/p1')));
  });

  test('categorías y empleados: solo admin escribe', async () => {
    await assertFails(addDoc(collection(vendedor(), 'categorias'), { nombre: 'X', orden: 9 }));
    await assertFails(addDoc(collection(vendedor(), 'empleados'), { nombre: 'X' }));
    await assertSucceeds(getDocs(collection(vendedor(), 'empleados')));
    await assertSucceeds(addDoc(collection(admin(), 'categorias'), { nombre: 'X', orden: 9 }));
    await assertSucceeds(addDoc(collection(admin(), 'empleados'), { nombre: 'X', rut: '2-7' }));
  });

  test('eventos: solo admin crea, edita y borra', async () => {
    const v = vendedor();
    await assertFails(setDoc(doc(v, 'eventos/nuevo'), { nombre: 'X', activo: true }));
    await assertFails(updateDoc(doc(v, EVENTO), { activo: false }));
    await assertFails(deleteDoc(doc(v, EVENTO)));

    // Replica _guardarEventoNuevo: evento + sectores en un batch.
    const a = admin();
    const batch = writeBatch(a);
    batch.set(doc(a, 'eventos/nuevo'), { nombre: 'X', activo: true, fechaCreacion: serverTimestamp() });
    batch.set(doc(a, 'eventos/nuevo/sectores/n1'), { nombre: 'Norte', totalVendido: 0, vendedoresasignados: [] });
    await assertSucceeds(batch.commit());
    await assertSucceeds(deleteDoc(doc(a, 'eventos/nuevo/sectores/n1')));
    await assertSucceeds(deleteDoc(doc(a, 'eventos/nuevo')));
  });
});

describe('operación del vendedor', () => {
  // Replica GestionStock._guardar: muchos productos en un batch + marca en el sector.
  test('ingreso de stock inicial con muchos productos', async () => {
    for (const f of [vendedor(), admin()]) {
      const batch = writeBatch(f);
      for (let i = 0; i < 60; i++) {
        batch.set(doc(f, `${SECTOR}/stock/prod${i}`), {
          productoId: `prod${i}`, nombre: `P${i}`, precio: 1000, cantidad: 10,
          cantidadInicial: 10, cantidadPropio: 10, cantidadPorTraspaso: 0, categoria: 'Bebidas',
        });
      }
      batch.delete(doc(f, `${SECTOR}/stock/p1`));
      await assertSucceeds(batch.commit());
      await assertSucceeds(setDoc(doc(f, SECTOR), {
        stockInicialIngresado: true, borradorStockInicial: deleteField(),
      }, { merge: true }));
    }
  });

  test('registrar merma (y no poder borrarla)', async () => {
    const f = vendedor();
    const mermaRef = doc(collection(f, `${SECTOR}/mermas`));
    await assertSucceeds(runTransaction(f, async (tx) => {
      const stock = await tx.get(doc(f, `${SECTOR}/stock/p1`));
      tx.update(stock.ref, { cantidad: stock.data().cantidad - 2 });
      tx.set(mermaRef, {
        eventoId: 'ev1', sectorId: 's1', fecha: serverTimestamp(), loteId: 'l1',
        productoId: 'p1', nombreProducto: 'Bebida', cantidadPerdida: 2, motivo: 'Rotura', precio: 1500,
      });
    }));
    await assertFails(deleteDoc(mermaRef));
    await assertFails(updateDoc(mermaRef, { cantidadPerdida: 0 }));
  });

  test('traspaso: enviar y confirmar; no se confirma dos veces', async () => {
    const f = vendedor();
    const datos = {
      fecha: serverTimestamp(), pedidoId: 'ped1', sectorOrigenId: 's1', sectorDestinoId: 's2',
      productoId: 'p1', nombre: 'Bebida', precio: 1500, cantidadEnviada: 5, estado: 'pendiente',
    };
    const entrante = doc(f, `${SECTOR_2}/traspasos_entrantes/t1`);
    const saliente = doc(f, `${SECTOR}/traspasos_salientes/t1`);
    await assertSucceeds(runTransaction(f, async (tx) => {
      const origen = await tx.get(doc(f, `${SECTOR}/stock/p1`));
      tx.update(origen.ref, { cantidad: origen.data().cantidad - 5 });
      tx.set(entrante, datos);
      tx.set(saliente, datos);
    }));

    const confirmacion = {
      estado: 'confirmado', cantidadRecibida: 4, cantidadDiferencia: 1,
      confirmadoAt: serverTimestamp(), comentarioDiferencia: 'Faltó una',
    };
    await assertSucceeds(runTransaction(f, async (tx) => {
      await tx.get(entrante);
      const destino = await tx.get(doc(f, `${SECTOR_2}/stock/p1`));
      const origen = await tx.get(doc(f, `${SECTOR}/stock/p1`));
      tx.update(destino.ref, { cantidad: destino.data().cantidad + 4, cantidadPorTraspaso: 4 });
      tx.update(origen.ref, { cantidad: origen.data().cantidad + 1 });
      tx.update(entrante, confirmacion);
      tx.update(saliente, confirmacion);
    }));

    await assertFails(updateDoc(entrante, { ...confirmacion, cantidadRecibida: 5 }));
  });

  test('traspaso: no se puede alterar lo enviado al confirmar', async () => {
    const f = vendedor();
    const entrante = doc(f, `${SECTOR_2}/traspasos_entrantes/t2`);
    await setDoc(entrante, { cantidadEnviada: 5, estado: 'pendiente', productoId: 'p1' });
    await assertFails(updateDoc(entrante, { estado: 'confirmado', cantidadEnviada: 50 }));
    await assertFails(setDoc(doc(f, `${SECTOR_2}/traspasos_entrantes/t3`), { estado: 'confirmado' }));
  });

  test('bandejeo: crear bandejero, ronda, rendir y cerrar', async () => {
    const f = vendedor();
    const bandejero = doc(collection(f, `${SECTOR}/bandejeros`));
    await assertSucceeds(setDoc(bandejero, { nombre: 'Pedro', creadoEn: serverTimestamp(), activo: true }));
    await assertSucceeds(setDoc(bandejero, { cajaVuelto: 5000 }, { merge: true }));

    const ronda = doc(f, `${bandejero.path}/rondas/r1`);
    await assertSucceeds(runTransaction(f, async (tx) => {
      const stock = await tx.get(doc(f, `${SECTOR}/stock/p1`));
      await tx.get(ronda);
      tx.update(stock.ref, { cantidad: stock.data().cantidad - 6 });
      tx.set(ronda, { estado: 'en_curso', productos: [], fechaInicio: serverTimestamp() }, { merge: true });
    }));

    const transaccion = doc(collection(f, 'transacciones'));
    await assertSucceeds(runTransaction(f, async (tx) => {
      const stock = await tx.get(doc(f, `${SECTOR}/stock/p1`));
      tx.update(stock.ref, { cantidad: stock.data().cantidad + 1 });
      tx.set(transaccion, { eventoId: 'ev1', sectorId: 's1', metodoPago: 'Bandejeo', montoTotal: 7500 });
      tx.set(ronda, { estado: 'rendida', transaccionId: transaccion.id }, { merge: true });
      tx.set(bandejero, { ultimaRondaRendida: true }, { merge: true });
    }));

    await assertSucceeds(setDoc(bandejero, {
      bandejeoCerrado: true, bandejeoCerradoEn: serverTimestamp(), cierreResumen: {}, ultimaRondaRendida: false,
    }, { merge: true }));

    await assertFails(updateDoc(transaccion, { montoTotal: 0 }));
    await assertFails(deleteDoc(transaccion));
    await assertFails(deleteDoc(ronda));
    await assertFails(deleteDoc(bandejero));
  });
});

describe('traspasos con sectores de turno cerrado', () => {
  // SECTOR = s1 (origen), SECTOR_2 = s2 (destino).
  const cerrar = (path) => env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), path), { turnoCerrado: true }));
  const datos = (estado = 'pendiente') => ({
    pedidoId: 'ped1', sectorOrigenId: 's1', sectorOrigenNombre: 's1', sectorDestinoId: 's2',
    productoId: 'p1', nombre: 'Bebida', precio: 1500, cantidadEnviada: 5, estado,
  });
  // Replica TraspasoService.enviar.
  const enviar = (f) => runTransaction(f, async (tx) => {
    const origen = await tx.get(doc(f, `${SECTOR}/stock/p1`));
    tx.update(origen.ref, { cantidad: origen.data().cantidad - 5 });
    tx.set(doc(f, `${SECTOR_2}/traspasos_entrantes/t1`), datos());
    tx.set(doc(f, `${SECTOR}/traspasos_salientes/t1`), datos());
  });
  // Replica TraspasoService.confirmarRecepcion (recibida 5 - diferencia).
  const confirmar = (f, diferencia) => runTransaction(f, async (tx) => {
    const destino = await tx.get(doc(f, `${SECTOR_2}/stock/p1`));
    const origen = await tx.get(doc(f, `${SECTOR}/stock/p1`));
    const confirmacion = {
      estado: 'confirmado', cantidadRecibida: 5 - diferencia,
      cantidadDiferencia: diferencia, confirmadoAt: serverTimestamp(),
    };
    tx.update(destino.ref, { cantidad: destino.data().cantidad + 5 - diferencia });
    if (diferencia > 0) tx.update(origen.ref, { cantidad: origen.data().cantidad + diferencia });
    tx.update(doc(f, `${SECTOR_2}/traspasos_entrantes/t1`), confirmacion);
    tx.update(doc(f, `${SECTOR}/traspasos_salientes/t1`), confirmacion);
  });

  test('no se puede enviar hacia un sector cerrado', async () => {
    await cerrar(SECTOR_2);
    await assertFails(enviar(vendedor()));
    await assertFails(setDoc(doc(vendedor(), `${SECTOR_2}/traspasos_entrantes/t9`), datos()));
  });

  test('no se puede enviar desde un sector cerrado', async () => {
    await cerrar(SECTOR);
    await assertFails(enviar(vendedor()));
    await assertFails(setDoc(doc(vendedor(), `${SECTOR}/traspasos_salientes/t9`), datos()));
  });

  test('no se puede confirmar en un destino cerrado', async () => {
    await assertSucceeds(enviar(vendedor()));
    await cerrar(SECTOR_2);
    await assertFails(confirmar(vendedor(), 0));
    await assertFails(updateDoc(doc(vendedor(), `${SECTOR_2}/traspasos_entrantes/t1`), {
      estado: 'confirmado', cantidadRecibida: 5, cantidadDiferencia: 0,
    }));
  });

  test('origen cerrado: no se devuelve la diferencia a su stock', async () => {
    await assertSucceeds(enviar(vendedor()));
    await cerrar(SECTOR);
    await assertFails(confirmar(vendedor(), 2));
    await assertSucceeds(confirmar(vendedor(), 0));
  });

  // Replica TraspasoService.confirmarRecepcion con el origen cerrado: suma lo
  // recibido al destino y registra el faltante en discrepancias.
  const discrepancia = (extra = {}) => ({
    eventoId: 'ev1', traspasoId: 't1', pedidoId: 'ped1',
    sectorOrigenId: 's1', sectorOrigenNombre: 'Sur',
    sectorDestinoId: 's2', sectorDestinoNombre: 'Norte',
    productoId: 'p1', nombreProducto: 'Bebida',
    cantidadEnviada: 5, cantidadRecibida: 3, diferencia: 2, comentario: 'Faltaron',
    vendedorUid: 'vend1', vendedorNombre: 'vend1', fecha: serverTimestamp(), estado: 'pendiente',
    ...extra,
  });
  const confirmarConFaltante = (f) => runTransaction(f, async (tx) => {
    const destino = await tx.get(doc(f, `${SECTOR_2}/stock/p1`));
    const confirmacion = {
      estado: 'confirmado', cantidadRecibida: 3, cantidadDiferencia: 2,
      confirmadoAt: serverTimestamp(), comentarioDiferencia: 'Faltaron', discrepanciaId: 't1',
    };
    tx.update(destino.ref, { cantidad: destino.data().cantidad + 3 });
    tx.update(doc(f, `${SECTOR_2}/traspasos_entrantes/t1`), confirmacion);
    tx.update(doc(f, `${SECTOR}/traspasos_salientes/t1`), confirmacion);
    tx.set(doc(f, `${EVENTO}/discrepancias/t1`), discrepancia());
  });

  test('origen cerrado con faltante: se confirma y se registra la discrepancia', async () => {
    await assertSucceeds(enviar(vendedor()));
    await cerrar(SECTOR);
    await assertSucceeds(confirmarConFaltante(vendedor()));
  });

  test('discrepancias: el vendedor solo crea; el admin lee y actualiza', async () => {
    await cerrar(SECTOR);
    const ref = (f) => doc(f, `${EVENTO}/discrepancias/t1`);
    await assertSucceeds(setDoc(ref(vendedor()), discrepancia()));
    await assertFails(getDoc(ref(vendedor())));
    await assertFails(getDocs(collection(vendedor(), `${EVENTO}/discrepancias`)));
    await assertFails(updateDoc(ref(vendedor()), { estado: 'resuelta' }));
    await assertFails(deleteDoc(ref(vendedor())));
    // Reescribirla sería un update: tampoco.
    await assertFails(setDoc(ref(vendedor()), discrepancia({ diferencia: 1, cantidadRecibida: 4 })));

    await assertSucceeds(getDocs(query(collection(admin(), `${EVENTO}/discrepancias`),
      where('estado', '==', 'pendiente'))));
    await assertSucceeds(updateDoc(ref(admin()), {
      estado: 'resuelta', resueltaAt: serverTimestamp(), resueltaPor: 'admin1', notaResolucion: 'ok',
    }));
    await assertFails(deleteDoc(ref(admin())));
  });

  test('discrepancias: no se pueden inventar', async () => {
    const crear = (f, id, data) => setDoc(doc(f, `${EVENTO}/discrepancias/${id}`), data);
    // Origen abierto: la diferencia debe volver a su stock, no a discrepancias.
    await assertFails(crear(vendedor(), 't1', discrepancia()));
    await cerrar(SECTOR);
    await assertFails(crear(vendedor(), 't1', discrepancia({ vendedorUid: 'otro' })));
    await assertFails(crear(vendedor(), 't1', discrepancia({ estado: 'resuelta' })));
    await assertFails(crear(vendedor(), 't1', discrepancia({ diferencia: 9 })));
    await assertFails(crear(vendedor(), 't1', discrepancia({ diferencia: 0, cantidadRecibida: 5 })));
    await assertFails(crear(vendedor(), 't2', discrepancia()));
    await assertFails(crear(vendedor(), 't1', discrepancia({ monto: 100000 })));
    await assertFails(crear(env.unauthenticatedContext().firestore(), 't1', discrepancia()));
  });

  test('si falta la copia saliente, el destino la crea confirmada aunque el origen esté cerrado', async () => {
    await cerrar(SECTOR);
    await assertSucceeds(setDoc(doc(vendedor(), `${SECTOR}/traspasos_salientes/t8`), datos('confirmado')));
  });

  test('con el turno cerrado el vendedor no toca el stock; el admin sí', async () => {
    await cerrar(SECTOR);
    await assertFails(updateDoc(doc(vendedor(), `${SECTOR}/stock/p1`), { cantidad: 1 }));
    await assertFails(setDoc(doc(vendedor(), `${SECTOR}/stock/nuevo`), { cantidad: 1 }));
    await assertFails(deleteDoc(doc(vendedor(), `${SECTOR}/stock/p1`)));
    await assertSucceeds(updateDoc(doc(admin(), `${SECTOR}/stock/p1`), { cantidad: 1 }));
  });
});
