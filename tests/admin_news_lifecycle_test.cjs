const assert = require('assert');
const fs = require('fs');
const { TextEncoder, TextDecoder } = require('util');
const { JSDOM } = require('jsdom');

const app = fs.readFileSync('assets/js/admin/app.js', 'utf8');
const id = 'news-test1234';
const mediaId = 'media-test1234';
const draft = {
  content_id: id, title: 'Barcelona', type: 'event', summary: 'A summary',
  body: 'A body', content_date: '2026-01-01', event_date: '2026-01-02',
  end_date: null, location: null, external_url: null, featured: false,
  homepage: false, cover_media_id: mediaId, status: 'draft'
};
const draftMarkdown = `---\n${Object.entries(draft).filter(([key]) => key !== 'body').map(([key, value]) => `${key}: ${JSON.stringify(value)}`).join('\n')}\n---\n\n${draft.body}\n`;
const publishedPath = `_news/barcelona-test1234.md`;
const publishedMarkdown = `---\nlayout: "news"\ncontent_id: "${id}"\nslug: "barcelona-test1234"\ntitle: "Barcelona"\nstatus: "published"\ntype: "event"\nevent_date: "2026-01-02"\nsummary: "A summary"\nfeatured: false\nhomepage: false\ndate_precision: "day"\nimage: "/assets/img/news/${id}/media-test1234.png"\nimage_alt: "photo.png"\n---\n\nA body\n`;

function response(body, status = 200, headers = {}) {
  return { ok: status >= 200 && status < 300, status, headers: new Map(Object.entries(headers)), json: async () => body, text: async () => JSON.stringify(body), blob: async () => new Blob([Buffer.from('image')], { type: 'image/png' }) };
}

async function main() {
  const dom = new JSDOM(`<!doctype html><body data-admin-mode="github-route" data-admin-route="news-edit">
    <section id="admin-loading"></section><section id="admin-github-login" hidden></section><section id="admin-github-dashboard" hidden></section><section id="admin-denied" hidden></section>
    <strong id="admin-github-login"></strong><p id="admin-github-repository"></p><img id="admin-github-avatar" hidden>
    <form id="admin-github-news-form">
      <input id="admin-news-title"><select id="admin-news-type"><option value="event">Event</option></select>
      <textarea id="admin-news-summary"></textarea><textarea id="admin-news-body"></textarea>
      <input id="admin-news-content-date" type="date"><input id="admin-news-event-date" type="date"><input id="admin-news-end-date">
      <input id="admin-news-location"><input id="admin-news-external-url"><select id="admin-news-cover-media-id"></select>
      <div id="admin-news-event-fields"></div><input id="admin-news-featured" type="checkbox"><input id="admin-news-homepage" type="checkbox"><button type="submit">Save draft</button>
    </form><p id="admin-github-news-message"></p><p id="admin-publication-status"></p><button id="admin-news-publish"></button><button id="admin-news-update" hidden></button><button id="admin-news-refresh" hidden></button><button id="admin-news-publish-now" hidden></button><button id="admin-news-unpublish" hidden></button><p id="admin-publication-message"></p><div id="admin-news-cover-preview"></div>
  </body>`, { url: `http://127.0.0.1:4000/admin/news/edit/?id=${id}`, runScripts: 'dangerously', pretendToBeVisual: true });
  const { window } = dom;
  window.TextEncoder = TextEncoder;
  window.TextDecoder = TextDecoder;
  window.ASTRA_CMS_CONFIG = { githubAuth: { clientId: 'client', brokerUrl: 'https://broker.example', repoOwner: 'Iyad-Ayoub', repoName: 'astra-team.github.io' } };
  window.localStorage.setItem('astra-cms-session-handle', 'opaque-handle');
  window.sessionStorage.setItem(`astra-cms-deployment-sha-${id}`, 'merge-sha');
  let deploymentRuns = [{ id: 2, run_number: 11, name: 'Deploy astra-team with jekyll', head_sha: 'main-b', status: 'completed', conclusion: 'success', updated_at: '2026-01-01T00:01:00Z' }];
  let compareDescended = true;
  let openPulls = [];
  window.URL.createObjectURL = () => 'blob:preview';
  window.fetch = async (url, options = {}) => {
    const value = String(url);
    if (value.startsWith('https://broker.example/session/restore')) return response({ access_token: 'token', expires_at: new Date(Date.now() + 3600000).toISOString() });
    if (!value.startsWith('https://api.github.com')) return response({});
    const path = value.slice('https://api.github.com'.length);
    if (path === '/user') return response({ login: 'editor', avatar_url: '' });
    if (path === '/repos/Iyad-Ayoub/astra-team.github.io') return response({ full_name: 'Iyad-Ayoub/astra-team.github.io', permissions: { push: true } });
    if (path.includes('/collaborators/')) return response({ permission: 'write' });
    if (path.includes('/git/ref/heads/cms-drafts')) return response({ object: { sha: 'draft-branch' } });
    if (path.includes('/contents/cms/media/news/index.json')) return response({ sha: 'index-sha', content: Buffer.from(JSON.stringify({ version: 1, items: [{ id: mediaId, path: `cms/media/news/${mediaId}.png`, filename: 'photo.png', mime: 'image/png', uploaded_at: '2026-01-01T00:00:00Z', alt_text: null }] })).toString('base64') });
    if (path.includes('/contents/cms/drafts/news/')) return response({ sha: 'draft-sha', content: Buffer.from(draftMarkdown).toString('base64') });
    if (path.includes('/contents/_news?ref=main')) return response([{ path: publishedPath, name: 'barcelona-test1234.md' }]);
    if (path.includes('/contents/_news/')) return response({ sha: 'published-blob', content: Buffer.from(publishedMarkdown).toString('base64') });
    if (path.includes('/pulls?state=open')) return response(openPulls);
    if (path.includes('/compare/merge-sha...main-b')) return response(compareDescended ? { status: 'ahead', base_commit: { sha: 'merge-sha' }, merge_base_commit: { sha: 'merge-sha' } } : { status: 'ahead', base_commit: { sha: 'merge-sha' }, merge_base_commit: { sha: 'other' } });
    if (path.includes('/actions/runs')) return response({ workflow_runs: path.includes('head_sha=merge-sha') ? [{ id: 1, run_number: 10, name: 'Deploy astra-team with jekyll', head_sha: 'merge-sha', status: 'completed', conclusion: 'failure', updated_at: '2026-01-01T00:00:00Z' }] : deploymentRuns });
    if (path.includes('/contents/cms/media/news/media-test1234.png')) return response({}, 200);
    if (options.method && options.method !== 'GET') throw new Error(`unexpected write: ${options.method} ${path}`);
    return response({});
  };
  window.eval(app);
  for (let i = 0; i < 80 && window.document.querySelector('#admin-news-title').value !== draft.title; i += 1) await new Promise(r => setTimeout(r, 10));
  if (window.document.querySelector('#admin-news-title').value !== draft.title) console.error('boot message:', window.document.querySelector('#admin-github-news-message').textContent, draftMarkdown);
  const title = window.document.querySelector('#admin-news-title');
  const save = window.document.querySelector('#admin-github-news-form button[type="submit"]');
  assert.strictEqual(title.value, draft.title, 'existing draft should hydrate');
  assert.strictEqual(save.disabled, true, 'existing draft starts clean');
  assert.strictEqual(window.document.querySelector('#admin-github-news-message').textContent, '', 'no stale dirty message');
  title.value = 'Barcelona changed'; title.dispatchEvent(new window.Event('input', { bubbles: true }));
  assert.strictEqual(save.disabled, false, 'editing makes draft dirty');
  title.value = draft.title; title.dispatchEvent(new window.Event('input', { bubbles: true }));
  assert.strictEqual(save.disabled, true, 'reverting restores pristine state');
  let writes = 0;
  const originalFetch = window.fetch;
  window.fetch = async (url, options) => { if (options && options.method && options.method !== 'GET') writes += 1; return originalFetch(url, options); };
  window.document.querySelector('#admin-github-news-form').dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise(r => setTimeout(r, 30));
  assert.strictEqual(writes, 0, 'no-op save performs no GitHub write');
  assert.strictEqual(window.document.querySelector('#admin-publication-status').textContent, 'Live', 'newest successful deployment wins over an older failure');
  assert.strictEqual(window.sessionStorage.getItem(`astra-cms-deployment-sha-${id}`), null, 'successful deployment clears stale tracking');
  window.sessionStorage.setItem(`astra-cms-deployment-sha-${id}`, 'merge-sha');
  openPulls = [{ number: 42, html_url: 'https://github.com/Iyad-Ayoub/astra-team.github.io/pull/42', base: { ref: 'main' }, head: { ref: 'cms-publish/news/news-test1234', sha: 'publication-sha' } }];
  window.document.querySelector('#admin-news-update').dispatchEvent(new window.Event('click', { bubbles: true }));
  await new Promise(r => setTimeout(r, 30));
  assert.strictEqual(writes, 0, 'no-op publication performs no branch or PR write');
  assert.strictEqual(window.sessionStorage.getItem(`astra-cms-deployment-sha-${id}`), 'merge-sha', 'content equality does not clear deployment tracking');
  assert.ok(window.document.querySelector('#admin-publication-message').textContent.includes('View pull request'), 'no-op keeps an existing PR visible');
  openPulls = [];
  deploymentRuns = [{ id: 3, run_number: 12, name: 'Deploy astra-team with jekyll', status: 'completed', conclusion: 'failure', updated_at: '2026-01-01T00:02:00Z' }];
  deploymentRuns[0].head_sha = 'main-c';
  compareDescended = false;
  window.eval(app);
  for (let i = 0; i < 80 && window.document.querySelector('#admin-publication-status').textContent !== 'Published to repository'; i += 1) await new Promise(r => setTimeout(r, 10));
  assert.strictEqual(window.document.querySelector('#admin-publication-status').textContent, 'Published to repository', 'failure is represented without claiming Live');
  console.log('admin_news_lifecycle_test: ok');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
