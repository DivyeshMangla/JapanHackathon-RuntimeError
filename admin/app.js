const $ = s => document.querySelector(s);
// Markup templates are written across lines to be readable. `html` drops a
// line break and the indentation after it wherever it comes before a tag or
// before an interpolation, so the markup it returns is exactly what the same
// template written on one line would produce.
const html = (strings, ...values) =>
  strings.reduce(
    (markup, text, i) =>
      markup + text.replace(/\n\s*(?=<|$)/g, '') + (i < values.length ? values[i] : ''),
    '',
  );

const esc = v =>
  String(v ?? '').replace(
    /[&<>"']/g,
    c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
  );
const paths = {
  wave: 'M3 10v4m4-8v12m5-15v18m5-16v14m4-10v6',
  grid: 'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z',
  users:
    'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2m20 0v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  heart:
    'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8',
  mic: 'M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3m-7 8v2a7 7 0 0 0 14 0v-2m-7 9v3m-4 0h8',
  activity: 'M3 12h4l3-8 4 16 3-8h4',
  settings:
    'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8m-9 4 2-1 .5-3 3-2 2 1 3-1 2 2 3 .5 1 3-1 2 .5 3-3 2-2-1-3 1-2-2-3-.5-1-3z',
  arrow: 'M5 12h14m-6-6 6 6-6 6',
  plus: 'M12 5v14M5 12h14',
  search: 'M21 21l-5-5M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0',
  logout: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4m7 14 5-5-5-5M21 12H9',
  calendar: 'M8 2v4m8-4v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14H3V6a2 2 0 0 1 2-2',
  check: 'M5 12l4 4L19 6',
  close: 'M6 6l12 12M18 6 6 18',
  down: 'M6 9l6 6 6-6',
  download: 'M12 3v12m-5-5 5 5 5-5M5 17v4h14v-4',
  shield: 'M12 3 3 7v5c0 5 9 9 9 9s9-4 9-9V7zM8 12l3 3 5-5',
  book: 'M4 3h7a3 3 0 0 1 3 3v15a3 3 0 0 0-3-3H4zM14 6a3 3 0 0 1 3-3h4v15h-4a3 3 0 0 0-3 3',
  clock: 'M12 8v5l3 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0',
  refresh: 'M20 7V3l-3 3a8 8 0 1 0 3 10M20 7h-5',
};
const icon = name =>
  html`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[name] || paths.grid}"/></svg>`;
const initials = name =>
  name
    .replace(/^Dr\.\s*/, '')
    .split(' ')
    .map(x => x[0])
    .slice(0, 2)
    .join('');
const avatar = (name, i = 0) =>
  `<span class="avatar ${['mint', 'lilac', 'peach'][i % 3]}">${esc(initials(name))}</span>`;
const badge = (label, cls = '') => `<span class="badge ${cls}">${esc(label)}</span>`;
const date = v =>
  v ? new Date(v).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }) : '—';
const relative = v => {
  if (!v) return 'No practice yet';
  const n = Math.max(0, Math.floor((Date.now() - new Date(v)) / 86400000));
  return n === 0 ? 'Today' : n === 1 ? 'Yesterday' : `${n} days ago`;
};
let user,
  config,
  overview,
  page = 'overview',
  filter = 'all',
  search = '',
  events = [],
  loadNumber = 0;
async function api(path, method = 'GET', payload) {
  const res = await fetch(`/api${path}`, {
    method,
    headers: payload ? { 'Content-Type': 'application/json' } : {},
    body: payload ? JSON.stringify(payload) : undefined,
  });
  const data = await res.json();
  if (!res.ok) {
    if (res.status === 401 && user) {
      user = null;
      renderLogin();
    }
    throw new Error(data.error || 'Request failed.');
  }
  return data;
}
function toast(message) {
  $('#toast').textContent = message;
  $('#toast').classList.add('show');
  setTimeout(() => $('#toast').classList.remove('show'), 4000);
}
function brand() {
  return html`<div class="brand">
    <span class="brand-mark"><svg viewBox="0 0 100 100" aria-hidden="true"><ellipse cx="28" cy="38" rx="6.5" ry="12.5" transform="rotate(-28 28 38)" fill="#FFC95C"/><ellipse cx="47" cy="26" rx="6.5" ry="13.5" transform="rotate(-8 47 26)" fill="#4FB8A4"/><ellipse cx="67" cy="32" rx="6" ry="12" transform="rotate(38 67 32)" fill="#F28BA8"/><ellipse cx="80" cy="50" rx="5.5" ry="11" transform="rotate(72 80 50)" fill="#A98BD6"/><circle cx="50" cy="66" r="19" fill="none" stroke="#34408F" stroke-width="14"/><circle cx="45.5" cy="63" r="1.9" fill="#34408F"/><circle cx="54.5" cy="63" r="1.9" fill="#34408F"/><path d="M53.1 71.1A5.5 5.5 0 0 1 46.9 71.1" fill="none" stroke="#34408F" stroke-width="1.8" stroke-linecap="round"/></svg></span>
    <span class="brand-text">melo
      <small>CARE WORKSPACE</small>
    </span>
  </div>`;
}
function renderLogin(error = '') {
  $('#app').innerHTML = html`<main class="login-shell">
    <section class="login-art">${brand()}
      <h1>A little practice.
        <br>A meaningful
        <br>
        <em>difference.</em>
      </h1>
      <p>A shared space for the people helping every voice find its way.</p>
      <div class="sound-wave" aria-hidden="true">${'<i></i>'.repeat(25)}</div>
    </section>
    <section class="login-panel">
      <div class="login-form">
        <div class="eyebrow">MELO / CARE TEAM</div>
        <h2>Welcome back.</h2>
        <p>Sign in to manage your care team and keep your patients moving forward.</p>
        <form id="login">
          <label class="field">Email address
            <input name="email" type="email" placeholder="you@clinic.com" autocomplete="username" required>
          </label>
          <label class="field">Password
            <input name="password" type="password" placeholder="Enter your password" autocomplete="current-password" required>
          </label>
          <div id="login-error">${error ? `<p class="form-error">${esc(error)}</p>` : ''}</div>
          <button class="btn" type="submit">Sign in to workspace ${icon('arrow')}</button>
        </form>
        ${
          config?.demo
            ? html`<div class="demo-note">
              <strong>Explore the demo workspace</strong>
              <br>All people and activity here are synthetic.
              <button type="button" id="demo-login">Use demo administrator account →</button>
            </div>`
            : ''
        }
        <p class="login-footer">Administrator and approved therapist access. Patients use the mobile app.</p>
      </div>
    </section>
  </main>`;
  $('#login').onsubmit = async e => {
    e.preventDefault();
    const button = e.target.querySelector('button');
    button.disabled = true;
    const b = Object.fromEntries(new FormData(e.target));
    try {
      const data = await api('/auth/login', 'POST', b);
      if (!['admin', 'therapist'].includes(data.user.role)) {
        await api('/auth/logout', 'POST', {});
        throw Error(
          'Patients use the mobile app. This workspace is for administrators and approved therapists.',
        );
      }
      user = data.user;
      await load();
    } catch (err) {
      $('#login-error').innerHTML = `<p class="form-error">${esc(err.message)}</p>`;
      button.disabled = false;
    }
  };
  $('#demo-login')?.addEventListener('click', () => {
    $('#login [name=email]').value = 'admin@melo.test';
    $('#login [name=password]').value = 'VoiceDemo!2026';
    $('#login').requestSubmit();
  });
}
const navItems = [
  ['overview', 'grid', 'Overview'],
  ['patients', 'users', 'Patients'],
  ['therapists', 'heart', 'Therapists'],
  ['recordings', 'mic', 'Recordings'],
  ['activity', 'activity', 'Activity log'],
  ['settings', 'settings', 'Settings'],
];
async function load() {
  const ticket = ++loadNumber;
  try {
    if (user?.role === 'therapist') {
      const result = await api('/patients');
      if (ticket !== loadNumber) return;
      overview = { patients: result.patients };
      renderTherapist();
      return;
    }
    const result = await api('/overview');
    if (ticket !== loadNumber) return;
    overview = result;
    if (page === 'activity') events = (await api('/audit')).events;
    render();
  } catch (e) {
    if (user) toast(e.message);
  }
}
function render() {
  if (!user) return renderLogin();
  const title = navItems.find(n => n[0] === page)?.[2] || 'Overview';
  $('#app').innerHTML = html`<div class="app">
    <aside class="sidebar">${brand()}
      <div class="workspace-label">WORKSPACE</div>
      <nav class="nav" aria-label="Main navigation">${navItems
        .map(
          ([
            id,
            i,
            label,
          ]) => html`<a href="#${id}" class="${page === id ? 'selected' : ''}" ${page === id ? 'aria-current="page"' : ''} title="${label}">${icon(i)}
          <span class="nav-label">${label}</span>
          ${id === 'therapists' && pending().length ? `<span class="count">${pending().length}</span>` : ''}
          </a>`,
        )
        .join('')}</nav>
      <div class="sidebar-foot">
        <div class="help-card">${icon('shield')}
          <br>
          <br>
          <strong>Thoughtful care, together.</strong>
          <p>One workspace. A clearer picture of every patient’s journey.</p>
        </div>
        <div class="profile">${avatar(user.name)}
          <div>
            <strong>${esc(user.name)}</strong>
            <small>Workspace administrator</small>
          </div>
          <button id="logout" title="Sign out">${icon('logout')}</button>
        </div>
      </div>
    </aside>
    <main class="main">
      <header class="topbar">
        <div class="breadcrumb">Workspace 
          <span class="muted"> / </span> 
          <b>${title}</b>
        </div>
        <div class="top-actions">
          <label class="search">${icon('search')}<input id="search" aria-label="Search patients or therapists" placeholder="Search people…" value="${esc(search)}"></label>
          <button class="icon-btn" id="refresh" title="Refresh workspace">${icon('refresh')}</button>
          ${avatar(user.name)}
        </div>
      </header>
      <div id="content">${pageContent()}</div>
      <footer class="workspace-note">
        <span>Melo · Care starts with listening.</span>
        <span>${config.demo ? 'Demo workspace · Synthetic data' : 'Connected workspace'} · ${new Date().getFullYear()}</span>
      </footer>
    </main>
  </div>`;
  $('#logout')?.addEventListener('click', logout);
  $('#refresh').onclick = () => load();
  $('#search').oninput = e => {
    search = e.target.value;
    if (page !== 'patients' && page !== 'therapists') {
      page = 'patients';
      history.replaceState(null, '', '#patients');
      render();
      $('#search').focus();
      $('#search').setSelectionRange(search.length, search.length);
      return;
    }
    $('#content').innerHTML = pageContent();
    bindContent();
  };
  bindContent();
}
function pending() {
  return overview.therapists.filter(t => t.status === 'pending');
}
function header(title, subtitle, actions = '') {
  return html`<section class="page-header">
    <div>
      <div class="eyebrow">YOUR CARE WORKSPACE</div>
      <h1>${title}</h1>
      <p>${subtitle}</p>
    </div>
    <div class="actions">${actions}</div>
  </section>`;
}
const addButton = () =>
  `<button class="btn" data-action="add">${icon('plus')} Add patient</button>`;
const cardHead = (title, subtitle = '', right = '') =>
  html`<div class="card-heading">
    <div>
      <h2>${title}</h2>
      ${subtitle ? `<p>${subtitle}</p>` : ''}
    </div>
    ${right}
  </div>`;
const link = (label, where) =>
  `<a class="text-link" href="#${where}">${label} ${icon('arrow')}</a>`;
function pageContent() {
  if (page === 'overview') return dashboard();
  if (page === 'patients')
    return (
      header(
        'Every patient. One place.',
        'Manage assignments and follow each patient’s progress.',
        addButton(),
      ) +
      html`<div class="filters">${[
        ['all', 'All patients'],
        ['unassigned', 'Unassigned'],
        ['consent', 'Awaiting consent'],
        ['attention', 'Needs a check-in'],
      ]
        .map(
          ([id, label]) =>
            `<button class="filter ${filter === id ? 'active' : ''}" data-filter="${id}">${label}</button>`,
        )
        .join('')}</div>
      <section class="card table-card">${cardHead('Patient directory', `${filteredPatients().length} patients`, `<button class="btn secondary small" data-action="export">${icon('download')} Export CSV</button>`)}
        ${patientTable(filteredPatients())}
      </section>`
    );
  if (page === 'therapists')
    return (
      header(
        'The people behind the progress.',
        'Review registrations and manage your care team.',
        `<button class="btn" data-action="add-therapist">${icon('plus')} Add therapist</button>`,
      ) +
      html`<section class="card">${cardHead('Care team', `${pending().length} registrations awaiting approval`)}
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Therapist</th>
                <th>Clinic / registration</th>
                <th>Patients</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>${overview.therapists
              .filter(t => (t.name + ' ' + t.email).toLowerCase().includes(search.toLowerCase()))
              .map(
                (t, i) =>
                  html`<tr>
                    <td>
                      <div class="person">${avatar(t.name, i)}
                        <div>${esc(t.name)}
                          <small>${esc(t.email)}</small>
                        </div>
                      </div>
                    </td>
                    <td>${esc(t.clinic)}
                      <small class="muted">
                        <br>
                        ${esc(t.registration)}
                      </small>
                    </td>
                    <td>${overview.patients.filter(p => p.therapist_id === t.id).length}</td>
                    <td>${badge(t.status, t.status === 'active' ? '' : t.status)}</td>
                    <td>${
                      t.status === 'pending'
                        ? `<button class="btn lime small" data-review="${t.id}">Review registration</button>`
                        : html`<button class="btn secondary small" data-status="${t.id}" data-next="${t.status === 'active' ? 'disabled' : 'active'}">${t.status === 'active' ? 'Disable access' : 'Enable access'}
                        </button>`
                    }</td>
                  </tr>`,
              )
              .join('')}</tbody>
          </table>
        </div>
      </section>`
    );
  if (page === 'activity')
    return (
      header('A clear record of care.', 'Account changes, consent approvals and care activity.') +
      html`<section class="card">${cardHead('Workspace activity', 'Most recent 200 events')}
        ${events.length ? events.map(activityRow).join('') : '<div class="empty">No activity yet.</div>'}
      </section>`
    );
  if (page === 'recordings')
    return (
      header(
        'Listen to the progress.',
        'Open a patient to review their uploaded practice recordings.',
      ) +
      html`<section class="card">${cardHead('Patient recordings', `${overview.recordings} recordings securely stored`)}
        ${
          overview.recordings === 0
            ? html`<div class="empty">No recordings uploaded yet.
              <br>Patients can record and sync practice from the connected mobile app.
            </div>`
            : patientTable(overview.patients)
        }
      </section>`
    );
  return (
    header('Workspace settings', 'Manage your access and understand your workspace.') +
    html`<div class="settings-grid">
      <section class="card">
        <h3>Workspace</h3>
        <div class="label-value">
          <span>Name</span>
          <b>Melo</b>
        </div>
        <div class="label-value">
          <span>Environment</span>
          <b>${config.demo ? 'Local demonstration' : 'Connected service'}</b>
        </div>
        <div class="label-value">
          <span>Data</span>
          <b>${config.demo ? 'Synthetic sample records' : 'Workspace records'}</b>
        </div>
        <p>The mobile app and this dashboard share the same API. Changes are saved immediately.</p>
      </section>
      <section class="card">
        <h3>Your account</h3>
        <div class="label-value">
          <span>Name</span>
          <b>${esc(user.name)}</b>
        </div>
        <div class="label-value">
          <span>Email</span>
          <b>${esc(user.email)}</b>
        </div>
        <p>Changing your password signs out all existing sessions.</p>
        <button class="btn secondary" data-action="password">Change password</button> 
        <button class="btn secondary" data-action="logout">Sign out</button>
      </section>
      <section class="card full">
        <h3>Consent document</h3>
        <p>${esc(config.consentText)}</p>
        <span class="badge neutral">Version ${esc(config.consentVersion)}</span>
      </section>
    </div>`
  );
}
function dashboard() {
  const patients = overview.patients,
    active = patients.filter(p => p.status === 'active'),
    practicing = active.filter(p => p.active_days > 0),
    unassigned = patients.filter(p => !p.therapist_id);
  return (
    header(
      'Good to see you, ' + esc(user.name.split(' ')[0]) + '.',
      'Here’s how your care community is doing today.',
      html`<span class="date-pill">${icon('calendar')}
        ${new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}
      </span>
      ${addButton()}`,
    ) +
    html`<section class="stats">${stat('Active patients', active.length, `${unassigned.length} awaiting therapist assignment`, 'users', true)}
      ${stat('Care team', overview.therapists.filter(t => t.status === 'active').length, `${pending().length} registrations to review`, 'heart')}
      ${stat('Practicing this week', practicing.length, `${active.length ? Math.round((practicing.length / active.length) * 100) : 0}% of active patients`, 'activity')}
      ${stat('Voice recordings', overview.recordings, 'Available for care team review', 'mic')}
    </section>` +
    html`<div class="grid-main">
      <section class="card">${cardHead('Small steps. Steady progress.', 'Completed practice sessions over the last 14 days', '<span class="legend"><i class="dot"></i> Sessions</span>')}
        ${chart()}
        <div class="chart-foot">
          <span>Every session is a step forward.</span>
          <strong>${overview.activity.reduce((n, x) => n + x.sessions, 0)} sessions completed</strong>
        </div>
      </section>
      <section class="card">${cardHead('Your attention, please', `${pending().length} therapist registrations awaiting review`, badge(pending().length + ' new', 'pending'))}
        ${
          pending()
            .slice(0, 2)
            .map(
              (t, i) =>
                html`<div class="request">${avatar(t.name, i + 1)}
                  <div>
                    <div class="request-name">${esc(t.name)}</div>
                    <div class="request-desc">${esc(t.clinic)}</div>
                  </div><button class="btn secondary small" data-review="${t.id}">Review ${icon('arrow')}
                </button>
                </div>`,
            )
            .join('') || '<div class="empty">You’re all caught up. No pending registrations.</div>'
        }
        <div class="approval-note">Review professional details before granting access to patient care.</div>
      </section>
    </div>` +
    html`<div class="grid-main">
      <section class="card table-card">${cardHead('Patients at a glance', 'A little attention makes a big difference.', link('View all', 'patients'))}
        ${patientTable(patients.slice(0, 5), true)}
        <div class="table-footer">
          <span>Showing ${Math.min(5, patients.length)} of ${patients.length} patients</span>
          <span>Updated just now</span>
        </div>
      </section>
      <section class="card">${cardHead('Latest activity', 'The moments that keep care moving.', link('View all', 'activity'))}
        ${overview.audit.slice(0, 4).map(activityRow).join('') || '<div class="empty">Your workspace activity will appear here.</div>'}
      </section>
    </div>`
  );
}
function stat(label, value, sub, i, primary = false) {
  return html`<article class="stat ${primary ? 'primary' : ''}">
  <div class="stat-top">${label}
    <span class="stat-icon">${icon(i)}</span>
  </div>
  <div class="stat-value">${value}</div>
  <div class="stat-sub">${sub}</div>
  </article>`;
}
function chart() {
  const a = overview.activity;
  const max = Math.max(4, ...a.map(d => d.sessions));
  const coords = a.map((d, i) => [35 + i * 35, 140 - (d.sessions / max) * 110]);
  const line = coords.map(p => p.join(',')).join(' ');
  const summary = a.map(d => date(d.day) + ': ' + d.sessions).join('; ');
  const gridLines = [0, 1, 2, 3]
    .map(
      i => html`<line x1="32" x2="500" y1="${140 - i * 36.67}" y2="${140 - i * 36.67}"/>
        <text x="7" y="${144 - i * 36.67}">${Math.round((max * i) / 3)}</text>`,
    )
    .join('');
  const points = coords
    .filter((_, i) => i % 3 === 0 || i === 13)
    .map(p => `<circle class="point" cx="${p[0]}" cy="${p[1]}" r="3"/>`)
    .join('');
  const dayLabels = a
    .map((d, i) =>
      (i % 3 === 0 && i < 12) || i === 13
        ? `<text x="${35 + i * 35}" y="166" text-anchor="middle">${date(d.day)}</text>`
        : '',
    )
    .join('');
  return html`<svg class="chart" viewBox="0 0 510 175" role="img" aria-label="Daily completed practice sessions, ${summary}">
    ${gridLines}
    <polygon class="area" points="35,140 ${line} 490,140"/>
    <polyline class="line" points="${line}"/>
    ${points}
    ${dayLabels}
  </svg>`;
}
function filteredPatients() {
  return overview.patients
    .filter(p =>
      (p.name + ' ' + p.email + ' ' + (p.therapist_name || ''))
        .toLowerCase()
        .includes(search.toLowerCase()),
    )
    .filter(
      p =>
        filter === 'all' ||
        (filter === 'unassigned' && !p.therapist_id) ||
        (filter === 'consent' && p.consent_status !== 'approved') ||
        (filter === 'attention' && p.has_plan && p.active_days < 3),
    );
}
function patientTable(patients, compact = false) {
  if (!patients.length) return '<div class="empty">No patients match this view.</div>';
  return html`<div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th>Patient</th>
          ${compact ? '' : '<th>Therapist</th>'}
          <th>${compact ? 'This week' : 'Practice days / week'}</th>
          <th>Status</th>
          <th></th>
        </tr>
      </thead>
      <tbody>${patients
        .map(
          (p, i) => html`<tr>
            <td>
              <div class="person">${avatar(p.name, i)}
                <div>${esc(p.name)}
                  <small>${compact ? relative(p.last_practice) : esc(p.email)}</small>
                </div>
              </div>
            </td>
            ${compact ? '' : `<td>${esc(p.therapist_name || 'Unassigned')}</td>`}
            <td>
              <div class="progress-cell"><span class="mini-progress" aria-label="${p.active_days} practice days out of seven">${Array.from({ length: 7 }, (_, j) => `<i class="${j < p.active_days ? 'filled' : ''}"></i>`).join('')}</span>
              <span>${p.active_days}/7</span>
            </div>
          </td>
          <td>${p.status === 'disabled' ? badge('Disabled', 'disabled') : !p.therapist_id ? badge('Unassigned', 'neutral') : p.consent_status !== 'approved' ? badge('Consent pending', 'pending') : p.has_plan ? badge('Active plan') : badge('Needs plan', 'pending')}</td>
          <td><button class="row-btn" data-patient="${p.id}" aria-label="Open ${esc(p.name)}">${icon('arrow')}</button>
          </td>
          </tr>`,
        )
        .join('')}</tbody>
    </table>
  </div>`;
}
function activityRow(a) {
  return html`<div class="activity">
    <span class="activity-icon">${icon(a.action.includes('plan') ? 'book' : a.action.includes('consent') ? 'check' : a.action.includes('recording') ? 'mic' : 'users')}</span>
    <div>
      <p>${esc(a.action)}</p>
      <small>${esc(a.detail || a.actor_name || 'Workspace')}</small>
    </div><time datetime="${esc(a.created_at)}">${date(a.created_at)}
  </time>
  </div>`;
}
function bindContent() {
  document.querySelectorAll('[data-action]').forEach(
    b =>
      (b.onclick = () =>
        ({
          add: () => accountDialog('patient'),
          'add-therapist': () => accountDialog('therapist'),
          password: passwordDialog,
          logout,
          export: exportCsv,
        })[b.dataset.action]?.()),
  );
  document.querySelectorAll('[data-filter]').forEach(
    b =>
      (b.onclick = () => {
        filter = b.dataset.filter;
        render();
      }),
  );
  document
    .querySelectorAll('[data-patient]')
    .forEach(b => (b.onclick = () => patientDialog(b.dataset.patient)));
  document
    .querySelectorAll('[data-review]')
    .forEach(b => (b.onclick = () => reviewDialog(b.dataset.review)));
  document
    .querySelectorAll('[data-status]')
    .forEach(b => (b.onclick = () => statusDialog(b.dataset.status, b.dataset.next)));
}
let activeObjectUrls = [];
function openDialog(title, description, content) {
  const d = $('#modal');
  for (const url of activeObjectUrls) URL.revokeObjectURL(url);
  activeObjectUrls = [];
  d.innerHTML = html`<div class="modal-body">
    <div class="modal-top">
      <div>
        <h2>${title}</h2>
        <p>${description}</p>
      </div>
      <button class="icon-btn" data-close aria-label="Close dialog">${icon('close')}</button>
    </div>
    ${content}
  </div>`;
  d.querySelectorAll('[data-close]').forEach(b => (b.onclick = () => d.close()));
  if (!d.open) d.showModal();
}
function formError(form, message) {
  let el = form.querySelector('.form-error');
  if (!el) {
    el = document.createElement('p');
    el.className = 'form-error';
    form.append(el);
  }
  el.textContent = message;
}
function handleForm(id, fn) {
  $(id).onsubmit = async e => {
    e.preventDefault();
    const b = e.target.querySelector('[type=submit]');
    b.disabled = true;
    try {
      await fn(Object.fromEntries(new FormData(e.target)));
    } catch (err) {
      formError(e.target, err.message);
    } finally {
      b.disabled = false;
    }
  };
}
function accountDialog(role) {
  openDialog(
    role === 'patient' ? 'A new beginning.' : 'Grow your care team.',
    role === 'patient'
      ? 'Create a patient account, then assign their therapist.'
      : 'Therapists you create here can sign in straight away. Self-registered therapists wait for your review.',
    html`<form id="account-form">
      <div class="form-grid">
        <label class="field full">Full name
          <input name="name" required maxlength="200">
        </label>
        <label class="field full">Email address
          <input name="email" type="email" required>
        </label>
        <label class="field full">Initial password
          <input name="password" type="password" required minlength="10" maxlength="128" autocomplete="new-password">
          <small>Share privately. The account holder can change this in the app.</small>
        </label>
        ${
          role === 'therapist'
            ? html`<label class="field">Clinic
              <input name="clinic" required>
            </label>
            <label class="field">Registration number
              <input name="registration" required>
            </label>`
            : ''
        }
      </div>
      <div class="form-actions">
        <button class="btn secondary" type="button" data-close>Cancel</button>
        <button class="btn" type="submit">Create ${role}</button>
      </div>
    </form>`,
  );
  handleForm('#account-form', async b => {
    await api('/users', 'POST', { ...b, role });
    $('#modal').close();
    toast(`${role === 'patient' ? 'Patient' : 'Therapist'} account created`);
    await load();
  });
}
function reviewDialog(id) {
  const t = overview.therapists.find(t => t.id === id);
  openDialog(
    'Review registration',
    'Confirm these details before approving therapist access.',
    html`<div class="label-value">
      <span>Name</span>
      <strong>${esc(t.name)}</strong>
    </div>
    <div class="label-value">
      <span>Email</span>
      <strong>${esc(t.email)}</strong>
    </div>
    <div class="label-value">
      <span>Clinic</span>
      <strong>${esc(t.clinic)}</strong>
    </div>
    <div class="label-value">
      <span>Registration</span>
      <strong>${esc(t.registration)}</strong>
    </div>
    <p class="approval-note">These details were supplied by the applicant. Approval is your confirmation that their professional details have been checked.</p>
    <form id="review-form">
      <div class="form-actions">
        <button type="button" class="btn secondary" data-close>Not now</button>
        <button type="submit" class="btn lime">${icon('check')} Approve therapist</button>
      </div>
    </form>`,
  );
  handleForm('#review-form', async () => {
    await api(`/users/${id}`, 'PATCH', { status: 'active' });
    $('#modal').close();
    toast('Therapist approved');
    await load();
  });
}
function statusDialog(id, status) {
  const t = [...overview.therapists, ...overview.patients].find(x => x.id === id);
  openDialog(
    status === 'disabled' ? 'Disable account access?' : 'Enable account access?',
    esc(t.name),
    html`<p class="approval-note">${status === 'disabled' ? 'Existing sessions will be signed out. Records will be retained.' : 'This person will be able to sign in again.'}</p>
    <form id="status-form">
      <div class="form-actions">
        <button type="button" class="btn secondary" data-close>Cancel</button><button type="submit" class="btn ${status === 'disabled' ? 'danger' : 'lime'}">Confirm
      </button>
    </div>
    </form>`,
  );
  handleForm('#status-form', async () => {
    await api(`/users/${id}`, 'PATCH', { status });
    $('#modal').close();
    toast('Account updated');
    await load();
  });
}
async function patientDialog(id) {
  try {
    const d = await api(`/patients/${id}`),
      p = d.patient;
    openDialog(
      esc(p.name),
      esc(p.email),
      html`<form id="assignment-form">
        <label class="field">Assigned therapist
          <select name="therapistId">
            <option value="">Unassigned</option>
            ${overview.therapists
              .filter(t => t.status === 'active')
              .map(
                t =>
                  `<option value="${t.id}" ${p.therapist_id === t.id ? 'selected' : ''}>${esc(t.name)}</option>`,
              )
              .join('')}
          </select>
        </label>
        <div class="form-actions">
          <button class="btn small" type="submit">Save assignment</button>
        </div>
      </form>
      <section class="detail-section">
        <h3>Consent ${badge(p.consent_status, p.consent_status === 'approved' ? '' : 'pending')}</h3>
        ${
          d.consent
            ? html`<p>Signed by ${esc(d.consent.signer_name)} · ${date(d.consent.signed_at)}
              <br>Version ${esc(d.consent.version)} · Optional analysis: ${d.consent.checks.analysis ? 'agreed' : 'declined'}
            </p><img class="consent-image" src="data:image/png;base64,${esc(d.consent.signature_png)}" alt="Patient consent signature">`
            : '<p>Consent has not been submitted yet.</p>'
        }
      </section>
      <section class="detail-section">
        <h3>Current plan</h3>
        ${
          d.plan
            ? html`<p>
              <strong>${esc(d.plan.title)}</strong> · ${d.plan.sessions_per_day} sessions per day
            </p>
            <ul>${d.plan.exercises.map(e => `<li>${esc(config.exercises.find(x => x.id === e)?.name || e)}</li>`).join('')}</ul>
            <p>${esc(d.plan.notes)}</p>`
            : '<p>The assigned therapist can prescribe a plan after approving consent.</p>'
        }
      </section>
      <section class="detail-section">
        <h3>Practice progress</h3>
        <p>${p.sessions} completed exercises · ${p.minutes} minutes · ${p.active_days} active days this week</p>
      </section>
      <section class="detail-section">
        <h3>Recordings (${d.recordings.length})</h3>
        ${
          d.recordings
            .map(
              r => html`<div class="recording-row">
                <strong>${esc(config.exercises.find(e => e.id === r.exercise_id)?.name || r.exercise_id)}</strong>
                <small>${date(r.created_at)} · ${r.duration_seconds} seconds</small><audio controls preload="none" src="/api/recordings/${r.id}/audio">
              </audio>
              ${r.review_note ? `<p>Therapist feedback: ${esc(r.review_note)}</p>` : ''}
              </div>`,
            )
            .join('') || '<p>No recordings uploaded yet.</p>'
        }
      </section>
      ${motorMarkup(d.motorSubmissions || [])}
      <div class="form-actions"><button class="btn ${p.status === 'active' ? 'danger' : 'secondary'}" id="patient-status">${p.status === 'active' ? 'Disable account' : 'Enable account'}</button>
      <button class="btn secondary" data-close>Done</button>
      </div>`,
    );
    handleForm('#assignment-form', async b => {
      await api(`/patients/${id}/assignment`, 'PUT', { therapistId: b.therapistId || null });
      toast('Assignment saved');
      await load();
    });
    $('#patient-status').onclick = () =>
      statusDialog(id, p.status === 'active' ? 'disabled' : 'active');
  } catch (e) {
    toast(e.message);
  }
}
function passwordDialog() {
  openDialog(
    'Change password',
    'You will need to sign in again after this change.',
    html`<form id="password-form">
      <div class="form-grid">
        <label class="field full">Current password
          <input type="password" name="currentPassword" required autocomplete="current-password">
        </label>
        <label class="field full">New password
          <input type="password" name="password" required minlength="10" maxlength="128" autocomplete="new-password">
        </label>
      </div>
      <div class="form-actions">
        <button type="button" class="btn secondary" data-close>Cancel</button>
        <button type="submit" class="btn">Change password</button>
      </div>
    </form>`,
  );
  handleForm('#password-form', async b => {
    await api('/auth/password', 'POST', b);
    $('#modal').close();
    user = null;
    renderLogin();
    toast('Password changed. Sign in again.');
  });
}
async function logout() {
  try {
    await api('/auth/logout', 'POST', {});
    user = null;
    search = '';
    renderLogin();
  } catch (e) {
    toast(e.message);
  }
}
function exportCsv() {
  const cell = v =>
    '"' +
    String(v ?? '')
      .replace(/^[=+@-]/, "'$&")
      .replaceAll('"', '""') +
    '"';
  const rows = [
    ['Name', 'Email', 'Therapist', 'Status', 'Consent', 'Practice days this week'],
    ...filteredPatients().map(p => [
      p.name,
      p.email,
      p.therapist_name,
      p.status,
      p.consent_status,
      p.active_days,
    ]),
  ];
  const url = URL.createObjectURL(
    new Blob([rows.map(r => r.map(cell).join(',')).join('\r\n')], { type: 'text/csv' }),
  );
  const a = document.createElement('a');
  a.href = url;
  a.download = 'melo-patients.csv';
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  toast('Patient directory exported');
}
window.addEventListener('hashchange', () => {
  page = navItems.some(n => n[0] === location.hash.slice(1)) ? location.hash.slice(1) : 'overview';
  filter = 'all';
  search = '';
  if (user) load();
});
async function start() {
  try {
    config = await api('/config');
    try {
      const me = await api('/auth/me');
      if (['admin', 'therapist'].includes(me.user.role)) user = me.user;
    } catch {}
    page = navItems.some(n => n[0] === location.hash.slice(1))
      ? location.hash.slice(1)
      : 'overview';
    if (user) await load();
    else renderLogin();
  } catch (e) {
    $('#app').innerHTML =
      `<div class="boot">Could not connect to the workspace. ${esc(e.message)} Reload to retry.</div>`;
  }
}
start();

function motorMarkup(submissions) {
  return html`<section class="detail-section"><h3>Handwriting practice</h3>
    <p>Automated observations require therapist review. A still photo cannot assess grip, pressure, movement, diagnose a condition or demonstrate clinical improvement.</p>
    ${
      submissions
        .map(
          s => html`<article class="motor-review">
      <h4>${esc(config.exercises.find(e => e.id === s.exercise_id)?.name || s.exercise_id)} · ${esc(s.practice_day)}</h4>
      <a href="/api/motor-submissions/${encodeURIComponent(s.id)}/photo" target="_blank" rel="noopener">Open original photo at full size</a>
      <img class="motor-photo" loading="lazy" src="/api/motor-submissions/${encodeURIComponent(s.id)}/photo" alt="Original, unedited practice paper">
      <p>${esc({ ready: 'Automated report · awaiting therapist verification', pending: 'Analysis queued', processing: 'Analysis processing — refresh to check', unavailable: 'Analysis unavailable. Review the original or retry when the local model is running.', declined: 'Automated analysis declined — human review only' }[s.analysis_status] || s.analysis_status)}</p>
      ${
        s.report
          ? html`<p>${esc(s.report.observations)}</p>
        <dl class="motor-metrics"><dt>Alignment</dt><dd>${esc(s.report.alignment.replaceAll('_', ' '))}</dd><dt>Formation</dt><dd>${esc(s.report.formation.replaceAll('_', ' '))}</dd><dt>Spacing</dt><dd>${esc(s.report.spacing.replaceAll('_', ' '))}</dd></dl>
        ${s.report.imageQuality === 'retake' ? '<p>A clearer photo may be needed. Check the original.</p>' : ''}
        <p>${esc(s.report.suggestion)}</p><small>Model: ${esc(s.report.model)} · ${esc(s.report.generatedAt)} · unvalidated visual observations</small>`
          : ''
      }
      ${s.review_note ? `<p><strong>Therapist feedback:</strong> ${esc(s.review_note)}</p>` : '<p>Awaiting therapist feedback</p>'}
      ${
        user.role === 'therapist'
          ? html`<form class="motor-feedback" data-submission="${esc(s.id)}"><label class="field">Your feedback after checking the original<textarea name="note" required maxlength="2000">${esc(s.review_note || '')}</textarea></label><button class="btn" type="submit">Save therapist feedback</button><p class="form-error" role="status"></p></form>
        ${s.analysis_status === 'unavailable' ? `<button class="btn secondary" data-motor-retry="${esc(s.id)}">Retry analysis</button>` : ''}`
          : ''
      }
    </article>`,
        )
        .join('') || '<p>No handwriting photos yet.</p>'
    }</section>`;
}

function bindMotor(patientId) {
  document.querySelectorAll('.motor-feedback').forEach(form =>
    handleForm(`.motor-feedback[data-submission="${form.dataset.submission}"]`, async b => {
      await api(`/motor-submissions/${form.dataset.submission}/review`, 'POST', { note: b.note });
      await therapistPatientDialog(patientId);
      toast('Therapist feedback saved');
    }),
  );
  document.querySelectorAll('[data-motor-retry]').forEach(
    button =>
      (button.onclick = async () => {
        button.disabled = true;
        try {
          await api(`/motor-submissions/${button.dataset.motorRetry}/analyze`, 'POST', {});
          await therapistPatientDialog(patientId);
        } catch (error) {
          toast(error.message);
          button.disabled = false;
        }
      }),
  );
}

function renderTherapist() {
  $('#app').innerHTML = html`<main class="therapist-workspace">
    <header class="topbar">${brand()}<strong>${esc(user.name)}</strong><button class="btn secondary" id="refresh">Refresh</button><button class="btn secondary" id="logout">Sign out</button></header>
    <section class="page-header"><h1>Your patients</h1><p>Short daily practice, original photos and your feedback.</p></section>
    <section class="card table-card">${patientTable(overview.patients)}</section>
  </main>`;
  $('#logout').onclick = logout;
  $('#refresh').onclick = load;
  document
    .querySelectorAll('[data-patient]')
    .forEach(button => (button.onclick = () => therapistPatientDialog(button.dataset.patient)));
}

async function therapistPatientDialog(id) {
  try {
    const d = await api(`/patients/${id}`);
    const exercises = config.exercises.filter(e => e.kind === 'motor');
    openDialog(
      esc(d.patient.name),
      'Check the original photo before sharing your clinical feedback.',
      html`
      <section class="detail-section"><h3>Consent</h3><p>Status: ${esc(d.consent?.status || 'missing')}</p>
      ${d.consent ? `<p>Signed by ${esc(d.consent.signer_name)}. Optional analysis: ${d.consent.checks.analysis ? 'agreed' : 'declined'}</p><img class="consent-image" src="data:image/png;base64,${esc(d.consent.signature_png)}" alt="Adult or guardian signature">` : ''}
      ${d.consent?.status === 'pending' ? '<form id="approve-care"><label><input type="checkbox" name="paper" required> I checked the adult or guardian signature and confirm the paper copy.</label><button class="btn" type="submit">Approve consent</button></form>' : ''}</section>
      ${d.consent?.status === 'approved' ? html`<form id="motor-forms"><h3>Clinical assessment</h3><label class="field">Age in years<input name="age" type="number" min="1" max="120" required value="${d.forms?.age || ''}"></label><label class="field">Demographic information<textarea name="demographic" required maxlength="2000">${esc(d.forms?.demographic || '')}</textarea></label><label class="field">Clinical information and suitability<textarea name="clinical" required maxlength="2000">${esc(d.forms?.clinical || '')}</textarea></label><button class="btn" type="submit">Save assessment</button></form>` : ''}
      ${
        d.forms && d.consent?.status === 'approved'
          ? html`<form id="motor-plan"><h3>Daily motor practice plan</h3><p>${esc(config.motorGuidance)}</p>
      <label class="field">Plan title<input name="title" required maxlength="200" value="${esc(d.plan?.title || 'My daily little practice')}"></label>
      ${exercises.map(e => `<label class="motor-choice"><input type="checkbox" name="exercise" value="${esc(e.id)}" ${d.plan?.exercises.includes(e.id) || !d.plan ? 'checked' : ''}> ${esc(e.name)} · ${e.minutes} min — ${esc(e.description)}</label>`).join('')}
      <p>This replaces the current plan. One gentle round per day; adapt to this child's needs.</p>
      <label class="field">Your instructions<textarea name="notes" maxlength="2000">${esc(d.plan?.notes || '')}</textarea></label><button class="btn" type="submit">Prescribe daily practice</button></form>`
          : ''
      }
      ${motorMarkup(d.motorSubmissions || [])}
      <div class="form-actions"><button class="btn secondary" id="refresh-patient">Refresh reports</button><button class="btn secondary" data-close>Done</button></div>`,
    );
    if ($('#approve-care'))
      handleForm('#approve-care', async () => {
        await api(`/patients/${id}/approve-consent`, 'POST', { paperCopy: true });
        await therapistPatientDialog(id);
      });
    if ($('#motor-forms'))
      handleForm('#motor-forms', async b => {
        await api(`/patients/${id}/forms`, 'PUT', {
          age: Number(b.age),
          demographic: b.demographic,
          clinical: b.clinical,
        });
        await therapistPatientDialog(id);
      });
    if ($('#motor-plan'))
      handleForm('#motor-plan', async b => {
        const selected = [...document.querySelectorAll('#motor-plan [name=exercise]:checked')].map(
          e => e.value,
        );
        await api(`/patients/${id}/plans`, 'POST', {
          title: b.title,
          exercises: selected,
          sessionsPerDay: 1,
          notes: b.notes,
        });
        await therapistPatientDialog(id);
      });
    $('#refresh-patient').onclick = () => therapistPatientDialog(id);
    bindMotor(id);
  } catch (error) {
    toast(error.message);
  }
}
