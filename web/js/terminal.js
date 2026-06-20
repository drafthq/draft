/* ============================================================
   TERMINAL — Typewriter effect cycling through commands.
   Auto-cycles on view; can be pinned to a specific command
   when a primary command card is hovered/focused.
   ============================================================ */

(function() {
    var cmdEl = document.getElementById('terminal-cmd');
    var outputEl = document.getElementById('terminal-output');
    var cursorEl = document.querySelector('.terminal-cursor');
    if (!cmdEl || !outputEl) return;

    var commands = [
        {
            key: 'init',
            cmd: '/draft:init',
            output: [
                { text: 'Analyzing codebase...', cls: 'out-info' },
                { text: 'Phase 1: Discovery    ████████░░ signals classified', cls: 'out-info' },
                { text: 'Phase 2: Wiring       ██████████ entry points mapped', cls: 'out-info' },
                { text: 'Phase 3: Depth        ██████████ data flows traced', cls: 'out-info' },
                { text: '→ Generated graph-primary architecture.md (fidelity dashboard + provenance + gaps)', cls: 'out-success' },
                { text: '→ Derived .ai-context.md (312 lines)', cls: 'out-success' },
                { text: '→ State persisted: freshness.json, signals.json', cls: 'out-file' }
            ]
        },
        {
            key: 'plan',
            cmd: '/draft:new-track "Add user authentication"',
            output: [
                { text: 'Starting collaborative intake...', cls: 'out-info' },
                { text: 'Loading context: .ai-context.md, tech-stack.md', cls: 'out-info' },
                { text: '? What authentication method? (OAuth, JWT, session...)', cls: 'out-info' },
                { text: '→ Created spec.md with 4 sections', cls: 'out-success' },
                { text: '→ Created plan.md with 3 phases, 12 tasks', cls: 'out-success' }
            ]
        },
        {
            key: 'implement',
            cmd: '/draft:implement',
            output: [
                { text: 'Track: add-user-auth | Phase 1 | Task 1 of 4', cls: 'out-info' },
                { text: 'RED   → Writing failing test...', cls: 'out-info' },
                { text: 'GREEN → Minimum implementation to pass...', cls: 'out-success' },
                { text: 'REFACTOR → Cleaning with tests green...', cls: 'out-success' },
                { text: '→ Task 1 complete. Committed: feat(auth): add jwt middleware', cls: 'out-file' }
            ]
        },
        {
            key: 'review',
            cmd: '/draft:review --full',
            output: [
                { text: 'Stage 1: Automated Validation  ✓ PASS', cls: 'out-success' },
                { text: 'Stage 2: Spec Compliance        ✓ PASS', cls: 'out-success' },
                { text: 'Stage 3: Code Quality           2 minor issues', cls: 'out-info' },
                { text: '→ Review complete. All critical checks passed.', cls: 'out-success' }
            ]
        },
        {
            key: 'bughunt',
            cmd: '/draft:bughunt',
            output: [
                { text: 'Scanning 14 dimensions...', cls: 'out-info' },
                { text: '  Correctness ██████████ clean', cls: 'out-success' },
                { text: '  Security    ████████░░ 1 issue (HIGH)', cls: 'out-info' },
                { text: '  Performance ██████████ clean', cls: 'out-success' },
                { text: '  Concurrency ████████░░ 1 issue (MEDIUM)', cls: 'out-info' },
                { text: '→ 2 confirmed bugs. Report: bughunt-report.md', cls: 'out-file' }
            ]
        }
    ];

    var keyIndex = {};
    commands.forEach(function(c, i) { keyIndex[c.key] = i; });

    var currentCmd = 0;
    var typeSpeed = 35;
    var pinned = false;          // true while a card holds the terminal
    var runToken = 0;            // invalidates in-flight sequences on jump

    function clearTimers() { runToken++; }

    function typeCommand(token, callback) {
        var cmd = commands[currentCmd].cmd;
        var charIndex = 0;
        cmdEl.textContent = '';
        outputEl.innerHTML = '';

        (function typeChar() {
            if (token !== runToken) return;
            if (charIndex < cmd.length) {
                cmdEl.textContent += cmd[charIndex];
                charIndex++;
                setTimeout(typeChar, typeSpeed + Math.random() * 20);
            } else if (callback) {
                callback();
            }
        })();
    }

    function showOutput(token, callback) {
        var lines = commands[currentCmd].output;
        var lineIndex = 0;

        function showLine() {
            if (token !== runToken) return;
            if (lineIndex < lines.length) {
                var span = document.createElement('span');
                span.className = 'out-line ' + lines[lineIndex].cls;
                span.textContent = lines[lineIndex].text;
                outputEl.appendChild(span);
                lineIndex++;
                setTimeout(showLine, 120);
            } else if (callback) {
                callback();
            }
        }

        setTimeout(showLine, 300);
    }

    function runSequence(autoAdvance) {
        var token = ++runToken;
        typeCommand(token, function() {
            showOutput(token, function() {
                if (autoAdvance && token === runToken && !pinned) {
                    currentCmd = (currentCmd + 1) % commands.length;
                    setTimeout(function() {
                        if (token === runToken && !pinned) runSequence(true);
                    }, 3000);
                }
            });
        });
    }

    // Public API: pin the terminal to a specific command (by key).
    window.draftTerminal = {
        show: function(key) {
            if (!(key in keyIndex)) return;
            pinned = true;
            currentCmd = keyIndex[key];
            clearTimers();
            runSequence(false);
        },
        release: function() {
            // resume auto-cycling from the command after the pinned one
            pinned = false;
            currentCmd = (currentCmd + 1) % commands.length;
            runSequence(true);
        }
    };

    // Wire primary command cards → terminal (hover + keyboard focus)
    var cards = document.querySelectorAll('.cmd-primary[data-term]');
    cards.forEach(function(card) {
        var key = card.getAttribute('data-term');
        card.addEventListener('mouseenter', function() { window.draftTerminal.show(key); });
        card.addEventListener('focusin', function() { window.draftTerminal.show(key); });
    });
    var grid = document.querySelector('.cmd-primary-grid');
    if (grid) {
        grid.addEventListener('mouseleave', function() { window.draftTerminal.release(); });
    }

    // Start auto-cycling when the section scrolls into view
    var terminalSection = document.getElementById('commands');
    if (!terminalSection) {
        runSequence(true);
        return;
    }

    var started = false;
    var observer = new IntersectionObserver(function(entries) {
        if (entries[0].isIntersecting && !started) {
            started = true;
            if (!pinned) runSequence(true);
        }
    }, { threshold: 0.3 });

    observer.observe(terminalSection);
})();
