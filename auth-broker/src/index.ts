interface Env {
  GITHUB_APP_CLIENT_ID: string;
  GITHUB_APP_CLIENT_SECRET: string;
  CMS_SESSIONS: KVNamespace;
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
const TICKET_TTL_MS = 60 * 1000;
const SESSION_MAX_TTL_MS = 8 * 60 * 60 * 1000;
const COOKIE_NAME = 'astra-cms-oauth';
const SESSION_COOKIE_NAME = 'astra-cms-session';

type Transaction = {
  callback: string;
  expiresAt: number;
  nonce: string;
  pkceVerifier: string;
  returnTo: string;
  state: string;
};

type Ticket = {
  accessToken: string;
  callback: string;
  expiresAt: number;
  nonce: string;
  returnTo: string;
  sessionExpiresAt: string;
};
type BrowserSession = Omit<Ticket, 'expiresAt' | 'nonce'>;

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

async function seal(value: Transaction | Ticket | BrowserSession, secret: string) {
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
function sessionCookie(value: string) { return `${SESSION_COOKIE_NAME}=${value}; HttpOnly; SameSite=None; Secure; Path=/; Max-Age=${SESSION_MAX_TTL_MS / 1000}`; }
function clearSessionCookie() { return `${SESSION_COOKIE_NAME}=; HttpOnly; SameSite=None; Secure; Path=/; Max-Age=0`; }

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

function randomValue() {
  return encoded(crypto.getRandomValues(new Uint8Array(32)));
}

function sessionTtlMs(expiresIn: unknown) {
  const seconds = Number(expiresIn);
  const milliseconds = Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : SESSION_MAX_TTL_MS;
  return Math.min(Math.max(milliseconds, 60 * 1000), SESSION_MAX_TTL_MS);
}

async function sessionKey(handle: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(handle));
  return `session:${encoded(new Uint8Array(digest))}`;
}

function callbackAllowed(callback: string | null) {
  return !!callback && CALLBACKS.has(callback);
}

function returnToAllowed(returnTo: string | null, callback: string) {
  if (!returnTo || !returnTo.startsWith('/') || returnTo.startsWith('//')) return false;
  const candidate = new URL(returnTo, callback);
  const allowedCallback = new URL(callback);
  const adminRoot = allowedCallback.pathname.replace(/auth\/callback\/$/, '');
  return candidate.origin === allowedCallback.origin && candidate.pathname.startsWith(adminRoot);
}

function githubCallback(request: Request) {
  return new URL('/oauth/callback', request.url).toString();
}

function safeErrorRedirect(callback: string, state: string, error: string, request: Request) {
  const url = new URL(callback);
  url.searchParams.set('error', error);
  url.searchParams.set('state', state);
  return new Response(null, { status: 302, headers: { Location: url.toString(), 'Cache-Control': 'no-store', 'Set-Cookie': clearTransactionCookie(request) } });
}

async function authorize(request: Request, env: Env) {
  const url = new URL(request.url);
  const callback = url.searchParams.get('redirect_uri');
  const returnTo = url.searchParams.get('return_to');
  if (!callbackAllowed(callback) || !returnToAllowed(returnTo, callback!)) {
    return json({ error: 'invalid_authorization_request' }, 400, request);
  }
  const pkceVerifier = randomValue();
  const state = randomValue();
  const transaction: Transaction = {
    callback: callback!, pkceVerifier, returnTo: returnTo!, state,
    nonce: encoded(crypto.getRandomValues(new Uint8Array(24))),
    expiresAt: Date.now() + TRANSACTION_TTL_MS
  };
  const github = new URL('https://github.com/login/oauth/authorize');
  github.search = new URLSearchParams({
    client_id: env.GITHUB_APP_CLIENT_ID,
    redirect_uri: githubCallback(request),
    state,
    code_challenge: await challengeFor(pkceVerifier),
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
  if (url.searchParams.get('error')) return safeErrorRedirect(transaction.callback, transaction.state, 'github_authorization_denied', request);
  if (!code) return new Response('Invalid or expired authentication request.', { status: 400, headers: { 'Cache-Control': 'no-store', 'Set-Cookie': clearTransactionCookie(request) } });
  const github = await fetch('https://github.com/login/oauth/access_token', {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ client_id: env.GITHUB_APP_CLIENT_ID, client_secret: env.GITHUB_APP_CLIENT_SECRET, code, redirect_uri: githubCallback(request), code_verifier: transaction.pkceVerifier })
  });
  const result = await github.json() as { access_token?: string; expires_in?: number; error?: string };
  if (!github.ok || !result.access_token || result.error) return safeErrorRedirect(transaction.callback, transaction.state, 'token_exchange_failed', request);
  const ticket = await seal({
    accessToken: result.access_token,
    callback: transaction.callback,
    expiresAt: Math.min(transaction.expiresAt, Date.now() + TICKET_TTL_MS),
    nonce: randomValue(),
    returnTo: transaction.returnTo,
    sessionExpiresAt: new Date(Date.now() + sessionTtlMs(result.expires_in)).toISOString()
  }, env.GITHUB_APP_CLIENT_SECRET);
  const redirect = new URL(transaction.callback);
  redirect.searchParams.set('ticket', ticket);
  return new Response(null, { status: 302, headers: { Location: redirect.toString(), 'Set-Cookie': clearTransactionCookie(request), 'Cache-Control': 'no-store' } });
}

async function exchange(request: Request, env: Env) {
  if (!originAllowed(request)) return json({ error: 'origin_not_allowed' }, 403, request);
  let body: { ticket?: string; redirect_uri?: string };
  try { body = await request.json(); } catch (_) { return json({ error: 'invalid_request' }, 400, request); }
  const ticket = await unseal<Ticket>(body.ticket, env.GITHUB_APP_CLIENT_SECRET);
  if (!ticket || ticket.expiresAt < Date.now() || !ticket.nonce || !callbackAllowed(body.redirect_uri || null) || !equal(ticket.callback, body.redirect_uri || '') || !returnToAllowed(ticket.returnTo, ticket.callback)) {
    return json({ error: 'invalid_or_expired_session' }, 400, request);
  }
  const browserSession: BrowserSession & { origin: string } = { accessToken: ticket.accessToken, callback: ticket.callback, returnTo: ticket.returnTo, sessionExpiresAt: ticket.sessionExpiresAt, origin: request.headers.get('Origin') || '' };
  const handle = randomValue();
  await env.CMS_SESSIONS.put(await sessionKey(handle), JSON.stringify(browserSession), { expirationTtl: Math.max(60, Math.floor((Date.parse(ticket.sessionExpiresAt) - Date.now()) / 1000)) });
  return json({ access_token: ticket.accessToken, expires_at: ticket.sessionExpiresAt, return_to: ticket.returnTo, session_handle: handle }, 200, request);
}

async function restore(request: Request, env: Env) {
  if (!originAllowed(request)) return json({ error: 'origin_not_allowed' }, 403, request);
  let body: { redirect_uri?: string; session_handle?: string };
  try { body = await request.json(); } catch (_) { return json({ error: 'invalid_request' }, 400, request); }
  const handle = body.session_handle || '';
  const serialized = handle ? await env.CMS_SESSIONS.get(await sessionKey(handle)) : null;
  const session = serialized ? JSON.parse(serialized) as BrowserSession & { origin: string } : null;
  if (!session || Date.parse(session.sessionExpiresAt) <= Date.now() || !equal(session.origin, request.headers.get('Origin') || '') || !callbackAllowed(body.redirect_uri || null) || !equal(session.callback, body.redirect_uri || '') || !returnToAllowed(session.returnTo, session.callback)) return json({ error: 'invalid_or_expired_session' }, 401, request);
  return json({ access_token: session.accessToken, expires_at: session.sessionExpiresAt, return_to: session.returnTo }, 200, request);
}

async function logout(request: Request, env: Env) {
  if (!originAllowed(request)) return json({ error: 'origin_not_allowed' }, 403, request);
  let body: { session_handle?: string }; try { body = await request.json(); } catch (_) { body = {}; }
  if (body.session_handle) await env.CMS_SESSIONS.delete(await sessionKey(body.session_handle));
  return json({ ok: true }, 200, request);
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
    if (request.method === 'POST' && url.pathname === '/session/restore') return restore(request, env);
    if (request.method === 'POST' && url.pathname === '/session/logout') return logout(request, env);
    return json({ error: 'not_found' }, 404, request);
  }
};
