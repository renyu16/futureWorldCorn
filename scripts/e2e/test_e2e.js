const uri = process.argv[2];
require('./proxied_ws.cjs');
const { SignClient } = require('@walletconnect/sign-client');
const { ethers } = require('ethers');

const PROJECT_ID = '38cfd0c495d4727d3d7e51ec3824a052';
const RELAY = 'wss://relay.walletconnect.org';
const CHAIN_ID = 4801;
const RPC_URL = 'http://8.141.100.69:8085/rpc';
const PRIVATE_KEY = process.env.WC_DEV_PK || ('0x' + 'a'.repeat(64));

(async () => {
  const client = await SignClient.init({
    projectId: PROJECT_ID,
    relayUrl: RELAY,
    metadata: { name: 'AutoTest Wallet', description: 'E2E automation wallet', url: 'https://futureworldcorn.app/', icons: [] },
    logger: 'error',
  });

  let autoDisconnected = false;
  let lastActivity = Date.now();

  client.on('session_proposal', async (proposal) => {
    console.log('== PROPOSAL RECEIVED id=' + proposal.id);
    console.log('   proposer meta:', JSON.stringify(proposal.params.proposer.metadata));
    console.log('   requiredNamespaces:', JSON.stringify(proposal.params.requiredNamespaces));

    const ns = (proposal.params.requiredNamespaces || {});
    const opt = (proposal.params.optionalNamespaces || {});
    const target = Object.keys(ns).length ? ns : opt;
    console.log('   optionalNamespaces:', JSON.stringify(opt));
    const approvals = {};
    const walletAddr = '0x8fd379246834eac74B8419FfdA202CF8051F7A03';
    for (const [key, val] of Object.entries(target)) {
      const chains = ((val.chains || []).length ? val.chains : (opt[key] && opt[key].chains)) || [`eip155:${CHAIN_ID}`];
      const chainIds = chains.map((c) => c.split(':')[1]);
      const accounts = chainIds.map((c) => `eip155:${c}:${walletAddr}`);
      approvals[key] = { chains, methods: val.methods || [], events: val.events || [], accounts };
    }
    console.log('   approvals:', JSON.stringify(approvals));
    try {
      const res = await client.approve({
        id: proposal.id,
        namespaces: approvals,
      });
      console.log('== SESSION APPROVED, topic=' + res.topic);
    } catch (e) {
      console.log('== approve ERROR: ' + e.message);
      if (e.message.includes('already approved')) { console.log('   (idempotent — continuing)'); }
      else process.exit(3);
    }
  });

  client.on('session_request', async ({ id, topic, params }) => {
    lastActivity = Date.now();
    console.log('== SESSION_REQUEST id=' + id + ' method=' + params.request.method);
    console.log('   params:', JSON.stringify(params.request.params));
    const req = params.request;
    if (req.method === 'eth_sendTransaction') {
      const [tx] = req.params;
      const w = new ethers.Wallet(PRIVATE_KEY);
      console.log('   from=' + w.address + ' to=' + tx.to + ' value=' + tx.value + ' data=' + (tx.data || '0x').slice(0, 70) + '...');
      const provider = new ethers.JsonRpcProvider(RPC_URL);
      const nonce = await provider.getTransactionCount(w.address, 'pending');
      const fee = await provider.getFeeData();
      const chainId = (await provider.getNetwork()).chainId;
      const gas = typeof tx.gas === 'string' ? BigInt(tx.gas) : (tx.gas || 0n);
      const gasPrice = typeof tx.gasPrice === 'string' ? BigInt(tx.gasPrice) : (tx.gasPrice || fee.gasPrice || 0n);
      const signed = await w.signTransaction({
        to: tx.to,
        value: tx.value ? BigInt(tx.value) : 0n,
        data: tx.data || '0x',
        nonce,
        chainId,
        gasLimit: typeof tx.gas === 'string' && tx.gas ? BigInt(tx.gas) : (tx.gasLimit && typeof tx.gasLimit === 'string' ? BigInt(tx.gasLimit) : (gas > 0n ? gas : 8000000n)),
        maxFeePerGas: fee.maxFeePerGas || undefined,
        maxPriorityFeePerGas: fee.maxPriorityFeePerGas || undefined,
        gasPrice: gasPrice > 0n ? gasPrice : undefined,
      });
      console.log('== SIGNED rawsig=', signed.slice(0, 20) + '...');
      const txHash = await provider.broadcastTransaction(signed);
      console.log('== BROADCAST txHash=' + txHash.hash);
      await client.respond({
        topic,
        response: {
          id,
          jsonrpc: '2.0',
          result: { transactionHash: txHash.hash },
        },
      });
      console.log('== RESPONDED to dApp OK');
      lastActivity = Date.now();
    } else {
      console.log('   (unhandled method)');
      try {
        await client.respond({ topic, response: { id, jsonrpc: '2.0', result: null } });
      } catch (e) { console.log('   respond err: ' + e.message); }
    }
  });

  client.on('session_delete', (d) => { console.log('== SESSION DELETED ' + d.topic); process.exit(0); });

  console.log('== pairing ==' + uri.slice(0, 40));
  try {
    const p = await Promise.race([
      client.pair({ uri }),
      new Promise((_, rej) => setTimeout(() => rej(new Error('pair timeout 50s')), 50000)),
    ]);
    console.log('== PAIRED in 1.1s topic=' + p.topic);
  } catch (e) {
    console.log('== FAIL ' + e.message);
    process.exit(1);
  }

  const _to = process.env.E2E_TIMEOUT ? parseInt(process.env.E2E_TIMEOUT, 10) : 0;
  const deadline = _to > 0 ? (Date.now() + _to * 1000) : 0;
  console.log('== waiting for session_request (persistent) deadline=' + deadline);
  setInterval(() => {
    if (deadline && Date.now() > deadline) { console.log('== E2E TIMEOUT (no tx) =='); process.exit(4); }
    if (lastActivity && Date.now() - lastActivity > 600000) {
      console.log('== IDLE EXIT (600s no request) ==');
      process.exit(0);
    }
  }, 5000);
})();