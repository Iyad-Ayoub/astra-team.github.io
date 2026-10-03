const assert = require('assert');
const fs = require('fs');
const { JSDOM } = require('jsdom');

const source = fs.readFileSync('assets/js/admin/app.js', 'utf8');
const exportMarker = '\n  async function boot() {';
const exported = source.replace(exportMarker, `
  window.__projectAdapter = { projectDraftPath, collectProjectPayload, validateProjectPayload, serializeProjectDraft, parseProjectDraft, projectEditableSignature };
${exportMarker}`);

const dom = new JSDOM(`<!doctype html><body data-admin-mode="github-route">
  <input id="admin-project-content-id"><input id="admin-project-acronym"><input id="admin-project-title">
  <select id="admin-project-status"><option value="ongoing">Ongoing</option><option value="completed">Completed</option></select>
  <select id="admin-project-scope"><option value="national">National</option><option value="european">European</option><option value="international">International</option></select>
  <select id="admin-project-type"><option value="research-project">Research project</option><option value="research-infrastructure">Research infrastructure</option><option value="joint-lab">Joint lab</option></select>
  <select id="admin-project-cover-media-id"><option value="">No cover image</option><option value="media-cover123">cover</option></select>
  <textarea id="admin-project-summary"></textarea><textarea id="admin-project-astra-role"></textarea>
  <input id="admin-project-programme"><input id="admin-project-start-date"><input id="admin-project-end-date"><input id="admin-project-kickoff-date"><input id="admin-project-coordinator">
  <textarea id="admin-project-partners"></textarea><input id="admin-project-external-url"><input id="admin-project-cordis-url">
  <section id="admin-loading"></section><section id="admin-github-login"></section><section id="admin-github-dashboard"></section><section id="admin-denied"></section>
</body>`, { url: 'http://127.0.0.1:4000/admin/projects/new/', runScripts: 'dangerously' });
dom.window.ASTRA_CMS_CONFIG = {};
dom.window.eval(exported);
const adapter = dom.window.__projectAdapter;
const document = dom.window.document;

function setFields(values) {
  Object.entries(values).forEach(([key, value]) => {
    const field = document.querySelector(`#admin-project-${String(key).replace(/_/g, '-')}`);
    if (!field) throw new Error(`missing field ${key}`);
    field.value = value;
  });
}

const valid = {
  'content-id': 'project-ab12', acronym: 'GAT', title: 'Global Autonomous Transportation', status: 'ongoing',
  scope: 'international', type: 'joint-lab', 'cover-media-id': 'media-cover123',
  summary: 'A research collaboration.', 'astra-role': 'Core research partner.', programme: 'JointLab',
  'start-date': '2024-01-01', 'end-date': '2026-12', 'kickoff-date': '2024-02-01', coordinator: 'Inria',
  partners: 'Inria\nValeo\n\nUC Berkeley', 'external-url': 'https://example.org/project', 'cordis-url': ''
};
setFields(valid);
const payload = adapter.collectProjectPayload();
assert.deepStrictEqual(Array.from(payload.partners), ['Inria', 'Valeo', 'UC Berkeley']);
assert.strictEqual(adapter.validateProjectPayload(payload), '');
assert.strictEqual(adapter.projectDraftPath(payload.id), 'cms/drafts/projects/project-ab12.md');
assert.throws(() => adapter.projectDraftPath('project-AB12'), /Invalid project identifier/);

const markdown = adapter.serializeProjectDraft(payload);
assert.match(markdown, /^order: -\d+$/m, 'new CMS projects receive a deterministic date-based order');
const expectedOrder = ['content_id', 'acronym', 'order', 'title', 'status', 'scope', 'type', 'programme', 'start_date', 'end_date', 'kickoff_date', 'coordinator', 'astra_role', 'partners', 'summary', 'external_url', 'cordis_url', 'cover_media_id'];
assert.deepStrictEqual(markdown.match(/^[a-z_]+:/gm).map((line) => line.slice(0, -1)), expectedOrder);
assert.strictEqual(adapter.parseProjectDraft(markdown).cover_media_id, 'media-cover123');

const legacyMarkdown = markdown.replace('cover_media_id: "media-cover123"\n', '');
assert.strictEqual(adapter.parseProjectDraft(legacyMarkdown).cover_media_id, null);
assert.throws(() => adapter.parseProjectDraft(markdown.replace('summary: "A research collaboration."', 'unsupported: true\nsummary: "A research collaboration."')), /Invalid project draft fields/);

for (const field of ['acronym', 'title', 'summary', 'astra_role']) {
  const missing = { ...payload, [field]: '' };
  assert.notStrictEqual(adapter.validateProjectPayload(missing), '', `missing ${field} rejected`);
}
for (const [field, value] of [['status', 'paused'], ['scope', 'local'], ['type', 'other']]) {
  assert.notStrictEqual(adapter.validateProjectPayload({ ...payload, [field]: value }), '', `invalid ${field} rejected`);
}
assert.notStrictEqual(adapter.validateProjectPayload({ ...payload, id: 'project-../escape' }), '');
assert.notStrictEqual(adapter.validateProjectPayload({ ...payload, external_url: 'javascript:alert(1)' }), '');
assert.notStrictEqual(adapter.validateProjectPayload({ ...payload, summary: '{{ unsafe }}' }), '');
assert.notStrictEqual(adapter.validateProjectPayload({ ...payload, cover_media_id: 'media-../escape' }), '');

const edited = { ...payload, title: 'Changed title' };
assert.notStrictEqual(adapter.projectEditableSignature(payload), adapter.projectEditableSignature(edited));
assert.strictEqual(adapter.projectEditableSignature(payload), adapter.projectEditableSignature({ ...edited, title: payload.title }));

console.log('phase_g12_project_adapter_test: ok');
