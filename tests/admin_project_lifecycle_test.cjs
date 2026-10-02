const assert = require('assert');
const fs = require('fs');
const { TextEncoder, TextDecoder } = require('util');
const { JSDOM, VirtualConsole } = require('jsdom');

const app = fs.readFileSync('assets/js/admin/app.js', 'utf8');
const id = 'project-test1234';
const record = {
  content_id: id, acronym: 'AST', title: 'Autonomous Systems Test', status: 'ongoing',
  scope: 'international', type: 'research-project', programme: null, start_date: '2026-01-01',
  end_date: null, kickoff_date: null, coordinator: 'Inria', astra_role: 'Research partner',
  partners: ['Inria'], summary: 'A project summary', external_url: null, cordis_url: null,
  cover_media_id: 'media-cover123', order: 9999
};
const markdown = `---\ncontent_id: "${id}"\nacronym: "AST"\norder: 9999\ntitle: "Autonomous Systems Test"\nstatus: "ongoing"\nscope: "international"\ntype: "research-project"\nprogramme: null\nstart_date: "2026-01-01"\nend_date: null\nkickoff_date: null\ncoordinator: "Inria"\nastra_role: "Research partner"\npartners: ["Inria"]\nsummary: "A project summary"\nexternal_url: null\ncordis_url: null\ncover_media_id: "media-cover123"\n---\n\n{% include project_details.html %}\n`;

function response(body, status = 200) {
  return { ok: status >= 200 && status < 300, status, json: async () => body, text: async () => JSON.stringify(body), blob: async () => ({ preview: true }) };
}

function formMarkup() {
  return `<form id="admin-github-project-form"><input id="admin-project-content-id"><input id="admin-project-acronym"><input id="admin-project-title"><select id="admin-project-status"><option value="ongoing">Ongoing</option><option value="completed">Completed</option></select><select id="admin-project-scope"><option value="national">National</option><option value="european">European</option><option value="international">International</option></select><select id="admin-project-type"><option value="research-project">Research project</option><option value="research-infrastructure">Research infrastructure</option><option value="joint-lab">Joint lab</option></select><select id="admin-project-cover-media-id"><option value="">No cover</option></select><div id="admin-project-cover-preview" hidden></div><textarea id="admin-project-summary"></textarea><textarea id="admin-project-astra-role"></textarea><input id="admin-project-programme"><input id="admin-project-start-date"><input id="admin-project-end-date"><input id="admin-project-kickoff-date"><input id="admin-project-coordinator"><textarea id="admin-project-partners"></textarea><input id="admin-project-external-url"><input id="admin-project-cordis-url"><button type="submit">Save draft</button></form><p id="admin-github-project-message"></p>`;
}

async function waitFor(predicate) {
  for (let i = 0; i < 100; i += 1) { if (predicate()) return; await new Promise((resolve) => setTimeout(resolve, 5)); }
  throw new Error('timed out waiting for project lifecycle');
}

async function main() {
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', (error) => { if (!/Not implemented: navigation/.test(error.message)) console.error(error); });
  const dom = new JSDOM(`<!doctype html><body data-admin-mode="github-route" data-admin-route="project-edit">${formMarkup()}<section id="admin-loading"></section><section id="admin-github-login"></section><section id="admin-github-dashboard"></section><section id="admin-denied"></section><strong id="admin-github-login"></strong><p id="admin-github-repository"></p><img id="admin-github-avatar"></body>`, { url: `http://127.0.0.1:4000/admin/projects/edit/?id=${id}`, runScripts: 'dangerously', virtualConsole });
  const { window } = dom;
  window.TextEncoder = TextEncoder; window.TextDecoder = TextDecoder; window.URL.createObjectURL = () => 'blob:preview';
  window.ASTRA_CMS_CONFIG = { githubAuth: { clientId: 'client', brokerUrl: 'https://broker.example', repoOwner: 'Iyad-Ayoub', repoName: 'astra-team.github.io' } };
  window.localStorage.setItem('astra-cms-session-handle', 'opaque-handle');
  let puts = 0; let lastPut; let writeMode = 'ok';
  window.fetch = async (url, options = {}) => {
    const value = String(url);
    if (value.startsWith('https://broker.example/session/restore')) return response({ access_token: 'token', expires_at: new Date(Date.now() + 3600000).toISOString() });
    if (!value.startsWith('https://api.github.com')) return response({});
    const path = value.slice('https://api.github.com'.length);
    if (path === '/user') return response({ login: 'editor', avatar_url: '' });
    if (path === '/repos/Iyad-Ayoub/astra-team.github.io') return response({ full_name: 'Iyad-Ayoub/astra-team.github.io', permissions: { push: true } });
    if (path.includes('/git/ref/heads/cms-drafts')) return response({ object: { sha: 'draft-branch' } });
    if (path.includes('/contents/cms/media/news/index.json')) return response({ sha: 'media-index', content: Buffer.from(JSON.stringify({ version: 1, items: [{ id: 'media-cover123', path: 'cms/media/news/media-cover123.png', filename: 'cover.png', mime: 'image/png', uploaded_at: '2026-01-01T00:00:00Z', alt_text: 'Cover' }] })).toString('base64') });
    if (path.includes('/contents/cms/media/news/media-cover123.png')) return response({});
    if (path.includes('/contents/cms/drafts/projects/')) {
      if (options.method === 'PUT') {
        if (writeMode === 'conflict') return response({ message: 'conflict' }, 409);
        if (writeMode === 'error') return response({ message: 'GitHub unavailable' }, 500);
        puts += 1; lastPut = JSON.parse(options.body); return response({ content: { sha: puts === 1 ? 'updated-sha' : 'updated-sha-2' } });
      }
      return response({ sha: 'original-sha', content: Buffer.from(markdown).toString('base64') });
    }
    if (options.method && options.method !== 'GET') throw new Error(`unexpected write: ${options.method} ${path}`);
    return response({});
  };
  window.eval(app);
  await waitFor(() => window.document.querySelector('#admin-project-title').value === record.title);
  const title = window.document.querySelector('#admin-project-title');
  const form = window.document.querySelector('#admin-github-project-form');
  const save = form.querySelector('button[type="submit"]');
  const message = window.document.querySelector('#admin-github-project-message');
  assert.strictEqual(save.disabled, true, 'existing project starts pristine');
  assert.strictEqual(message.textContent, '', 'existing project has no dirty message');
  assert.strictEqual(window.document.querySelector('#admin-project-cover-media-id').value, 'media-cover123', 'cover selection restores');
  await waitFor(() => window.document.querySelector('#admin-project-cover-preview img'));
  title.value = 'Changed project'; title.dispatchEvent(new window.Event('input', { bubbles: true }));
  assert.strictEqual(save.disabled, false); assert.ok(message.textContent.includes('Unsaved changes'));
  title.value = record.title; title.dispatchEvent(new window.Event('input', { bubbles: true }));
  assert.strictEqual(save.disabled, true, 'reverting restores pristine state');
  const cover = window.document.querySelector('#admin-project-cover-media-id');
  cover.value = ''; cover.dispatchEvent(new window.Event('change', { bubbles: true }));
  assert.strictEqual(save.disabled, false, 'cover change marks project dirty');
  cover.value = 'media-cover123'; cover.dispatchEvent(new window.Event('change', { bubbles: true }));
  assert.strictEqual(save.disabled, true, 'cover revert restores pristine state');
  form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.strictEqual(puts, 0, 'no-op save does not write');
  title.value = 'Changed project'; title.dispatchEvent(new window.Event('input', { bubbles: true }));
  form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
  await waitFor(() => puts === 1);
  assert.strictEqual(lastPut.branch, 'cms-drafts'); assert.strictEqual(lastPut.sha, 'original-sha');
  assert.ok(message.textContent.includes('Saved')); assert.strictEqual(save.disabled, true);
  title.value = 'Conflict project'; title.dispatchEvent(new window.Event('input', { bubbles: true }));
  writeMode = 'conflict'; form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
  await waitFor(() => message.textContent.includes('changed in GitHub'));
  assert.strictEqual(save.disabled, false, 'conflict leaves project editable');
  writeMode = 'error'; form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
  await waitFor(() => message.textContent.includes('GitHub unavailable'));
  assert.strictEqual(save.disabled, false, 'generic errors leave project editable');
  writeMode = 'ok';
  title.value = 'Changed again'; title.dispatchEvent(new window.Event('input', { bubbles: true }));
  const held = new Promise(() => {});
  const originalFetch = window.fetch;
  window.fetch = async (url, options = {}) => { if (options.method === 'PUT') return held; return originalFetch(url, options); };
  form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise((resolve) => setTimeout(resolve, 10));
  form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise((resolve) => setTimeout(resolve, 10));
  assert.strictEqual(puts, 1, 'duplicate submissions are blocked');

  const newDom = new JSDOM(`<!doctype html><body data-admin-mode="github-route" data-admin-route="project-new">${formMarkup()}<section class="astra-admin-publication"><p id="admin-project-publication-status">Checking publication status…</p><button id="admin-project-publish" type="button">Submit for publication</button><button id="admin-project-update" type="button">Submit update</button><button id="admin-project-refresh" type="button">Refresh publication</button><button id="admin-project-publish-now" type="button">Publish now</button><button id="admin-project-unpublish" type="button">Unpublish from website</button><p id="admin-project-publication-message"></p></section><section id="admin-loading"></section><section id="admin-github-login"></section><section id="admin-github-dashboard"></section><section id="admin-denied"></section><strong id="admin-github-login"></strong><p id="admin-github-repository"></p><img id="admin-github-avatar"></body>`, { url: 'http://127.0.0.1:4000/admin/projects/new/', runScripts: 'dangerously', virtualConsole });
  newDom.window.TextEncoder = TextEncoder; newDom.window.TextDecoder = TextDecoder;
  newDom.window.ASTRA_CMS_CONFIG = window.ASTRA_CMS_CONFIG;
  newDom.window.localStorage.setItem('astra-cms-session-handle', 'opaque-handle');
  let newPut; let newPublicationRequests = 0;
  newDom.window.fetch = async (url, options = {}) => {
    const value = String(url);
    if (value.startsWith('https://broker.example/session/restore')) return response({ access_token: 'token', expires_at: new Date(Date.now() + 3600000).toISOString() });
    if (!value.startsWith('https://api.github.com')) return response({});
    const path = value.slice('https://api.github.com'.length);
    if (path.includes('/pulls') || path.includes('/contents/_projects') || path.includes('/git/ref/heads/cms-publish/')) newPublicationRequests += 1;
    if (path === '/user') return response({ login: 'editor' });
    if (path === '/repos/Iyad-Ayoub/astra-team.github.io') return response({ full_name: 'Iyad-Ayoub/astra-team.github.io', permissions: { push: true } });
    if (path.includes('/git/ref/heads/cms-drafts')) return response({ object: { sha: 'draft-branch' } });
    if (path.includes('/contents/cms/media/news/index.json')) return response({ sha: 'media-index', content: Buffer.from(JSON.stringify({ version: 1, items: [] })).toString('base64') });
    if (path.includes('/contents/cms/drafts/projects/') && options.method === 'PUT') { newPut = JSON.parse(options.body); return response({ content: { sha: 'new-sha' } }); }
    return response({});
  };
  newDom.window.eval(app);
  await waitFor(() => newDom.window.document.querySelector('#admin-project-publication-status').textContent === 'Draft');
  assert.strictEqual(newDom.window.document.querySelector('#admin-project-publication-status').textContent, 'Draft');
  assert.ok(newDom.window.document.querySelector('#admin-project-publication-message').textContent.includes('Save the project draft before publication becomes available.'));
  assert.strictEqual(newDom.window.document.querySelector('#admin-project-publish').hidden, true, 'unsaved Project cannot submit publication');
  assert.strictEqual(newPublicationRequests, 0, 'unsaved Project skips publication-status requests');
  const newDocument = newDom.window.document;
  [['acronym', 'NEW'], ['title', 'New project'], ['summary', 'Summary'], ['astra-role', 'Role']].forEach(([field, value]) => { newDocument.querySelector(`#admin-project-${field}`).value = value; });
  newDocument.querySelector('#admin-github-project-form').dispatchEvent(new newDom.window.Event('submit', { bubbles: true, cancelable: true }));
  await waitFor(() => newPut !== undefined);
  assert.match(newPut.branch, /^cms-drafts$/); assert.match(newPut.message, /^cms: create project draft project-/); assert.ok(!Object.prototype.hasOwnProperty.call(newPut, 'sha'), 'new project does not send a SHA');
  console.log('admin_project_lifecycle_test: ok');
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
