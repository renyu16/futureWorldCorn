import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_PORT = 8085;
const DEFAULT_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'web');
const RPC_PATH = '/rpc';
const RPC_DEFAULT_UPSTREAM = process.env.RPC_PROXY_UPSTREAM || 'https://worldchain-sepolia.g.alchemy.com/public';
const RPC_TIMEOUT = 20000;

function parseArgs(argv) {
  const args = { port: DEFAULT_PORT, host: '0.0.0.0', dir: DEFAULT_DIR, rpcUpstream: RPC_DEFAULT_UPSTREAM };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--port') args.port = Number(argv[++i]);
    else if (argv[i] === '--host') args.host = argv[++i];
    else if (argv[i] === '--dir') args.dir = argv[++i];
    else if (argv[i] === '--rpc-upstream') args.rpcUpstream = argv[++i];
  }
  return args;
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
};

const args = parseArgs(process.argv.slice(2));
const root = path.resolve(args.dir);
const port = args.port;
const host = args.host;
const rpcUpstream = args.rpcUpstream;

const SETTLE_PRIVATE_KEY = process.env.SETTLE_PRIVATE_KEY || '';
const SETTLE_API_TOKEN = process.env.SETTLE_API_TOKEN || '';
const SETTLE_PREDICTION_MARKET_ADDRESS =
  process.env.SETTLE_PREDICTION_MARKET_ADDRESS ||
  '0x9cb69cb7da9677b3a122a6a4e402398a6df4a026';
const SETTLE_TIMEOUT = 30000;

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error(`error: invalid port: ${args.port}`);
  process.exit(1);
}

function send(res, status, chunk, headers = {}) {
  const len = typeof chunk === 'string' ? Buffer.byteLength(chunk) : chunk.length;
  res.writeHead(status, { 'Content-Length': len, ...headers });
  res.end(chunk);
}

function proxyRpc(req, res) {
  if (req.method !== 'POST') return send(res, 405, 'Method Not Allowed');
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    const body = Buffer.concat(chunks);
    let upstream;
    try {
      upstream = new URL(rpcUpstream);
    } catch {
      return send(res, 500, JSON.stringify({ jsonrpc: '2.0', id: null, error: { code: -32099, message: 'bad upstream config' } }));
    }
    const client = upstream.protocol === 'http:' ? http : https;
    const outReq = client.request(
      upstream,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'content-length': body.length,
          accept: 'application/json',
        },
        timeout: RPC_TIMEOUT,
      },
      (upRes) => {
        const status = upRes.statusCode || 502;
        res.writeHead(status, {
          'Content-Type': upRes.headers['content-type'] || 'application/json; charset=utf-8',
          'Cache-Control': 'no-store',
        });
        upRes.pipe(res);
      }
    );
    outReq.on('timeout', () => outReq.destroy(new Error('rpc upstream timeout')));
    outReq.on('error', (err) => {
      console.error(`rpc proxy error: ${err.message}`);
      if (!res.headersSent) {
        send(res, 502, JSON.stringify({ jsonrpc: '2.0', id: null, error: { code: -32099, message: 'upstream error' } }));
      } else {
        res.end();
      }
    });
    outReq.end(body);
  });
  req.on('error', () => send(res, 400, 'Bad Request'));
}

function readJsonBody(req, cb) {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    try {
      cb(JSON.parse(Buffer.concat(chunks).toString('utf8')));
    } catch {
      cb(null);
    }
  });
  req.on('error', () => cb(null));
}

function sendJson(res, status, obj) {
  send(res, status, JSON.stringify(obj), {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
}

async function handleSettle(req, res) {
  if (req.method !== 'POST') return sendJson(res, 405, { ok: false, error: 'method not allowed' });
  const auth = (req.headers['authorization'] || '').trim();
  const expected = `Bearer ${SETTLE_API_TOKEN}`;
  if (!SETTLE_API_TOKEN || auth !== expected) {
    return sendJson(res, 401, { ok: false, error: 'unauthorized' });
  }
  readJsonBody(req, async (body) => {
    if (!body || typeof body.marketId !== 'number' || typeof body.result !== 'boolean') {
      return sendJson(res, 400, { ok: false, error: 'invalid body: "marketId" (number) and "result" (boolean) required' });
    }
    const { marketId, result } = body;
    if (!Number.isInteger(marketId) || marketId < 1) {
      return sendJson(res, 400, { ok: false, error: 'invalid marketId' });
    }
    if (!SETTLE_PRIVATE_KEY) {
      return sendJson(res, 501, { ok: false, error: 'settle not configured: missing SETTLE_PRIVATE_KEY' });
    }
    let ethers;
    try {
      ethers = await import('ethers');
    } catch {
      return sendJson(res, 501, { ok: false, error: 'settle not configured: ethers not installed (run "npm install" in deploy/webserver)' });
    }
    try {
      const provider = new ethers.JsonRpcProvider(rpcUpstream, undefined, { staticNetwork: true });
      const wallet = new ethers.Wallet(SETTLE_PRIVATE_KEY, provider);
      const iface = new ethers.Interface(['function resolveMarket(uint256 marketId, bool result)']);
      const data = iface.encodeFunctionData('resolveMarket', [marketId, result]);
      const tx = await wallet.sendTransaction({ to: SETTLE_PREDICTION_MARKET_ADDRESS, data });
      const receipt = await Promise.race([
        tx.wait(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('tx wait timeout')), SETTLE_TIMEOUT)),
      ]);
      return sendJson(res, 200, { ok: true, txHash: receipt.hash || tx.hash });
    } catch (e) {
      console.error(`settle error: ${e?.message || e}`);
      return sendJson(res, 200, { ok: false, error: 'broadcast failed: ' + (e?.shortMessage || e?.message || 'unknown') });
    }
  });
}

function serveFile(res, filePath) {
  fs.readFile(filePath, (err, buf) => {
    if (err) return send(res, 404, 'Not Found');
    const ext = path.extname(filePath).toLowerCase();
    send(res, 200, buf, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
  });
}

const server = http.createServer((req, res) => {
  let urlPath;
  try {
    urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch {
    return send(res, 400, 'Bad Request');
  }
  if (urlPath === RPC_PATH) return proxyRpc(req, res);
  if (urlPath === '/api/settle') return handleSettle(req, res);
  if (req.method !== 'GET' && req.method !== 'HEAD') return send(res, 405, 'Method Not Allowed');
  let filePath = path.join(root, urlPath === '/' ? 'index.html' : urlPath);
  if (!filePath.startsWith(root)) return send(res, 403, 'Forbidden');
  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
  }
  if (fs.existsSync(filePath)) {
    let real;
    try {
      real = fs.realpathSync(filePath);
      if (!real.startsWith(root)) return send(res, 403, 'Forbidden');
    } catch {
      return send(res, 404, 'Not Found');
    }
    return serveFile(res, real);
  }
  if (!path.extname(urlPath)) return serveFile(res, path.join(root, 'index.html'));
  send(res, 404, 'Not Found');
});

server.on('error', (err) => {
  console.error(`server error: ${err.message}`);
  process.exit(1);
});

server.listen(port, host, () => {
  console.log(`serving ${root} on http://${host}:${port}`);
});