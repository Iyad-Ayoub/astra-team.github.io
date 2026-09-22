(function () {
  'use strict';

  var config = window.ASTRA_CMS_CONFIG || {};
  var mode = document.body.dataset.adminMode;
  var client;
  var validRoles = ['admin', 'editor', 'contributor'];
  var validNewsTypes = ['news', 'event', 'award', 'project', 'open-source', 'team', 'collaboration', 'demo'];
  var passwordSetupRequired = false;
  var currentProfile;
  var editingNews;
  var githubSessionKey = 'astra-github-cms-session';
  var githubTransactionKey = 'astra-github-cms-transaction';

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
    ['admin-loading', 'admin-github-login', 'admin-github-dashboard', 'admin-github-route', 'admin-denied'].forEach(function (id) {
      setHidden(id, id !== name);
    });
  }

  function githubMessage(value) { message('admin-github-login-message', value); }

  function denyGithub(reason) {
    sessionStorage.removeItem(githubSessionKey);
    text('admin-denied-message', reason);
    showGithub('admin-denied');
  }

  function base64Url(bytes) {
    var binary = '';
    bytes.forEach(function (byte) { binary += String.fromCharCode(byte); });
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
  }

  function randomValue() {
    var bytes = new Uint8Array(32);
    window.crypto.getRandomValues(bytes);
    return base64Url(bytes);
  }

  async function pkceChallenge(verifier) {
    var bytes = new TextEncoder().encode(verifier);
    var digest = await window.crypto.subtle.digest('SHA-256', bytes);
    return base64Url(new Uint8Array(digest));
  }

  function storedGithubSession() {
    try {
      var session = JSON.parse(sessionStorage.getItem(githubSessionKey) || 'null');
      if (!session || !session.accessToken || !session.expiresAt || Date.parse(session.expiresAt) <= Date.now()) return null;
      return session;
    } catch (_) { return null; }
  }

  function storeGithubSession(session) {
    if (!session || !session.access_token || !session.expires_at) throw new Error('The broker did not return a valid GitHub session.');
    sessionStorage.setItem(githubSessionKey, JSON.stringify({ accessToken: session.access_token, expiresAt: session.expires_at }));
  }

  function githubApi(path, accessToken) {
    return fetch('https://api.github.com' + path, {
      headers: { Accept: 'application/vnd.github+json', Authorization: 'Bearer ' + accessToken, 'X-GitHub-Api-Version': '2022-11-28' },
      cache: 'no-store'
    });
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
    var route = document.body.dataset.adminRoute;
    if (route) {
      showGithub('admin-github-route');
      return;
    }
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
    if (!github || !window.crypto || !window.crypto.subtle) {
      githubMessage('GitHub sign-in is not configured for this build.');
      return;
    }
    var state = randomValue();
    var verifier = randomValue();
    var challenge = await pkceChallenge(verifier);
    var returnTo = window.location.pathname + window.location.search;
    sessionStorage.setItem(githubTransactionKey, JSON.stringify({ state: state, verifier: verifier, returnTo: returnTo }));
    var authorizeUrl = new URL('/authorize', github.brokerUrl + '/');
    authorizeUrl.search = new URLSearchParams({
      client_id: github.clientId,
      redirect_uri: githubCallbackUrl(),
      state: state,
      code_challenge: challenge,
      code_challenge_method: 'S256',
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
    var state = params.get('state');
    var transaction;
    try { transaction = JSON.parse(sessionStorage.getItem(githubTransactionKey) || 'null'); } catch (_) { transaction = null; }
    if (!github || !ticket || !state || !transaction || state !== transaction.state) {
      denyGithub('This GitHub sign-in link is invalid, expired, or no longer available.');
      return;
    }
    window.history.replaceState({}, document.title, window.location.pathname);
    try {
      var response = await fetch(new URL('/session/exchange', github.brokerUrl + '/').toString(), {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ ticket: ticket, state: state, code_verifier: transaction.verifier, redirect_uri: githubCallbackUrl() })
      });
      if (!response.ok) throw new Error('The GitHub sign-in session could not be completed.');
      storeGithubSession(await response.json());
      sessionStorage.removeItem(githubTransactionKey);
      var identity = await verifyGithubRepositoryAccess(storedGithubSession());
      window.location.replace(new URL(transaction.returnTo || adminRootUrl(), window.location.origin).toString());
      return identity;
    } catch (error) { denyGithub(friendlyError(error, 'GitHub sign-in failed.')); }
  }

  async function bootGithub() {
    if (mode === 'callback') {
      await completeGithubCallback();
      return;
    }
    var session = storedGithubSession();
    if (!session) { showGithub('admin-github-login'); return; }
    try { showGithubAuthenticated(await verifyGithubRepositoryAccess(session)); }
    catch (error) { denyGithub(friendlyError(error, 'GitHub repository access could not be verified.')); }
  }

  function logoutGithub() {
    sessionStorage.removeItem(githubSessionKey);
    sessionStorage.removeItem(githubTransactionKey);
    window.location.assign(adminRootUrl());
  }

  function bindGithubEvents() {
    document.querySelectorAll('#admin-github-login-button').forEach(function (button) { button.addEventListener('click', beginGithubLogin); });
    document.querySelectorAll('#admin-github-logout').forEach(function (button) { button.addEventListener('click', logoutGithub); });
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
      homepage: newsField('homepage').checked
    };
  }

  function validateNewsPayload(payload) {
    if (!payload.title || !payload.summary || !payload.body || !payload.content_date) return 'Complete the required fields.';
    if (validNewsTypes.indexOf(payload.type) === -1) return 'Choose a supported content type.';
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
    if (!safeNewsText(payload.title) || !safeNewsText(payload.summary) || !safeNewsText(payload.body)) return 'Liquid syntax, script tags, and inline event handlers are not allowed.';
    return '';
  }

  function resetNewsForm(record) {
    editingNews = record || null;
    text('admin-news-form-title', record ? 'Edit News or Event' : 'New News or Event');
    newsField('title').value = record ? record.title : '';
    newsField('type').value = record ? record.type : 'news';
    newsField('summary').value = record ? record.summary : '';
    newsField('body').value = record ? record.body : '';
    newsField('content-date').value = record ? record.content_date : '';
    newsField('event-date').value = record && record.event_date ? record.event_date : '';
    newsField('end-date').value = record && record.end_date ? record.end_date : '';
    newsField('location').value = record && record.location ? record.location : '';
    newsField('external-url').value = record && record.external_url ? record.external_url : '';
    newsField('featured').checked = Boolean(record && record.featured);
    newsField('homepage').checked = Boolean(record && record.homepage);
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
    bindEvents();
    bindGithubEvents();
    if (githubSettings()) {
      await bootGithub();
      return;
    }
    await bootSupabase();
  }

  boot();
}());
