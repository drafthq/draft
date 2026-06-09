/* ============================================================
   MAIN — Init, nav state, scroll spy, install tabs, mobile menu
   ============================================================ */

(function() {
    // ============================================================
    // CURSOR GLOW ORB
    // ============================================================
    var orb = document.getElementById('cursor-glow');
    if (orb && window.matchMedia('(hover: hover)').matches) {
        var orbX = 0, orbY = 0, targetX = 0, targetY = 0;

        document.addEventListener('mousemove', function(e) {
            targetX = e.clientX;
            targetY = e.clientY;
        });

        var orbRaf;
        function updateOrb() {
            orbX += (targetX - orbX) * 0.08;
            orbY += (targetY - orbY) * 0.08;
            orb.style.left = orbX + 'px';
            orb.style.top = orbY + 'px';
            orbRaf = requestAnimationFrame(updateOrb);
        }
        document.addEventListener('visibilitychange', function() {
            if (document.hidden) {
                cancelAnimationFrame(orbRaf);
            } else {
                orbRaf = requestAnimationFrame(updateOrb);
            }
        });
        updateOrb();
    } else if (orb) {
        orb.style.display = 'none';
    }

    // ============================================================
    // TOP NAV SCROLL EFFECT
    // ============================================================
    var topNav = document.getElementById('top-nav');
    var scrollThreshold = 80;

    if (topNav) {
        function updateNavScroll() {
            if (window.scrollY > scrollThreshold) {
                topNav.classList.add('scrolled');
            } else {
                topNav.classList.remove('scrolled');
            }
        }

        window.addEventListener('scroll', updateNavScroll, { passive: true });
        updateNavScroll();
    }

    // ============================================================
    // MOBILE NAV TOGGLE
    // ============================================================
    var navToggle = document.getElementById('nav-toggle');
    if (navToggle && topNav) {
        navToggle.addEventListener('click', function() {
            topNav.classList.toggle('open');
        });

        // Close on any link click inside the mobile dropdown
        topNav.querySelectorAll('.nav-links a, .nav-actions a').forEach(function(link) {
            link.addEventListener('click', function() {
                topNav.classList.remove('open');
            });
        });

        // Close mobile menu when clicking outside
        document.addEventListener('click', function(e) {
            if (topNav.classList.contains('open') && !topNav.contains(e.target)) {
                topNav.classList.remove('open');
            }
        });
    }

    // ============================================================
    // SCROLL SPY — Update side nav dots
    // ============================================================
    var sections = document.querySelectorAll('.section[id]');
    var sideDots = document.querySelectorAll('.side-dot');

    if (sections.length > 0 && sideDots.length > 0) {
        var scrollSpy = new IntersectionObserver(function(entries) {
            entries.forEach(function(entry) {
                if (entry.isIntersecting) {
                    var id = entry.target.id;
                    sideDots.forEach(function(dot) {
                        dot.classList.toggle('active', dot.getAttribute('href') === '#' + id);
                    });
                }
            });
        }, {
            threshold: 0.3,
            rootMargin: '-20% 0px -20% 0px'
        });

        sections.forEach(function(section) {
            scrollSpy.observe(section);
        });
    }

    // Smooth scroll for side nav and anchor links
    document.querySelectorAll('a[href^="#"]').forEach(function(link) {
        link.addEventListener('click', function(e) {
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

    // ============================================================
    // INSTALL TABS
    // ============================================================
    var installTabs = document.querySelectorAll('.install-tab');
    var installPanels = document.querySelectorAll('.install-panel');

    installTabs.forEach(function(tab) {
        tab.addEventListener('click', function() {
            var target = this.getAttribute('data-target');

            installTabs.forEach(function(t) { t.classList.remove('active'); });
            this.classList.add('active');

            installPanels.forEach(function(panel) {
                panel.classList.toggle('active', panel.id === 'panel-' + target);
            });
        });
    });

    // ============================================================
    // HANDLE URL HASH ON LOAD
    // ============================================================
    if (window.location.hash) {
        var hashTarget = document.getElementById(window.location.hash.slice(1));
        if (hashTarget) {
            setTimeout(function() {
                hashTarget.scrollIntoView({ behavior: 'smooth' });
            }, 100);
        }
    }
})();
