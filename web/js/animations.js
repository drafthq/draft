/* ============================================================
   ANIMATIONS — IntersectionObserver, parallax tilt
   ============================================================ */

(function() {
    // ============================================================
    // SCROLL REVEAL
    // ============================================================
    var revealElements = document.querySelectorAll(
        '.reveal, .reveal-left, .reveal-right, .reveal-scale, .reveal-stagger, .pipeline'
    );

    var revealObserver = new IntersectionObserver(function(entries) {
        entries.forEach(function(entry) {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    if (revealElements.length > 0) {
        revealElements.forEach(function(el) {
            revealObserver.observe(el);
        });
    }

    // ============================================================
    // AUTO-ADD REVEAL CLASSES
    // ============================================================
    // Add reveal classes to section elements
    document.querySelectorAll('.section-inner').forEach(function(inner) {
        // Section label, h2, subtitle
        var label = inner.querySelector('.section-label');
        var h2 = inner.querySelector('h2');
        var subtitle = inner.querySelector('.section-subtitle');

        if (label) label.classList.add('reveal');
        if (h2) h2.classList.add('reveal');
        if (subtitle) subtitle.classList.add('reveal');

        // Grids get staggered reveal
        inner.querySelectorAll('.problem-grid, .bento-grid, .commands-grid, .arch-grid, .audience-grid, .team-flow, .pricing-comparison').forEach(function(grid) {
            grid.classList.add('reveal-stagger');
        });

        // Comparisons and callouts
        inner.querySelectorAll('.comparison, .callout, .dual-output, .industry-table-wrap').forEach(function(el) {
            el.classList.add('reveal');
        });

        // Terminal
        inner.querySelectorAll('.terminal').forEach(function(el) {
            el.classList.add('reveal-scale');
        });
    });

    // Re-observe the newly classed elements (reuse the single observer)
    if (revealObserver) {
        document.querySelectorAll(
            '.reveal, .reveal-left, .reveal-right, .reveal-scale, .reveal-stagger, .pipeline'
        ).forEach(function(el) {
            if (!el.classList.contains('visible')) {
                revealObserver.observe(el);
            }
        });
    }

    // ============================================================
    // PARALLAX TILT ON BENTO CARDS
    // ============================================================
    if (window.matchMedia('(hover: hover)').matches) {
        document.querySelectorAll('.bento-card').forEach(function(card) {
            card.addEventListener('mousemove', function(e) {
                var rect = card.getBoundingClientRect();
                var x = e.clientX - rect.left;
                var y = e.clientY - rect.top;
                var centerX = rect.width / 2;
                var centerY = rect.height / 2;
                var rotateX = ((y - centerY) / centerY) * -3;
                var rotateY = ((x - centerX) / centerX) * 3;

                card.style.transform = 'perspective(800px) rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg) translateY(-3px)';
            });

            card.addEventListener('mouseleave', function() {
                card.style.transform = '';
            });
        });
    }

    // Video player removed — videos section replaced with audience cards
})();
