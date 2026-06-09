/* ============================================================
   DRAFT EBOOK — Page Interactivity (static page routing)
   ============================================================ */

// Chapter manifest — for keyboard navigation and sidebar search
const CHAPTERS = [
    { id: 'what-is-draft',              title: 'What is Draft?' },
    { id: 'the-problem',                title: 'The Problem' },
    { id: 'context-driven-development', title: 'Context-Driven Development' },
    { id: 'getting-started',            title: 'Getting Started' },
    { id: 'context-tiering',            title: 'Context Tiering' },
    { id: 'agent-system',               title: 'The Agent System' },
    { id: 'signal-classification',      title: 'Signal Classification' },
    { id: 'incremental-refresh',        title: 'Incremental Refresh' },
    { id: 'specs-and-plans',            title: 'Specs & Plans' },
    { id: 'implementation',             title: 'Implementation' },
    { id: 'review-pipeline',            title: 'Review Pipeline' },
    { id: 'managing-tracks',            title: 'Managing Tracks' },
    { id: 'deep-review',               title: 'Deep Review' },
    { id: 'bug-hunt',                   title: 'Bug Hunt' },
    { id: 'coverage',                   title: 'Coverage' },
    { id: 'pattern-learning',           title: 'Pattern Learning' },
    { id: 'decomposition',              title: 'Decomposition' },
    { id: 'adrs',                       title: 'Architecture Decision Records' },
    { id: 'monorepo-federation',        title: 'Monorepo Federation' },
    { id: 'jira-integration',           title: 'Jira Integration' },
    { id: 'multi-ide-support',          title: 'Multi-IDE Support' },
    { id: 'philosophy-references',      title: 'Philosophy & References' },
    { id: 'command-reference',          title: 'Command Reference' },
    { id: 'file-reference',             title: 'File Reference' },
];

// ============================================================
// INITIALIZATION
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
    initSidebar();
    initProgress();
    initSearch();
    buildPageTOC();
    initCopyButtons();
    initShareButton();
});

// ============================================================
// ON THIS PAGE (mini-TOC from headings)
// ============================================================
function buildPageTOC() {
    const tocContainer = document.getElementById('page-toc-list');
    if (!tocContainer) return;

    const headings = document.querySelectorAll('.chapter-wrapper h2, .chapter-wrapper h3');
    tocContainer.innerHTML = '';

    if (headings.length === 0) {
        const toc = document.querySelector('.page-toc');
        if (toc) toc.style.display = 'none';
        return;
    }

    const toc = document.querySelector('.page-toc');
    if (toc) toc.style.display = '';

    headings.forEach(h => {
        if (!h.id) {
            h.id = h.textContent.toLowerCase()
                .replace(/[^a-z0-9]+/g, '-')
                .replace(/^-|-$/g, '');
        }

        const item = document.createElement('a');
        item.href = '#' + h.id;
        item.className = 'page-toc-item' + (h.tagName === 'H3' ? ' page-toc-item--h3' : '');
        item.textContent = h.textContent;
        item.addEventListener('click', (e) => {
            e.preventDefault();
            h.scrollIntoView({ behavior: 'smooth', block: 'start' });
        });

        tocContainer.appendChild(item);
    });

    observeHeadings(headings);
}

function observeHeadings(headings) {
    const tocItems = document.querySelectorAll('.page-toc-item');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                tocItems.forEach(item => item.classList.remove('active'));
                const activeItem = document.querySelector(`.page-toc-item[href="#${entry.target.id}"]`);
                if (activeItem) activeItem.classList.add('active');
            }
        });
    }, { rootMargin: '-80px 0px -70% 0px', threshold: 0 });

    headings.forEach(h => observer.observe(h));
}

// ============================================================
// SIDEBAR
// ============================================================
function initSidebar() {
    const toggle = document.getElementById('sidebar-toggle');
    const backdrop = document.getElementById('sidebar-backdrop');

    if (toggle) {
        toggle.addEventListener('click', toggleMobileSidebar);
    }

    if (backdrop) {
        backdrop.addEventListener('click', closeMobileSidebar);
    }

    // Close sidebar when a chapter link is clicked (mobile)
    document.querySelectorAll('.sidebar-chapter').forEach(link => {
        link.addEventListener('click', () => {
            if (window.innerWidth <= 768) {
                closeMobileSidebar();
            }
        });
    });

    // Swipe-to-close on the sidebar
    initSidebarSwipe();
}

function toggleMobileSidebar() {
    const sidebar = document.getElementById('book-sidebar');
    const backdrop = document.getElementById('sidebar-backdrop');
    if (!sidebar || !backdrop) return;
    const isOpen = sidebar.classList.toggle('open');

    backdrop.classList.toggle('visible', isOpen);
    document.body.style.overflow = isOpen ? 'hidden' : '';
}

function closeMobileSidebar() {
    const sidebar = document.getElementById('book-sidebar');
    const backdrop = document.getElementById('sidebar-backdrop');

    if (sidebar) sidebar.classList.remove('open');
    if (backdrop) backdrop.classList.remove('visible');
    document.body.style.overflow = '';
}

function initSidebarSwipe() {
    const sidebar = document.getElementById('book-sidebar');
    if (!sidebar) return;

    let startX = 0;
    sidebar.addEventListener('touchstart', (e) => {
        startX = e.touches[0].clientX;
    }, { passive: true });

    sidebar.addEventListener('touchend', (e) => {
        const dx = e.changedTouches[0].clientX - startX;
        if (dx < -60) closeMobileSidebar(); // swipe left to close
    }, { passive: true });
}

// ============================================================
// READING PROGRESS
// ============================================================
function initProgress() {
    const bar = document.getElementById('reading-progress');
    if (!bar) return;

    window.addEventListener('scroll', () => {
        const winH = window.innerHeight;
        const docH = document.documentElement.scrollHeight;
        const scrolled = window.scrollY;
        const pct = Math.min(100, (scrolled / (docH - winH)) * 100);
        bar.style.width = pct + '%';
    }, { passive: true });
}

// ============================================================
// SIDEBAR SEARCH
// ============================================================
function initSearch() {
    const input = document.getElementById('sidebar-search-input');
    if (!input) return;

    input.addEventListener('input', () => {
        const query = input.value.toLowerCase().trim();
        document.querySelectorAll('.sidebar-chapter').forEach(el => {
            const text = el.textContent.toLowerCase();
            el.style.display = query === '' || text.includes(query) ? '' : 'none';
        });

        document.querySelectorAll('.sidebar-part').forEach(part => {
            const visibleChapters = part.querySelectorAll('.sidebar-chapter:not([style*="display: none"])');
            part.style.display = visibleChapters.length === 0 && query !== '' ? 'none' : '';
        });
    });
}

// ============================================================
// COPY TO CLIPBOARD
// ============================================================
function copyText(text) {
    // Clipboard API requires secure context (HTTPS/localhost)
    if (navigator.clipboard && window.isSecureContext) {
        return navigator.clipboard.writeText(text);
    }
    // Fallback for HTTP contexts
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) { /* ignore */ }
    document.body.removeChild(ta);
    return Promise.resolve();
}

function initCopyButtons() {
    const COPY_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
    const CHECK_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';

    document.querySelectorAll('.chapter-wrapper pre').forEach(pre => {
        const btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.title = 'Copy';
        btn.innerHTML = COPY_ICON;
        btn.addEventListener('click', () => {
            const code = pre.querySelector('code');
            const text = (code || pre).textContent.replace(/^\$ /gm, '');
            copyText(text).then(() => {
                btn.innerHTML = CHECK_ICON;
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.innerHTML = COPY_ICON;
                    btn.classList.remove('copied');
                }, 1500);
            });
        });
        pre.appendChild(btn);
    });
}

// ============================================================
// KEYBOARD NAVIGATION
// ============================================================
document.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT') return;

    const currentId = document.body.dataset.chapter;
    if (!currentId) return;

    const idx = CHAPTERS.findIndex(c => c.id === currentId);
    if (idx === -1) return;

    if (e.key === 'ArrowLeft' && idx > 0) {
        location.href = '../' + CHAPTERS[idx - 1].id + '/';
    } else if (e.key === 'ArrowRight' && idx < CHAPTERS.length - 1) {
        location.href = '../' + CHAPTERS[idx + 1].id + '/';
    }
});
// ============================================================
// SHARE BUTTON (chapter pages)
// ============================================================
function initShareButton() {
    const topbarRight = document.querySelector('.book-topbar-right');
    if (!topbarRight) return;

    // Read OG meta tags set on each chapter page
    const ogUrl = document.querySelector('meta[property="og:url"]');
    const ogTitle = document.querySelector('meta[property="og:title"]');
    if (!ogUrl) return;

    const pageUrl = ogUrl.content;
    const pageTitle = ogTitle ? ogTitle.content : document.title;

    // Create share wrapper
    const wrapper = document.createElement('div');
    wrapper.className = 'topbar-share';
    wrapper.innerHTML = `
        <button class="topbar-share-toggle" aria-label="Share this chapter" title="Share">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>
            Share
        </button>
        <div class="share-dropdown">
            <button class="share-option" data-platform="linkedin">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
                LinkedIn
            </button>
            <button class="share-option" data-platform="x">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
                X / Twitter
            </button>
            <div class="share-divider"></div>
            <button class="share-option" data-platform="copy">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
                Copy link
            </button>
        </div>
    `;

    topbarRight.appendChild(wrapper);

    // Toggle dropdown
    const toggle = wrapper.querySelector('.topbar-share-toggle');
    const dropdown = wrapper.querySelector('.share-dropdown');

    toggle.addEventListener('click', (e) => {
        e.stopPropagation();
        dropdown.classList.toggle('open');
    });

    // Close on outside click
    document.addEventListener('click', () => dropdown.classList.remove('open'));
    dropdown.addEventListener('click', (e) => e.stopPropagation());

    // Share handlers
    wrapper.querySelectorAll('.share-option').forEach(btn => {
        btn.addEventListener('click', () => {
            const platform = btn.dataset.platform;
            const url = encodeURIComponent(pageUrl);
            const text = encodeURIComponent(pageTitle);

            if (platform === 'linkedin') {
                window.open(`https://www.linkedin.com/sharing/share-offsite/?url=${url}`, '_blank', 'width=600,height=500');
            } else if (platform === 'x') {
                window.open(`https://x.com/intent/tweet?url=${url}&text=${text}`, '_blank', 'width=600,height=400');
            } else if (platform === 'copy') {
                copyText(pageUrl).then(() => {
                    btn.querySelector('svg').style.display = 'none';
                    const original = btn.textContent;
                    btn.textContent = 'Copied!';
                    btn.classList.add('copied');
                    setTimeout(() => {
                        btn.classList.remove('copied');
                        btn.innerHTML = `
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
                            Copy link
                        `;
                    }, 1500);
                });
            }
            dropdown.classList.remove('open');
        });
    });
}

// ============================================================
// AUDIO PLAYER INJECTION (NotebookLM Edition)
// ============================================================
function initAudioSupport() {
    if (window.draftAudio) return;

    const isChapter = !!document.body.dataset.chapter;
    const isAudioPage = document.body.classList.contains('audio-player-page');
    const base = (isChapter || isAudioPage) ? '../' : './';
    
    // Inject Styles once
    if (!document.querySelector(`link[href*="audio-player.css"]`)) {
        const link = document.createElement('link');
        link.rel = 'stylesheet'; link.href = base + 'css/audio-player.css';
        document.head.appendChild(link);
    }

    // Inject Script once
    if (!document.querySelector(`script[src*="audio-player.js"]`)) {
        const script = document.createElement('script');
        script.src = base + 'js/audio-player.js';
        script.defer = true;
        document.head.appendChild(script);
    }

    // Store chapters in localStorage for the audio player page
    localStorage.setItem('draft-chapters', JSON.stringify(CHAPTERS));

    // Add Listen Button to Chapters
    if (isChapter) {
        const wrapper = document.querySelector('.chapter-wrapper');
        const meta = wrapper.querySelector('.chapter-meta');
        if (meta) {
            const btn = document.createElement('button');
            btn.className = 'btn-listen-chapter';
            btn.innerHTML = `
                <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 1a2 2 0 0 1 2 2v10a2 2 0 0 1-4 0V3a2 2 0 0 1 2-2z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg>
                Listen to Audiobook
            `;
            meta.parentNode.insertBefore(btn, meta.nextSibling);
        }
    }
}
