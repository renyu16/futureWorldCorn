// Proxied WebSocket: routes wss:// through Clash (127.0.0.1:7897).
// Replaces global.WebSocket so @walletconnect sign-client auto-uses it.
// Implements both the browser WebSocket API (addEventListener) AND the
// @walletconnect jsonrpc-ws-connection legacy style: onopen/onmessage/onclose/onerror
// as well as on()/off()/once() EventEmitter methods.
const WsApi = require('ws');
const { HttpsProxyAgent } = require('https-proxy-agent');
const { EventEmitter } = require('events');

const PROXY = process.env.WC_PROXY || 'http://127.0.0.1:7897';
const agent = new HttpsProxyAgent(PROXY);

function openTunnel(host, port) {
  return new Promise((resolve, reject) => {
    const [ph, pp] = PROXY.replace(/^http:\/\//, '').split(':');
    const net = require('net');
    const tls = require('tls');
    const sock = net.connect(parseInt(pp, 10), ph, () => {
      sock.write(`CONNECT ${host}:${port} HTTP/1.1\r\nHost: ${host}:${port}\r\n\r\n`);
    });
    let buf = '';
    sock.on('data', (d) => {
      buf += d.toString('latin1');
      const idx = buf.indexOf('\r\n\r\n');
      if (idx === -1) return;
      const head = buf.slice(0, idx);
      const rest = buf.slice(idx + 4);
      if (!/^HTTP\/1\.[01] 200/i.test(head)) { sock.destroy(); return reject(new Error('CONNECT failed: ' + head.split('\r\n')[0])); }
      sock.removeAllListeners('data');
      sock.removeAllListeners('error');
      sock.setTimeout(0);
      try {
        const tlsSock = tls.connect({ socket: sock, servername: host }, () => {
          if (rest.length) tlsSock.unshift(Buffer.from(rest, 'latin1'));
          resolve(tlsSock);
        });
        tlsSock.on('error', reject);
      } catch (e) { reject(e); }
    });
    sock.on('error', reject);
    sock.setTimeout(12000, () => { sock.destroy(); reject(new Error('tunnel timeout')); });
  });
}

function createProxiedWebSocket(url, protocols) {
  console.log('[ws] URL=', String(url).slice(0, 180));
  let headers = undefined;
  let finalUrl = String(url);
  try {
    const u = new URL(finalUrl);
    const auth = u.searchParams.get('auth');
    if (auth) {
      headers = { Authorization: 'Bearer ' + auth };
      u.searchParams.delete('auth');
      finalUrl = u.toString();
    }
    console.log('[ws] AUTH moved to Bearer header, finalUrl=', finalUrl.slice(0, 100));
  } catch (e) { /* NOOP */ }
  if (Array.isArray(protocols)) {
    return new WsApi(finalUrl, protocols, { agent, headers });
  }
  return new WsApi(finalUrl, { agent, headers });
}

class ProxiedWebSocket {
  constructor(url, protocols) {
    this.url = String(url);
    this.readyState = 0;
    this.bufferedAmount = 0;
    this._emitter = new EventEmitter();
    this._emitter.setMaxListeners(50);
    this._ws = createProxiedWebSocket(this.url, protocols);
    this._ws.on('open', () => {
      this.readyState = 1;
      const evt = { type: 'open' };
      this._emitter.emit('open', evt);
      this._emitter.emit('_open', evt);
    });
    this._ws.on('message', (data, isBinary) => {
      const payload = isBinary ? Buffer.from(data) : String(data);
      const evt = {
        type: 'message',
        data: payload,
        target: this,
        currentTarget: this,
      };
      this._emitter.emit('message', evt);
      this._emitter.emit('_message', evt);
    });
    this._ws.on('error', (e) => { this._emitter.emit('error', e); });
    this._ws.on('unexpected-response', (req, res) => {
      let b = '';
      res.on('data', (c) => (b += c));
      res.on('end', () => {
        const msg = 'unexpected-response ' + res.statusCode + ' ' + b.slice(0, 120);
        console.log('[ws] ' + msg);
        this._emitter.emit('error', new Error(msg));
      });
    });
    this._ws.on('close', (code, reason) => {
      this.readyState = 3;
      this._emitter.emit('close', { type: 'close', code, reason });
    });
  }

  // ---- EventEmitter-style API (used by @walletconnect/jsonrpc-ws-connection) ----
  on(event, listener) {
    if (event === 'open') return this._emitter.on('_open', listener);
    if (event === 'message') return this._emitter.on('_message', listener);
    return this._emitter.on(event, listener);
  }
  once(event, listener) {
    if (event === 'open') return this._emitter.once('_open', listener);
    if (event === 'message') return this._emitter.once('_message', listener);
    return this._emitter.once(event, listener);
  }
  off(event, listener) {
    if (event === 'open') return this._emitter.off('_open', listener);
    if (event === 'message') return this._emitter.off('_message', listener);
    return this._emitter.off(event, listener);
  }
  removeListener(event, listener) { return this.off(event, listener); }

  // ---- Browser-style on* properties ----
  set onopen(fn) { if (fn) this._emitter.on('_open', fn); }
  set onmessage(fn) { if (fn) this._emitter.on('_message', fn); }
  set onclose(fn) { if (fn) this._emitter.on('close', fn); }
  set onerror(fn) { if (fn) this._emitter.on('error', fn); }
  get onopen() { return null; }
  get onmessage() { return null; }
  get onclose() { return null; }
  get onerror() { return null; }

  // ---- Browser-style addEventListener ----
  addEventListener(type, fn) {
    if (type === 'open') this._emitter.on('_open', fn);
    else if (type === 'message') this._emitter.on('_message', fn);
    else this._emitter.on(type, fn);
  }
  removeEventListener(type, fn) {
    if (type === 'open') this._emitter.off('_open', fn);
    else if (type === 'message') this._emitter.off('_message', fn);
    else this._emitter.off(type, fn);
  }

  send(data) {
    console.log('[ws-send]', String(data).slice(0, 100));
    this._ws.send(data);
  }
  close() { this._ws.close(); }
}

if (!process.env.WC_NO_PROXY) {
  global.WebSocket = ProxiedWebSocket;
}

module.exports = { setProxyEnv: () => { global.WebSocket = ProxiedWebSocket; }, openTunnel };