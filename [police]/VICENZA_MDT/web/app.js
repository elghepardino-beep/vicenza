const app = document.getElementById('app');
const toast = document.getElementById('toast');

const state = {
    officer: null,
    dashboard: null,
    currentPage: 'dashboard'
};

function notify(message) {
    toast.textContent = message || 'Operazione completata.';
    toast.classList.remove('hidden');

    setTimeout(() => {
        toast.classList.add('hidden');
    }, 2500);
}

async function nui(action, payload = {}) {
    const response = await fetch(`https://${GetParentResourceName()}/action`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({
            action,
            payload
        })
    });

    return response.json();
}

async function closeMdt() {
    await fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({})
    });
}

function escapeHtml(value) {
    return String(value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
}

function prettyDate(value) {
    if (!value) return '---';
    return String(value).replace('T', ' ').replace('.000Z', '');
}

function parseJsonBox(value, fallback) {
    if (!value || !value.trim()) return fallback;

    try {
        return JSON.parse(value);
    } catch {
        notify('JSON non valido. Verrà ignorato.');
        return fallback;
    }
}

function setPage(page) {
    state.currentPage = page;

    document.querySelectorAll('.page').forEach(el => {
        el.classList.toggle('active', el.id === page);
    });

    document.querySelectorAll('.nav').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.page === page);
    });

    const titles = {
        dashboard: 'Dashboard',
        citizens: 'Cittadini',
        vehicles: 'Veicoli',
        incidents: 'Incidenti',
        warrants: 'Mandati',
        bolos: 'BOLO',
        charges: 'Codice Penale',
        announcements: 'Annunci'
    };

    document.getElementById('pageTitle').textContent = titles[page] || 'VICENZA MDT';

    if (page === 'incidents') loadIncidents();
    if (page === 'warrants') loadWarrants();
    if (page === 'bolos') loadBolos();
    if (page === 'charges') loadCharges();
}

function renderDashboard(dashboard) {
    if (!dashboard) return;

    document.getElementById('statWarrants').textContent = dashboard.stats?.activeWarrants ?? 0;
    document.getElementById('statBolos').textContent = dashboard.stats?.activeBolos ?? 0;
    document.getElementById('statIncidents').textContent = dashboard.stats?.openIncidents ?? 0;
    document.getElementById('statCharges').textContent = dashboard.stats?.chargesCount ?? 0;

    const recent = document.getElementById('recentIncidents');
    recent.innerHTML = '';

    if (!dashboard.recentIncidents?.length) {
        recent.innerHTML = `<div class="item"><p>Nessun incidente recente.</p></div>`;
    } else {
        dashboard.recentIncidents.forEach(item => {
            recent.innerHTML += `
                <div class="item">
                    <div class="item-head">
                        <h4>#${item.id} ${escapeHtml(item.title)}</h4>
                        <span class="badge ${escapeHtml(item.priority)}">${escapeHtml(item.priority)}</span>
                    </div>
                    <p>${escapeHtml(item.type)} · ${escapeHtml(item.status)} · ${prettyDate(item.created_at)}</p>
                    <p>Creato da: ${escapeHtml(item.created_by_name)}</p>
                </div>
            `;
        });
    }

    const ann = document.getElementById('dashboardAnnouncements');
    const ann2 = document.getElementById('announcementList');
    ann.innerHTML = '';
    ann2.innerHTML = '';

    if (!dashboard.announcements?.length) {
        ann.innerHTML = `<div class="item"><p>Nessun annuncio.</p></div>`;
        ann2.innerHTML = ann.innerHTML;
    } else {
        dashboard.announcements.forEach(item => {
            const html = `
                <div class="item">
                    <div class="item-head">
                        <h4>${escapeHtml(item.title)}</h4>
                        <span class="badge ${escapeHtml(item.priority)}">${escapeHtml(item.priority)}</span>
                    </div>
                    <p>${escapeHtml(item.message)}</p>
                    <div class="badges">
                        <span class="badge">Da ${escapeHtml(item.created_by_name)}</span>
                        <span class="badge">${prettyDate(item.created_at)}</span>
                    </div>
                </div>
            `;

            ann.innerHTML += html;
            ann2.innerHTML += html;
        });
    }
}

function bootstrap(payload) {
    state.officer = payload.officer;
    state.dashboard = payload.dashboard;

    document.getElementById('officerName').textContent = state.officer?.name || 'Operatore';
    document.getElementById('officerJob').textContent =
        `${state.officer?.job || 'job'} · grado ${state.officer?.grade ?? 0}`;

    renderDashboard(state.dashboard);
}

async function reloadBoot() {
    const res = await nui('boot');

    if (res.ok) {
        bootstrap(res);
    }
}

async function searchCitizens() {
    const q = document.getElementById('citizenSearch').value;
    const box = document.getElementById('citizenResults');

    const res = await nui('searchCitizens', {
        q,
        limit: 30
    });

    box.innerHTML = '';

    if (!res.ok) {
        notify(res.message);
        return;
    }

    if (!res.results.length) {
        box.innerHTML = `<div class="item"><p>Nessun cittadino trovato.</p></div>`;
        return;
    }

    res.results.forEach(c => {
        box.innerHTML += `
            <div class="item">
                <div class="item-head">
                    <h4>${escapeHtml(c.firstname)} ${escapeHtml(c.lastname)}</h4>
                    <button onclick="openCitizen('${escapeHtml(c.identifier)}')">Apri</button>
                </div>
                <p>${escapeHtml(c.identifier)}</p>
                <div class="badges">
                    <span class="badge">${escapeHtml(c.dateofbirth || 'N/D')}</span>
                    <span class="badge">${escapeHtml(c.sex || 'N/D')}</span>
                    ${c.phone ? `<span class="badge">${escapeHtml(c.phone)}</span>` : ''}
                </div>
            </div>
        `;
    });
}

async function openCitizen(identifier) {
    const res = await nui('getCitizen', {
        identifier
    });

    if (!res.ok) {
        notify(res.message);
        return;
    }

    const c = res.citizen;
    const p = res.profile || {};
    const detail = document.getElementById('citizenDetail');
    detail.classList.remove('hidden');

    const vehicles = res.vehicles || [];
    const warrants = res.warrants || [];
    const bolos = res.bolos || [];
    const licenses = res.licenses || [];
    const incidents = res.incidents || [];

    detail.innerHTML = `
        <div class="panel-head">
            <h3>${escapeHtml(c.firstname)} ${escapeHtml(c.lastname)}</h3>
            <span class="badge ${escapeHtml(p.risk_level || 'low')}">Rischio: ${escapeHtml(p.risk_level || 'low')}</span>
        </div>

        ${p.image ? `<img src="${escapeHtml(p.image)}" />` : ''}

        <p><strong>Identifier:</strong> ${escapeHtml(c.identifier)}</p>
        <p><strong>Nascita:</strong> ${escapeHtml(c.dateofbirth || 'N/D')} · <strong>Sesso:</strong> ${escapeHtml(c.sex || 'N/D')}</p>

        <input id="profileImage" placeholder="URL immagine profilo" value="${escapeHtml(p.image || '')}" />

        <select id="profileRisk">
            <option value="low" ${p.risk_level === 'low' ? 'selected' : ''}>Basso</option>
            <option value="medium" ${p.risk_level === 'medium' ? 'selected' : ''}>Medio</option>
            <option value="high" ${p.risk_level === 'high' ? 'selected' : ''}>Alto</option>
            <option value="critical" ${p.risk_level === 'critical' ? 'selected' : ''}>Critico</option>
        </select>

        <textarea id="profileNotes" placeholder="Note operative">${escapeHtml(p.notes || '')}</textarea>

        <button onclick="saveCitizenProfile('${escapeHtml(c.identifier)}')">Salva profilo</button>

        <div class="grid-2" style="margin-top:16px;">
            <div>
                <h4>Veicoli</h4>
                <div class="list">
                    ${vehicles.length ? vehicles.map(v => `
                        <div class="item">
                            <h4>${escapeHtml(v.plate)}</h4>
                            <p>${escapeHtml(v.type || 'vehicle')}</p>
                        </div>
                    `).join('') : '<div class="item"><p>Nessun veicolo.</p></div>'}
                </div>
            </div>

            <div>
                <h4>Licenze</h4>
                <div class="list">
                    ${licenses.length ? licenses.map(l => `
                        <div class="item"><p>${escapeHtml(l.type)}</p></div>
                    `).join('') : '<div class="item"><p>Nessuna licenza trovata.</p></div>'}
                </div>
            </div>
        </div>

        <h4>Mandati attivi / pending</h4>
        <div class="list">
            ${warrants.length ? warrants.map(w => `
                <div class="item">
                    <h4>#${w.id} ${escapeHtml(w.title)}</h4>
                    <p>${escapeHtml(w.status)} · ${prettyDate(w.created_at)}</p>
                </div>
            `).join('') : '<div class="item"><p>Nessun mandato.</p></div>'}
        </div>

        <h4>BOLO</h4>
        <div class="list">
            ${bolos.length ? bolos.map(b => `
                <div class="item">
                    <h4>#${b.id} ${escapeHtml(b.title)}</h4>
                    <p>${escapeHtml(b.priority)} · ${prettyDate(b.created_at)}</p>
                </div>
            `).join('') : '<div class="item"><p>Nessun BOLO.</p></div>'}
        </div>

        <h4>Incidenti collegati</h4>
        <div class="list">
            ${incidents.length ? incidents.map(i => `
                <div class="item">
                    <h4>#${i.id} ${escapeHtml(i.title)}</h4>
                    <p>${escapeHtml(i.status)} · ${prettyDate(i.created_at)}</p>
                </div>
            `).join('') : '<div class="item"><p>Nessun incidente collegato.</p></div>'}
        </div>
    `;
}

async function saveCitizenProfile(identifier) {
    const res = await nui('saveCitizenProfile', {
        identifier,
        image: document.getElementById('profileImage').value,
        risk_level: document.getElementById('profileRisk').value,
        notes: document.getElementById('profileNotes').value,
        tags: []
    });

    notify(res.message || 'Salvato.');
    if (res.ok) openCitizen(identifier);
}

async function searchVehicles() {
    const q = document.getElementById('vehicleSearch').value;
    const box = document.getElementById('vehicleResults');

    const res = await nui('searchVehicles', {
        q,
        limit: 30
    });

    box.innerHTML = '';

    if (!res.ok) {
        notify(res.message);
        return;
    }

    if (!res.results.length) {
        box.innerHTML = `<div class="item"><p>Nessun veicolo trovato.</p></div>`;
        return;
    }

    res.results.forEach(v => {
        box.innerHTML += `
            <div class="item">
                <div class="item-head">
                    <h4>${escapeHtml(v.plate)}</h4>
                    <button onclick="openVehicle('${escapeHtml(v.plate)}')">Apri</button>
                </div>
                <p>Owner: ${escapeHtml(v.owner)}</p>
                <div class="badges">
                    <span class="badge">${escapeHtml(v.type || 'vehicle')}</span>
                    <span class="badge">Stored: ${escapeHtml(v.stored)}</span>
                </div>
            </div>
        `;
    });
}

async function openVehicle(plate) {
    const res = await nui('getVehicle', {
        plate
    });

    if (!res.ok) {
        notify(res.message);
        return;
    }

    const v = res.vehicle;
    const detail = document.getElementById('vehicleDetail');
    detail.classList.remove('hidden');

    detail.innerHTML = `
        <div class="panel-head">
            <h3>Veicolo ${escapeHtml(v.plate)}</h3>
        </div>

        <p><strong>Owner:</strong> ${escapeHtml(v.owner)}</p>
        <p><strong>Tipo:</strong> ${escapeHtml(v.type || 'vehicle')}</p>

        <h4>Mandati</h4>
        <div class="list">
            ${res.warrants?.length ? res.warrants.map(w => `
                <div class="item">
                    <h4>#${w.id} ${escapeHtml(w.title)}</h4>
                    <p>${escapeHtml(w.status)}</p>
                </div>
            `).join('') : '<div class="item"><p>Nessun mandato.</p></div>'}
        </div>

        <h4>BOLO</h4>
        <div class="list">
            ${res.bolos?.length ? res.bolos.map(b => `
                <div class="item">
                    <h4>#${b.id} ${escapeHtml(b.title)}</h4>
                    <p>${escapeHtml(b.priority)}</p>
                </div>
            `).join('') : '<div class="item"><p>Nessun BOLO.</p></div>'}
        </div>
    `;
}

async function loadIncidents() {
    const res = await nui('listIncidents', {
        limit: 50
    });

    const box = document.getElementById('incidentList');
    box.innerHTML = '';

    if (!res.ok) {
        notify(res.message);
        return;
    }

    if (!res.results.length) {
        box.innerHTML = `<div class="item"><p>Nessun incidente.</p></div>`;
        return;
    }

    res.results.forEach(i => {
        box.innerHTML += `
            <div class="item">
                <div class="item-head">
                    <h4>#${i.id} ${escapeHtml(i.title)}</h4>
                    <span class="badge ${escapeHtml(i.priority)}">${escapeHtml(i.priority)}</span>
                </div>
                <p>${escapeHtml(i.type)} · ${escapeHtml(i.status)} · ${prettyDate(i.created_at)}</p>
                <p>Luogo: ${escapeHtml(i.location || 'N/D')}</p>
            </div>
        `;
    });
}

async function createIncident() {
    const involved = parseJsonBox(document.getElementById('incInvolved').value, []);

    const res = await nui('createIncident', {
        title: document.getElementById('incTitle').value,
        type: document.getElementById('incType').value,
        priority: document.getElementById('incPriority').value,
        location: document.getElementById('incLocation').value,
        summary: document.getElementById('incSummary').value,
        involved,
        evidence: [],
        charges: []
    });

    notify(res.message);

    if (res.ok) {
        document.getElementById('incTitle').value = '';
        document.getElementById('incSummary').value = '';
        document.getElementById('incInvolved').value = '';
        loadIncidents();
        reloadBoot();
    }
}

async function loadWarrants() {
    const res = await nui('listWarrants', {
        status: 'active'
    });

    const box = document.getElementById('warrantList');
    box.innerHTML = '';

    if (!res.ok) {
        notify(res.message);
        return;
    }

    if (!res.results.length) {
        box.innerHTML = `<div class="item"><p>Nessun mandato attivo.</p></div>`;
        return;
    }

    res.results.forEach(w => {
        box.innerHTML += `
            <div class="item">
                <div class="item-head">
                    <h4>#${w.id} ${escapeHtml(w.title)}</h4>
                    <span class="badge">${escapeHtml(w.status)}</span>
                </div>
                <p>${escapeHtml(w.target_label || w.target_identifier || w.plate || 'N/D')}</p>
                <p>${escapeHtml(w.reason || '')}</p>
                <div class="actions">
                    <button onclick="setWarrantStatus(${w.id}, 'closed')">Chiudi</button>
                    <button onclick="setWarrantStatus(${w.id}, 'rejected')">Rigetta</button>
                </div>
            </div>
        `;
    });
}

async function createWarrant() {
    const res = await nui('createWarrant', {
        target_type: document.getElementById('warTargetType').value,
        target_identifier: document.getElementById('warTargetIdentifier').value,
        target_label: document.getElementById('warTargetLabel').value,
        plate: document.getElementById('warPlate').value,
        title: document.getElementById('warTitle').value,
        reason: document.getElementById('warReason').value,
        expires_at: document.getElementById('warExpires').value
    });

    notify(res.message);

    if (res.ok) {
        loadWarrants();
        reloadBoot();
    }
}

async function setWarrantStatus(id, status) {
    const res = await nui('setWarrantStatus', {
        id,
        status
    });

    notify(res.message);

    if (res.ok) {
        loadWarrants();
        reloadBoot();
    }
}

async function loadBolos() {
    const res = await nui('listBolos', {
        status: 'active'
    });

    const box = document.getElementById('boloList');
    box.innerHTML = '';

    if (!res.ok) {
        notify(res.message);
        return;
    }

    if (!res.results.length) {
        box.innerHTML = `<div class="item"><p>Nessun BOLO attivo.</p></div>`;
        return;
    }

    res.results.forEach(b => {
        box.innerHTML += `
            <div class="item">
                <div class="item-head">
                    <h4>#${b.id} ${escapeHtml(b.title)}</h4>
                    <span class="badge ${escapeHtml(b.priority)}">${escapeHtml(b.priority)}</span>
                </div>
                <p>${escapeHtml(b.description || '')}</p>
                <div class="badges">
                    <span class="badge">${escapeHtml(b.type)}</span>
                    ${b.plate ? `<span class="badge">Targa ${escapeHtml(b.plate)}</span>` : ''}
                    ${b.person_label ? `<span class="badge">${escapeHtml(b.person_label)}</span>` : ''}
                </div>
                <div class="actions">
                    <button onclick="setBoloStatus(${b.id}, 'closed')">Chiudi BOLO</button>
                </div>
            </div>
        `;
    });
}

async function createBolo() {
    const res = await nui('createBolo', {
        type: document.getElementById('boloType').value,
        title: document.getElementById('boloTitle').value,
        description: document.getElementById('boloDescription').value,
        person_identifier: document.getElementById('boloPersonIdentifier').value,
        person_label: document.getElementById('boloPersonLabel').value,
        plate: document.getElementById('boloPlate').value,
        image: document.getElementById('boloImage').value,
        priority: document.getElementById('boloPriority').value
    });

    notify(res.message);

    if (res.ok) {
        loadBolos();
        reloadBoot();
    }
}

async function setBoloStatus(id, status) {
    const res = await nui('setBoloStatus', {
        id,
        status
    });

    notify(res.message);

    if (res.ok) {
        loadBolos();
        reloadBoot();
    }
}

async function loadCharges() {
    const res = await nui('listCharges');
    const box = document.getElementById('chargeList');

    box.innerHTML = '';

    if (!res.ok) {
        notify(res.message);
        return;
    }

    if (!res.results.length) {
        box.innerHTML = `<div class="item"><p>Nessun reato registrato.</p></div>`;
        return;
    }

    res.results.forEach(c => {
        box.innerHTML += `
            <div class="item">
                <div class="item-head">
                    <h4>${escapeHtml(c.code)} · ${escapeHtml(c.title)}</h4>
                    <button onclick="fillCharge(${encodeURIComponent(JSON.stringify(c))})">Modifica</button>
                </div>
                <p>${escapeHtml(c.description || '')}</p>
                <div class="badges">
                    <span class="badge">${escapeHtml(c.category)}</span>
                    <span class="badge">$${escapeHtml(c.fine)}</span>
                    <span class="badge">${escapeHtml(c.jail)} mesi/minuti RP</span>
                </div>
            </div>
        `;
    });
}

function fillCharge(encoded) {
    const c = JSON.parse(decodeURIComponent(encoded));

    document.getElementById('chargeCode').value = c.code;
    document.getElementById('chargeCategory').value = c.category;
    document.getElementById('chargeTitle').value = c.title;
    document.getElementById('chargeDescription').value = c.description || '';
    document.getElementById('chargeFine').value = c.fine;
    document.getElementById('chargeJail').value = c.jail;
}

async function saveCharge() {
    const res = await nui('upsertCharge', {
        code: document.getElementById('chargeCode').value,
        category: document.getElementById('chargeCategory').value,
        title: document.getElementById('chargeTitle').value,
        description: document.getElementById('chargeDescription').value,
        fine: document.getElementById('chargeFine').value,
        jail: document.getElementById('chargeJail').value
    });

    notify(res.message);

    if (res.ok) {
        loadCharges();
        reloadBoot();
    }
}

async function createAnnouncement() {
    const res = await nui('createAnnouncement', {
        title: document.getElementById('annTitle').value,
        message: document.getElementById('annMessage').value,
        priority: document.getElementById('annPriority').value
    });

    notify(res.message);

    if (res.ok) {
        document.getElementById('annTitle').value = '';
        document.getElementById('annMessage').value = '';
        reloadBoot();
    }
}

document.querySelectorAll('.nav').forEach(btn => {
    btn.addEventListener('click', () => setPage(btn.dataset.page));
});

document.getElementById('closeBtn').addEventListener('click', closeMdt);
document.getElementById('searchCitizenBtn').addEventListener('click', searchCitizens);
document.getElementById('searchVehicleBtn').addEventListener('click', searchVehicles);
document.getElementById('createIncidentBtn').addEventListener('click', createIncident);
document.getElementById('reloadIncidentsBtn').addEventListener('click', loadIncidents);
document.getElementById('createWarrantBtn').addEventListener('click', createWarrant);
document.getElementById('reloadWarrantsBtn').addEventListener('click', loadWarrants);
document.getElementById('createBoloBtn').addEventListener('click', createBolo);
document.getElementById('reloadBolosBtn').addEventListener('click', loadBolos);
document.getElementById('reloadChargesBtn').addEventListener('click', loadCharges);
document.getElementById('saveChargeBtn').addEventListener('click', saveCharge);
document.getElementById('createAnnouncementBtn').addEventListener('click', createAnnouncement);

document.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
        closeMdt();
    }
});

setInterval(() => {
    const d = new Date();
    document.getElementById('clock').textContent =
        `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}, 1000);

window.addEventListener('message', event => {
    const data = event.data;

    if (data.type === 'open') {
        app.classList.remove('hidden');
        bootstrap(data.payload);
        setPage('dashboard');
    }

    if (data.type === 'close') {
        app.classList.add('hidden');
    }

    if (data.type === 'refresh') {
        reloadBoot();

        if (state.currentPage === 'incidents') loadIncidents();
        if (state.currentPage === 'warrants') loadWarrants();
        if (state.currentPage === 'bolos') loadBolos();
        if (state.currentPage === 'charges') loadCharges();
    }
});