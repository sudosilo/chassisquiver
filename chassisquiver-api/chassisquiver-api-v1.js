const http = require('http');
const { createClient } = require('redis');

const PORT = process.env.PORT || 3000;
const KEY = 'chassisquiver:runs';
const MAX = 20000;

const db = createClient({ url: process.env.REDIS_URL });
db.on('error', e => console.error('redis', e.message));

const VT = ['car', 'suv', 'pickup', 'dually', 'van', 'box', 'semi', 'rv', 'other'];
const num = (v, lo, hi) => { const n = Number(v); return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : null; };
const str = (v, n) => (typeof v === 'string' ? v.replace(/[\u0000-\u001f]/g, '').trim().slice(0, n) : '');

function clean(r) {
  if (!r || typeof r !== 'object') return null;
  const id = str(r.id, 40), device = str(r.device, 40), road = str(r.road, 80);
  if (!/^[a-z0-9]+$/i.test(id) || !/^[a-z0-9]+$/i.test(device) || !road) return null;
  const score = num(r.score, 0, 10);
  if (score == null) return null;
  const v = r.vehicle && typeof r.vehicle === 'object' ? r.vehicle : {};
  return {
    id, device, road, score,
    at: num(r.at, 0, 1e14) || Date.now(),
    rating: r.rating == null ? null : num(r.rating, 0, 10),
    outside: num(r.outside, 0, 100), spm: num(r.spm, 0, 10000), spikes: num(r.spikes, 0, 1e7),
    rms: num(r.rms, 0, 1000), p95: num(r.p95, 0, 1000), peak: num(r.peak, 0, 1000),
    secs: num(r.secs, 0, 1e7), miles: num(r.miles, 0, 1e5), mph: r.mph == null ? null : num(r.mph, 0, 300),
    band: num(r.band, 0, 100), bump: num(r.bump, 0, 100), rate: num(r.rate, 0, 10000),
    vehicle: {
      type: VT.includes(v.type) ? v.type : 'other',
      make: str(v.make, 40), model: str(v.model, 40), year: str(String(v.year ?? ''), 4),
      miles: str(String(v.miles ?? ''), 9), tires: str(v.tires, 12), tiretype: str(v.tiretype, 12), susp: str(v.susp, 12)
    },
    received: Date.now()
  };
}

function send(res, code, obj) {
  res.writeHead(code, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(JSON.stringify(obj));
}

async function all() {
  const list = await db.lRange(KEY, 0, MAX - 1);
  const out = [];
  for (const s of list) { try { out.push(JSON.parse(s)); } catch (e) {} }
  return out;
}

const server = http.createServer(async (req, res) => {
  try {
    const u = new URL(req.url, 'http://x');
    if (req.method === 'OPTIONS') return send(res, 204, {});
    if (req.method === 'GET' && u.pathname === '/') return send(res, 200, { app: 'chassisquiver-api', ok: true });
    if (req.method === 'GET' && u.pathname === '/runs') {
      let runs = await all();
      const road = (u.searchParams.get('road') || '').toLowerCase();
      if (road) runs = runs.filter(r => r.road.toLowerCase() === road);
      return send(res, 200, { runs });
    }
    if (req.method === 'POST' && u.pathname === '/runs') {
      let body = '';
      for await (const c of req) { body += c; if (body.length > 8000) return send(res, 413, { error: 'too large' }); }
      let r;
      try { r = clean(JSON.parse(body)); } catch (e) { r = null; }
      if (!r) return send(res, 400, { error: 'bad run' });
      const runs = await all();
      if (runs.some(x => x.id === r.id)) return send(res, 200, { ok: true, dup: true });
      await db.lPush(KEY, JSON.stringify(r));
      await db.lTrim(KEY, 0, MAX - 1);
      return send(res, 201, { ok: true });
    }
    const m = u.pathname.match(/^\/runs\/([a-z0-9]+)$/i);
    if (req.method === 'DELETE' && m) {
      const device = u.searchParams.get('device') || '';
      const list = await db.lRange(KEY, 0, MAX - 1);
      let n = 0;
      for (const s of list) {
        try { const r = JSON.parse(s); if (r.id === m[1] && r.device === device) { await db.lRem(KEY, 1, s); n++; } } catch (e) {}
      }
      return send(res, 200, { ok: true, removed: n });
    }
    send(res, 404, { error: 'not found' });
  } catch (e) {
    console.error(e);
    send(res, 500, { error: 'server error' });
  }
});

db.connect().then(() => server.listen(PORT, () => console.log('chassisquiver-api on ' + PORT)))
  .catch(e => { console.error('redis connect failed', e.message); process.exit(1); });
