/* ============================================================
   IMPACT CONSOLE — the hero's live codebase graph
   ------------------------------------------------------------
   A small dependency graph of a typical web app, laid out by
   module. Every few seconds one file is "changed": its blast
   radius ripples outward depth by depth along real edges, and
   the ledger prints what graph-impact would print — files by
   depth, modules reached, and the code/test/doc/config split.
   The numbers come from a BFS over the graph, not from copy.
   ============================================================ */

(function () {
    'use strict';

    var wrap = document.getElementById('console-graph');
    var canvas = document.getElementById('hero-canvas');
    if (!wrap || !canvas) return;

    var ctx = canvas.getContext('2d');
    var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    /* ---- Palette (the pane is dark in both themes) ---------- */
    var C = {
        edge: 'rgba(146, 164, 204, 0.16)',
        node: 'rgba(146, 164, 204, 0.42)',
        label: 'rgba(146, 164, 204, 0.55)',
        blue: [91, 141, 239],
        amber: [242, 179, 61]
    };
    function rgba(c, a) { return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; }

    /* ---- Modules and files ---------------------------------- */
    var MODULES = [
        { id: 'api',        label: 'api',        x: 0.20, y: 0.28, r: 0.13 },
        { id: 'auth',       label: 'auth',       x: 0.52, y: 0.22, r: 0.12 },
        { id: 'lib',        label: 'lib',        x: 0.82, y: 0.32, r: 0.13 },
        { id: 'pages',      label: 'pages',      x: 0.18, y: 0.74, r: 0.12 },
        { id: 'components', label: 'components', x: 0.50, y: 0.76, r: 0.12 },
        { id: 'tests',      label: 'tests',      x: 0.80, y: 0.76, r: 0.11 },
        { id: 'docs',       label: 'docs',       x: 0.86, y: 0.56, r: 0.05 }
    ];

    var FILES = [
        ['api', 'src/api/session/route.ts'],
        ['api', 'src/api/auth/[...nextauth]/route.ts'],
        ['api', 'src/api/users/route.ts'],
        ['api', 'src/api/payments/charge.ts'],
        ['api', 'src/api/payments/webhook.ts'],
        ['api', 'src/api/orders/route.ts'],
        ['api', 'src/api/health.ts'],
        ['auth', 'src/auth/login.ts'],
        ['auth', 'src/auth/session.ts'],
        ['auth', 'src/auth/jwt.ts'],
        ['auth', 'src/auth/oauth.ts'],
        ['auth', 'src/middleware/requireAuth.ts'],
        ['auth', 'src/auth/permissions.ts'],
        ['lib', 'src/lib/db/client.ts'],
        ['lib', 'src/lib/db/schema.ts'],
        ['lib', 'src/lib/cache.ts'],
        ['lib', 'src/lib/logger.ts'],
        ['lib', 'src/lib/http.ts'],
        ['lib', 'src/lib/queue.ts'],
        ['lib', 'next.config.ts', 'config'],
        ['lib', 'src/config/env.ts', 'config'],
        ['pages', 'src/pages/dashboard.tsx'],
        ['pages', 'src/pages/account/settings.tsx'],
        ['pages', 'src/pages/checkout.tsx'],
        ['pages', 'src/pages/orders/[id].tsx'],
        ['pages', 'src/pages/login.tsx'],
        ['pages', 'src/pages/index.tsx'],
        ['components', 'src/components/UserMenu.tsx'],
        ['components', 'src/components/Button.tsx'],
        ['components', 'src/components/Table.tsx'],
        ['components', 'src/components/PaymentForm.tsx'],
        ['components', 'src/components/Modal.tsx'],
        ['components', 'src/components/Nav.tsx'],
        ['tests', 'tests/auth/login.spec.ts', 'test'],
        ['tests', 'tests/api/session.spec.ts', 'test'],
        ['tests', 'tests/e2e/checkout.spec.ts', 'test'],
        ['tests', 'tests/lib/db.spec.ts', 'test'],
        ['tests', 'tests/components/UserMenu.spec.tsx', 'test'],
        ['tests', 'tests/api/payments.spec.ts', 'test'],
        ['docs', 'docs/runbooks/auth-incident.md', 'doc'],
        ['docs', 'docs/api/payments.md', 'doc'],
        ['docs', 'README.md', 'doc']
    ];

    /* dependent -> [dependencies]. A change in a dependency impacts the dependent. */
    var DEPS = {
        'src/auth/login.ts': ['src/auth/jwt.ts', 'src/auth/session.ts', 'src/lib/db/client.ts', 'src/lib/logger.ts'],
        'src/auth/session.ts': ['src/lib/cache.ts', 'src/lib/db/client.ts'],
        'src/auth/jwt.ts': ['src/config/env.ts'],
        'src/auth/oauth.ts': ['src/auth/session.ts', 'src/lib/http.ts'],
        'src/middleware/requireAuth.ts': ['src/auth/session.ts', 'src/auth/jwt.ts', 'src/auth/permissions.ts'],
        'src/auth/permissions.ts': ['src/lib/db/client.ts'],
        'src/api/session/route.ts': ['src/auth/login.ts', 'src/auth/session.ts'],
        'src/api/auth/[...nextauth]/route.ts': ['src/auth/login.ts', 'src/auth/oauth.ts'],
        'src/api/users/route.ts': ['src/middleware/requireAuth.ts', 'src/lib/db/client.ts'],
        'src/api/payments/charge.ts': ['src/middleware/requireAuth.ts', 'src/lib/db/client.ts', 'src/lib/queue.ts', 'src/lib/http.ts'],
        'src/api/payments/webhook.ts': ['src/lib/queue.ts', 'src/lib/db/client.ts', 'src/lib/logger.ts'],
        'src/api/orders/route.ts': ['src/middleware/requireAuth.ts', 'src/lib/db/client.ts'],
        'src/api/health.ts': ['src/lib/db/client.ts', 'src/lib/cache.ts'],
        'src/lib/db/client.ts': ['src/lib/db/schema.ts', 'src/config/env.ts', 'src/lib/logger.ts'],
        'src/lib/cache.ts': ['src/config/env.ts'],
        'src/lib/http.ts': ['src/lib/logger.ts'],
        'src/lib/queue.ts': ['src/lib/logger.ts', 'src/config/env.ts'],
        'next.config.ts': ['src/config/env.ts'],
        'src/pages/dashboard.tsx': ['src/components/UserMenu.tsx', 'src/components/Table.tsx', 'src/middleware/requireAuth.ts'],
        'src/pages/account/settings.tsx': ['src/components/UserMenu.tsx', 'src/auth/session.ts'],
        'src/pages/checkout.tsx': ['src/components/PaymentForm.tsx', 'src/api/payments/charge.ts'],
        'src/pages/orders/[id].tsx': ['src/components/Table.tsx', 'src/api/orders/route.ts'],
        'src/pages/login.tsx': ['src/auth/login.ts', 'src/components/Button.tsx'],
        'src/pages/index.tsx': ['src/components/Nav.tsx', 'src/components/Button.tsx'],
        'src/components/UserMenu.tsx': ['src/auth/session.ts', 'src/components/Button.tsx'],
        'src/components/PaymentForm.tsx': ['src/components/Button.tsx', 'src/components/Modal.tsx', 'src/lib/http.ts'],
        'src/components/Nav.tsx': ['src/components/UserMenu.tsx'],
        'src/components/Modal.tsx': ['src/components/Button.tsx'],
        'tests/auth/login.spec.ts': ['src/auth/login.ts'],
        'tests/api/session.spec.ts': ['src/api/session/route.ts'],
        'tests/e2e/checkout.spec.ts': ['src/pages/checkout.tsx'],
        'tests/lib/db.spec.ts': ['src/lib/db/client.ts'],
        'tests/components/UserMenu.spec.tsx': ['src/components/UserMenu.tsx'],
        'tests/api/payments.spec.ts': ['src/api/payments/charge.ts', 'src/api/payments/webhook.ts'],
        'docs/runbooks/auth-incident.md': ['src/auth/login.ts', 'src/middleware/requireAuth.ts'],
        'docs/api/payments.md': ['src/api/payments/charge.ts'],
        'README.md': ['next.config.ts']
    };

    /* Files whose change we simulate, in order. */
    var TARGETS = [
        'src/auth/login.ts',
        'src/lib/db/client.ts',
        'src/components/Button.tsx',
        'src/lib/queue.ts'
    ];

    /* ---- Build graph ---------------------------------------- */
    /* Fixed seed on purpose: the layout must be identical on every load so
       the static ledger in the HTML matches the first frame exactly. */
    var seed = 7;
    function rand() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }

    var nodes = [], byPath = {}, modById = {};
    MODULES.forEach(function (m) { modById[m.id] = m; m.count = 0; });
    FILES.forEach(function (f) { modById[f[0]].count++; });

    var moduleIndex = {};
    FILES.forEach(function (f) {
        var m = modById[f[0]];
        var i = moduleIndex[m.id] = (moduleIndex[m.id] || 0);
        moduleIndex[m.id]++;
        var ang = (i / m.count) * Math.PI * 2 + rand() * 0.9;
        var rad = m.count === 1 ? 0 : (0.45 + rand() * 0.55);
        var n = {
            path: f[1], mod: m.id, cat: f[2] || 'code',
            ux: m.x + Math.cos(ang) * m.r * rad,
            uy: m.y + Math.sin(ang) * m.r * rad * 0.85,
            x: 0, y: 0, lit: -1
        };
        nodes.push(n);
        byPath[n.path] = n;
    });

    var edges = [];           /* { a: dependent node, b: dependency node } */
    var dependents = {};      /* dependency path -> [dependent paths] */
    Object.keys(DEPS).forEach(function (from) {
        DEPS[from].forEach(function (to) {
            if (!byPath[from] || !byPath[to]) return;
            edges.push({ a: byPath[from], b: byPath[to], lit: -1 });
            (dependents[to] = dependents[to] || []).push(from);
        });
    });

    /* Impact BFS: who is affected when `target` changes, by depth (max 3). */
    function impact(target) {
        var depth = {}, order = [[target]], frontier = [target];
        depth[target] = 0;
        for (var d = 1; d <= 3; d++) {
            var next = [];
            frontier.forEach(function (p) {
                (dependents[p] || []).forEach(function (q) {
                    if (depth[q] === undefined) { depth[q] = d; next.push(q); }
                });
            });
            order.push(next);
            frontier = next;
        }
        return { depth: depth, levels: order };
    }

    /* ---- Ledger DOM ----------------------------------------- */
    var $ = function (id) { return document.getElementById(id); };
    var el = {
        cmd: $('console-cmd'), target: $('ledger-target'),
        rows: [1, 2, 3].map(function (d) { return { row: $('ledger-d' + d), n: $('ledger-n' + d), list: $('ledger-l' + d) }; }),
        files: $('cf-files'), modules: $('cf-modules'),
        code: $('cf-code'), test: $('cf-test'), doc: $('cf-doc'), config: $('cf-config')
    };

    function short(p) { return p.replace(/^src\//, ''); }

    function writeLedger(target, res) {
        if (el.cmd) {
            el.cmd.textContent = 'graph-impact --file ';
            var b = document.createElement('b');
            b.textContent = target;
            el.cmd.appendChild(b);
        }
        if (el.target) el.target.textContent = target;
        var files = 0, mods = {}, cats = { code: 0, test: 0, doc: 0, config: 0 };
        for (var d = 1; d <= 3; d++) {
            var list = res.levels[d] || [];
            var r = el.rows[d - 1];
            if (!r.row) continue;
            r.n.textContent = list.length;
            r.list.innerHTML = '';
            list.slice(0, 4).forEach(function (p) {
                var li = document.createElement('li');
                li.textContent = short(p);
                r.list.appendChild(li);
            });
            if (list.length > 4) {
                var more = document.createElement('li');
                more.className = 'more';
                more.textContent = '+' + (list.length - 4) + ' more';
                r.list.appendChild(more);
            }
            list.forEach(function (p) { files++; mods[byPath[p].mod] = 1; cats[byPath[p].cat]++; });
        }
        if (el.files) el.files.textContent = files;
        if (el.modules) el.modules.textContent = Object.keys(mods).length;
        ['code', 'test', 'doc', 'config'].forEach(function (k) { if (el[k]) el[k].textContent = cats[k]; });
    }

    function setRowState(stage) {
        el.rows.forEach(function (r, i) {
            if (r.row) r.row.classList.toggle('is-on', stage >= i + 1);
        });
    }

    /* ---- Timeline ------------------------------------------- */
    var STAGE_AT = [0, 550, 1250, 1950];   /* ms after cycle start when depth d lights */
    var DRAW = 520;                        /* ms an edge takes to draw */
    var HOLD_UNTIL = 6600, FADE = 500, CYCLE = HOLD_UNTIL + FADE;

    var targetIdx = 0, cycleStart = 0, current = null, stage = -1, lastNow = 0;

    function beginCycle(now) {
        var target = TARGETS[targetIdx % TARGETS.length];
        targetIdx++;
        current = impact(target);
        current.target = target;
        cycleStart = now;
        stage = -1;
        nodes.forEach(function (n) { n.lit = current.depth[n.path] === undefined ? -1 : current.depth[n.path]; });
        edges.forEach(function (e) {
            /* an edge lights when its dependency is lit and its dependent is one depth further */
            var db = current.depth[e.b.path], da = current.depth[e.a.path];
            e.lit = (db !== undefined && da !== undefined && da === db + 1) ? da : -1;
        });
        writeLedger(target, current);
        setRowState(0);
    }

    /* ---- Sizing --------------------------------------------- */
    var W = 0, H = 0, dpr = 1;
    function resize() {
        dpr = Math.min(window.devicePixelRatio || 1, 2);
        W = wrap.clientWidth; H = wrap.clientHeight;
        canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.font = '600 10px "JetBrains Mono", monospace';   /* resizing resets context state */
        var pad = 26;
        nodes.forEach(function (n) {
            n.x = pad + n.ux * (W - pad * 2);
            n.y = pad + n.uy * (H - pad * 2);
        });
    }

    /* ---- Drawing -------------------------------------------- */
    function ease(t) { return t < 0 ? 0 : t > 1 ? 1 : 1 - Math.pow(1 - t, 3); }

    function draw(now) {
        lastNow = now;
        var t = now - cycleStart;
        var fade = t > HOLD_UNTIL ? 1 - (t - HOLD_UNTIL) / FADE : 1;
        if (fade < 0) fade = 0;

        /* Advance ledger rows with the animation */
        var s = 0;
        for (var d = 1; d <= 3; d++) if (t >= STAGE_AT[d] + DRAW * 0.6) s = d;
        if (s !== stage) { stage = s; setRowState(s); }

        ctx.clearRect(0, 0, W, H);

        /* Module labels */
        ctx.fillStyle = C.label;
        ctx.textAlign = 'center';
        MODULES.forEach(function (m) {
            var pad = 26;
            var x = pad + m.x * (W - pad * 2), y = pad + (m.y - m.r * 0.95) * (H - pad * 2);
            ctx.fillText(m.label.toUpperCase(), x, Math.max(12, y));
        });

        /* Base edges */
        ctx.lineWidth = 1;
        ctx.strokeStyle = C.edge;
        ctx.beginPath();
        edges.forEach(function (e) { ctx.moveTo(e.b.x, e.b.y); ctx.lineTo(e.a.x, e.a.y); });
        ctx.stroke();

        /* Lit edges, drawn from dependency toward dependent */
        edges.forEach(function (e) {
            if (e.lit < 1) return;
            var p = ease((t - STAGE_AT[e.lit]) / DRAW);
            if (p <= 0) return;
            var alpha = (e.lit === 1 ? 0.9 : e.lit === 2 ? 0.6 : 0.38) * fade;
            ctx.strokeStyle = rgba(C.blue, alpha);
            ctx.lineWidth = e.lit === 1 ? 1.6 : 1.2;
            ctx.beginPath();
            ctx.moveTo(e.b.x, e.b.y);
            ctx.lineTo(e.b.x + (e.a.x - e.b.x) * p, e.b.y + (e.a.y - e.b.y) * p);
            ctx.stroke();
        });

        /* Ripple rings from the target */
        var target = byPath[current.target];
        for (var k = 1; k <= 3; k++) {
            var rp = (t - STAGE_AT[k]) / 1400;
            if (rp <= 0 || rp >= 1) continue;
            ctx.beginPath();
            ctx.arc(target.x, target.y, 10 + rp * Math.min(W, H) * 0.42, 0, Math.PI * 2);
            ctx.strokeStyle = rgba(C.amber, (1 - rp) * 0.35 * fade);
            ctx.lineWidth = 1;
            ctx.stroke();
        }

        /* Nodes */
        nodes.forEach(function (n) {
            var r = 3.2, fill = C.node;
            if (n.lit === 0) {
                r = 6; fill = rgba(C.amber, fade);
            } else if (n.lit > 0) {
                var p = ease((t - STAGE_AT[n.lit] - DRAW * 0.6) / 380);
                if (p > 0) {
                    var a = (n.lit === 1 ? 1 : n.lit === 2 ? 0.72 : 0.5) * fade;
                    r = 3.2 + 1.9 * p;
                    fill = rgba(C.blue, a * p + (1 - p) * 0.42);
                }
            }
            ctx.beginPath();
            ctx.arc(n.x, n.y, r, 0, Math.PI * 2);
            ctx.fillStyle = fill;
            ctx.fill();
            if (n.lit === 0) {
                ctx.beginPath();
                ctx.arc(n.x, n.y, 11, 0, Math.PI * 2);
                ctx.strokeStyle = rgba(C.amber, 0.55 * fade);
                ctx.lineWidth = 1.2;
                ctx.stroke();
            }
        });

        /* Target label */
        if (fade > 0.05) {
            ctx.fillStyle = rgba(C.amber, fade);
            ctx.textAlign = target.ux > 0.6 ? 'right' : 'left';
            ctx.fillText(short(current.target), target.x + (target.ux > 0.6 ? -14 : 14), target.y - 12);
        }
    }

    /* ---- Loop ----------------------------------------------- */
    var raf = null, running = false, visible = false;

    function frame(now) {
        if (!running) return;
        if (!current || (!reduceMotion && now - cycleStart >= CYCLE)) beginCycle(now);
        draw(reduceMotion ? cycleStart + HOLD_UNTIL - 1 : now);
        if (reduceMotion) { running = false; return; }
        raf = requestAnimationFrame(frame);
    }

    function start() {
        if (running) return;
        running = true;
        raf = requestAnimationFrame(frame);
    }
    function stop() {
        running = false;
        if (raf) cancelAnimationFrame(raf);
        raf = null;
    }

    resize();
    if ('ResizeObserver' in window) {
        new ResizeObserver(function () { resize(); if (current) draw(lastNow); }).observe(wrap);
    } else {
        window.addEventListener('resize', resize);
    }

    if ('IntersectionObserver' in window) {
        new IntersectionObserver(function (entries) {
            visible = entries[0].isIntersecting;
            if (visible) start(); else stop();
        }, { threshold: 0.05 }).observe(wrap);
    } else {
        visible = true;
        start();
    }

    document.addEventListener('visibilitychange', function () {
        if (document.hidden) stop(); else if (visible && !reduceMotion) start();
    });
})();
