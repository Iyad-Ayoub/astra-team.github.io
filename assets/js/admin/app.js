(function () {
  'use strict';

  var config = window.ASTRA_CMS_CONFIG || {};
  var mode = document.body.dataset.adminMode;
  var client;
  var validRoles = ['admin', 'editor', 'contributor'];
  var passwordSetupRequired = false;

  function element(id) { return document.getElementById(id); }
  function setHidden(id, hidden) { var node = element(id); if (node) node.hidden = hidden; }
  function text(id, value) { var node = element(id); if (node) node.textContent = value || ''; }
  function message(id, value) { text(id, value); }

  function show(name) {
    ['admin-loading', 'admin-login', 'admin-reset', 'admin-dashboard', 'admin-denied', 'admin-password-setup'].forEach(function (id) {
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
    show('admin-dashboard');
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
    ['admin-logout', 'admin-denied-logout'].forEach(function (id) { if (element(id)) element(id).addEventListener('click', logout); });
  }

  async function boot() {
    bindEvents();
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

  boot();
}());
