(function () {
  'use strict';

  var config = window.ASTRA_CMS_CONFIG || {};
  var mode = document.body.dataset.adminMode;
  var client;
  var validRoles = ['admin', 'editor', 'contributor'];
  var validNewsTypes = ['event', 'award', 'project', 'open-source', 'team', 'collaboration', 'demo'];
  var passwordSetupRequired = false;
  var currentProfile;
  var editingNews;
  var githubSession;
  var githubSessionHandleKey = 'astra-cms-session-handle';
  var githubDraftBranch = 'cms-drafts';
  var githubDraftRoot = 'cms/drafts/news';
  var githubMediaRoot = 'cms/media/news';
  var githubMediaIndexPath = githubMediaRoot + '/index.json';
  var maxMediaBytes = 5 * 1024 * 1024;
  var mediaIndex = [];

  function element(id) { return document.getElementById(id); }
  function setHidden(id, hidden) { var node = element(id); if (node) node.hidden = hidden; }
  function text(id, value) { var node = element(id); if (node) node.textContent = value || ''; }
  function message(id, value) { text(id, value); }

  function show(name) {
    ['admin-loading', 'admin-login', 'admin-reset', 'admin-dashboard', 'admin-news-list', 'admin-news-form-panel', 'admin-denied', 'admin-password-setup'].forEach(function (id) {
      setHidden(id, id !== name);
    });
  }

  function callbackUrl() {
    return new URL('auth/callback/', window.location.href).toString();
  }

  function loginUrl() {
    return new URL('../../', window.location.href).toString();
  }

  function deny(reason) {
    text('admin-denied-message', reason);
    show('admin-denied');
  }

  function friendlyError(error, fallback) {
    return error && error.message ? error.message : fallback;
  }

  function adminRootUrl() {
    var marker = '/admin/';
    var position = window.location.pathname.indexOf(marker);
    var prefix = position === -1 ? '' : window.location.pathname.slice(0, position);
    return new URL(prefix + '/admin/', window.location.origin).toString();
  }

  function githubCallbackUrl() {
    return new URL('auth/callback/', adminRootUrl()).toString();
  }

  function githubSettings() {
    var github = config.githubAuth || {};
    if (github.repoOwner !== 'Iyad-Ayoub' || github.repoName !== 'astra-team.github.io') return null;
    if (!github.clientId || !github.brokerUrl) return null;
    return github;
  }

  function githubElement(id) { return element(id); }

  function showGithub(name) {
    ['admin-loading', 'admin-github-login', 'admin-github-dashboard', 'admin-denied'].forEach(function (id) {
      setHidden(id, id !== name);
    });
  }

  function githubMessage(value) { message('admin-github-login-message', value); }

  function denyGithub(reason) {
    githubSession = null;
    text('admin-denied-message', reason);
    showGithub('admin-denied');
  }

  function storedGithubSession() {
    if (!githubSession || !githubSession.accessToken || !githubSession.expiresAt || Date.parse(githubSession.expiresAt) <= Date.now()) return null;
    return githubSession;
  }

  function storeGithubSession(session) {
    if (!session || !session.access_token || !session.expires_at) throw new Error('The broker did not return a valid GitHub session.');
    githubSession = { accessToken: session.access_token, expiresAt: session.expires_at };
    if (session.session_handle) localStorage.setItem(githubSessionHandleKey, session.session_handle);
  }

  async function restoreGithubSession() {
    var github = githubSettings();
    if (!github) return null;
    var handle = localStorage.getItem(githubSessionHandleKey);
    if (!handle) return null;
    var response = await fetch(new URL('/session/restore', github.brokerUrl + '/').toString(), { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify({ redirect_uri: githubCallbackUrl(), session_handle: handle }) });
    if (response.status === 401) return null;
    if (!response.ok) throw new Error('The GitHub session could not be restored.');
    storeGithubSession(await response.json());
    return storedGithubSession();
  }

  function githubApi(path, accessToken, options) {
    options = options || {};
    return fetch('https://api.github.com' + path, {
      method: options.method || 'GET',
      headers: Object.assign({ Accept: 'application/vnd.github+json', Authorization: 'Bearer ' + accessToken, 'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json' }, options.headers || {}),
      cache: 'no-store',
      body: options.body ? JSON.stringify(options.body) : undefined
    });
  }

  async function githubResponse(path, session, options) {
    var response = await githubApi(path, session.accessToken, options);
    var data = await response.json().catch(function () { return {}; });
    if (!response.ok) {
      var error = new Error(data.message || 'GitHub request failed.');
      error.status = response.status;
      throw error;
    }
    return data;
  }

  function draftPath(id) {
    if (!/^news-[a-z0-9]+$/.test(id)) throw new Error('Invalid draft identifier.');
    return githubDraftRoot + '/' + id + '.md';
  }

  function utf8Base64(value) {
    var bytes = new TextEncoder().encode(value);
    var binary = '';
    bytes.forEach(function (byte) { binary += String.fromCharCode(byte); });
    return btoa(binary);
  }

  function fromBase64(value) {
    var binary = atob(value.replace(/\s/g, ''));
    return new TextDecoder().decode(Uint8Array.from(binary, function (character) { return character.charCodeAt(0); }));
  }

  function mediaPath(id, extension) {
    if (!/^media-[a-z0-9]+$/.test(id) || ['jpg', 'png', 'webp'].indexOf(extension) === -1) throw new Error('Invalid media identifier.');
    return githubMediaRoot + '/' + id + '.' + extension;
  }

  function mediaMessage(value) { message('admin-media-message', value); }

  function mediaType(bytes) {
    if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return { extension: 'jpg', mime: 'image/jpeg' };
    if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) return { extension: 'png', mime: 'image/png' };
    if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) return { extension: 'webp', mime: 'image/webp' };
    return null;
  }

  function bytesBase64(bytes) {
    var binary = ''; var chunk = 0x8000;
    for (var index = 0; index < bytes.length; index += chunk) binary += String.fromCharCode.apply(null, bytes.subarray(index, index + chunk));
    return btoa(binary);
  }

  async function readMediaIndex(session) {
    var github = githubSettings();
    try {
      var data = await githubResponse('/repos/' + github.repoOwner + '/' + github.repoName + '/contents/' + githubMediaIndexPath + '?ref=' + githubDraftBranch, session);
      var parsed = JSON.parse(fromBase64(data.content));
      if (!parsed || parsed.version !== 1 || !Array.isArray(parsed.items)) throw new Error('Invalid media index.');
      mediaIndex = parsed.items.filter(function (item) { return item && /^media-[a-z0-9]+$/.test(item.id) && typeof item.path === 'string' && /^cms\/media\/news\/media-[a-z0-9]+\.(jpg|png|webp)$/.test(item.path); });
      return { items: mediaIndex, sha: data.sha };
    } catch (error) { if (error.status === 404) { mediaIndex = []; return { items: [], sha: null }; } throw error; }
  }

  function serializeMediaIndex(items) {
    return JSON.stringify({ version: 1, items: items.slice().sort(function (a, b) { return a.id.localeCompare(b.id); }).map(function (item) { return { id: item.id, path: item.path, filename: item.filename, mime: item.mime, uploaded_at: item.uploaded_at, alt_text: item.alt_text || null }; }) }, null, 2) + '\n';
  }

  async function githubMediaBlob(session, item) {
    var github = githubSettings();
    var response = await githubApi('/repos/' + github.repoOwner + '/' + github.repoName + '/contents/' + item.path + '?ref=' + githubDraftBranch, session.accessToken, { headers: { Accept: 'application/vnd.github.raw' } });
    if (!response.ok) { var error = new Error('Unable to load media preview.'); error.status = response.status; throw error; }
    return response.blob();
  }

  function renderCoverPreview(item, session) {
    var box = element('admin-news-cover-preview');
    if (!box) return;
    box.replaceChildren(); box.hidden = !item;
    if (!item) return;
    githubMediaBlob(session, item).then(function (blob) { var image = document.createElement('img'); image.src = URL.createObjectURL(blob); image.alt = item.alt_text || item.filename; box.appendChild(image); }).catch(function () { box.hidden = true; });
  }

  function populateCoverMedia(record, session) {
    var select = element('admin-news-cover-media-id');
    if (!select) return;
    select.replaceChildren(new Option('No cover image', ''));
    mediaIndex.forEach(function (item) { select.add(new Option(item.filename + ' (' + item.id + ')', item.id)); });
    select.value = record && record.cover_media_id ? record.cover_media_id : '';
    renderCoverPreview(mediaIndex.find(function (item) { return item.id === select.value; }), session);
  }

  async function ensureGithubDraftBranch(session) {
    var github = githubSettings();
    var base = '/repos/' + github.repoOwner + '/' + github.repoName;
    try { return await githubResponse(base + '/git/ref/heads/' + githubDraftBranch, session); }
    catch (error) {
      if (error.status !== 404) throw error;
      var main = await githubResponse(base + '/git/ref/heads/main', session);
      try { return await githubResponse(base + '/git/refs', session, { method: 'POST', body: { ref: 'refs/heads/' + githubDraftBranch, sha: main.object.sha } }); }
      catch (creationError) {
        if (creationError.status !== 422) throw creationError;
        return githubResponse(base + '/git/ref/heads/' + githubDraftBranch, session);
      }
    }
  }

  function serializeGithubDraft(record) {
    var fields = ['content_id', 'title', 'type', 'summary', 'content_date', 'event_date', 'end_date', 'location', 'external_url', 'featured', 'homepage', 'cover_media_id', 'status'];
    var values = {
      content_id: record.id, title: record.title, type: record.type, summary: record.summary,
      content_date: record.content_date, event_date: record.event_date, end_date: record.end_date,
      location: record.location, external_url: record.external_url, featured: record.featured,
      homepage: record.homepage, cover_media_id: record.cover_media_id || null, status: 'draft'
    };
    return '---\n' + fields.map(function (field) { return field + ': ' + JSON.stringify(values[field]); }).join('\n') + '\n---\n\n' + record.body.trim() + '\n';
  }

  function parseGithubDraft(markdown) {
    var match = markdown.match(/^---\n([\s\S]*?)\n---\n\n?([\s\S]*)$/);
    if (!match) throw new Error('Invalid CMS draft format.');
    var allowed = ['content_id', 'title', 'type', 'summary', 'content_date', 'event_date', 'end_date', 'location', 'external_url', 'featured', 'homepage', 'cover_media_id', 'status'];
    var record = { body: match[2].replace(/\n$/, '') };
    match[1].split('\n').forEach(function (line) {
      var separator = line.indexOf(': ');
      var key = line.slice(0, separator);
      if (separator < 1 || allowed.indexOf(key) === -1 || Object.prototype.hasOwnProperty.call(record, key)) throw new Error('Invalid CMS draft fields.');
      record[key] = JSON.parse(line.slice(separator + 2));
    });
    record.id = record.content_id;
    if (!Object.prototype.hasOwnProperty.call(record, 'cover_media_id')) record.cover_media_id = null;
    if (!/^news-[a-z0-9]+$/.test(record.id) || record.status !== 'draft' || validateNewsPayload(record, true)) throw new Error('Invalid CMS draft content.');
    return record;
  }

  async function readGithubDraft(session, id) {
    var github = githubSettings();
    var path = draftPath(id);
    var data = await githubResponse('/repos/' + github.repoOwner + '/' + github.repoName + '/contents/' + path + '?ref=' + githubDraftBranch, session);
    return { record: parseGithubDraft(fromBase64(data.content)), sha: data.sha };
  }

  function githubDraftMessage(value) { message('admin-github-news-message', value); }

  function currentDraftId() {
    var id = new URLSearchParams(window.location.search).get('id');
    return id && /^news-[a-z0-9]+$/.test(id) ? id : null;
  }

  function publicationBranch(id) { if (!/^news-[a-z0-9]+$/.test(id)) throw new Error('Invalid draft identifier.'); return 'cms-publish/news/' + id; }
  function publicSlug(record) { var words = record.title.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 72); return (words || 'news') + '-' + record.id.replace(/^news-/, '').slice(-8); }
  function publicNewsPath(record) { return '_news/' + publicSlug(record) + '.md'; }
  function publicMediaPath(record, media) { return 'assets/img/news/' + record.id + '/' + media.path.split('/').pop(); }
  function publicationMessage(value) { message('admin-publication-message', value); }
  function serializePublicNews(record, media) {
    var fields = { layout: 'news', content_id: record.id, slug: publicSlug(record), title: record.title, status: 'published', type: record.type, event_date: record.event_date, summary: record.summary, featured: record.featured, homepage: record.homepage, end_date: record.end_date, location: record.location, external_url: record.external_url, date_precision: 'day', image: media ? '/' + publicMediaPath(record, media) : null, image_alt: media ? media.alt_text || media.filename : null };
    return '---\n' + Object.keys(fields).filter(function (key) { return fields[key] !== null && fields[key] !== ''; }).map(function (key) { return key + ': ' + JSON.stringify(fields[key]); }).join('\n') + '\n---\n\n' + record.body.trim() + '\n';
  }
  function setPublicationStatus(value, link) { text('admin-publication-status', value); var button = element('admin-news-publish'); if (button) button.disabled = value !== 'Draft'; if (link) { var anchor = document.createElement('a'); anchor.href = link; anchor.textContent = 'View pull request'; anchor.className = 'astra-admin-text-link'; var box = element('admin-publication-message'); box.replaceChildren(anchor); } }
  async function loadPublicationStatus(session, record) { var github = githubSettings(), base = '/repos/' + github.repoOwner + '/' + github.repoName, branch = publicationBranch(record.id); try { var pulls = await githubResponse(base + '/pulls?state=open&head=' + encodeURIComponent(github.repoOwner + ':' + branch), session); if (pulls.length) { setPublicationStatus('Submitted', pulls[0].html_url); return; } var publicFile = await githubResponse(base + '/contents/' + publicNewsPath(record) + '?ref=main', session); if (publicFile) { setPublicationStatus('Published'); return; } } catch (error) { if (error.status !== 404) { setPublicationStatus('Error'); publicationMessage(friendlyError(error, 'Unable to determine publication status.')); return; } } setPublicationStatus('Draft'); }
  async function submitGithubPublication() {
    var id = currentDraftId(), session = storedGithubSession();
    if (!id || !session) { publicationMessage('Save and sign in before submitting for publication.'); return; }
    try {
      await verifyGithubRepositoryAccess(session);
      var draft = await readGithubDraft(session, id), record = draft.record, github = githubSettings(), base = '/repos/' + github.repoOwner + '/' + github.repoName, branch = publicationBranch(id);
      if (validNewsTypes.indexOf(record.type) === -1) throw new Error('This draft uses a legacy unsupported type. Select a canonical public type before publication.');
      var pulls = await githubResponse(base + '/pulls?state=open&head=' + encodeURIComponent(github.repoOwner + ':' + branch), session);
      if (pulls.length) { setPublicationStatus('Submitted', pulls[0].html_url); publicationMessage('Submitted: existing pull request #' + pulls[0].number + '.'); return; }
      var main = await githubResponse(base + '/git/ref/heads/main', session);
      try { await githubResponse(base + '/git/refs', session, { method: 'POST', body: { ref: 'refs/heads/' + branch, sha: main.object.sha } }); } catch (error) { if (error.status !== 422) throw error; publicationMessage('Publication branch already exists and needs review before reuse.'); return; }
      var media = null;
      if (record.cover_media_id) { await readMediaIndex(session); media = mediaIndex.find(function (item) { return item.id === record.cover_media_id; }); if (!media) throw new Error('Referenced cover media is missing.'); }
      var newsBody = { message: 'cms: prepare news publication ' + id, content: utf8Base64(serializePublicNews(record, media)), branch: branch };
      await githubResponse(base + '/contents/' + publicNewsPath(record), session, { method: 'PUT', body: newsBody });
      if (media) { var image = await githubMediaBlob(session, media); var bytes = new Uint8Array(await image.arrayBuffer()); await githubResponse(base + '/contents/' + publicMediaPath(record, media), session, { method: 'PUT', body: { message: 'cms: copy news cover ' + id, content: bytesBase64(bytes), branch: branch } }); }
      var pr = await githubResponse(base + '/pulls', session, { method: 'POST', body: { title: 'Publish News: ' + record.title, head: branch, base: 'main', body: 'CMS publication\n\nContent ID: ' + id + '\nType: ' + record.type + '\nCover media: ' + (media ? 'included' : 'none') + '\nSource: ' + githubDraftBranch + '/' + draftPath(id) } });
      setPublicationStatus('Submitted', pr.html_url); publicationMessage('Submitted: pull request #' + pr.number + ' created.');
    } catch (error) { publicationMessage(friendlyError(error, 'Unable to submit this draft for publication.')); }
  }

  async function saveGithubDraft(event) {
    event.preventDefault();
    var payload = collectNewsPayload();
    var validationError = validateNewsPayload(payload);
    if (validationError) { githubDraftMessage(validationError); return; }
    var id = currentDraftId() || ('news-' + Date.now().toString(36));
    var existingSha = editingNews && editingNews.githubSha;
    payload.id = id;
    payload.status = 'draft';
    var github = githubSettings();
    var session = storedGithubSession() || await restoreGithubSession();
    if (!session) {
      githubDraftMessage('Your GitHub session has expired. Sign in again before saving this draft.');
      return;
    }
    try {
      await verifyGithubRepositoryAccess(session);
      if (payload.cover_media_id) {
        await readMediaIndex(session);
        if (!mediaIndex.some(function (item) { return item.id === payload.cover_media_id; })) throw new Error('Choose a cover image from the CMS media library.');
      }
      await ensureGithubDraftBranch(session);
      var body = { message: 'cms: ' + (existingSha ? 'update' : 'create') + ' news draft ' + id, content: utf8Base64(serializeGithubDraft(payload)), branch: githubDraftBranch };
      if (existingSha) body.sha = existingSha;
      var response = await githubResponse('/repos/' + github.repoOwner + '/' + github.repoName + '/contents/' + draftPath(id), session, { method: 'PUT', body: body });
      editingNews = payload;
      editingNews.githubSha = response.content.sha;
      githubDraftMessage('Draft saved to GitHub.');
      if (!currentDraftId()) window.location.assign(new URL('../edit/?id=' + encodeURIComponent(id), window.location.href).toString());
    } catch (error) {
      githubDraftMessage(error.status === 409 ? 'This draft changed in GitHub. Reload it before saving again.' : friendlyError(error, 'Unable to save this GitHub draft.'));
    }
  }

  async function loadGithubNewsRoute(identity) {
    var route = document.body.dataset.adminRoute;
    if (!route) return;
    var session = storedGithubSession();
    try {
      await ensureGithubDraftBranch(session);
      if (route === 'news') {
        var github = githubSettings();
        var entries;
        try { entries = await githubResponse('/repos/' + github.repoOwner + '/' + github.repoName + '/contents/' + githubDraftRoot + '?ref=' + githubDraftBranch, session); } catch (error) { if (error.status === 404) entries = []; else throw error; }
        var container = element('admin-github-news-items');
        container.replaceChildren();
        for (var index = 0; index < entries.length; index += 1) {
          var draft = await readGithubDraft(session, entries[index].name.replace(/\.md$/, ''));
          var link = document.createElement('a');
          link.className = 'astra-admin-news-item'; link.href = new URL('edit/?id=' + encodeURIComponent(draft.record.id), window.location.href).toString();
          link.textContent = draft.record.title + ' · ' + draft.record.type + ' · ' + draft.record.content_date;
          container.appendChild(link);
        }
        if (!entries.length) container.textContent = 'No GitHub drafts yet.';
      } else if (route === 'media') {
        await readMediaIndex(session);
        renderMediaLibrary(session);
      } else {
        await readMediaIndex(session);
        var id = route === 'news-edit' ? currentDraftId() : null;
        if (route === 'news-edit' && !id) throw new Error('A valid draft identifier is required.');
        if (id) { var loaded = await readGithubDraft(session, id); loaded.record.githubSha = loaded.sha; resetNewsForm(loaded.record); populateCoverMedia(loaded.record, session); await loadPublicationStatus(session, loaded.record); } else { resetNewsForm(null); populateCoverMedia(null, session); }
      }
    } catch (error) { githubDraftMessage(friendlyError(error, 'Unable to load GitHub drafts.')); }
  }

  function renderMediaLibrary(session) {
    var container = element('admin-media-items');
    if (!container) return;
    container.replaceChildren();
    if (!mediaIndex.length) { container.textContent = 'No uploaded images yet.'; return; }
    mediaIndex.forEach(function (item) {
      var card = document.createElement('article'); card.className = 'astra-admin-media-item';
      var label = document.createElement('p'); label.textContent = item.filename + ' · ' + item.id; card.appendChild(label);
      if (item.alt_text) { var alt = document.createElement('small'); alt.textContent = item.alt_text; card.appendChild(alt); }
      githubMediaBlob(session, item).then(function (blob) { var image = document.createElement('img'); image.src = URL.createObjectURL(blob); image.alt = item.alt_text || item.filename; card.prepend(image); }).catch(function () { card.appendChild(document.createTextNode('Preview unavailable.')); });
      container.appendChild(card);
    });
  }

  async function uploadMedia(event) {
    event.preventDefault();
    var file = element('admin-media-file').files[0];
    var altText = element('admin-media-alt-text').value.trim();
    if (!file) { mediaMessage('Select a JPEG, PNG, or WebP image.'); return; }
    if (file.size > maxMediaBytes) { mediaMessage('Images must be 5 MB or smaller.'); return; }
    if (altText.length > 300 || !safeNewsText(altText)) { mediaMessage('Enter safe alt text of 300 characters or fewer.'); return; }
    var bytes = new Uint8Array(await file.arrayBuffer());
    var type = mediaType(bytes);
    if (!type) { mediaMessage('Only valid JPEG, PNG, and WebP image files are allowed.'); return; }
    var session = storedGithubSession();
    if (!session) { mediaMessage('Your GitHub session has expired. Sign in again before uploading.'); return; }
    var id = 'media-' + Date.now().toString(36);
    var item = { id: id, path: mediaPath(id, type.extension), filename: file.name.replace(/[\r\n]/g, ' ').slice(0, 180), mime: type.mime, uploaded_at: new Date().toISOString(), alt_text: altText || null };
    try {
      await verifyGithubRepositoryAccess(session);
      await ensureGithubDraftBranch(session);
      var index = await readMediaIndex(session);
      if (index.items.some(function (existing) { return existing.id === id; })) throw new Error('A media item with this identifier already exists. Try uploading again.');
      await githubResponse('/repos/' + githubSettings().repoOwner + '/' + githubSettings().repoName + '/contents/' + item.path, session, { method: 'PUT', body: { message: 'cms: create media ' + id, content: bytesBase64(bytes), branch: githubDraftBranch } });
      var updated = index.items.concat([item]);
      var indexBody = { message: 'cms: index media ' + id, content: utf8Base64(serializeMediaIndex(updated)), branch: githubDraftBranch };
      if (index.sha) indexBody.sha = index.sha;
      await githubResponse('/repos/' + githubSettings().repoOwner + '/' + githubSettings().repoName + '/contents/' + githubMediaIndexPath, session, { method: 'PUT', body: indexBody });
      mediaIndex = updated; element('admin-media-upload-form').reset(); mediaMessage('Image uploaded to the GitHub draft branch.'); renderMediaLibrary(session);
    } catch (error) { mediaMessage(error.status === 409 ? 'Media changed in GitHub. Reload the library and try again.' : friendlyError(error, 'Unable to upload this image.')); }
  }

  async function verifyGithubRepositoryAccess(session) {
    var github = githubSettings();
    if (!github) throw new Error('GitHub CMS configuration is unavailable.');
    var userResponse = await githubApi('/user', session.accessToken);
    if (!userResponse.ok) throw new Error('Your GitHub session is invalid or expired.');
    var user = await userResponse.json();
    var repoResponse = await githubApi('/repos/' + github.repoOwner + '/' + github.repoName, session.accessToken);
    if (!repoResponse.ok) throw new Error('You do not have access to the ASTRA repository.');
    var repository = await repoResponse.json();
    if (!repository.permissions || repository.permissions.push !== true) {
      throw new Error('GitHub write access to the ASTRA repository is required for CMS access.');
    }
    return { user: user, repository: repository };
  }

  function showGithubAuthenticated(identity) {
    text('admin-github-login', identity.user.login);
    text('admin-github-repository', identity.repository.full_name + ' · Write access verified');
    var avatar = githubElement('admin-github-avatar');
    if (avatar) {
      avatar.src = identity.user.avatar_url;
      avatar.alt = identity.user.login + ' GitHub avatar';
      avatar.hidden = false;
    }
    showGithub('admin-github-dashboard');
  }

  async function beginGithubLogin() {
    var github = githubSettings();
    if (!github) {
      githubMessage('GitHub sign-in is not configured for this build.');
      return;
    }
    var returnTo = window.location.pathname + window.location.search;
    var authorizeUrl = new URL('/authorize', github.brokerUrl + '/');
    authorizeUrl.search = new URLSearchParams({
      redirect_uri: githubCallbackUrl(),
      return_to: returnTo
    }).toString();
    window.location.assign(authorizeUrl.toString());
  }

  async function completeGithubCallback() {
    var github = githubSettings();
    var params = new URLSearchParams(window.location.search);
    if (params.get('error')) {
      denyGithub('GitHub sign-in was denied or cancelled.');
      return;
    }
    var ticket = params.get('ticket');
    if (!github || !ticket) {
      denyGithub('This GitHub sign-in link is invalid, expired, or no longer available.');
      return;
    }
    window.history.replaceState({}, document.title, window.location.pathname);
    try {
      var response = await fetch(new URL('/session/exchange', github.brokerUrl + '/').toString(), {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ ticket: ticket, redirect_uri: githubCallbackUrl() })
      });
      if (!response.ok) throw new Error('The GitHub sign-in session could not be completed.');
      var brokerSession = await response.json();
      storeGithubSession(brokerSession);
      var identity = await verifyGithubRepositoryAccess(storedGithubSession());
      window.location.replace(new URL(brokerSession.return_to || adminRootUrl(), window.location.origin).toString());
      return identity;
    } catch (error) { denyGithub(friendlyError(error, 'GitHub sign-in failed.')); }
  }

  async function bootGithub() {
    if (mode === 'callback') {
      await completeGithubCallback();
      return;
    }
    var session;
    try { session = storedGithubSession() || await restoreGithubSession(); }
    catch (error) { denyGithub(friendlyError(error, 'GitHub session restoration failed.')); return; }
    if (!session) { showGithub('admin-github-login'); return; }
    try {
      var identity = await verifyGithubRepositoryAccess(session);
      showGithubAuthenticated(identity);
      await loadGithubNewsRoute(identity);
    }
    catch (error) { denyGithub(friendlyError(error, 'GitHub repository access could not be verified.')); }
  }

  async function logoutGithub() {
    var github = githubSettings();
    var handle = localStorage.getItem(githubSessionHandleKey);
    githubSession = null;
    localStorage.removeItem(githubSessionHandleKey);
    if (github) { try { await fetch(new URL('/session/logout', github.brokerUrl + '/').toString(), { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ session_handle: handle }) }); } catch (_) {} }
    window.location.assign(adminRootUrl());
  }

  function bindGithubEvents() {
    document.querySelectorAll('#admin-github-login-button').forEach(function (button) { button.addEventListener('click', beginGithubLogin); });
    document.querySelectorAll('#admin-github-logout').forEach(function (button) { button.addEventListener('click', logoutGithub); });
    if (element('admin-github-news-form')) element('admin-github-news-form').addEventListener('submit', saveGithubDraft);
    if (element('admin-news-publish')) element('admin-news-publish').addEventListener('click', submitGithubPublication);
    if (newsField('type')) newsField('type').addEventListener('change', toggleEventFields);
    if (element('admin-media-upload-form')) element('admin-media-upload-form').addEventListener('submit', uploadMedia);
    if (newsField('cover-media-id')) newsField('cover-media-id').addEventListener('change', function () { renderCoverPreview(mediaIndex.find(function (item) { return item.id === newsField('cover-media-id').value; }), storedGithubSession()); });
  }

  async function loadProfile(session) {
    var response = await client.from('profiles')
      .select('id, display_name, role, status')
      .eq('id', session.user.id)
      .maybeSingle();

    if (response.error || !response.data) {
      await client.auth.signOut();
      deny('Your verified account does not have an active CMS profile. Contact an administrator.');
      return;
    }
    if (response.data.status !== 'active' || validRoles.indexOf(response.data.role) === -1) {
      await client.auth.signOut();
      deny('This CMS account is unavailable. Contact an administrator.');
      return;
    }

    text('admin-display-name', response.data.display_name || session.user.email || 'ASTRA CMS user');
    text('admin-user-email', session.user.email || '');
    text('admin-role', response.data.role.charAt(0).toUpperCase() + response.data.role.slice(1));
    setHidden('admin-users-nav', response.data.role !== 'admin');
    currentProfile = response.data;
    show('admin-dashboard');
  }

  function isEditorialUser() {
    return currentProfile && (currentProfile.role === 'admin' || currentProfile.role === 'editor');
  }

  function newsField(name) {
    return element('admin-news-' + name);
  }

  function setNewsMessage(value) {
    message('admin-news-form-message', value);
  }

  function toggleEventFields() {
    var isEvent = newsField('type').value === 'event';
    setHidden('admin-news-event-fields', !isEvent);
    newsField('event-date').required = isEvent;
  }

  function safeNewsText(value) {
    return !(/\{\{|\{%|<\s*script\b|\son[a-z]+\s*=/i.test(value));
  }

  function collectNewsPayload() {
    return {
      title: newsField('title').value.trim(),
      type: newsField('type').value,
      summary: newsField('summary').value.trim(),
      body: newsField('body').value.trim(),
      content_date: newsField('content-date').value,
      event_date: newsField('event-date').value || null,
      end_date: newsField('end-date').value || null,
      location: newsField('location').value.trim() || null,
      external_url: newsField('external-url').value.trim() || null,
      featured: newsField('featured').checked,
      homepage: newsField('homepage').checked,
      cover_media_id: newsField('cover-media-id') ? newsField('cover-media-id').value || null : null
    };
  }

  function validateNewsPayload(payload, allowLegacy) {
    if (!payload.title || !payload.summary || !payload.body || !payload.content_date) return 'Complete the required fields.';
    if (validNewsTypes.indexOf(payload.type) === -1 && !(allowLegacy && payload.type === 'news')) return 'Choose a supported content type.';
    if (payload.title.length > 180 || payload.summary.length > 600 || payload.body.length > 30000 || (payload.location && payload.location.length > 160)) return 'One or more fields are too long.';
    if (!/^\d{4}-\d{2}-\d{2}$/.test(payload.content_date)) return 'Enter a valid content date.';
    if (payload.type === 'event' && !payload.event_date) return 'An event date is required for an event.';
    if (payload.event_date && !/^\d{4}-\d{2}-\d{2}$/.test(payload.event_date)) return 'Enter a valid event date.';
    if (payload.end_date && !/^\d{4}-\d{2}-\d{2}$/.test(payload.end_date)) return 'Enter a valid end date.';
    if (payload.end_date && payload.event_date && payload.end_date < payload.event_date) return 'The end date cannot be before the event date.';
    if (payload.external_url) {
      try {
        var url = new URL(payload.external_url);
        if (url.protocol !== 'https:' && url.protocol !== 'http:') throw new Error('unsupported protocol');
      } catch (_) { return 'Enter a valid http or https external URL.'; }
    }
    if (payload.cover_media_id && !/^media-[a-z0-9]+$/.test(payload.cover_media_id)) return 'Choose a cover image from the CMS media library.';
    if (!safeNewsText(payload.title) || !safeNewsText(payload.summary) || !safeNewsText(payload.body)) return 'Liquid syntax, script tags, and inline event handlers are not allowed.';
    return '';
  }

  function resetNewsForm(record) {
    editingNews = record || null;
    text('admin-news-form-title', record ? 'Edit News or Event' : 'New News or Event');
    newsField('title').value = record ? record.title : '';
    newsField('type').value = record && validNewsTypes.indexOf(record.type) !== -1 ? record.type : 'event';
    newsField('summary').value = record ? record.summary : '';
    newsField('body').value = record ? record.body : '';
    newsField('content-date').value = record ? record.content_date : '';
    newsField('event-date').value = record && record.event_date ? record.event_date : '';
    newsField('end-date').value = record && record.end_date ? record.end_date : '';
    newsField('location').value = record && record.location ? record.location : '';
    newsField('external-url').value = record && record.external_url ? record.external_url : '';
    newsField('featured').checked = Boolean(record && record.featured);
    newsField('homepage').checked = Boolean(record && record.homepage);
    if (newsField('cover-media-id')) newsField('cover-media-id').value = record && record.cover_media_id ? record.cover_media_id : '';
    setHidden('admin-news-return', !(record && record.status === 'in_review' && isEditorialUser()));
    setNewsMessage(record && record.status === 'in_review' && !isEditorialUser() ? 'This item is in review and cannot be changed by its contributor.' : '');
    toggleEventFields();
  }

  async function loadNews() {
    message('admin-news-list-message', '');
    var response = await client.from('cms_news')
      .select('id, title, type, summary, body, content_date, event_date, end_date, location, external_url, featured, homepage, status, updated_at, created_by')
      .order('updated_at', { ascending: false });
    var container = element('admin-news-items');
    container.replaceChildren();
    if (response.error) {
      message('admin-news-list-message', friendlyError(response.error, 'Unable to load News & Events.'));
      return;
    }
    if (!response.data.length) {
      var empty = document.createElement('p');
      empty.textContent = 'No News or Events drafts yet.';
      container.appendChild(empty);
      return;
    }
    response.data.forEach(function (record) {
      var button = document.createElement('button');
      var detail = document.createElement('small');
      button.type = 'button';
      button.className = 'astra-admin-news-item';
      button.dataset.newsId = record.id;
      button.textContent = record.title;
      detail.textContent = record.type + ' · ' + record.content_date + ' · ' + record.status + ' · Updated ' + new Date(record.updated_at).toLocaleString();
      button.appendChild(detail);
      button.addEventListener('click', function () { openNewsForm(record); });
      container.appendChild(button);
    });
  }

  async function openNewsList() {
    show('admin-news-list');
    await loadNews();
  }

  function openNewsForm(record) {
    resetNewsForm(record);
    show('admin-news-form-panel');
  }

  async function saveNews(event) {
    if (event) event.preventDefault();
    var payload = collectNewsPayload();
    var validationError = validateNewsPayload(payload);
    if (validationError) { setNewsMessage(validationError); return false; }
    if (editingNews && editingNews.status === 'in_review' && !isEditorialUser()) {
      setNewsMessage('This item is in review and cannot be changed by its contributor.');
      return false;
    }
    setNewsMessage('Saving draft…');
    var response = editingNews
      ? await client.from('cms_news').update(payload).eq('id', editingNews.id).select().single()
      : await client.from('cms_news').insert(payload).select().single();
    if (response.error) { setNewsMessage(friendlyError(response.error, 'Unable to save this draft.')); return false; }
    editingNews = response.data;
    resetNewsForm(editingNews);
    setNewsMessage('Draft saved.');
    return true;
  }

  async function submitNewsForReview() {
    if (!editingNews) {
      var saved = await saveNews();
      if (!saved) return;
    }
    if (editingNews.status !== 'draft') {
      setNewsMessage('This item is already in review.');
      return;
    }
    var response = await client.from('cms_news').update({ status: 'in_review' }).eq('id', editingNews.id).select().single();
    if (response.error) { setNewsMessage(friendlyError(response.error, 'Unable to submit this item for review.')); return; }
    editingNews = response.data;
    resetNewsForm(editingNews);
    setNewsMessage('Submitted for review. Publishing is not available in this phase.');
  }

  async function returnNewsToDraft() {
    if (!editingNews || !isEditorialUser()) return;
    var response = await client.from('cms_news').update({ status: 'draft' }).eq('id', editingNews.id).select().single();
    if (response.error) { setNewsMessage(friendlyError(response.error, 'Unable to return this item to draft.')); return; }
    editingNews = response.data;
    resetNewsForm(editingNews);
    setNewsMessage('Returned to draft.');
  }

  async function handleSession(session) {
    if (!session) {
      if (mode === 'callback') {
        deny('This invitation or password-reset link is invalid, expired, or already used.');
      } else {
        show('admin-login');
      }
      return;
    }
    if (passwordSetupRequired) {
      show('admin-password-setup');
      return;
    }
    await loadProfile(session);
  }

  async function handleAuthState(event, session) {
    // Supabase reports a recovery link as PASSWORD_RECOVERY and an invitation
    // redirect as an authenticated SIGNED_IN event. Do not inspect callback
    // query/hash parameters or client metadata to decide this state.
    if (mode === 'callback' && session && (event === 'PASSWORD_RECOVERY' || event === 'SIGNED_IN')) {
      passwordSetupRequired = true;
    }
    await handleSession(session);
  }

  async function signIn(event) {
    event.preventDefault();
    var email = element('admin-email').value.trim();
    var password = element('admin-password').value;
    if (!email || !password) {
      message('admin-login-message', 'Enter your email address and password.');
      return;
    }
    message('admin-login-message', '');
    var response = await client.auth.signInWithPassword({ email: email, password: password });
    if (response.error) message('admin-login-message', friendlyError(response.error, 'Unable to sign in.'));
  }

  async function requestReset(event) {
    event.preventDefault();
    var email = element('admin-reset-email').value.trim();
    if (!email) {
      message('admin-reset-message', 'Enter your email address.');
      return;
    }
    var response = await client.auth.resetPasswordForEmail(email, { redirectTo: callbackUrl() });
    message('admin-reset-message', response.error ? friendlyError(response.error, 'Unable to send reset link.') : 'If this address has an ASTRA CMS account, a reset link has been sent.');
  }

  async function setPassword(event) {
    event.preventDefault();
    var password = element('admin-new-password').value;
    var confirmation = element('admin-confirm-password').value;
    if (password.length < 14) {
      message('admin-password-message', 'Use at least 14 characters.');
      return;
    }
    if (password !== confirmation) {
      message('admin-password-message', 'The passwords do not match.');
      return;
    }
    var response = await client.auth.updateUser({ password: password });
    if (response.error) {
      message('admin-password-message', friendlyError(response.error, 'Unable to set your password.'));
      return;
    }
    window.history.replaceState({}, document.title, window.location.pathname);
    passwordSetupRequired = false;
    await handleAuthState('USER_UPDATED', (await client.auth.getSession()).data.session);
  }

  async function logout() {
    await client.auth.signOut();
    currentProfile = null;
    editingNews = null;
    if (mode === 'callback') window.location.assign(loginUrl());
  }

  function bindEvents() {
    var loginForm = element('admin-login-form');
    var resetForm = element('admin-reset-form');
    var passwordForm = element('admin-password-form');
    if (loginForm) loginForm.addEventListener('submit', signIn);
    if (resetForm) resetForm.addEventListener('submit', requestReset);
    if (passwordForm) passwordForm.addEventListener('submit', setPassword);
    if (element('admin-reset-link')) element('admin-reset-link').addEventListener('click', function () { show('admin-reset'); });
    if (element('admin-back-to-login')) element('admin-back-to-login').addEventListener('click', function () { show('admin-login'); });
    if (element('admin-news-nav')) element('admin-news-nav').addEventListener('click', openNewsList);
    if (element('admin-news-back')) element('admin-news-back').addEventListener('click', function () { show('admin-dashboard'); });
    if (element('admin-news-new')) element('admin-news-new').addEventListener('click', function () { openNewsForm(null); });
    if (element('admin-news-form-back')) element('admin-news-form-back').addEventListener('click', openNewsList);
    if (element('admin-news-form')) element('admin-news-form').addEventListener('submit', saveNews);
    if (element('admin-news-submit')) element('admin-news-submit').addEventListener('click', submitNewsForReview);
    if (element('admin-news-return')) element('admin-news-return').addEventListener('click', returnNewsToDraft);
    if (newsField('type')) newsField('type').addEventListener('change', toggleEventFields);
    ['admin-logout', 'admin-denied-logout'].forEach(function (id) { if (element(id)) element(id).addEventListener('click', logout); });
  }

  async function bootSupabase() {
    if (!config.supabaseUrl || !config.supabasePublishableKey || !window.supabase) {
      deny('The ASTRA CMS is not configured for this build. Contact an administrator.');
      return;
    }
    client = window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });
    client.auth.onAuthStateChange(function (event, session) {
      window.setTimeout(function () { handleAuthState(event, session); }, 0);
    });
    var response = await client.auth.getSession();
    await handleAuthState('INITIAL_SESSION', response.data.session);
  }

  async function boot() {
    bindGithubEvents();
    if (githubSettings()) {
      await bootGithub();
      return;
    }
    bindEvents();
    await bootSupabase();
  }

  boot();
}());
