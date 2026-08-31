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
    const outReq = https.request(
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