/* ═══════════════════════════════════════════════
   RAZER ROLEPLAY - F5 MENU LOGIC
   ═══════════════════════════════════════════════ */

let currentData = {};
let currentConfig = {};
let radioState = { sound: 'click', animation: 'hand', speed: 1.0, prop: true };

// ═══════ MESSAGE LISTENER ═══════
window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.action === 'open') {
        currentConfig = d;
        currentData = d.data;
        applyTheme(d.theme);
        document.getElementById('server-name').innerText = d.serverName;
        document.getElementById('player-id-display').innerText = `ID: ${d.data.id}`;
        renderCategories(d.categories, d.data.isAdmin);
        showMain();
        document.getElementById('app').classList.remove('hidden');
    }
    if (d.action === 'close') {
        document.getElementById('app').classList.add('hidden');
    }
});

// ═══════ THEME ═══════
function applyTheme(theme) {
    const r = document.documentElement.style;
    r.setProperty('--primary', theme.primary);
    r.setProperty('--secondary', theme.secondary);
    r.setProperty('--accent', theme.accent);
    r.setProperty('--bg', theme.background);
    r.setProperty('--surface', theme.surface);
    r.setProperty('--border', theme.border);
    r.setProperty('--success', theme.success);
    r.setProperty('--danger', theme.danger);
    r.setProperty('--warning', theme.warning);
}

// ═══════ MENU PRINCIPALE ═══════
function renderCategories(categories, isAdmin) {
    const grid = document.getElementById('categories-grid');
    grid.innerHTML = '';
    categories.forEach(cat => {
        if (!cat.enabled) return;
        if (cat.adminOnly && !isAdmin) return;
        const card = document.createElement('div');
        card.className = 'category-card';
        card.onclick = () => openCategory(cat.id);
        card.innerHTML = `
            ${cat.adminOnly ? '<span class="admin-badge">ADMIN</span>' : ''}
            <div class="icon-wrap"><i class="icon-${cat.icon}"></i></div>
            <h3>${cat.label}</h3>
            <p>${getCategoryDescription(cat.id)}</p>
        `;
        grid.appendChild(card);
    });
}

function getCategoryDescription(id) {
    const d = {
        info: 'Status del tuo personaggio',
        billing: 'Visualizza e paga le fatture',
        radio: 'Personalizza animazioni radio',
        fps: 'Ottimizza le prestazioni',
        adult: 'Animazioni interattive',
        house: 'Gestisci le tue proprietà',
        admin: 'Pannello di moderazione'
    };
    return d[id] || '';
}

function showMain() {
    document.getElementById('main-menu').classList.remove('hidden');
    document.getElementById('detail-panel').classList.add('hidden');
    document.getElementById('radio-fullscreen').classList.add('hidden');
}

function backToMain() { showMain(); }

// ═══════ APERTURA CATEGORIE ═══════
function openCategory(id) {
    if (id === 'radio') return openRadio();
    if (id === 'billing') {
        fetch(`https://${GetParentResourceName()}/openBilling`, { method: 'POST', body: '{}' });
        return;
    }
    document.getElementById('main-menu').classList.add('hidden');
    document.getElementById('detail-panel').classList.remove('hidden');
    const title = currentConfig.categories.find(c => c.id === id).label;
    document.getElementById('detail-title').innerText = title;
    const content = document.getElementById('detail-content');

    switch(id) {
        case 'info':  content.innerHTML = renderInfo();  break;
        case 'fps':   content.innerHTML = renderFPS();   break;
        case 'adult': content.innerHTML = renderAdult(); break;
        case 'house': content.innerHTML = renderHouse(); break;
        case 'admin': content.innerHTML = renderAdmin();
                      setupAdminListeners(); break;
    }
}

// ═══════ INFORMAZIONI PERSONALI ═══════
function renderInfo() {
    const d = currentData;
    return `
        <div class="info-grid">
            <div class="info-card"><label>Nome</label><div class="value">${d.firstname}</div></div>
            <div class="info-card"><label>Cognome</label><div class="value">${d.lastname}</div></div>
            <div class="info-card"><label>ID Sessione</label><div class="value">#${d.id}</div></div>
            <div class="info-card"><label>Alloggio</label><div class="value">${d.hasHouse ? '🏠 Casa Popolare' : '❌ Nessuno'}</div></div>
            <div class="info-card"><label>Lavoro Primario (Job 1)</label><div class="value">${d.job.label} <small>(${d.job.grade_label})</small></div></div>
            <div class="info-card"><label>Lavoro Secondario (Job 2)</label><div class="value">${d.job2.label}</div></div>
            <div class="info-card"><label>💵 Contanti</label><div class="value money">$${d.cash.toLocaleString()}</div></div>
            <div class="info-card"><label>🏦 Banca</label><div class="value money">$${d.bank.toLocaleString()}</div></div>
        </div>
    `;
}

// ═══════ FPS ═══════
function renderFPS() {
    let html = '<div class="fps-grid">';
    currentConfig.fps.presets.forEach(p => {
        html += `<div class="fps-preset" onclick="setFPS('${p.id}', this)">
            <h3>${p.label}</h3>
            <p style="color:var(--text-muted); font-size:12px; margin-top:6px;">Distanza: ${p.distance}m</p>
        </div>`;
    });
    return html + '</div>';
}

function setFPS(preset, el) {
    document.querySelectorAll('.fps-preset').forEach(e => e.classList.remove('active'));
    el.classList.add('active');
    fetch(`https://${GetParentResourceName()}/setFPS`, {
        method: 'POST', body: JSON.stringify({ preset })
    });
}

// ═══════ +18 ═══════
function renderAdult() {
    let html = '<div class="chip-grid" style="grid-template-columns:repeat(3,1fr);">';
    currentConfig.adult.list.forEach(a => {
        html += `<div class="chip" onclick="playAdult('${a.id}')">${a.label}</div>`;
    });
    return html + '</div>';
}

function playAdult(id) {
    fetch(`https://${GetParentResourceName()}/playAdultAnim`, {
        method: 'POST', body: JSON.stringify({ id })
    });
}

// ═══════ CASA ═══════
function renderHouse() {
    return `
        <div class="info-grid">
            <button class="btn-primary" onclick="houseAct('lock')">🔒 Blocca/Sblocca</button>
            <button class="btn-primary" onclick="houseAct('enter')">🚪 Entra/Esci</button>
            <button class="btn-primary" onclick="houseAct('manage')">🔑 Gestione Chiavi</button>
            <button class="btn-danger" onclick="houseAct('sell')">💰 Vendi Proprietà</button>
        </div>
    `;
}

function houseAct(action) {
    fetch(`https://${GetParentResourceName()}/houseAction`, {
        method: 'POST', body: JSON.stringify({ action })
    });
}

// ═══════ ADMIN ═══════
function renderAdmin() {
    return `
        <div class="copy-banner">💡 Premi <kbd>INVIO</kbd> o clicca sui dati sensibili per copiarli negli appunti</div>
        <div class="admin-actions">
            <button class="btn-primary" onclick="adminVeh('repair')">🔧 Ripara veicolo</button>
            <button class="btn-secondary" onclick="adminVeh('tuning')">⚙️ Apri menu tuning</button>
        </div>
        <div class="admin-search">
            <input type="number" id="admin-target-id" placeholder="Cerca tramite ID giocatore..." />
            <button class="btn-primary" onclick="adminSearch()">🔍 Cerca</button>
        </div>
        <div id="admin-result"></div>
    `;
}

function setupAdminListeners() {
    document.getElementById('admin-target-id').addEventListener('keydown', e => {
        if (e.key === 'Enter') adminSearch();
    });
}

function adminVeh(action) {
    fetch(`https://${GetParentResourceName()}/admin:${action === 'repair' ? 'repairVehicle' : 'openTuning'}`, {
        method: 'POST', body: '{}'
    });
}

async function adminSearch() {
    const id = document.getElementById('admin-target-id').value;
    if (!id) return;
    const res = await fetch(`https://${GetParentResourceName()}/admin:searchPlayer`, {
        method: 'POST', body: JSON.stringify({ id })
    });
    const data = await res.json();
    if (data.error) {
        document.getElementById('admin-result').innerHTML = `<div class="info-card" style="border-color:var(--danger)">❌ ${data.error}</div>`;
        return;
    }
    document.getElementById('admin-result').innerHTML = `
        <div class="info-grid">
            <div class="info-card"><label>Nome Completo</label><div class="value">${data.firstname} ${data.lastname}</div></div>
            <div class="info-card"><label>ID</label><div class="value">#${data.id}</div></div>
            <div class="info-card sensitive" onclick="copy('${data.discord}')"><label>ID Discord</label><div class="value">${data.discord}</div></div>
            <div class="info-card sensitive" onclick="copy('${data.license}')"><label>Licenza</label><div class="value" style="font-size:11px;">${data.license}</div></div>
            <div class="info-card sensitive" onclick="copy('${data.steam}')"><label>Steam</label><div class="value" style="font-size:11px;">${data.steam}</div></div>
            <div class="info-card"><label>Gruppo Permessi</label><div class="value" style="color:var(--primary)">${data.group}</div></div>
            <div class="info-card"><label>Job 1</label><div class="value">${data.job}</div></div>
            <div class="info-card"><label>Job 2</label><div class="value">${data.job2}</div></div>
            <div class="info-card"><label>💵 Contanti</label><div class="value money">$${data.cash.toLocaleString()}</div></div>
            <div class="info-card"><label>🏦 Banca</label><div class="value money">$${data.bank.toLocaleString()}</div></div>
        </div>
    `;
}

function copy(text) {
    navigator.clipboard.writeText(text);
    showToast('📋 Copiato negli appunti!');
}

function showToast(msg) {
    const t = document.createElement('div');
    t.style.cssText = 'position:fixed;bottom:30px;left:50%;transform:translateX(-50%);background:var(--primary);color:white;padding:12px 24px;border-radius:8px;z-index:9999;animation:slideUp 0.3s;';
    t.innerText = msg;
    document.body.appendChild(t);
    setTimeout(() => t.remove(), 2000);
}

// ═══════ RADIO FULLSCREEN ═══════
function openRadio() {
    document.getElementById('main-menu').classList.add('hidden');
    document.getElementById('radio-fullscreen').classList.remove('hidden');

    const anims = document.getElementById('radio-anims');
    anims.innerHTML = '';
    currentConfig.radio.animations.forEach(a => {
        const c = document.createElement('div');
        c.className = 'chip' + (a.id === radioState.animation ? ' active' : '');
        c.innerText = a.label;
        c.onclick = () => {
            document.querySelectorAll('#radio-anims .chip').forEach(x => x.classList.remove('active'));
            c.classList.add('active');
            radioState.animation = a.id;
        };
        anims.appendChild(c);
    });

    const sounds = document.getElementById('radio-sounds');
    sounds.innerHTML = '';
    currentConfig.radio.sounds.forEach(s => {
        const c = document.createElement('div');
        c.className = 'chip' + (s.id === radioState.sound ? ' active' : '');
        c.innerText = s.label;
        c.onclick = () => {
            document.querySelectorAll('#radio-sounds .chip').forEach(x => x.classList.remove('active'));
            c.classList.add('active');
            radioState.sound = s.id;
            const a = document.getElementById('preview-audio');
            a.src = 'sounds/' + s.file;
            a.play().catch(() => {});
        };
        sounds.appendChild(c);
    });

    document.getElementById('radio-speed').addEventListener('input', e => {
        document.getElementById('speed-value').innerText = e.target.value;
        radioState.speed = parseFloat(e.target.value);
    });
}

function closeRadio() { showMain(); }

function saveRadio() {
    radioState.prop = document.getElementById('radio-prop').checked;
    fetch(`https://${GetParentResourceName()}/radio:save`, {
        method: 'POST', body: JSON.stringify(radioState)
    });
    showToast('✅ Impostazioni Radio salvate');
    showMain();
}

// ═══════ CLOSE ═══════
function closeMenu() {
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: '{}' });
}

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeMenu();
});