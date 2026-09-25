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
  accessExpiresAt: number;
  callback: string;
  expiresAt: number;
  nonce: string;
  returnTo: string;
};
type SessionRecord = {
  accessToken: string;
  accessExpiresAt: number;
  callback: string;
  returnTo: string;
  origin: string;
  createdAt: number;
  updatedAt: number;
  identity?: { login: string; avatarUrl: string; repository: { fullName: string; push: boolean } };
};
type GitHubTokenResponse = { access_token?: string; expires_in?: number; error?: string };
type PublicSession = { authenticated: true; session_handle: string; expires_at: string; return_to: string; login: string; avatar_url: string; repository: { full_name: string; push: boolean } };
type SessionResult = { handle: string; session: SessionRecord };

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

async function seal(value: unknown, secret: string) {
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

function randomValue() {
  return encoded(crypto.getRandomValues(new Uint8Array(32)));
}


function expiryFromSeconds(seconds: unknown, fallback: number) {
  const value = Number(seconds);
  return Date.now() + (Number.isFinite(value) && value > 0 ? Math.min(value * 1000, SESSION_MAX_TTL_MS) : fallback);
}

function validHandle(handle: string) {
  return /^[A-Za-z0-9_-]{32,}$/.test(handle);
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
  const result = await github.json() as GitHubTokenResponse;
  if (!github.ok || !result.access_token || result.error) return safeErrorRedirect(transaction.callback, transaction.state, 'token_exchange_failed', request);
  const accessExpiresAt = expiryFromSeconds(result.expires_in, SESSION_MAX_TTL_MS);
  const ticket = await seal({
    accessToken: result.access_token,
    accessExpiresAt,
    callback: transaction.callback,
    expiresAt: Math.min(transaction.expiresAt, Date.now() + TICKET_TTL_MS),
    nonce: randomValue(),
    returnTo: transaction.returnTo
  }, env.GITHUB_APP_CLIENT_SECRET);
  const redirect = new URL(transaction.callback);
  redirect.searchParams.set('ticket', ticket);
  return new Response(null, { status: 302, headers: { Location: redirect.toString(), 'Set-Cookie': clearTransactionCookie(request), 'Cache-Control': 'no-store' } });
}

function githubApiRequest(accessToken: string, path: string, options: RequestInit = {}) {
  const headers = new Headers(options.headers || {});
  headers.set('Accept', 'application/vnd.github+json');
  headers.set('Authorization', `Bearer ${accessToken}`);
  headers.set('X-GitHub-Api-Version', '2022-11-28');
  if (options.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  return fetch(`https://api.github.com${path}`, { ...options, headers });
}

async function saveSession(handle: string, session: SessionRecord, env: Env) {
  const sessionExpiresAt = session.accessExpiresAt;
  if (sessionExpiresAt <= Date.now()) throw new Error('session_expired');
  await env.CMS_SESSIONS.put(await sessionKey(handle), await seal(session, env.GITHUB_APP_CLIENT_SECRET), { expirationTtl: Math.max(60, Math.floor((sessionExpiresAt - Date.now()) / 1000)) });
}

async function loadSession(handle: string, env: Env): Promise<SessionRecord | null> {
  if (!validHandle(handle)) return null;
  const serialized = await env.CMS_SESSIONS.get(await sessionKey(handle));
  const session = await unseal<SessionRecord>(serialized || undefined, env.GITHUB_APP_CLIENT_SECRET);
  if (!session || typeof session.accessToken !== 'string' || !Number.isFinite(session.accessExpiresAt) || typeof session.callback !== 'string' || typeof session.returnTo !== 'string' || typeof session.origin !== 'string') return null;
  if (session.accessExpiresAt <= Date.now()) return null;
  return session;
}

async function usableSession(handle: string, env: Env): Promise<SessionRecord | null> {
  try {
    const session = await loadSession(handle, env);
    if (session) return session;
    try { await env.CMS_SESSIONS.delete(await sessionKey(handle)); } catch (_) {}
    return null;
  } catch (_) {
    try { await env.CMS_SESSIONS.delete(await sessionKey(handle)); } catch (_) {}
    return null;
  }
}

async function identityFor(session: SessionRecord) {
  const userResponse = await githubApiRequest(session.accessToken, '/user');
  if (userResponse.status === 401) throw new Error('authentication_required');
  if (!userResponse.ok) throw new Error('github_identity_unavailable');
  const user = await userResponse.json() as { login?: string; avatar_url?: string };
  const repositoryPath = '/repos/Iyad-Ayoub/astra-team.github.io';
  const repositoryResponse = await githubApiRequest(session.accessToken, repositoryPath);
  if (repositoryResponse.status === 401) throw new Error('authentication_required');
  if (!repositoryResponse.ok) throw new Error('repository_access_unavailable');
  const repository = await repositoryResponse.json() as { full_name?: string; permissions?: { push?: boolean } };
  if (!user.login || !repository.full_name || !repository.permissions || repository.permissions.push !== true) throw new Error('repository_write_access_required');
  return { login: user.login, avatarUrl: user.avatar_url || '', repository: { fullName: repository.full_name, push: repository.permissions.push === true } };
}

function publicSession(handle: string, session: SessionRecord): PublicSession {
  return { authenticated: true, session_handle: handle, expires_at: new Date(session.accessExpiresAt).toISOString(), return_to: session.returnTo, login: session.identity?.login || '', avatar_url: session.identity?.avatarUrl || '', repository: { full_name: session.identity?.repository.fullName || 'Iyad-Ayoub/astra-team.github.io', push: session.identity?.repository.push === true } };
}

async function exchangeSession(body: { ticket?: string; redirect_uri?: string }, request: Request, env: Env): Promise<SessionResult | Response> {
  const ticket = await unseal<Ticket>(body.ticket, env.GITHUB_APP_CLIENT_SECRET);
  if (!ticket || ticket.expiresAt < Date.now() || !ticket.nonce || !callbackAllowed(body.redirect_uri || null) || !equal(ticket.callback, body.redirect_uri || '') || !returnToAllowed(ticket.returnTo, ticket.callback)) {
    return json({ error: 'invalid_or_expired_session' }, 400, request);
  }
  const session: SessionRecord = { accessToken: ticket.accessToken, accessExpiresAt: ticket.accessExpiresAt, callback: ticket.callback, returnTo: ticket.returnTo, origin: request.headers.get('Origin') || '', createdAt: Date.now(), updatedAt: Date.now() };
  const handle = randomValue();
  try {
    session.identity = await identityFor(session);
    await saveSession(handle, session, env);
    return { handle, session };
  } catch (error) {
    await env.CMS_SESSIONS.delete(await sessionKey(handle));
    return json({ error: error instanceof Error && error.message === 'authentication_required' ? 'authentication_required' : 'repository_access_required' }, 401, request);
  }
}

async function exchange(request: Request, env: Env, safe = true) {
  if (!originAllowed(request)) return json({ error: 'origin_not_allowed' }, 403, request);
  let body: { ticket?: string; redirect_uri?: string };
  try { body = await request.json(); } catch (_) { return json({ error: 'invalid_request' }, 400, request); }
  const result = await exchangeSession(body, request, env);
  if (result instanceof Response) return result;
  return json(safe ? publicSession(result.handle, result.session) : { access_token: result.session.accessToken, expires_at: new Date(result.session.accessExpiresAt).toISOString(), return_to: result.session.returnTo, session_handle: result.handle }, 200, request);
}

async function restoreSession(body: { redirect_uri?: string; session_handle?: string }, request: Request, env: Env): Promise<SessionResult | Response> {
  const handle = body.session_handle || '';
  let session = await usableSession(handle, env);
  if (!session || !equal(session.origin, request.headers.get('Origin') || '') || !callbackAllowed(body.redirect_uri || null) || !equal(session.callback, body.redirect_uri || '') || !returnToAllowed(session.returnTo, session.callback)) return json({ error: 'invalid_or_expired_session' }, 401, request);
  try {
    session.identity = await identityFor(session);
    session.updatedAt = Date.now();
    await saveSession(handle, session, env);
    return { handle, session };
  } catch (_) {
    await env.CMS_SESSIONS.delete(await sessionKey(handle));
    return json({ error: 'authentication_required' }, 401, request);
  }
}

async function restore(request: Request, env: Env, safe = true) {
  if (!originAllowed(request)) return json({ error: 'origin_not_allowed' }, 403, request);
  let body: { redirect_uri?: string; session_handle?: string };
  try { body = await request.json(); } catch (_) { return json({ error: 'invalid_request' }, 400, request); }
  const result = await restoreSession(body, request, env);
  if (result instanceof Response) return result;
  return json(safe ? publicSession(result.handle, result.session) : { access_token: result.session.accessToken, expires_at: new Date(result.session.accessExpiresAt).toISOString(), return_to: result.session.returnTo, session_handle: result.handle }, 200, request);
}

const REPO_PREFIX = '/repos/Iyad-Ayoub/astra-team.github.io';

function cmsId(value: unknown) {
  return typeof value === 'string' && /^news-[a-z0-9]+$/.test(value) ? value : null;
}

function mediaId(value: unknown) {
  return typeof value === 'string' && /^media-[a-z0-9]+$/.test(value) ? value : null;
}

function cmsBranch(id: string, kind: string) {
  if (kind === 'draft') return 'cms-drafts';
  if (kind === 'publish') return `cms-publish/news/${id}`;
  if (kind === 'unpublish') return `cms-unpublish/news/${id}`;
  return null;
}

function publicNewsFile(path: unknown) {
  return typeof path === 'string' && /^_news\/[a-z0-9-]+\.md$/.test(path) ? path : null;
}

async function githubJson(session: SessionRecord, path: string, method = 'GET', body?: unknown) {
  const response = await githubApiRequest(session.accessToken, path, { method, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await response.text();
  let data: any = {};
  try { data = text ? JSON.parse(text) : {}; } catch (_) { data = {}; }
  if (!response.ok) { const error = new Error(data.message || 'GitHub request failed.'); (error as any).status = response.status; throw error; }
  return data;
}

async function cmsOperation(operation: string, payload: any, session: SessionRecord) {
  const base = REPO_PREFIX;
  if (operation === 'draft_list') return githubJson(session, `${base}/contents/cms/drafts/news?ref=cms-drafts`);
  if (operation === 'draft_get') {
    const id = cmsId(payload.id); if (!id) throw new Error('invalid_draft_id');
    return githubJson(session, `${base}/contents/cms/drafts/news/${id}.md?ref=cms-drafts`);
  }
  if (operation === 'draft_save') {
    const id = cmsId(payload.id); if (!id || typeof payload.content !== 'string' || payload.content.length > 40000) throw new Error('invalid_draft');
    const body: any = { message: payload.sha ? `cms: update news draft ${id}` : `cms: create news draft ${id}`, content: payload.content, branch: 'cms-drafts' };
    if (typeof payload.sha === 'string') body.sha = payload.sha;
    return githubJson(session, `${base}/contents/cms/drafts/news/${id}.md`, 'PUT', body);
  }
  if (operation === 'media_index') {
    try { return await githubJson(session, `${base}/contents/cms/media/news/index.json?ref=cms-drafts`); } catch (error) { if ((error as any).status === 404) return { content: encoded(new TextEncoder().encode('{"version":1,"items":[]}')), sha: null }; throw error; }
  }
  if (operation === 'media_get') {
    const id = mediaId(payload.id); const extension = typeof payload.extension === 'string' && /^(?:jpg|png|webp)$/.test(payload.extension) ? payload.extension : null;
    if (!id || !extension) throw new Error('invalid_media_id');
    return githubJson(session, `${base}/contents/cms/media/news/${id}.${extension}?ref=cms-drafts`);
  }
  if (operation === 'media_upload') {
    const id = mediaId(payload.id); const extension = typeof payload.extension === 'string' && /^(?:jpg|png|webp)$/.test(payload.extension) ? payload.extension : null;
    if (!id || !extension || typeof payload.content !== 'string' || !/^[A-Za-z0-9+/=]+$/.test(payload.content) || !payload.metadata || typeof payload.metadata.filename !== 'string' || !/^[^\r\n]{1,180}$/.test(payload.metadata.filename) || !/^(?:image\/(?:jpeg|png|webp))$/.test(payload.metadata.mime || '') || (payload.metadata.alt_text && (typeof payload.metadata.alt_text !== 'string' || payload.metadata.alt_text.length > 300))) throw new Error('invalid_media');
    const index = await cmsOperation('media_index', {}, session);
    const decodedIndex = JSON.parse(new TextDecoder().decode(decoded(index.content || '')));
    const items = Array.isArray(decodedIndex.items) ? decodedIndex.items : [];
    if (items.some((item: any) => item && item.id === id)) throw new Error('media_conflict');
    await githubJson(session, `${base}/contents/cms/media/news/${id}.${extension}`, 'PUT', { message: `cms: create media ${id}`, content: payload.content, branch: 'cms-drafts' });
    const item = { id, path: `cms/media/news/${id}.${extension}`, filename: payload.metadata.filename, mime: payload.metadata.mime, uploaded_at: payload.metadata.uploaded_at, alt_text: payload.metadata.alt_text || null };
    const updated = { items: items.concat([item]) };
    const indexBody: any = { message: `cms: index media ${id}`, content: encoded(new TextEncoder().encode(JSON.stringify(updated))), branch: 'cms-drafts' };
    if (index.sha) indexBody.sha = index.sha;
    await githubJson(session, `${base}/contents/cms/media/news/index.json`, 'PUT', indexBody);
    return item;
  }
  if (operation === 'draft_branch') return githubJson(session, `${base}/git/ref/heads/cms-drafts`);
  if (operation === 'ensure_draft_branch') {
    const main = await githubJson(session, `${base}/git/ref/heads/main`);
    return githubJson(session, `${base}/git/refs`, 'POST', { ref: 'refs/heads/cms-drafts', sha: main.object.sha });
  }
  if (operation === 'ensure_branch') {
    const id = cmsId(payload.id); const kind = payload.kind === 'publish' || payload.kind === 'unpublish' ? payload.kind : null; const branch = id && kind ? cmsBranch(id, kind) : null;
    if (!id || !branch) throw new Error('invalid_lifecycle_branch');
    const main = await githubJson(session, `${base}/git/ref/heads/main`);
    try { return await githubJson(session, `${base}/git/refs`, 'POST', { ref: `refs/heads/${branch}`, sha: main.object.sha }); } catch (error) {
      if ((error as any).status !== 422) throw error;
      const closed = await githubJson(session, `${base}/pulls?state=closed&head=Iyad-Ayoub:${branch}`);
      if (!closed.some((pull: any) => pull.merged_at)) throw new Error('publication_branch_requires_review');
      return githubJson(session, `${base}/git/refs/heads/${branch}`, 'PATCH', { sha: main.object.sha, force: false });
    }
  }
  if (operation === 'publication_prepare') {
    const id = cmsId(payload.id); const branch = id && cmsBranch(id, 'publish');
    const newsPath = publicNewsFile(payload.news_path);
    if (!id || !branch || !newsPath || typeof payload.markdown !== 'string' || payload.markdown.includes('cms/')) throw new Error('invalid_publication');
    const ref = await githubJson(session, `${base}/git/ref/heads/${branch}`);
    const parent = await githubJson(session, `${base}/git/commits/${ref.object.sha}`);
    const files: Array<{ path: string; content: string }> = [{ path: newsPath, content: payload.markdown }];
    if (payload.media && typeof payload.media.content === 'string' && /^(?:jpg|png|webp)$/.test(payload.media.extension || '') && typeof payload.media.filename === 'string' && new RegExp(`^media-[a-z0-9]+\\.${payload.media.extension}$`).test(payload.media.filename)) files.push({ path: `assets/img/news/${id}/${payload.media.filename}`, content: payload.media.content });
    const blobs = await Promise.all(files.map((file) => githubJson(session, `${base}/git/blobs`, 'POST', { content: file.content, encoding: 'base64' })));
    const tree = await githubJson(session, `${base}/git/trees`, 'POST', { base_tree: parent.tree.sha, tree: files.map((file, index) => ({ path: file.path, mode: '100644', type: 'blob', sha: blobs[index].sha })) });
    const commit = await githubJson(session, `${base}/git/commits`, 'POST', { message: `cms: prepare news publication ${id}`, tree: tree.sha, parents: [ref.object.sha] });
    return githubJson(session, `${base}/git/refs/heads/${branch}`, 'PATCH', { sha: commit.sha, force: false });
  }
  if (operation === 'unpublish_prepare') {
    const id = cmsId(payload.id); const branch = id && cmsBranch(id, 'unpublish'); const path = publicNewsFile(payload.path);
    if (!id || !branch || !path) throw new Error('invalid_unpublish');
    const current = await githubJson(session, `${base}/contents/${path}?ref=main`);
    const currentMarkdown = new TextDecoder().decode(decoded(current.content || ''));
    if (!new RegExp(`^content_id: ["']?${id}["']?$`, 'm').test(currentMarkdown)) throw new Error('unpublish_content_mismatch');
    return githubJson(session, `${base}/contents/${path}`, 'DELETE', { message: `cms: unpublish news ${id}`, sha: current.sha, branch });
  }
  if (operation === 'published_find') {
    const id = cmsId(payload.id); if (!id) throw new Error('invalid_draft_id');
    const files = await githubJson(session, `${base}/contents/_news?ref=main`);
    for (const file of files) { const current = await githubJson(session, `${base}/contents/${publicNewsFile(file.path)}?ref=main`); const markdown = new TextDecoder().decode(decoded(current.content || '')); if (new RegExp(`^content_id: ["']?${id}["']?$`, 'm').test(markdown)) return { path: file.path, sha: current.sha, markdown }; }
    return null;
  }
  if (operation === 'public_file') {
    const branch = typeof payload.branch === 'string' && /^(?:main|cms-(?:publish|unpublish)\/news\/news-[a-z0-9]+)$/.test(payload.branch) ? payload.branch : null; const path = publicNewsFile(payload.path);
    if (!branch || !path) throw new Error('invalid_public_file');
    return githubJson(session, `${base}/contents/${path}?ref=${branch}`);
  }
  if (operation === 'pulls') {
    const id = cmsId(payload.id); const kind = payload.kind === 'publish' || payload.kind === 'unpublish' ? payload.kind : null; const branch = id && kind ? cmsBranch(id, kind) : null; const state = payload.state === 'closed' ? 'closed' : 'open';
    if (!branch) throw new Error('invalid_pull_query');
    return githubJson(session, `${base}/pulls?state=${state}&head=Iyad-Ayoub:${branch}`);
  }
  if (operation === 'create_pr') {
    const id = cmsId(payload.id); const kind = payload.kind === 'publish' || payload.kind === 'unpublish' ? payload.kind : null; const branch = id && kind ? cmsBranch(id, kind) : null;
    if (!id || !branch || typeof payload.title !== 'string' || typeof payload.body !== 'string') throw new Error('invalid_pull');
    return githubJson(session, `${base}/pulls`, 'POST', { title: payload.title, head: branch, base: 'main', body: payload.body });
  }
  if (operation === 'checks') {
    if (typeof payload.sha !== 'string' || !/^[0-9a-f]+$/.test(payload.sha)) throw new Error('invalid_commit');
    return githubJson(session, `${base}/commits/${payload.sha}/check-runs?filter=latest`);
  }
  throw new Error('operation_not_allowed');
}

async function v2Github(request: Request, env: Env) {
  if (!originAllowed(request)) return json({ error: 'origin_not_allowed' }, 403, request);
  let body: { session_handle?: string; operation?: string; payload?: any };
  try { body = await request.json(); } catch (_) { return json({ error: 'invalid_request' }, 400, request); }
  let session: SessionRecord | null = null;
  try { session = await usableSession(body.session_handle || '', env); } catch (_) { session = null; }
  if (!session || !equal(session.origin, request.headers.get('Origin') || '')) return json({ error: 'authentication_required' }, 401, request);
  try { return json(await cmsOperation(body.operation || '', body.payload || {}, session), 200, request); }
  catch (error) { if ((error as any).status === 401) { await env.CMS_SESSIONS.delete(await sessionKey(body.session_handle || '')); return json({ error: 'authentication_required' }, 401, request); } return json({ error: error instanceof Error ? error.message : 'cms_operation_failed' }, 400, request); }
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
    // TEMPORARY: legacy token responses remain only until the v2 frontend is
    // deployed and manually verified, then these routes must be removed.
    if (request.method === 'POST' && url.pathname === '/session/exchange') return exchange(request, env, false);
    if (request.method === 'POST' && url.pathname === '/session/restore') return restore(request, env, false);
    if (request.method === 'POST' && url.pathname === '/v2/session/exchange') return exchange(request, env, true);
    if (request.method === 'POST' && url.pathname === '/v2/session/restore') return restore(request, env, true);
    if (request.method === 'POST' && url.pathname === '/v2/session/logout') return logout(request, env);
    if (request.method === 'POST' && url.pathname === '/v2/github') return v2Github(request, env);
    if (request.method === 'POST' && url.pathname === '/session/logout') return logout(request, env);
    return json({ error: 'not_found' }, 404, request);
  }
};
