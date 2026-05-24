/* ============================================================
   TERMINAL — Typewriter effect cycling through commands
   ============================================================ */

(function() {
    var cmdEl = document.getElementById('terminal-cmd');
    var outputEl = document.getElementById('terminal-output');
    var cursorEl = document.querySelector('.terminal-cursor');
    if (!cmdEl || !outputEl) return;

    var commands = [
        {
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
            cmd: '/draft:plan "Add user authentication"',
            output: [
                { text: 'Starting collaborative intake...', cls: 'out-info' },
                { text: 'Loading context: .ai-context.md, tech-stack.md', cls: 'out-info' },
                { text: '? What authentication method? (OAuth, JWT, session...)', cls: 'out-info' },
                { text: '→ Created spec-draft.md with 4 sections', cls: 'out-success' },
                { text: '→ Created plan-draft.md with 3 phases, 12 tasks', cls: 'out-success' }
            ]
        },
        {
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
            cmd: '/draft:bughunt',
            output: [
                { text: 'Scanning 14 dimensions...', cls: 'out-info' },
                { text: '  Correctness ██████████ clean', cls: 'out-success' },
                { text: '  Security    ████████░░ 1 issue (HIGH)', cls: 'out-info' },
                { text: '  Performance ██████████ clean', cls: 'out-success' },
                { text: '  Concurrency ████████░░ 1 issue (MEDIUM)', cls: 'out-info' },
                { text: '→ 2 confirmed bugs. Report: bughunt-report.md', cls: 'out-file' }
            ]
        },
        {
            cmd: '/draft:review --full',
            output: [
                { text: 'Stage 1: Automated Validation  ✓ PASS', cls: 'out-success' },
                { text: 'Stage 2: Spec Compliance        ✓ PASS', cls: 'out-success' },
                { text: 'Stage 3: Code Quality           2 minor issues', cls: 'out-info' },
                { text: '→ Review complete. All critical checks passed.', cls: 'out-success' }
            ]
        }
    ];

    var currentCmd = 0;
    var charIndex = 0;
    var isTyping = false;
    var typeSpeed = 35;

    function typeCommand(callback) {
        isTyping = true;
        var cmd = commands[currentCmd].cmd;
        charIndex = 0;
        cmdEl.textContent = '';
        outputEl.innerHTML = '';

        function typeChar() {
            if (charIndex < cmd.length) {
                cmdEl.textContent += cmd[charIndex];
                charIndex++;
                setTimeout(typeChar, typeSpeed + Math.random() * 20);
            } else {
                isTyping = false;
                if (callback) callback();
            }
        }

        typeChar();
    }

    function showOutput(callback) {
        var lines = commands[currentCmd].output;
        var lineIndex = 0;

        function showLine() {
            if (lineIndex < lines.length) {
                var span = document.createElement('span');
                span.className = 'out-line ' + lines[lineIndex].cls;
                span.textContent = lines[lineIndex].text;
                outputEl.appendChild(span);
                lineIndex++;
                setTimeout(showLine, 120);
            } else {
                if (callback) callback();
            }
        }

        setTimeout(showLine, 300);
    }

    function nextSequence() {
        typeCommand(function() {
            showOutput(function() {
                currentCmd = (currentCmd + 1) % commands.length;
                setTimeout(nextSequence, 3000);
            });
        });
    }

    // Start when terminal is visible
    var terminalSection = document.getElementById('commands');
    if (!terminalSection) {
        nextSequence();
        return;
    }

    var started = false;
    var observer = new IntersectionObserver(function(entries) {
        if (entries[0].isIntersecting && !started) {
            started = true;
            nextSequence();
        }
    }, { threshold: 0.3 });

    observer.observe(terminalSection);
})();
