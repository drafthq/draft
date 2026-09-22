/* ============================================================
   Playground — interactive graph query demo (pre-rendered)
   ============================================================
   Tab-switcher with 6 fixtures showing each wrapper's real output
   shape (scripts/tools/*.sh, as of Draft 5.0.0). No live engine; the
   data is illustrative, the fields and structure are exact.
   ============================================================ */
(function () {
    'use strict';

    /* Fixtures simulate a typical TypeScript webapp codebase — auth, API,
       payments, a database layer — so the numbers and shapes feel plausible
       to any developer browsing the page. Real graph engine output, real
       schema; the data is illustrative. */
    var fixtures = {
        impact: {
            cmd: "graph-impact --file src/lib/auth/jwt.ts",
            json: {
                "target": "src/lib/auth/jwt.ts",
                "kind": "file",
                "impacted": [
                    {
                        "name": "handleLogin",
                        "file": "src/api/auth/login.ts",
                        "qualified": "webapp-3f9c1a7e.src.api.auth.login.handleLogin",
                        "hop": 1
                    },
                    {
                        "name": "refreshSession",
                        "file": "src/api/session/route.ts",
                        "qualified": "webapp-3f9c1a7e.src.api.session.route.refreshSession",
                        "hop": 1
                    },
                    {
                        "name": "src/api/session/route.ts",
                        "file": "src/api/session/route.ts",
                        "qualified": "",
                        "hop": 1
                    },
                    {
                        "name": "getCurrentUser",
                        "file": "src/lib/server/getCurrentUser.ts",
                        "qualified": "webapp-3f9c1a7e.src.lib.server.getCurrentUser.getCurrentUser",
                        "hop": 1
                    },
                    {
                        "name": "requireAuth",
                        "file": "src/middleware/requireAuth.ts",
                        "qualified": "webapp-3f9c1a7e.src.middleware.requireAuth.requireAuth",
                        "hop": 1
                    },
                    {
                        "name": "GET",
                        "file": "src/api/users/[id]/route.ts",
                        "qualified": "webapp-3f9c1a7e.src.api.users.[id].route.GET",
                        "hop": 2
                    },
                    {
                        "name": "DashboardPage",
                        "file": "src/pages/dashboard.tsx",
                        "qualified": "webapp-3f9c1a7e.src.pages.dashboard.DashboardPage",
                        "hop": 2
                    },
                    {
                        "name": "loginAs",
                        "file": "tests/helpers/auth.ts",
                        "qualified": "webapp-3f9c1a7e.tests.helpers.auth.loginAs",
                        "hop": 2
                    },
                    {
                        "name": "checkoutFlow",
                        "file": "tests/e2e/checkout.spec.ts",
                        "qualified": "webapp-3f9c1a7e.tests.e2e.checkout.spec.checkoutFlow",
                        "hop": 3
                    }
                ],
                "downstream_files": [
                    "src/api/auth/login.ts",
                    "src/api/session/route.ts",
                    "src/api/users/[id]/route.ts",
                    "src/lib/server/getCurrentUser.ts",
                    "src/middleware/requireAuth.ts",
                    "src/pages/dashboard.tsx",
                    "tests/e2e/checkout.spec.ts",
                    "tests/helpers/auth.ts"
                ],
                "affected_modules": [
                    "src",
                    "tests"
                ],
                "max_depth": 3,
                "by_category": {
                    "code": 6,
                    "test": 2
                },
                "status": "ok",
                "truncated": false,
                "source": "memory-graph"
            }
        },
        callers: {
            cmd: "graph-callers --symbol verifyJWT",
            json: {
                "symbol": "verifyJWT",
                "callers": [
                    {
                        "name": "handleLogin",
                        "file": "src/api/auth/login.ts",
                        "qualified": ""
                    },
                    {
                        "name": "refreshSession",
                        "file": "src/api/session/route.ts",
                        "qualified": ""
                    },
                    {
                        "name": "getCurrentUser",
                        "file": "src/lib/server/getCurrentUser.ts",
                        "qualified": ""
                    },
                    {
                        "name": "requireAuth",
                        "file": "src/middleware/requireAuth.ts",
                        "qualified": ""
                    }
                ],
                "status": "ok",
                "source": "memory-graph"
            }
        },
        hotspots: {
            cmd: "hotspot-rank --top 6",
            json: {
                "hotspots": [
                    {
                        "id": "webapp-3f9c1a7e.src.lib.db.connection.query",
                        "name": "query",
                        "fanIn": 38,
                        "score": 43,
                        "complexity": 3,
                        "cognitive": 2,
                        "isEntryPoint": false
                    },
                    {
                        "id": "webapp-3f9c1a7e.src.lib.payments.stripe.chargeCard",
                        "name": "chargeCard",
                        "fanIn": 12,
                        "score": 41,
                        "complexity": 11,
                        "cognitive": 18,
                        "isEntryPoint": false
                    },
                    {
                        "id": "webapp-3f9c1a7e.src.middleware.requireAuth.requireAuth",
                        "name": "requireAuth",
                        "fanIn": 19,
                        "score": 32,
                        "complexity": 6,
                        "cognitive": 7,
                        "isEntryPoint": false
                    },
                    {
                        "id": "webapp-3f9c1a7e.src.lib.auth.jwt.verifyJWT",
                        "name": "verifyJWT",
                        "fanIn": 22,
                        "score": 29,
                        "complexity": 4,
                        "cognitive": 3,
                        "isEntryPoint": false
                    },
                    {
                        "id": "webapp-3f9c1a7e.src.lib.server.getCurrentUser.getCurrentUser",
                        "name": "getCurrentUser",
                        "fanIn": 14,
                        "score": 19,
                        "complexity": 3,
                        "cognitive": 2,
                        "isEntryPoint": false
                    },
                    {
                        "id": "webapp-3f9c1a7e.src.components.Layout.Layout",
                        "name": "Layout",
                        "fanIn": 16,
                        "score": 19,
                        "complexity": 2,
                        "cognitive": 1,
                        "isEntryPoint": false
                    }
                ],
                "enrichment": "ok",
                "source": "memory-graph"
            }
        },
        cycles: {
            cmd: "cycle-detect",
            json: {
                "cycles": [
                    [
                        "webapp-3f9c1a7e.src.lib.cart.applyDiscount",
                        "webapp-3f9c1a7e.src.lib.cart.recalcTotal"
                    ],
                    [
                        "webapp-3f9c1a7e.src.api.orders.createOrder",
                        "webapp-3f9c1a7e.src.lib.inventory.reserveStock",
                        "webapp-3f9c1a7e.src.lib.orders.retryOrder"
                    ]
                ],
                "truncated": false,
                "source": "memory-graph"
            }
        },
        modules: {
            cmd: "graph-arch --repo . | jq '{project, total_nodes, total_edges, packages, layers}'",
            json: {
                "project": "webapp-3f9c1a7e",
                "total_nodes": 4812,
                "total_edges": 11390,
                "packages": [
                    {
                        "name": "lib",
                        "node_count": 1204,
                        "fan_in": 41,
                        "fan_out": 6
                    },
                    {
                        "name": "tests",
                        "node_count": 1012,
                        "fan_in": 0,
                        "fan_out": 33
                    },
                    {
                        "name": "api",
                        "node_count": 836,
                        "fan_in": 9,
                        "fan_out": 27
                    },
                    {
                        "name": "components",
                        "node_count": 692,
                        "fan_in": 18,
                        "fan_out": 11
                    },
                    {
                        "name": "pages",
                        "node_count": 311,
                        "fan_in": 0,
                        "fan_out": 24
                    },
                    {
                        "name": "middleware",
                        "node_count": 88,
                        "fan_in": 12,
                        "fan_out": 4
                    }
                ],
                "layers": [
                    {
                        "name": "lib",
                        "layer": "core",
                        "reason": "fan-in=41, fan-out=6"
                    },
                    {
                        "name": "middleware",
                        "layer": "core",
                        "reason": "fan-in=12, fan-out=4"
                    },
                    {
                        "name": "components",
                        "layer": "internal",
                        "reason": "fan-in=18, fan-out=11"
                    },
                    {
                        "name": "api",
                        "layer": "api",
                        "reason": "fan-in=9, fan-out=27"
                    },
                    {
                        "name": "pages",
                        "layer": "entry",
                        "reason": "fan-in=0, fan-out=24"
                    },
                    {
                        "name": "tests",
                        "layer": "entry",
                        "reason": "fan-in=0, fan-out=33"
                    }
                ]
            }
        },
        mermaid: {
            cmd: 'mermaid-from-graph --diagram module-deps',
            // Mermaid mode emits markdown text, not JSON. Show the fenced block.
            text: "```mermaid\nflowchart LR\n    \"src/api/auth/login.ts\" --> \"src/lib/auth/jwt.ts\"\n    \"src/middleware/requireAuth.ts\" --> \"src/lib/auth/jwt.ts\"\n    \"src/lib/server/getCurrentUser.ts\" --> \"src/lib/auth/jwt.ts\"\n    \"src/api/session/route.ts\" --> \"src/middleware/requireAuth.ts\"\n    \"src/pages/dashboard.tsx\" --> \"src/lib/server/getCurrentUser.ts\"\n    \"src/api/users/[id]/route.ts\" --> \"src/lib/db/connection.ts\"\n```\n"
        }
    };

    /* ─── Pretty-print JSON with syntax classes for highlighting ───── */
    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
    }

    function colorize(json) {
        var raw = JSON.stringify(json, null, 2);
        // Order matters: strings first (so we don't double-color keys)
        return raw.replace(
            /"([^"\\]|\\.)*"(\s*:)?|\b(true|false)\b|\b(null)\b|-?\b\d+(?:\.\d+)?\b/g,
            function (match, _g1, _g2, bool, nul) {
                if (/^".*"\s*:/.test(match)) {
                    var key = match.replace(/\s*:$/, '');
                    return '<span class="pg-key">' + escapeHtml(key) + '</span>:';
                }
                if (bool) return '<span class="pg-bool">' + match + '</span>';
                if (nul)  return '<span class="pg-null">' + match + '</span>';
                if (match.charAt(0) === '"') return '<span class="pg-str">' + escapeHtml(match) + '</span>';
                return '<span class="pg-num">' + match + '</span>';
            }
        );
    }

    function colorizeMermaid(text) {
        // Highlight fenced ```mermaid blocks differently
        return escapeHtml(text)
            .replace(/^(##\s+.*)$/gm, '<span class="pg-violet">$1</span>')
            .replace(/^(```mermaid)$/gm, '<span class="pg-key">$1</span>')
            .replace(/^(```)$/gm, '<span class="pg-key">$1</span>')
            .replace(/(%%[^\n]*)/g, '<span class="pg-comment">$1</span>')
            .replace(/^(\s+classDef\s+)(\w+)\s+(.+)$/gm,
                '<span class="pg-key">$1</span><span class="pg-bool">$2</span> <span class="pg-str">$3</span>')
            .replace(/^(\s+class\s+)(\w+)\s+(\w+)$/gm,
                '<span class="pg-key">$1</span>$2 <span class="pg-bool">$3</span>');
    }

    function render(tab) {
        var pane    = document.getElementById('playground-output');
        var cmdEl   = document.getElementById('playground-cmd');
        if (!pane || !cmdEl) return;
        var fixture = fixtures[tab];
        if (!fixture) return;
        cmdEl.textContent = fixture.cmd;
        if (fixture.text) {
            pane.innerHTML = colorizeMermaid(fixture.text);
        } else {
            pane.innerHTML = colorize(fixture.json);
        }
    }

    function init() {
        var tabs = document.querySelectorAll('.playground-tab');
        if (!tabs.length) return;

        var panel = document.getElementById('playground-panel');
        function select(tab) {
            Array.prototype.forEach.call(tabs, function (t) {
                var on = t === tab;
                t.classList.toggle('is-active', on);
                t.setAttribute('aria-selected', on ? 'true' : 'false');
                t.setAttribute('tabindex', on ? '0' : '-1');
            });
            if (panel && tab.id) panel.setAttribute('aria-labelledby', tab.id);
            render(tab.getAttribute('data-tab'));
        }
        Array.prototype.forEach.call(tabs, function (tab, i) {
            tab.addEventListener('click', function () { select(tab); });
            tab.addEventListener('keydown', function (e) {
                var next = e.key === 'ArrowRight' ? i + 1
                    : e.key === 'ArrowLeft' ? i - 1
                    : e.key === 'Home' ? 0
                    : e.key === 'End' ? tabs.length - 1
                    : null;
                if (next === null) return;
                e.preventDefault();
                var t = tabs[(next + tabs.length) % tabs.length];
                select(t);
                t.focus();
            });
        });

        // Initial render
        render('impact');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
