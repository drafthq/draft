/* ============================================================
   ANIMATIONS — scroll reveals, card spotlight
   ============================================================ */

(function () {
    'use strict';

    var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    /* ---- Auto-assign reveal classes ------------------------- */
    document.querySelectorAll('.section-inner').forEach(function (inner) {
        ['.section-label', 'h2', '.section-subtitle'].forEach(function (sel) {
            var node = inner.querySelector(sel);
            if (node) node.classList.add('reveal');
        });

        inner.querySelectorAll(
            '.problem-grid, .bento-grid, .commands-grid, .init-phases, .team-flow, ' +
            '.pricing-comparison, .cmd-primary-grid, .dual-output'
        ).forEach(function (grid) { grid.classList.add('reveal-stagger'); });

        inner.querySelectorAll(
            '.comparison, .callout, .industry-table-wrap, .vs-table-wrap, .roles, ' +
            '.routing-block, .cmd-routed, .init-state, .faq-list, .proof, .install-tabs, .install-panels'
        ).forEach(function (node) { node.classList.add('reveal'); });

        inner.querySelectorAll('.terminal, .playground').forEach(function (node) {
            node.classList.add('reveal-scale');
        });
    });

    /* ---- Observe ------------------------------------------- */
    var targets = document.querySelectorAll('.reveal, .reveal-left, .reveal-right, .reveal-scale, .reveal-stagger');

    if (reduceMotion || !('IntersectionObserver' in window)) {
        targets.forEach(function (node) { node.classList.add('visible'); });
    } else {
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    entry.target.classList.add('visible');
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.08, rootMargin: '0px 0px -40px 0px' });

        targets.forEach(function (node) { observer.observe(node); });
    }

    /* ---- Spotlight: cursor-tracked highlight on bento cards - */
    if (window.matchMedia('(hover: hover)').matches) {
        document.querySelectorAll('.bento-card').forEach(function (card) {
            card.addEventListener('mousemove', function (e) {
                var rect = card.getBoundingClientRect();
                card.style.setProperty('--mx', (e.clientX - rect.left) + 'px');
                card.style.setProperty('--my', (e.clientY - rect.top) + 'px');
            });
        });
    }
})();
