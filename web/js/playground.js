/* ============================================================
   Playground — interactive graph query demo (pre-rendered)
   ============================================================
   Tab-switcher with 6 fixtures showing real-shaped JSON output
   from each graph query mode. No live engine; output is static
   but accurate per docs/shared/graph-query.md schema.
   ============================================================ */
(function () {
    'use strict';

    /* Fixtures simulate a typical TypeScript webapp codebase — auth, API,
       payments, a database layer — so the numbers and shapes feel plausible
       to any developer browsing the page. Real graph engine output, real
       schema; the data is illustrative. */
    var fixtures = {
        impact: {
            cmd: 'graph-impact --file src/auth/login.ts',
            json: {
                target: 'src/auth/login.ts',
                impact: {
                    files: 47,
                    modules: 6,
                    affected_modules: ['api', 'middleware', 'pages', 'lib', 'components', 'tests'],
                    by_category: { code: 22, test: 14, doc: 6, config: 5 },
                    files_by_depth: {
                        '1': [
                            'src/api/session/route.ts',
                            'src/api/auth/[...nextauth]/route.ts',
                            'src/middleware/requireAuth.ts',
                            'src/lib/auth/jwt.ts'
                        ],
                        '2': [
                            'src/pages/dashboard.tsx',
                            'src/pages/account/settings.tsx',
                            'src/components/UserMenu.tsx',
                            'tests/auth/login.spec.ts'
                        ],
                        '3': [
                            'tests/e2e/checkout.spec.ts',
                            'docs/runbooks/auth-incident.md'
                        ]
                    }
                },
                warning: 'High blast radius: 47 files affected. Consider scoping the change or coordinating with the API and payments teams.'
            }
        },
        callers: {
            cmd: 'graph-callers --symbol verifyJWT',
            json: {
                target: 'verifyJWT',
                callers: [
                    { func: 'requireAuth',     file: 'src/middleware/requireAuth.ts',          module: 'middleware', line: 24, kind: 'ts-call', confidence: 'direct' },
                    { func: 'authenticate',    file: 'src/api/session/route.ts',               module: 'api',        line: 41, kind: 'ts-call', confidence: 'direct' },
                    { func: 'refreshSession',  file: 'src/api/session/route.ts',               module: 'api',        line: 87, kind: 'ts-call', confidence: 'direct' },
                    { func: 'getCurrentUser',  file: 'src/lib/server/getCurrentUser.ts',       module: 'lib',        line: 18, kind: 'ts-call', confidence: 'direct' },
                    { func: 'checkApiKey',     file: 'src/api/webhooks/stripe.ts',             module: 'api',        line: 12, kind: 'ts-call', confidence: 'inferred' }
                ],
                total: 5,
                by_module: { middleware: 1, api: 3, lib: 1 },
                note: 'intra-file call edges only; cross-file resolution requires type information'
            }
        },
        hotspots: {
            cmd: 'hotspot-rank --top 10',
            json: {
                hotspots: [
                    { id: 'src/lib/db/connection.ts',          module: 'lib',         lines:  624, fanIn: 38 },
                    { id: 'src/api/users/[id]/route.ts',       module: 'api',         lines:  892, fanIn: 24 },
                    { id: 'src/lib/auth/jwt.ts',               module: 'lib',         lines:  411, fanIn: 22 },
                    { id: 'src/middleware/requireAuth.ts',     module: 'middleware',  lines:  287, fanIn: 19 },
                    { id: 'src/lib/payments/stripe.ts',        module: 'lib',         lines:  738, fanIn: 17 },
                    { id: 'src/components/Layout.tsx',         module: 'components',  lines:  512, fanIn: 16 },
                    { id: 'src/lib/server/getCurrentUser.ts',  module: 'lib',         lines:  198, fanIn: 14 },
                    { id: 'src/api/checkout/route.ts',         module: 'api',         lines: 1043, fanIn: 11 }
                ]
            }
        },
        cycles: {
            cmd: 'cycle-detect',
            json: {
                cycles: [
                    ['lib', 'api', 'lib'],
                    ['components', 'lib', 'utils', 'components']
                ],
                count: 2,
                warning: '2 circular dependency cycle(s) detected. These indicate tight coupling.'
            }
        },
        modules: {
            cmd: 'graph-snapshot --modules',
            json: {
                modules: [
                    { kind: 'node', id: 'src',         sizeKB: 1284 },
                    { kind: 'node', id: 'lib',         sizeKB:  712 },
                    { kind: 'node', id: 'api',         sizeKB:  504 },
                    { kind: 'node', id: 'components',  sizeKB:  486 },
                    { kind: 'node', id: 'middleware',  sizeKB:   94 },
                    { kind: 'node', id: 'pages',       sizeKB:  318 },
                    { kind: 'node', id: 'tests',       sizeKB:  442 }
                ],
                dependencies: [
                    { kind: 'edge', source: 'pages',       target: 'components', weight: 124 },
                    { kind: 'edge', source: 'api',         target: 'lib',        weight: 218 },
                    { kind: 'edge', source: 'middleware',  target: 'lib',        weight:  47 },
                    { kind: 'edge', source: 'components',  target: 'lib',        weight:  91 },
                    { kind: 'edge', source: 'pages',       target: 'lib',        weight:  62 },
                    { kind: 'edge', source: 'tests',       target: 'lib',        weight: 156 },
                    { kind: 'edge', source: 'tests',       target: 'api',        weight:  88 }
                ],
                cycles: [],
                summary: {
                    modules: 7,
                    edges:   7,
                    cycles:  0,
                    hub_modules: [
                        { module: 'lib',        dependents_weight: 574 },
                        { module: 'components', dependents_weight: 124 },
                        { module: 'api',        dependents_weight:  88 }
                    ]
                }
            }
        },
        mermaid: {
            cmd: 'mermaid-from-graph --diagram module-deps',
            // Mermaid mode emits markdown text, not JSON. Show a fenced block.
            text:
                '## Module Dependencies\n\n' +
                '```mermaid\n' +
                'graph LR\n' +
                '    pages --> components\n' +
                '    pages --> lib\n' +
                '    api --> lib\n' +
                '    middleware --> lib\n' +
                '    components --> lib\n' +
                '    tests --> lib\n' +
                '    tests --> api\n' +
                '    classDef hub fill:#7c3aed,stroke:#5b21b6,color:#fff\n' +
                '    class lib hub\n' +
                '```\n\n' +
                '## API Surface\n\n' +
                '```mermaid\n' +
                'graph TD\n' +
                '    Client -->|POST /auth/login| login[login.ts]\n' +
                '    Client -->|GET /api/users/:id| users[users/route.ts]\n' +
                '    Client -->|POST /api/checkout| checkout[checkout/route.ts]\n' +
                '    login --> jwt[lib/auth/jwt.ts]\n' +
                '    users --> db[lib/db/connection.ts]\n' +
                '    checkout --> stripe[lib/payments/stripe.ts]\n' +
                '```\n'
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

        Array.prototype.forEach.call(tabs, function (tab) {
            tab.addEventListener('click', function () {
                Array.prototype.forEach.call(tabs, function (t) {
                    t.classList.remove('is-active');
                    t.setAttribute('aria-selected', 'false');
                });
                tab.classList.add('is-active');
                tab.setAttribute('aria-selected', 'true');
                render(tab.getAttribute('data-tab'));
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
