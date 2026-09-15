/* ============================================================
   MAIN — nav state, scroll spy, tabs, copy, star count
   ============================================================ */

(function () {
    'use strict';

    /* ---- Cursor glow orb ------------------------------------ */
    var orb = document.getElementById('cursor-glow');
    if (orb && window.matchMedia('(hover: hover)').matches) {
        var orbX = 0, orbY = 0, targetX = 0, targetY = 0, orbRaf;
        document.addEventListener('mousemove', function (e) { targetX = e.clientX; targetY = e.clientY; });
        var updateOrb = function () {
            orbX += (targetX - orbX) * 0.08;
            orbY += (targetY - orbY) * 0.08;
            orb.style.left = orbX + 'px';
            orb.style.top = orbY + 'px';
            orbRaf = requestAnimationFrame(updateOrb);
        };
        document.addEventListener('visibilitychange', function () {
            if (document.hidden) cancelAnimationFrame(orbRaf); else orbRaf = requestAnimationFrame(updateOrb);
        });
        updateOrb();
    } else if (orb) {
        orb.style.display = 'none';
    }

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
        topNav.querySelectorAll('.nav-links a, .nav-actions a').forEach(function (link) {
            link.addEventListener('click', function () { topNav.classList.remove('open'); });
        });
        document.addEventListener('click', function (e) {
            if (topNav.classList.contains('open') && !topNav.contains(e.target)) topNav.classList.remove('open');
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

    /* ---- Install tabs --------------------------------------- */
    var installTabs = document.querySelectorAll('.install-tab');
    var installPanels = document.querySelectorAll('.install-panel');
    installTabs.forEach(function (tab) {
        tab.addEventListener('click', function () {
            var target = this.getAttribute('data-target');
            installTabs.forEach(function (t) { t.classList.remove('active'); t.setAttribute('aria-selected', 'false'); });
            this.classList.add('active');
            this.setAttribute('aria-selected', 'true');
            installPanels.forEach(function (panel) { panel.classList.toggle('active', panel.id === 'panel-' + target); });
        });
    });

    /* ---- Role switcher -------------------------------------- */
    var roleTabs = Array.prototype.slice.call(document.querySelectorAll('.role-tab'));
    var rolePanels = document.querySelectorAll('.role-panel');
    function selectRole(tab) {
        var target = tab.getAttribute('data-role');
        roleTabs.forEach(function (t) {
            var on = t === tab;
            t.setAttribute('aria-selected', on ? 'true' : 'false');
            t.setAttribute('tabindex', on ? '0' : '-1');
        });
        rolePanels.forEach(function (panel) { panel.classList.toggle('active', panel.id === 'role-' + target); });
    }
    roleTabs.forEach(function (tab, i) {
        tab.addEventListener('click', function () { selectRole(tab); });
        tab.addEventListener('keydown', function (e) {
            var next = e.key === 'ArrowRight' ? i + 1 : e.key === 'ArrowLeft' ? i - 1 : null;
            if (next === null) return;
            e.preventDefault();
            var t = roleTabs[(next + roleTabs.length) % roleTabs.length];
            selectRole(t);
            t.focus();
        });
    });

    /* ---- Copy buttons --------------------------------------- */
    document.querySelectorAll('[data-copy]').forEach(function (btn) {
        var label = btn.querySelector('span');
        var idle = label ? label.textContent : '';
        btn.addEventListener('click', function () {
            var text = btn.getAttribute('data-copy');
            var done = function () {
                btn.classList.add('copied');
                if (label) label.textContent = 'Copied';
                setTimeout(function () { btn.classList.remove('copied'); if (label) label.textContent = idle; }, 1600);
            };
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(done, function () {});
            } else {
                var ta = document.createElement('textarea');
                ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
                document.body.appendChild(ta); ta.select();
                try { document.execCommand('copy'); done(); } catch (_) { /* no-op */ }
                document.body.removeChild(ta);
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
