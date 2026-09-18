#!/usr/bin/env node
// Parla con App Store Connect per la parte che altool non copre: vedere le
// build caricate e collegarle ai gruppi di tester di TestFlight. Gira SUL MAC,
// dove c'e' la chiave .p8.
//
//   node testflight-mac.js stato                  <- cosa c'e' e come sta
//   node testflight-mac.js collega <app> <ver>    <- collega ai gruppi esterni
//
//   <app> = customer | driver        <ver> = 1.1.0+7
//
// NON crea gruppi e non ne tocca la configurazione: usa quelli che esistono
// gia', esattamente come sono. Se un gruppo non c'e', lo dice e si ferma.
//
// Perche' Node e non Python: il token di Apple e' un JWT firmato ES256 e sul
// Mac non ci sono ne' PyJWT ne' ruby-jwt; il modulo crypto di Node firma
// ES256 nel formato che Apple vuole (ieee-p1363) senza installare niente.

const crypto = require('crypto');
const fs = require('fs');

const KEY_PATH = '/Users/titanodevstudio/.appstoreconnect/private_keys/AuthKey_ZSR6KF48RK.p8';
const KID = 'ZSR6KF48RK';
const ISS = 'ed3ff578-1aa7-46bf-a803-f1a393afa2fb';
const BUNDLE = { customer: 'com.lenny.customer', driver: 'com.lenny.drivers' };

function b64url(buf) {
  return Buffer.from(buf).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function token() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: KID, typ: 'JWT' }));
  const payload = b64url(JSON.stringify({
    iss: ISS, iat: now, exp: now + 900, aud: 'appstoreconnect-v1',
  }));
  const firma = crypto.sign(
    'sha256',
    Buffer.from(`${header}.${payload}`),
    { key: fs.readFileSync(KEY_PATH), dsaEncoding: 'ieee-p1363' },
  );
  return `${header}.${payload}.${b64url(firma)}`;
}

async function api(metodo, percorso, corpo) {
  const url = percorso.startsWith('http')
    ? percorso : `https://api.appstoreconnect.apple.com${percorso}`;
  const r = await fetch(url, {
    method: metodo,
    headers: {
      Authorization: `Bearer ${token()}`,
      'Content-Type': 'application/json',
    },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  const testo = await r.text();
  if (!r.ok) {
    throw new Error(`${metodo} ${percorso} -> ${r.status}\n${testo}`);
  }
  return testo ? JSON.parse(testo) : {};
}

async function app(nome) {
  const r = await api('GET', `/v1/apps?filter[bundleId]=${BUNDLE[nome]}`);
  if (!r.data.length) throw new Error(`app ${nome} (${BUNDLE[nome]}) non trovata`);
  return r.data[0];
}

async function build(idApp, versione) {
  const [nome, numero] = versione.split('+');
  const r = await api('GET',
    `/v1/builds?filter[app]=${idApp}&filter[version]=${numero}`
    + `&filter[preReleaseVersion.version]=${nome}&limit=1`);
  return r.data[0] || null;
}

async function gruppi(idApp) {
  const r = await api('GET', `/v1/apps/${idApp}/betaGroups?limit=50`);
  return r.data;
}

async function stato() {
  for (const nome of ['customer', 'driver']) {
    const a = await app(nome);
    console.log(`\n=== ${nome} (${BUNDLE[nome]}) - ${a.attributes.name} - id ${a.id}`);

    const r = await api('GET', `/v1/builds?filter[app]=${a.id}&limit=5&sort=-uploadedDate`);
    console.log('  build caricate (le 5 piu' + "'" + ' recenti):');
    for (const b of r.data) {
      const g = await api('GET', `/v1/betaGroups?filter[builds]=${b.id}&limit=50`);
      const nomi = g.data.map((x) => x.attributes.name).join(', ') || 'NESSUN GRUPPO';
      const loc = await api('GET', `/v1/builds/${b.id}/betaBuildLocalizations`);
      const note = loc.data.map((x) => `${x.attributes.locale}: ${(x.attributes.whatsNew || '').split('\n')[0]}`);
      console.log(`    build ${b.attributes.version}  ${b.attributes.processingState}`
        + `  scade ${b.attributes.expired ? 'SI' : 'no'}  caricata ${b.attributes.uploadedDate}`);
      console.log(`      gruppi: ${nomi}`);
      console.log(`      note:   ${note.join(' | ') || '(nessuna)'}`);
    }

    console.log('  gruppi di tester configurati:');
    for (const g of await gruppi(a.id)) {
      const at = g.attributes;
      console.log(`    "${at.name}"  ${at.isInternalGroup ? 'INTERNO' : 'esterno'}`
        + `  link pubblico: ${at.publicLinkEnabled ? at.publicLink : 'spento'}`
        + `  build automatica: ${at.hasAccessToAllBuilds ? 'SI' : 'no'}  id ${g.id}`);
    }
  }
}

// Per i gruppi ESTERNI Apple vuole la sua revisione della build prima di
// distribuirla. Questa azione dice a che punto e', e se la richiesta non e'
// mai partita la manda.
async function review(nome, versione) {
  const a = await app(nome);
  const b = await build(a.id, versione);
  if (!b) throw new Error('build ' + versione + ' non trovata');
  const r = await api('GET', '/v1/betaAppReviewSubmissions?filter[build]=' + b.id);
  if (r.data.length) {
    console.log(nome + ' ' + versione + ': revisione ' + r.data[0].attributes.betaReviewState);
    return;
  }
  console.log(nome + ' ' + versione + ': nessuna richiesta di revisione, la mando');
  const creata = await api('POST', '/v1/betaAppReviewSubmissions', {
    data: {
      type: 'betaAppReviewSubmissions',
      relationships: { build: { data: { type: 'builds', id: b.id } } },
    },
  });
  console.log('  inviata, stato ' + creata.data.attributes.betaReviewState);
}

async function collega(nome, versione, noteTesto) {
  const a = await app(nome);
  const b = await build(a.id, versione);
  if (!b) throw new Error(`build ${versione} non trovata per ${nome}: Apple la sta ancora elaborando?`);
  console.log(`${nome} build ${versione}: stato ${b.attributes.processingState}`);
  if (b.attributes.processingState !== 'VALID') {
    throw new Error(`la build non e' ancora pronta (${b.attributes.processingState}), riprovare piu' tardi`);
  }

  // Le note "Cosa provare" servono ai gruppi esterni: senza, TestFlight non
  // distribuisce. Si scrivono solo se mancano, per non sovrascrivere a mano.
  if (noteTesto) {
    const loc = await api('GET', `/v1/builds/${b.id}/betaBuildLocalizations`);
    const it = loc.data.find((x) => x.attributes.locale === 'it') || loc.data[0];
    if (it) {
      await api('PATCH', `/v1/betaBuildLocalizations/${it.id}`, {
        data: { type: 'betaBuildLocalizations', id: it.id, attributes: { whatsNew: noteTesto } },
      });
      console.log(`  note aggiornate (${it.attributes.locale})`);
    } else {
      await api('POST', '/v1/betaBuildLocalizations', {
        data: {
          type: 'betaBuildLocalizations',
          attributes: { locale: 'it', whatsNew: noteTesto },
          relationships: { build: { data: { type: 'builds', id: b.id } } },
        },
      });
      console.log('  note create (it)');
    }
  }

  const esistenti = await gruppi(a.id);
  const esterni = esistenti.filter((g) => !g.attributes.isInternalGroup);
  if (!esterni.length) throw new Error('nessun gruppo esterno gia' + "'" + ' configurato: mi fermo, non ne creo');

  const gia = await api('GET', `/v1/betaGroups?filter[builds]=${b.id}&limit=50`);
  const giaId = new Set(gia.data.map((x) => x.id));
  const daFare = esterni.filter((g) => !giaId.has(g.id));
  if (!daFare.length) {
    console.log('  gia collegata a tutti i gruppi esterni, niente da fare');
    return;
  }

  await api('POST', `/v1/builds/${b.id}/relationships/betaGroups`, {
    data: daFare.map((g) => ({ type: 'betaGroups', id: g.id })),
  });
  console.log(`  collegata ai gruppi: ${daFare.map((g) => g.attributes.name).join(', ')}`);

  const dopo = await api('GET', `/v1/betaGroups?filter[builds]=${b.id}&limit=50`);
  console.log(`  verifica: ${dopo.data.map((x) => x.attributes.name).join(', ')}`);
}

(async () => {
  const [azione, ...resto] = process.argv.slice(2);
  try {
    if (azione === 'stato') await stato();
    else if (azione === 'review') await review(resto[0], resto[1]);
    else if (azione === 'collega') {
      const fileNote = process.env.NOTE_FILE;
      const note = fileNote ? fs.readFileSync(fileNote, 'utf8').trim() : (process.env.NOTE_TESTFLIGHT || '');
      await collega(resto[0], resto[1], note);
    } else {
      console.log('uso: testflight-mac.js stato | collega <customer|driver> <1.1.0+7>');
      process.exit(1);
    }
  } catch (e) {
    console.error('ERRORE:', e.message);
    process.exit(1);
  }
})();
