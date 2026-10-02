const assert = require('assert');
const fs = require('fs');
const { TextEncoder, TextDecoder } = require('util');
const { JSDOM } = require('jsdom');

const app = fs.readFileSync('assets/js/admin/app.js', 'utf8');
const layout = fs.readFileSync('_layouts/admin.html', 'utf8');
const dashboard = fs.readFileSync('_pages/admin/index.html', 'utf8');
const projectPages = fs.readFileSync('_pages/admin/projects/index.html', 'utf8') + fs.readFileSync('_pages/admin/projects/new.html', 'utf8') + fs.readFileSync('_pages/admin/projects/edit.html', 'utf8');
assert.match(layout, /\/admin\/projects\/.*Projects/);
assert.match(layout, /page\.admin_active == 'projects'/);
assert.match(dashboard, /href="\{\{ '\/admin\/projects\/' \| relative_url \}\}"/);
assert.ok(dashboard.includes('Manage shared images and media used across CMS content.'));
assert.ok(!dashboard.includes('available here in a later phase'));
assert.match(projectPages, /admin-github-project-items/);
assert.strictEqual((app.match(/admin-github-project-form.*addEventListener\('submit'/g) || []).length, 1);
assert.strictEqual((app.match(/admin-github-project-form.*addEventListener\('change'/g) || []).length, 1);
assert.ok(!projectPages.includes('admin-news-publish'));
['Ongoing', 'Completed', 'National', 'European', 'International', 'Research project', 'Research infrastructure', 'Joint lab'].forEach((label) => assert.ok(app.includes(`'${label}'`), `display label ${label}`));

const id = 'project-list123';
const markdown = `---\ncontent_id: "${id}"\nacronym: "AST"\norder: 2\ntitle: "Autonomous Test"\nstatus: "ongoing"\nscope: "international"\ntype: "research-project"\nprogramme: "Horizon"\nstart_date: null\nend_date: null\nkickoff_date: null\ncoordinator: null\nastra_role: "Research partner"\npartners: []\nsummary: "Summary"\nexternal_url: null\ncordis_url: null\ncover_media_id: null\n---\n\n{% include project_details.html %}\n`;
const response = (body, status = 200) => ({ ok: status >= 200 && status < 300, status, json: async () => body });

async function main() {
  const dom = new JSDOM('<!doctype html><body data-admin-mode="github-route" data-admin-route="projects"><div id="admin-github-project-items"></div><section id="admin-loading"></section><section id="admin-github-login"></section><section id="admin-github-dashboard"></section><section id="admin-denied"></section><strong id="admin-github-login"></strong><p id="admin-github-repository"></p></body>', { url: 'http://127.0.0.1:4000/admin/projects/', runScripts: 'dangerously' });
  const { window } = dom;
  window.TextEncoder = TextEncoder; window.TextDecoder = TextDecoder;
  window.ASTRA_CMS_CONFIG = { githubAuth: { clientId: 'client', brokerUrl: 'https://broker.example', repoOwner: 'Iyad-Ayoub', repoName: 'astra-team.github.io' } };
  window.localStorage.setItem('astra-cms-session-handle', 'opaque-handle');
  window.fetch = async (url) => {
    const value = String(url);
    if (value.startsWith('https://broker.example/session/restore')) return response({ access_token: 'token', expires_at: new Date(Date.now() + 3600000).toISOString() });
    const path = value.slice('https://api.github.com'.length);
    if (path === '/user') return response({ login: 'editor' });
    if (path === '/repos/Iyad-Ayoub/astra-team.github.io') return response({ full_name: 'Iyad-Ayoub/astra-team.github.io', permissions: { push: true } });
    if (path.includes('/git/ref/heads/cms-drafts')) return response({ object: { sha: 'draft-branch' } });
    if (path.includes('/contents/cms/drafts/projects?')) return response([{ name: `${id}.md`, path: `cms/drafts/projects/${id}.md` }, { name: 'project-bad.md', path: 'cms/drafts/projects/project-bad.md' }]);
    if (path.includes(`/contents/cms/drafts/projects/${id}.md`)) return response({ content: Buffer.from(markdown).toString('base64') });
    if (path.includes('/contents/cms/drafts/projects/project-bad.md')) return response({ content: 'not a project draft' });
    return response({});
  };
  window.eval(app);
  for (let i = 0; i < 100 && !window.document.querySelector('.astra-admin-news-item'); i += 1) await new Promise((resolve) => setTimeout(resolve, 5));
  const link = window.document.querySelector('.astra-admin-news-item');
  assert.ok(link, 'valid project draft renders');
  assert.strictEqual(link.querySelector('.astra-admin-news-title').textContent, 'AST — Autonomous Test');
  assert.ok(link.textContent.includes('Ongoing') && link.textContent.includes('International') && link.textContent.includes('Research project'));
  assert.ok(markdown.includes('status: "ongoing"') && markdown.includes('scope: "international"') && markdown.includes('type: "research-project"'));
  assert.ok(link.href.includes('/admin/projects/edit/?id=project-list123'));
  assert.ok(!link.querySelector('.astra-admin-news-title').textContent.includes(id));
  console.log('admin_project_ux_test: ok');
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
