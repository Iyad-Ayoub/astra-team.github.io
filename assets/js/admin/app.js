(function () {
  'use strict';

  var config = window.ASTRA_CMS_CONFIG || {};
  var mode = document.body.dataset.adminMode;
  var validNewsTypes = ['event', 'award', 'project', 'open-source', 'team', 'collaboration', 'demo'];
  var editingNews;
  var publicationSubmitting = false;
  var unpublishSubmitting = false;
  var publicationStatusEpoch = 0;
  var publicationStatusTimer;
  var sessionRestoreEpoch = 0;
  var sessionRestoreInFlight = false;
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
    localStorage.removeItem(githubSessionHandleKey);
    text('admin-denied-message', reason);
    showGithub('admin-denied');
  }

  function storedGithubSession() {
    if (!githubSession || !githubSession.sessionHandle || !githubSession.expiresAt || Date.parse(githubSession.expiresAt) <= Date.now()) return null;
    return githubSession;
  }

  function normalizedGithubSession(session) {
    if (!session || session.authenticated !== true || !session.session_handle || !session.expires_at) throw new Error('The broker did not return a valid CMS session.');
    return { sessionHandle: session.session_handle, expiresAt: session.expires_at, login: session.login || '', avatarUrl: session.avatar_url || '', repository: session.repository || {} };
  }

  function storeNormalizedGithubSession(session) {
    githubSession = session;
    localStorage.setItem(githubSessionHandleKey, session.sessionHandle);
  }

  function storeGithubSession(session) {
    storeNormalizedGithubSession(normalizedGithubSession(session));
  }

  async function restoreGithubSession(handleOverride, commitState) {
    var github = githubSettings();
    if (!github) return null;
    var handle = handleOverride || localStorage.getItem(githubSessionHandleKey);
    if (!handle) return null;
    var response = await fetch(new URL('/v2/session/restore', github.brokerUrl + '/').toString(), { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify({ redirect_uri: githubCallbackUrl(), session_handle: handle }) });
    if (response.status === 401) return null;
    if (!response.ok) throw new Error('The GitHub session could not be restored.');
    var restored = normalizedGithubSession(await response.json());
    if (commitState !== false) storeNormalizedGithubSession(restored);
    return restored;
  }

  async function githubOperation(operation, payload, session) {
    var github = githubSettings();
    var response = await fetch(new URL('/v2/github', github.brokerUrl + '/').toString(), { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify({ session_handle: session.sessionHandle, operation: operation, payload: payload || {} }) });
    var data = await response.json().catch(function () { return {}; });
    if (!response.ok) {
      if (response.status === 401) {
        preserveNewsFormForReauthentication();
        denyGithub('Your GitHub session expired or was revoked. Sign in again to continue.');
      }
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
      var data = await githubOperation('media_index', {}, session);
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
    var data = await githubOperation('media_get', { id: item.id, extension: item.path.split('.').pop() }, session);
    var binary = atob((data.content || '').replace(/\s/g, ''));
    var bytes = Uint8Array.from(binary, function (character) { return character.charCodeAt(0); });
    return new Blob([bytes], { type: item.mime || 'application/octet-stream' });
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
    try { return await githubOperation('draft_branch', {}, session); }
    catch (error) {
      if (error.status !== 404) throw error;
      try { return await githubOperation('ensure_draft_branch', {}, session); }
      catch (creationError) {
        if (creationError.status !== 422) throw creationError;
        return githubOperation('draft_branch', {}, session);
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
    var data = await githubOperation('draft_get', { id: id }, session);
    return { record: parseGithubDraft(fromBase64(data.content)), sha: data.sha };
  }

  function githubDraftMessage(value) { message('admin-github-news-message', value); }

  function currentDraftId() {
    var id = new URLSearchParams(window.location.search).get('id');
    return id && /^news-[a-z0-9]+$/.test(id) ? id : null;
  }

  function publicationBranch(id) { if (!/^news-[a-z0-9]+$/.test(id)) throw new Error('Invalid draft identifier.'); return 'cms-publish/news/' + id; }
  function unpublishBranch(id) { if (!/^news-[a-z0-9]+$/.test(id)) throw new Error('Invalid draft identifier.'); return 'cms-unpublish/news/' + id; }
  function publicSlug(record, published) { if (published) return published.path.replace(/^_news\//, '').replace(/\.md$/, ''); var words = record.title.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 72); return (words || 'news') + '-' + record.id.replace(/^news-/, '').slice(-8); }
  function publicNewsPath(record, published) { return published ? published.path : '_news/' + publicSlug(record) + '.md'; }
  async function publishedNewsByContentId(session, id) { return githubOperation('published_find', { id: id }, session); }
  function publicMediaPath(record, media) { return 'assets/img/news/' + record.id + '/' + media.path.split('/').pop(); }
  function publicationMessage(value) { message('admin-publication-message', value); }
  function serializePublicNews(record, media, published) {
    var fields = { layout: 'news', content_id: record.id, slug: publicSlug(record, published), title: record.title, status: 'published', type: record.type, event_date: record.event_date, summary: record.summary, featured: record.featured, homepage: record.homepage, end_date: record.end_date, location: record.location, external_url: record.external_url, date_precision: 'day', image: media ? '/' + publicMediaPath(record, media) : null, image_alt: media ? media.alt_text || media.filename : null };
    return '---\n' + Object.keys(fields).filter(function (key) { return fields[key] !== null && fields[key] !== ''; }).map(function (key) { return key + ': ' + JSON.stringify(fields[key]); }).join('\n') + '\n---\n\n' + record.body.trim() + '\n';
  }
  async function draftMedia(session, record) { if (!record.cover_media_id) return null; await readMediaIndex(session); var media = mediaIndex.find(function (item) { return item.id === record.cover_media_id; }); if (!media) throw new Error('Referenced cover media is missing.'); return media; }
  function publicationDetails(value, pullLink, publicLink) { var box = element('admin-publication-message'); if (!box) return; box.replaceChildren(); if (value) { var detail = document.createElement('span'); detail.textContent = value; box.appendChild(detail); } [[pullLink, 'View pull request'], [publicLink, 'View public News page']].forEach(function (entry) { if (!entry[0]) return; var anchor = document.createElement('a'); anchor.href = entry[0]; anchor.textContent = entry[1]; anchor.className = 'astra-admin-text-link'; box.appendChild(anchor); }); }
  function publicNewsUrl(published) { if (!published) return null; var prefix = adminRootUrl().replace(/admin\/$/, ''); return new URL('news/' + publicSlug({}, published) + '/', prefix).toString(); }
  function setPublicationStatus(value) { text('admin-publication-status', value); var button = element('admin-news-publish'), update = element('admin-news-update'), unpublish = element('admin-news-unpublish'); if (button) { button.hidden = value !== 'Draft'; button.disabled = value !== 'Draft'; } if (update) { update.hidden = value !== 'Update available'; update.disabled = value !== 'Update available'; } if (unpublish) { unpublish.hidden = value !== 'Published'; unpublish.disabled = value !== 'Published'; } }
  function renderPublicationState(value, detail, pullLink, publicLink) { setPublicationStatus(value); publicationDetails(detail, pullLink, publicLink); }
  function setPublicationLoading() { publicationStatusEpoch += 1; stopPublicationStatusPolling(); renderPublicationState('Checking publication status…', ''); }
  async function createPublicationCommit(session, branch, record, media, published) {
    var files = [{ path: publicNewsPath(record, published), mode: '100644', type: 'blob', content: utf8Base64(serializePublicNews(record, media, published)) }];
    if (media) { var image = await githubMediaBlob(session, media); var bytes = new Uint8Array(await image.arrayBuffer()); files.push({ path: publicMediaPath(record, media), mode: '100644', type: 'blob', content: bytesBase64(bytes) }); }
    await githubOperation('publication_prepare', { id: record.id, news_path: publicNewsPath(record, published), markdown: files[0].content, media: files[1] ? { extension: files[1].path.split('.').pop(), filename: files[1].path.split('/').pop(), content: files[1].content } : null }, session);
  }
  async function ensureLifecycleBranch(session, branch) { return githubOperation('ensure_branch', { id: branch.split('/').pop(), kind: branch.indexOf('cms-unpublish/') === 0 ? 'unpublish' : 'publish' }, session); }
  async function publicationBranchMatchesDraft(session, record, branch, published, media) { try { var data = await githubOperation('public_file', { branch: branch, path: publicNewsPath(record, published) }, session); return fromBase64(data.content) === serializePublicNews(record, media, published); } catch (error) { return false; } }
  function stopPublicationStatusPolling() { if (publicationStatusTimer) { window.clearTimeout(publicationStatusTimer); publicationStatusTimer = null; } }
  function schedulePublicationStatusPolling(session, record, knownLifecycle) { stopPublicationStatusPolling(); publicationStatusTimer = window.setTimeout(function () { loadPublicationStatus(session, record, knownLifecycle); }, 15000); }
  function validationDetail(validation, unpublish) { if (validation === 'passed') return unpublish ? 'Validation passed. Ready to merge.' : 'Validation passed. Ready to publish.'; return validation === 'failed' ? 'Validation failed.' : 'Validation in progress…'; }
  async function publicationValidationState(session, pull, unpublish) { try { var checks = await githubOperation('checks', { sha: pull.head.sha }, session); var validation = (checks.check_runs || []).filter(function (check) { return unpublish || check.name === 'CMS publication validation'; }); if (!validation.length || validation.some(function (check) { return check.status !== 'completed'; })) return 'pending'; return validation.every(function (check) { return ['success', 'neutral', 'skipped'].indexOf(check.conclusion) !== -1; }) ? 'passed' : 'failed'; } catch (_) { return 'unknown'; } }
  async function loadPublicationStatus(session, record, knownLifecycle) { var epoch = ++publicationStatusEpoch, branch = publicationBranch(record.id), removal = unpublishBranch(record.id); stopPublicationStatusPolling(); try { var published = await publishedNewsByContentId(session, record.id), media = await draftMedia(session, record), pulls = await githubOperation('pulls', { id: record.id, kind: 'publish', state: 'open' }, session), removals = await githubOperation('pulls', { id: record.id, kind: 'unpublish', state: 'open' }, session); if (epoch !== publicationStatusEpoch) return; if (removals.length) { var removal = removals[0], removalValidation = await publicationValidationState(session, removal, true); if (epoch !== publicationStatusEpoch) return; renderPublicationState('Unpublish submitted', validationDetail(removalValidation, true), removal.html_url); if (removalValidation === 'pending' || removalValidation === 'unknown') schedulePublicationStatusPolling(session, record, { state: 'Unpublish submitted', pull: removal, unpublish: true }); return; } if (pulls.length) { var pull = pulls[0], validation = await publicationValidationState(session, pull); if (epoch !== publicationStatusEpoch) return; var detail = validationDetail(validation, false); if (!await publicationBranchMatchesDraft(session, record, branch, published, media)) detail = 'Draft changed after submission. The existing request remains unchanged. ' + detail; if (epoch !== publicationStatusEpoch) return; var state = published ? 'Update submitted' : 'Submitted'; renderPublicationState(state, detail, pull.html_url, publicNewsUrl(published)); if (validation === 'pending' || validation === 'unknown') schedulePublicationStatusPolling(session, record, { state: state, pull: pull, unpublish: false }); return; } if (published) { if (serializePublicNews(record, media, published) === published.markdown) renderPublicationState('Published', '', null, publicNewsUrl(published)); else renderPublicationState('Update available', '', null, publicNewsUrl(published)); return; } } catch (error) { if (epoch !== publicationStatusEpoch) return; if (knownLifecycle) { renderPublicationState(knownLifecycle.state, 'Validation in progress…', knownLifecycle.pull.html_url); schedulePublicationStatusPolling(session, record, knownLifecycle); return; } renderPublicationState('Error/Conflict', friendlyError(error, 'Unable to determine publication status.')); return; } if (epoch === publicationStatusEpoch) renderPublicationState('Draft', ''); }
  function setPublicationBusy(busy) { publicationSubmitting = busy; ['admin-news-publish', 'admin-news-update'].forEach(function (id) { var button = element(id); if (button) button.disabled = busy || button.hidden; }); }
  function preserveNewsFormForReauthentication() { var form = element('admin-github-news-form'); if (!form) return; try { sessionStorage.setItem('astra-cms-reauth-draft', JSON.stringify({ route: window.location.pathname + window.location.search, contentId: currentDraftId(), draftPath: currentDraftId() ? draftPath(currentDraftId()) : null, draftSha: editingNews && editingNews.githubSha ? editingNews.githubSha : null, fields: collectNewsPayload() })); } catch (_) {} }
  function restoreNewsFormAfterReauthentication() { try { var saved = JSON.parse(sessionStorage.getItem('astra-cms-reauth-draft') || 'null'); if (!saved || saved.route !== window.location.pathname + window.location.search || saved.contentId !== currentDraftId() || !saved.fields) return; var changed = saved.draftSha && editingNews && editingNews.githubSha && saved.draftSha !== editingNews.githubSha; if (changed) { var restoreLocal = window.confirm('This News draft changed on GitHub while you were signed out. Choose OK to restore your local unsaved changes, or Cancel to keep the newer server draft.'); if (!restoreLocal) { sessionStorage.removeItem('astra-cms-reauth-draft'); setNewsMessage('Kept the newer GitHub draft; local recovery data was discarded.'); return; } setNewsMessage('Restored local changes from the matching recovery snapshot. Review before saving.'); } Object.keys(saved.fields).forEach(function (key) { var field = newsField(key.replace(/_/g, '-')); if (!field) return; if (field.type === 'checkbox') field.checked = Boolean(saved.fields[key]); else field.value = saved.fields[key] || ''; }); sessionStorage.removeItem('astra-cms-reauth-draft'); toggleEventFields(); } catch (_) {} }
  async function submitGithubPublication() {
    if (publicationSubmitting) return;
    publicationStatusEpoch += 1;
    stopPublicationStatusPolling();
    var id = currentDraftId(), session = storedGithubSession() || await restoreGithubSession();
    if (!id || !session) { preserveNewsFormForReauthentication(); publicationMessage('Your GitHub session has expired. Sign in again to continue this publication request.'); await beginGithubLogin(); return; }
    setPublicationBusy(true); renderPublicationState('Submitting publication request…', '');
    try {
      await verifyGithubRepositoryAccess(session);
      var draft = await readGithubDraft(session, id), record = draft.record, github = githubSettings(), base = '/repos/' + github.repoOwner + '/' + github.repoName, branch = publicationBranch(id), published = await publishedNewsByContentId(session, id);
      if (validNewsTypes.indexOf(record.type) === -1) throw new Error('This draft uses a legacy unsupported type. Select a canonical public type before publication.');
      var pulls = await githubOperation('pulls', { id: id, kind: 'publish', state: 'open' }, session);
      if (pulls.length) { var existingState = published ? 'Update submitted' : 'Submitted'; renderPublicationState(existingState, 'Validation in progress…', pulls[0].html_url, publicNewsUrl(published)); await loadPublicationStatus(session, record, { state: existingState, pull: pulls[0], unpublish: false }); return; }
      await ensureLifecycleBranch(session, branch);
      var media = await draftMedia(session, record);
      await createPublicationCommit(session, branch, record, media, published);
      var pr = await githubOperation('create_pr', { id: id, kind: 'publish', title: 'Publish News: ' + record.title, body: 'CMS publication\n\nContent ID: ' + id + '\nType: ' + record.type + '\nCover media: ' + (media ? 'included' : 'none') + '\nSource: ' + githubDraftBranch + '/' + draftPath(id) }, session);
      renderPublicationState(published ? 'Update submitted' : 'Submitted', 'Validation in progress…', pr.html_url, publicNewsUrl(published));
      await loadPublicationStatus(session, record, { state: published ? 'Update submitted' : 'Submitted', pull: pr, unpublish: false });
    } catch (error) { renderPublicationState('Draft', friendlyError(error, 'Unable to submit this draft for publication.')); }
    finally { setPublicationBusy(false); }
  }

  async function submitGithubUnpublish() {
    if (unpublishSubmitting || publicationSubmitting) return;
    if (!window.confirm('Unpublish this News item?\n\nIt will be removed from the public website after approval. The CMS draft and media will be kept.')) return;
    publicationStatusEpoch += 1;
    stopPublicationStatusPolling();
    var id = currentDraftId(), session = storedGithubSession() || await restoreGithubSession();
    if (!id || !session) { publicationMessage('Your GitHub session has expired. Sign in again before requesting unpublish.'); return; }
    unpublishSubmitting = true;
    renderPublicationState('Requesting unpublish…', '');
    try {
      await verifyGithubRepositoryAccess(session);
      var github = githubSettings(), base = '/repos/' + github.repoOwner + '/' + github.repoName, branch = unpublishBranch(id), published = await publishedNewsByContentId(session, id);
      if (!published) throw new Error('No published News item was found for this draft.');
      var pulls = await githubOperation('pulls', { id: id, kind: 'unpublish', state: 'open' }, session);
      var lifecycleRecord = editingNews || { id: id, cover_media_id: null };
      if (pulls.length) { renderPublicationState('Unpublish submitted', 'Validation in progress…', pulls[0].html_url); await loadPublicationStatus(session, lifecycleRecord, { state: 'Unpublish submitted', pull: pulls[0], unpublish: true }); return; }
      var publicationPulls = await githubOperation('pulls', { id: id, kind: 'publish', state: 'open' }, session);
      if (publicationPulls.length) throw new Error('An existing publication or update request must be resolved before unpublishing.');
      await ensureLifecycleBranch(session, branch);
      await githubOperation('unpublish_prepare', { id: id, path: published.path }, session);
      var pr = await githubOperation('create_pr', { id: id, kind: 'unpublish', title: 'Unpublish News: ' + id, body: 'CMS unpublish request\n\nContent ID: ' + id + '\nPublic file: ' + published.path + '\nPublic media remains in place until it can be proven unreferenced.' }, session);
      renderPublicationState('Unpublish submitted', 'Validation in progress…', pr.html_url);
      await loadPublicationStatus(session, lifecycleRecord, { state: 'Unpublish submitted', pull: pr, unpublish: true });
    } catch (error) { renderPublicationState('Error/Conflict', friendlyError(error, 'Unable to request removal from the website.')); }
    finally { unpublishSubmitting = false; }
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
      var response = await githubOperation('draft_save', { id: id, content: body.content, sha: body.sha }, session);
      editingNews = payload;
      editingNews.githubSha = response.content.sha;
      try { sessionStorage.removeItem('astra-cms-reauth-draft'); } catch (_) {}
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
        try { entries = await githubOperation('draft_list', {}, session); } catch (error) { if (error.status === 404) entries = []; else throw error; }
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
        if (id) { setPublicationLoading(); var loaded = await readGithubDraft(session, id); loaded.record.githubSha = loaded.sha; resetNewsForm(loaded.record); populateCoverMedia(loaded.record, session); await loadPublicationStatus(session, loaded.record); } else { resetNewsForm(null); populateCoverMedia(null, session); }
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
      await githubOperation('media_upload', { id: id, extension: type.extension, content: bytesBase64(bytes), metadata: item }, session);
      var updated = index.items.concat([item]);
      mediaIndex = updated; element('admin-media-upload-form').reset(); mediaMessage('Image uploaded to the GitHub draft branch.'); renderMediaLibrary(session);
    } catch (error) { mediaMessage(error.status === 409 ? 'Media changed in GitHub. Reload the library and try again.' : friendlyError(error, 'Unable to upload this image.')); }
  }

  async function verifyGithubRepositoryAccess(session) {
    if (!session || !session.login || !session.repository || session.repository.push !== true) throw new Error('GitHub write access to the ASTRA repository is required for CMS access.');
    return { user: { login: session.login, avatar_url: session.avatarUrl }, repository: { full_name: session.repository.full_name, permissions: { push: session.repository.push } } };
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
      var response = await fetch(new URL('/v2/session/exchange', github.brokerUrl + '/').toString(), {
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
    if (github) { try { await fetch(new URL('/v2/session/logout', github.brokerUrl + '/').toString(), { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ session_handle: handle }) }); } catch (_) {} }
    window.location.assign(adminRootUrl());
  }

  async function restoreFromOtherTab(expectedHandle) {
    var epoch = ++sessionRestoreEpoch;
    if (sessionRestoreInFlight) return;
    sessionRestoreInFlight = true;
    preserveNewsFormForReauthentication();
    try {
      var session = await restoreGithubSession(expectedHandle, false);
      if (epoch !== sessionRestoreEpoch || localStorage.getItem(githubSessionHandleKey) !== expectedHandle) return;
      if (!session) { denyGithub('Your GitHub session expired or was revoked. Sign in again to continue.'); return; }
      storeNormalizedGithubSession(session);
      var identity = await verifyGithubRepositoryAccess(session);
      if (epoch !== sessionRestoreEpoch || localStorage.getItem(githubSessionHandleKey) !== expectedHandle) return;
      showGithubAuthenticated(identity);
      await loadGithubNewsRoute(identity);
      githubDraftMessage('GitHub session restored from another tab.');
    } catch (error) { if (epoch === sessionRestoreEpoch) denyGithub(friendlyError(error, 'GitHub session restoration failed.')); }
    finally {
      sessionRestoreInFlight = false;
      var latest = localStorage.getItem(githubSessionHandleKey);
      if (latest && latest !== expectedHandle && epoch !== sessionRestoreEpoch) void restoreFromOtherTab(latest);
    }
  }

  function bindGithubEvents() {
    document.querySelectorAll('#admin-github-login-button').forEach(function (button) { button.addEventListener('click', beginGithubLogin); });
    document.querySelectorAll('#admin-github-relogin-button').forEach(function (button) { button.addEventListener('click', beginGithubLogin); });
    document.querySelectorAll('#admin-github-logout').forEach(function (button) { button.addEventListener('click', logoutGithub); });
    if (element('admin-github-news-form')) element('admin-github-news-form').addEventListener('submit', saveGithubDraft);
    if (element('admin-news-publish')) element('admin-news-publish').addEventListener('click', submitGithubPublication);
    if (element('admin-news-update')) element('admin-news-update').addEventListener('click', submitGithubPublication);
    if (element('admin-news-unpublish')) element('admin-news-unpublish').addEventListener('click', submitGithubUnpublish);
    if (newsField('type')) newsField('type').addEventListener('change', toggleEventFields);
    if (element('admin-media-upload-form')) element('admin-media-upload-form').addEventListener('submit', uploadMedia);
    if (newsField('cover-media-id')) newsField('cover-media-id').addEventListener('change', function () { renderCoverPreview(mediaIndex.find(function (item) { return item.id === newsField('cover-media-id').value; }), storedGithubSession()); });
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
    setNewsMessage('');
    toggleEventFields();
    restoreNewsFormAfterReauthentication();
  }

  async function boot() {
    bindGithubEvents();
    window.addEventListener('storage', function (event) {
      if (event.key !== githubSessionHandleKey || event.newValue === (githubSession && githubSession.sessionHandle)) return;
      if (event.newValue) void restoreFromOtherTab(event.newValue);
      else denyGithub('You have been signed out. Sign in again to continue.');
    });
    await bootGithub();
  }

  boot();
}());
