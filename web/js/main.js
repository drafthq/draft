/* ============================================================
   MAIN — nav state, scroll spy, tabs, copy, star count
   ============================================================ */

(function () {
    'use strict';

    /* ---- Top nav: scrolled state ---------------------------- */
    var topNav = document.getElementById('top-nav');
    if (topNav) {
        var updateNavScroll = function () {
            topNav.classList.toggle('scrolled', window.scrollY > 24);
        };
        window.addEventListener('scroll', updateNavScroll, { passive: true });
        updateNavScroll();
    }

    /* ---- Mobile nav toggle ---------------------------------- */
    var navToggle = document.getElementById('nav-toggle');
    if (navToggle && topNav) {
        navToggle.addEventListener('click', function () {
            var open = topNav.classList.toggle('open');
            navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
        });
        var closeNav = function () {
            topNav.classList.remove('open');
            navToggle.setAttribute('aria-expanded', 'false');
        };
        topNav.querySelectorAll('.nav-links a, .nav-actions a').forEach(function (link) {
            link.addEventListener('click', closeNav);
        });
        document.addEventListener('click', function (e) {
            if (topNav.classList.contains('open') && !topNav.contains(e.target)) closeNav();
        });
    }

    /* ---- Scroll spy: side ticks + nav links ----------------- */
    var sections = document.querySelectorAll('.section[id]');
    var sideDots = document.querySelectorAll('.side-dot');
    var navLinks = document.querySelectorAll('.nav-links a[href^="#"]');

    if (sections.length > 0 && 'IntersectionObserver' in window) {
        var spy = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                var id = '#' + entry.target.id;
                sideDots.forEach(function (dot) { dot.classList.toggle('active', dot.getAttribute('href') === id); });
                navLinks.forEach(function (a) { a.classList.toggle('active', a.getAttribute('href') === id); });
            });
        }, { threshold: 0, rootMargin: '-20% 0px -50% 0px' });
        sections.forEach(function (section) { spy.observe(section); });
    }

    /* ---- Smooth anchors ------------------------------------- */
    document.querySelectorAll('a[href^="#"]').forEach(function (link) {
        link.addEventListener('click', function (e) {
            var targetId = this.getAttribute('href');
            if (targetId === '#') return;
            var target = document.querySelector(targetId);
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                history.replaceState(null, '', targetId);
            }
        });
    });

    /* ---- Tab groups (ARIA tabs: roving focus, arrow keys) --- */
    function tabGroup(tabs, panelIdOf, activeClass) {
        if (!tabs.length) return;
        function select(tab) {
            tabs.forEach(function (t) {
                var on = t === tab;
                t.setAttribute('aria-selected', on ? 'true' : 'false');
                t.setAttribute('tabindex', on ? '0' : '-1');
                if (activeClass) t.classList.toggle(activeClass, on);
                var panel = document.getElementById(panelIdOf(t));
                if (panel) panel.classList.toggle('active', on);
            });
        }
        tabs.forEach(function (tab, i) {
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
    }
    tabGroup(Array.prototype.slice.call(document.querySelectorAll('.install-tab')),
        function (t) { return 'panel-' + t.getAttribute('data-target'); }, 'active');
    tabGroup(Array.prototype.slice.call(document.querySelectorAll('.role-tab')),
        function (t) { return 'role-' + t.getAttribute('data-role'); }, null);

    /* ---- Copy buttons --------------------------------------- */
    document.querySelectorAll('[data-copy]').forEach(function (btn) {
        var label = btn.querySelector('span');
        var idle = label ? label.textContent : '';
        var settle = function (text, cls) {
            btn.classList.add(cls);
            if (label) label.textContent = text;
            setTimeout(function () { btn.classList.remove(cls); if (label) label.textContent = idle; }, 1600);
        };
        var done = function () { settle('Copied', 'copied'); };
        var legacy = function () {
            var ta = document.createElement('textarea');
            ta.value = btn.getAttribute('data-copy');
            ta.setAttribute('readonly', '');
            ta.style.position = 'fixed';
            ta.style.opacity = '0';
            document.body.appendChild(ta);
            ta.select();
            var ok = false;
            try { ok = document.execCommand('copy'); } catch (_) { ok = false; }
            document.body.removeChild(ta);
            if (ok) done(); else settle('Copy failed', 'failed');
        };
        btn.addEventListener('click', function () {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(btn.getAttribute('data-copy')).then(done, legacy);
            } else {
                legacy();
            }
        });
    });

    /* ---- GitHub star count (best effort, cached 1h) --------- */
    var starEl = document.getElementById('gh-stars');
    if (starEl && window.fetch) {
        var KEY = 'draft-gh-stars', cached = null;
        try { cached = JSON.parse(sessionStorage.getItem(KEY) || 'null'); } catch (_) { /* no-op */ }
        var show = function (n) {
            starEl.textContent = n >= 1000 ? (n / 1000).toFixed(1).replace(/\.0$/, '') + 'k' : String(n);
        };
        if (cached && Date.now() - cached.t < 3600000) {
            show(cached.n);
        } else {
            fetch('https://api.github.com/repos/drafthq/draft', { headers: { Accept: 'application/vnd.github+json' } })
                .then(function (r) { return r.ok ? r.json() : null; })
                .then(function (data) {
                    if (!data || typeof data.stargazers_count !== 'number') return;
                    show(data.stargazers_count);
                    try { sessionStorage.setItem(KEY, JSON.stringify({ n: data.stargazers_count, t: Date.now() })); } catch (_) { /* no-op */ }
                })
                .catch(function () {});
        }
    }

    /* ---- Hash on load --------------------------------------- */
    if (window.location.hash) {
        var hashTarget = document.getElementById(window.location.hash.slice(1));
        if (hashTarget) setTimeout(function () { hashTarget.scrollIntoView({ behavior: 'smooth' }); }, 100);
    }
})();
