interface Env {
  GITHUB_APP_CLIENT_ID: string;
  GITHUB_APP_CLIENT_SECRET: string;
}

const CALLBACKS = new Set([
  'http://127.0.0.1:4000/admin/auth/callback/',
  'http://localhost:4000/admin/auth/callback/',
  'https://iyad-ayoub.github.io/astra-team.github.io/admin/auth/callback/'
]);
const ORIGINS = new Set([
  'http://127.0.0.1:4000',
  'http://localhost:4000',
  'https://iyad-ayoub.github.io'
]);
const TRANSACTION_TTL_MS = 10 * 60 * 1000;
const SESSION_MAX_TTL_MS = 8 * 60 * 60 * 1000;
const COOKIE_NAME = 'astra-cms-oauth';

type Transaction = {
  callback: string;
  challenge: string;
  expiresAt: number;
  nonce: string;
  state: string;
};

type Ticket = Transaction & { code: string };

function json(body: Record<string, unknown>, status: number, request: Request, headers: HeadersInit = {}) {
  const responseHeaders = new Headers(headers);
  responseHeaders.set('Content-Type', 'application/json; charset=utf-8');
  responseHeaders.set('Cache-Control', 'no-store');
  addCors(responseHeaders, request);
  return new Response(JSON.stringify(body), { status, headers: responseHeaders });
}

function addCors(headers: Headers, request: Request) {
  const origin = request.headers.get('Origin');
  if (origin && ORIGINS.has(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
    headers.set('Access-Control-Allow-Credentials', 'true');
    headers.set('Vary', 'Origin');
  }
}

function originAllowed(request: Request) {
  const origin = request.headers.get('Origin');
  return !!origin && ORIGINS.has(origin);
}

function encoded(bytes: Uint8Array) {
  let binary = '';
  bytes.forEach((byte) => { binary += String.fromCharCode(byte); });
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function decoded(value: string) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - value.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function encryptionKey(secret: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret));
  return crypto.subtle.importKey('raw', digest, { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
}

async function seal(value: Transaction | Ticket, secret: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipher = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    await encryptionKey(secret),
    new TextEncoder().encode(JSON.stringify(value))
  );
  return `${encoded(iv)}.${encoded(new Uint8Array(cipher))}`;
}

async function unseal<T>(value: string | undefined, secret: string): Promise<T | null> {
  if (!value || !value.includes('.')) return null;
  try {
    const [iv, cipher] = value.split('.', 2);
    const plain = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: decoded(iv) },
      await encryptionKey(secret),
      decoded(cipher)
    );
    return JSON.parse(new TextDecoder().decode(plain)) as T;
  } catch (_) {
    return null;
  }
}

function cookie(request: Request, name: string) {
  const entry = (request.headers.get('Cookie') || '').split(';').map((part) => part.trim()).find((part) => part.startsWith(`${name}=`));
  return entry ? entry.slice(name.length + 1) : undefined;
}

function transactionCookie(value: string, request: Request) {
  void request;
  return `${COOKIE_NAME}=${value}; HttpOnly; SameSite=None; Secure; Path=/; Max-Age=600`;
}

function clearTransactionCookie(request: Request) {
  void request;
  return `${COOKIE_NAME}=; HttpOnly; SameSite=None; Secure; Path=/; Max-Age=0`;
}

function equal(left: string, right: string) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return difference === 0;
}

async function challengeFor(verifier: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return encoded(new Uint8Array(digest));
}

function callbackAllowed(callback: string | null) {
  return !!callback && CALLBACKS.has(callback);
}

function githubCallback(request: Request) {
  return new URL('/oauth/callback', request.url).toString();
}

function safeErrorRedirect(callback: string, state: string, error: string) {
  const url = new URL(callback);
  url.searchParams.set('error', error);
  url.searchParams.set('state', state);
  return new Response(null, { status: 302, headers: { Location: url.toString(), 'Cache-Control': 'no-store' } });
}

async function authorize(request: Request, env: Env) {
  const url = new URL(request.url);
  const callback = url.searchParams.get('redirect_uri');
  const state = url.searchParams.get('state');
  const challenge = url.searchParams.get('code_challenge');
  const method = url.searchParams.get('code_challenge_method');
  if (url.searchParams.get('client_id') !== env.GITHUB_APP_CLIENT_ID || !callbackAllowed(callback) || !state || !challenge || method !== 'S256') {
    return json({ error: 'invalid_authorization_request' }, 400, request);
  }
  const transaction: Transaction = {
    callback: callback!, challenge, state,
    nonce: encoded(crypto.getRandomValues(new Uint8Array(24))),
    expiresAt: Date.now() + TRANSACTION_TTL_MS
  };
  const github = new URL('https://github.com/login/oauth/authorize');
  github.search = new URLSearchParams({
    client_id: env.GITHUB_APP_CLIENT_ID,
    redirect_uri: githubCallback(request),
    state,
    code_challenge: challenge,
    code_challenge_method: 'S256'
  }).toString();
  return new Response(null, { status: 302, headers: { Location: github.toString(), 'Set-Cookie': transactionCookie(await seal(transaction, env.GITHUB_APP_CLIENT_SECRET), request), 'Cache-Control': 'no-store' } });
}

async function oauthCallback(request: Request, env: Env) {
  const url = new URL(request.url);
  const transaction = await unseal<Transaction>(cookie(request, COOKIE_NAME), env.GITHUB_APP_CLIENT_SECRET);
  const state = url.searchParams.get('state') || '';
  const code = url.searchParams.get('code');
  if (!transaction || transaction.expiresAt < Date.now() || !equal(state, transaction.state)) {
    return new Response('Invalid or expired authentication request.', { status: 400, headers: { 'Cache-Control': 'no-store', 'Set-Cookie': clearTransactionCookie(request) } });
  }
  if (url.searchParams.get('error')) return safeErrorRedirect(transaction.callback, transaction.state, 'github_authorization_denied');
  if (!code) return new Response('Invalid or expired authentication request.', { status: 400, headers: { 'Cache-Control': 'no-store', 'Set-Cookie': clearTransactionCookie(request) } });
  const ticket = await seal({ ...transaction, code }, env.GITHUB_APP_CLIENT_SECRET);
  const redirect = new URL(transaction.callback);
  redirect.searchParams.set('ticket', ticket);
  redirect.searchParams.set('state', transaction.state);
  return new Response(null, { status: 302, headers: { Location: redirect.toString(), 'Set-Cookie': transactionCookie(await seal(transaction, env.GITHUB_APP_CLIENT_SECRET), request), 'Cache-Control': 'no-store' } });
}

async function exchange(request: Request, env: Env) {
  if (!originAllowed(request)) return json({ error: 'origin_not_allowed' }, 403, request);
  let body: { ticket?: string; state?: string; code_verifier?: string; redirect_uri?: string };
  try { body = await request.json(); } catch (_) { return json({ error: 'invalid_request' }, 400, request); }
  const ticket = await unseal<Ticket>(body.ticket, env.GITHUB_APP_CLIENT_SECRET);
  const transaction = await unseal<Transaction>(cookie(request, COOKIE_NAME), env.GITHUB_APP_CLIENT_SECRET);
  if (!ticket || !transaction || ticket.expiresAt < Date.now() || !callbackAllowed(body.redirect_uri || null) || !body.state || !body.code_verifier || !equal(ticket.state, body.state) || !equal(transaction.state, body.state) || !equal(ticket.nonce, transaction.nonce)) {
    return json({ error: 'invalid_or_expired_session' }, 400, request, { 'Set-Cookie': clearTransactionCookie(request) });
  }
  if (!equal(await challengeFor(body.code_verifier), ticket.challenge)) {
    return json({ error: 'invalid_or_expired_session' }, 400, request, { 'Set-Cookie': clearTransactionCookie(request) });
  }
  const github = await fetch('https://github.com/login/oauth/access_token', {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ client_id: env.GITHUB_APP_CLIENT_ID, client_secret: env.GITHUB_APP_CLIENT_SECRET, code: ticket.code, redirect_uri: githubCallback(request), code_verifier: body.code_verifier })
  });
  const result = await github.json() as { access_token?: string; expires_in?: number; error?: string };
  if (!github.ok || !result.access_token || result.error) {
    return json({ error: 'token_exchange_failed' }, 502, request, { 'Set-Cookie': clearTransactionCookie(request) });
  }
  const ttl = Math.min(Math.max(Number(result.expires_in) || SESSION_MAX_TTL_MS, 60 * 1000), SESSION_MAX_TTL_MS);
  return json({ access_token: result.access_token, expires_at: new Date(Date.now() + ttl).toISOString() }, 200, request, { 'Set-Cookie': clearTransactionCookie(request) });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') {
      if (!originAllowed(request)) return new Response(null, { status: 403 });
      const headers = new Headers({ 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type', 'Access-Control-Max-Age': '600' });
      addCors(headers, request);
      return new Response(null, { status: 204, headers });
    }
    if (request.method === 'GET' && url.pathname === '/authorize') return authorize(request, env);
    if (request.method === 'GET' && url.pathname === '/oauth/callback') return oauthCallback(request, env);
    if (request.method === 'POST' && url.pathname === '/session/exchange') return exchange(request, env);
    return json({ error: 'not_found' }, 404, request);
  }
};
