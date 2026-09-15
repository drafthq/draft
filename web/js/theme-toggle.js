/* ============================================================
   Theme toggle — dark by default, light on request
   ============================================================
   The site ships dark. A visitor can switch to light; the
   choice persists in localStorage. Sets `data-theme` on <html>.
   ============================================================ */
(function () {
    'use strict';
    var KEY = 'draft-theme';

    function applyTheme(theme) {
        if (theme === 'light') {
            document.documentElement.removeAttribute('data-theme');
        } else {
            document.documentElement.setAttribute('data-theme', 'dark');
        }
    }

    function preferredTheme() {
        var stored = null;
        try { stored = localStorage.getItem(KEY); } catch (_) { /* no-op */ }
        return stored === 'light' ? 'light' : 'dark';
    }

    function toggle() {
        var current = document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
        var next = current === 'dark' ? 'light' : 'dark';
        applyTheme(next);
        try { localStorage.setItem(KEY, next); } catch (_) { /* no-op */ }
    }

    function injectButton() {
        if (document.querySelector('.theme-toggle')) return;
        var btn = document.createElement('button');
        btn.className = 'theme-toggle';
        btn.setAttribute('type', 'button');
        btn.setAttribute('aria-label', 'Toggle light and dark theme');
        btn.setAttribute('title', 'Toggle theme');
        btn.innerHTML =
            '<svg class="icon-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>' +
            '<svg class="icon-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="M4.93 4.93l1.41 1.41"/><path d="M17.66 17.66l1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="M4.93 19.07l1.41-1.41"/><path d="M17.66 6.34l1.41-1.41"/></svg>';
        btn.addEventListener('click', toggle);
        document.body.appendChild(btn);
    }

    applyTheme(preferredTheme());

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', injectButton);
    } else {
        injectButton();
    }
})();
