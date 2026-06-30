let allBills = [];
let activeFilter = 'all';
let categories = [];

window.addEventListener('message', e => {
    const d = e.data;
    if (d.action === 'open') {
        applyTheme(d.theme);
        categories = d.categories;
        allBills = d.bills;
        renderFilters();
        renderBills();
        document.getElementById('billing-app').classList.remove('hidden');
    }
});

function applyTheme(t) {
    const r = document.documentElement.style;
    r.setProperty('--primary', t.primary);
    r.setProperty('--bg', t.background);
    r.setProperty('--surface', t.surface);
    r.setProperty('--border', t.border);
}

function renderFilters() {
    const c = document.getElementById('filters');
    c.innerHTML = '';
    categories.forEach(cat => {
        const el = document.createElement('div');
        el.className = 'filter-chip' + (cat.id === activeFilter ? ' active' : '');
        el.innerText = cat.label;
        el.onclick = () => { activeFilter = cat.id; renderFilters(); renderBills(); };
        c.appendChild(el);
    });
}

function renderBills() {
    const list = document.getElementById('bills-list');
    const filtered = activeFilter === 'all' ? allBills : allBills.filter(b => b.category === activeFilter);

    document.getElementById('stat-count').innerText = allBills.length;
    const total = allBills.reduce((s, b) => s + b.amount, 0);
    document.getElementById('stat-total').innerText = '$' + total.toLocaleString();

    if (filtered.length === 0) {
        list.innerHTML = '<div class="empty">✨ Nessuna fattura in sospeso!</div>';
        return;
    }

    list.innerHTML = '';
    filtered.forEach(b => {
        const society = b.target_society || 'Sistema';
        const date = new Date(b.created_at).toLocaleString('it-IT');
        const el = document.createElement('div');
        el.className = 'bill-item';
        el.innerHTML = `
            <div class="bill-info">
                <h4>📄 ${b.label}</h4>
                <p>Da: ${society} • ${date}</p>
            </div>
            <div class="bill-amount">$${b.amount.toLocaleString()}</div>
            <div class="bill-actions">
                <button class="btn-secondary" onclick="pay(${b.id}, 'cash')">💵 Contanti</button>
                <button class="btn-primary" onclick="pay(${b.id}, 'bank')">🏦 Banca</button>
            </div>
        `;
        list.appendChild(el);
    });
}

async function pay(id, method) {
    await fetch(`https://${GetParentResourceName()}/pay`, {
        method: 'POST', body: JSON.stringify({ id, method })
    });
    setTimeout(refresh, 400);
}

async function payAll() {
    if (!confirm('Pagare tutte le fatture dal conto bancario?')) return;
    await fetch(`https://${GetParentResourceName()}/payAll`, { method: 'POST', body: '{}' });
    setTimeout(refresh, 400);
}

async function refresh() {
    const r = await fetch(`https://${GetParentResourceName()}/refresh`, { method: 'POST', body: '{}' });
    allBills = await r.json();
    renderBills();
}

function closeBilling() {
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: '{}' });
    document.getElementById('billing-app').classList.add('hidden');
}

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeBilling();
});