#!/usr/bin/env bash
# ============================================================
# build-book.sh — Generate static HTML pages for each book chapter
# Source: web/book/chapters/*.html (fragments)
# Output: web/book/<chapter-id>/index.html (full pages)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOK_DIR="$ROOT/web/book"
CHAPTERS_DIR="$BOOK_DIR/chapters"
SITEMAP_FILE="$ROOT/web/sitemap.xml"
TODAY="$(date +%Y-%m-%d)"

# ============================================================
# CHAPTER MANIFEST — parallel arrays (order matters)
# ============================================================
CHAPTER_IDS=(
    "what-is-draft"
    "the-problem"
    "context-driven-development"
    "getting-started"
    "specs-and-plans"
    "implementation"
    "review-pipeline"
    "managing-tracks"
    "decomposition"
    "adrs"
    "context-tiering"
    "agent-system"
    "signal-classification"
    "incremental-refresh"
    "deep-review"
    "bug-hunt"
    "coverage"
    "pattern-learning"
    "monorepo-federation"
    "jira-integration"
    "multi-ide-support"
    "philosophy-references"
    "command-reference"
    "file-reference"
)

CHAPTER_FILES=(
    "00-what-is-draft.html"
    "01-the-problem.html"
    "02-context-driven-development.html"
    "03-getting-started.html"
    "04-specs-and-plans.html"
    "05-implementation.html"
    "06-review-pipeline.html"
    "07-managing-tracks.html"
    "08-decomposition.html"
    "09-adrs.html"
    "10-context-tiering.html"
    "11-agent-system.html"
    "12-signal-classification.html"
    "13-incremental-refresh.html"
    "14-deep-review.html"
    "15-bug-hunt.html"
    "16-coverage.html"
    "17-pattern-learning.html"
    "18-monorepo-federation.html"
    "19-jira-integration.html"
    "20-multi-ide-support.html"
    "21-philosophy-references.html"
    "appendix-a-command-reference.html"
    "appendix-b-file-reference.html"
)

CHAPTER_TITLES=(
    "What is Draft?"
    "The Problem"
    "Context-Driven Development"
    "Getting Started"
    "Specs &amp; Plans"
    "Implementation"
    "Review Pipeline"
    "Managing Tracks"
    "Decomposition"
    "Architecture Decision Records"
    "Context Tiering"
    "The Agent System"
    "Signal Classification"
    "Incremental Refresh"
    "Deep Review"
    "Bug Hunt"
    "Coverage"
    "Pattern Learning"
    "Monorepo Federation"
    "Jira Integration"
    "Multi-IDE Support"
    "Philosophy &amp; References"
    "Command Reference"
    "File Reference"
)

CHAPTER_NUMS=("0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "A" "B")

CHAPTER_DESCRIPTIONS=(
    "What Draft is, what it is not, who it is for, and what you get — 33 commands and 7 specialized agents for structured AI development."
    "Why AI coding assistants produce wrong code without structure — the gap between speed and correctness, and why better prompting is not the answer."
    "The Context-Driven Development methodology — every decision grounded in explicit, versioned, reviewable documents rather than implicit assumptions."
    "Install Draft and run your first commands in five minutes. Set up architecture discovery, create a track, and start implementing."
    "Collaborative spec intake and phased plan generation — requirements to specification to implementation plan, reviewed before code exists."
    "Task-by-task implementation with TDD enforcement — RED, GREEN, REFACTOR cycles with architecture checkpoints and production robustness patterns."
    "Three-stage code review pipeline — automated validation, spec compliance checking, and code quality analysis with STRIDE threat modeling."
    "Track lifecycle management — status markers, parallel tracks, blocked state handling, and git-aware rollback."
    "Breaking large features into independently shippable sub-tasks — tree decomposition with dependency ordering and blast radius scoping."
    "Architecture Decision Records — structured decision capture with context, rationale, consequences, and lifecycle management."
    "How Draft organizes project context into three tiers — always-loaded profiles, working memory, and deep storage — like CPU memory hierarchy."
    "Seven specialized agents — Architect, Debugger, Ops, Planner, RCA, Reviewer, and Writer — each with behavioral protocols tuned for their domain."
    "How Draft classifies source files into 11 signal categories to determine which architecture sections get deep treatment, brief mention, or skip."
    "How Draft detects changes and updates only what has drifted — freshness hashing, signal drift detection, and targeted regeneration."
    "Production-grade deep review with ACID compliance audits — atomicity, isolation, durability, idempotency, resilience, and observability checks."
    "14-dimension bug hunting sweep — from null safety to concurrency, security to algorithmic complexity. Only HIGH/CONFIRMED confidence reported."
    "Spec-to-implementation coverage analysis — gap identification, untested paths, and target enforcement at 95%+ coverage."
    "How Draft detects codebase patterns, records them to guardrails, and applies learned conventions to future work."
    "Context federation across monorepo services — per-service draft directories with shared root context and service aggregation."
    "Mapping Draft tracks to Jira issues — preview before creation, epic/story/sub-task mapping, and bidirectional sync."
    "How Draft works across Claude Code, Copilot, Cursor, Gemini, and Antigravity IDE — platform-specific syntax transforms."
    "The philosophical foundations of Context-Driven Development — structured development, quality gates, incremental refinement."
    "Complete reference for all 33 Draft commands — usage, options, examples, and output for each slash command."
    "Complete reference for all Draft-generated files — architecture.md, .ai-context.md, .ai-profile.md, specs, plans, and state files."
)

# Per-chapter SEO keywords
CHAPTER_KEYWORDS=(
    "what is draft, ai coding plugin, context-driven development, claude code plugin, ai development methodology"
    "ai coding problems, ai assistant wrong code, ai code quality, prompt engineering limits, ai development challenges"
    "context-driven development, CDD methodology, spec-driven development, ai structured development, development methodology"
    "install draft, draft getting started, claude code setup, draft tutorial, ai plugin installation"
    "spec driven development, software specifications, phased planning, requirements to code, ai planning"
    "tdd enforcement, test-driven development, red green refactor, ai implementation, production robustness"
    "code review pipeline, automated validation, spec compliance, STRIDE threat modeling, code quality analysis"
    "track management, feature tracking, parallel development, git rollback, status management"
    "task decomposition, feature breakdown, dependency ordering, blast radius, sub-task management"
    "architecture decision records, ADR, decision capture, technical decisions, architecture documentation"
    "context tiering, ai context management, token optimization, ai memory hierarchy, context window management"
    "ai agent system, specialized ai agents, architect agent, debugger agent, ai code reviewer agent"
    "signal classification, codebase analysis, file categorization, architecture discovery, adaptive analysis"
    "incremental refresh, freshness tracking, signal drift detection, targeted regeneration, change detection"
    "deep code review, ACID compliance, production audit, idempotency check, resilience testing"
    "bug hunting, 14-dimension sweep, concurrency bugs, security vulnerabilities, algorithmic complexity"
    "test coverage analysis, spec coverage, gap identification, coverage enforcement, untested paths"
    "pattern learning, codebase conventions, guardrails, convention detection, pattern recognition"
    "monorepo federation, multi-service context, service aggregation, monorepo management, shared context"
    "jira integration, draft to jira, ticket creation, epic mapping, project management integration"
    "multi-ide support, claude code, github copilot, cursor ai, gemini ai, antigravity ide"
    "software development philosophy, quality gates, incremental refinement, development principles"
    "draft commands, slash commands, command reference, draft cli, command documentation"
    "draft file reference, architecture.md, ai-context.md, ai-profile.md, draft directory structure"
)

CHAPTER_PRIORITIES=(
    "0.8" "0.7" "0.7" "0.8" "0.7" "0.7" "0.7" "0.6"
    "0.6" "0.6" "0.6" "0.6" "0.6" "0.6" "0.7" "0.7"
    "0.6" "0.6" "0.6" "0.6" "0.6" "0.5" "0.8" "0.7"
)

NUM_CHAPTERS=${#CHAPTER_IDS[@]}

# ============================================================
# SIDEBAR GENERATOR
# ============================================================
generate_sidebar() {
    local current_id="$1"
    local prefix="$2" # "./" for landing page, "../" for chapter pages

    local sidebar=""
    sidebar+=' <aside class="book-sidebar" id="book-sidebar">'$'\n'
    sidebar+=' <div class="sidebar-search">'$'\n'
    sidebar+=' <svg class="sidebar-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>'$'\n'
    sidebar+=' <input type="text" id="sidebar-search-input" placeholder="Search chapters..." autocomplete="off">'$'\n'
    sidebar+=' </div>'$'\n'

    # Part definitions: name|start_idx|end_idx
    local parts=(
        "Introduction|0|0"
        "I. Foundation|1|3"
        "II. Track Lifecycle|4|9"
        "III. How Draft Thinks|10|13"
        "IV. Quality|14|17"
        "V. Enterprise|18|20"
        "VI. Closing|21|21"
        "Appendix|22|23"
    )

    for part_def in "${parts[@]}"; do
        IFS='|' read -r part_name start end <<< "$part_def"
        sidebar+=' <div class="sidebar-part">'$'\n'
        sidebar+=" <div class=\"sidebar-part-title\">$part_name</div>"$'\n'
        sidebar+=' <ul class="sidebar-chapters">'$'\n'

        for ((i=start; i<=end; i++)); do
            local id="${CHAPTER_IDS[$i]}"
            local title="${CHAPTER_TITLES[$i]}"
            local num="${CHAPTER_NUMS[$i]}"
            local active=""
            if [[ "$id" == "$current_id" ]]; then
                active=" active"
            fi
            sidebar+=" <li><a href=\"${prefix}${id}/\" class=\"sidebar-chapter${active}\" data-chapter=\"${id}\">"$'\n'
            sidebar+=" <span class=\"ch-num\">${num}.</span>${title}"$'\n'
            sidebar+=' </a></li>'$'\n'
        done

        sidebar+=' </ul>'$'\n'
        sidebar+=' </div>'$'\n'
    done

    sidebar+=' </aside>'

    echo "$sidebar"
}

# ============================================================
# CHAPTER PAGE GENERATOR
# ============================================================
generate_chapter_page() {
    local idx="$1"
    local id="${CHAPTER_IDS[$idx]}"
    local file="${CHAPTER_FILES[$idx]}"
    local title="${CHAPTER_TITLES[$idx]}"
    local desc="${CHAPTER_DESCRIPTIONS[$idx]}"
    local keywords="${CHAPTER_KEYWORDS[$idx]}"
    local num="${CHAPTER_NUMS[$idx]}"
    local priority="${CHAPTER_PRIORITIES[$idx]}"

    local source_file="$CHAPTERS_DIR/$file"
    if [[ ! -f "$source_file" ]]; then
        echo "ERROR: Chapter source not found: $source_file" >&2
        return 1
    fi

    local chapter_content
    chapter_content="$(cat "$source_file")"

    # Build prev/next navigation
    local prev_nav='<div></div>'
    local next_nav='<div></div>'
    if (( idx > 0 )); then
        local prev_id="${CHAPTER_IDS[$((idx-1))]}"
        local prev_title="${CHAPTER_TITLES[$((idx-1))]}"
        prev_nav="<a href=\"../${prev_id}/\" class=\"chapter-nav-link chapter-nav-link--prev\"><span class=\"chapter-nav-label\">&larr; Previous</span><span class=\"chapter-nav-title\">${prev_title}</span></a>"
    fi
    if (( idx < NUM_CHAPTERS - 1 )); then
        local next_id="${CHAPTER_IDS[$((idx+1))]}"
        local next_title="${CHAPTER_TITLES[$((idx+1))]}"
        next_nav="<a href=\"../${next_id}/\" class=\"chapter-nav-link chapter-nav-link--next\"><span class=\"chapter-nav-label\">Next &rarr;</span><span class=\"chapter-nav-title\">${next_title}</span></a>"
    fi

    local sidebar
    sidebar="$(generate_sidebar "$id" "../")"

    # Escape description for JSON-LD (double quotes)
    local json_desc="${desc//\"/\\\"}"
    local json_title="${title//&amp;/&}"
    json_title="${json_title//\"/\\\"}"

    local output_dir="$BOOK_DIR/$id"
    mkdir -p "$output_dir"

    cat > "$output_dir/index.html" <<HEREDOC
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title} — Draft Book</title>
    <meta name="description" content="${desc}">
    <meta name="author" content="Mayur Pise">
    <meta name="theme-color" content="#2563eb">
    <meta name="keywords" content="${keywords}">
    <meta name="robots" content="index, follow">
    <link rel="icon" type="image/svg+xml" href="../../favicon.svg">
    <meta property="og:title" content="${title} — Draft Book">
    <meta property="og:description" content="${desc}">
    <meta property="og:type" content="article">
    <meta property="og:url" content="https://getdraft.dev/book/${id}/">
    <meta property="og:image" content="https://getdraft.dev/social-preview.png">
    <meta property="og:image:alt" content="${title} — Draft Book">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${title} — Draft Book">
    <meta name="twitter:description" content="${desc}">
    <meta name="twitter:image" content="https://getdraft.dev/social-preview.png">
    <meta name="twitter:image:alt" content="${title} — Draft Book">
    <link rel="canonical" href="https://getdraft.dev/book/${id}/">

    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": "${json_title}",
      "description": "${json_desc}",
      "url": "https://getdraft.dev/book/${id}/",
      "isPartOf": { "@type": "Book", "name": "The Draft Book", "url": "https://getdraft.dev/book/" },
      "author": { "@type": "Person", "name": "Mayur Pise", "url": "https://github.com/mayurpise" },
      "publisher": { "@type": "Organization", "name": "Draft", "url": "https://getdraft.dev" },
      "position": $((idx + 1)),
      "inLanguage": "en"
    }
    </script>

    <script async src="https://www.googletagmanager.com/gtag/js?id=G-F6X062B4B7"></script>
    <script>
        window.dataLayer = window.dataLayer || [];
        function gtag() { dataLayer.push(arguments); }
        gtag('js', new Date());
        gtag('config', 'G-F6X062B4B7');
    </script>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="preload" as="style"
        href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600&family=JetBrains+Mono:wght@400;500&display=swap"
        onload="this.onload=null;this.rel='stylesheet'">
    <noscript>
        <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    </noscript>

    <link rel="stylesheet" href="../css/book.css">

    <!-- Theme: apply early to prevent flash of wrong theme -->
    <script>
    (function(){try{var t=localStorage.getItem('draft-theme');if(!t&&window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches)t='dark';if(t==='dark')document.documentElement.setAttribute('data-theme','dark');}catch(e){}})();
    </script>
</head>
<body data-chapter="${id}">

    <div class="reading-progress" id="reading-progress"></div>
    <div class="sidebar-backdrop" id="sidebar-backdrop"></div>

    <header class="book-topbar">
        <div class="book-topbar-left">
            <button class="sidebar-toggle" id="sidebar-toggle" aria-label="Toggle sidebar">
                <span></span><span></span><span></span>
            </button>
            <a href="https://getdraft.dev" class="book-topbar-logo">Draft <span>Book</span></a>
            <div class="book-topbar-divider"></div>
            <span class="book-topbar-chapter">${title}</span>
        </div>
        <div class="book-topbar-right">
            <a href="https://getdraft.dev" class="book-topbar-link">Home</a>
            <a href="https://github.com/mayurpise/draft" target="_blank" rel="noopener noreferrer" class="topbar-github">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
                GitHub
            </a>
        </div>
    </header>

    <div class="book-layout">
${sidebar}

        <main class="book-content">
${chapter_content}

            <nav class="chapter-nav">
                ${prev_nav}
                ${next_nav}
            </nav>
        </main>

        <nav class="page-toc" id="page-toc" style="display: none;">
            <div class="page-toc-title">On this page</div>
            <div id="page-toc-list" class="page-toc-list"></div>
        </nav>
    </div>

    <script src="../js/book.js"></script>
    <script src="../../js/theme-toggle.js"></script>
</body>
</html>
HEREDOC
}

# ============================================================
# LANDING PAGE GENERATOR (TOC with hash redirect)
# ============================================================
generate_landing_page() {
    local sidebar
    sidebar="$(generate_sidebar "" "./")"

    local _out="$BOOK_DIR/index.html"
    local _tmp
    _tmp="$(mktemp "${_out}.XXXXXX")"

    cat > "$_tmp" <<'LANDING_HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>The Draft Book — Context-Driven Development Deep Dive</title>
    <meta name="description" content="A comprehensive guide to Draft's Context-Driven Development methodology. 24 chapters covering specs, plans, TDD, code review, bug hunting, ACID audits, and more.">
    <meta name="author" content="Mayur Pise">
    <meta name="theme-color" content="#2563eb">
    <meta name="keywords" content="context-driven development book, ai coding methodology, claude code guide, spec driven development, ai code review, tdd enforcement, ai architecture discovery, bug hunting methodology, copilot best practices, ai development workflow">
    <meta name="robots" content="index, follow">
    <link rel="icon" type="image/svg+xml" href="../favicon.svg">
    <meta property="og:title" content="The Draft Book — Context-Driven Development Deep Dive">
    <meta property="og:description" content="22 chapters covering Draft's methodology, features, and philosophy. From context tiering to 14-dimension bug hunting.">
    <meta property="og:type" content="book">
    <meta property="og:url" content="https://getdraft.dev/book/">
    <meta property="og:image" content="https://getdraft.dev/social-preview.png">
    <meta property="og:image:alt" content="The Draft Book — Context-Driven Development Deep Dive">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="The Draft Book — Context-Driven Development Deep Dive">
    <meta name="twitter:description" content="22 chapters covering specs, plans, TDD enforcement, 3-stage code review, 14-dimension bug hunting, and ACID audits for AI coding agents.">
    <meta name="twitter:image" content="https://getdraft.dev/social-preview.png">
    <meta name="twitter:image:alt" content="The Draft Book — Context-Driven Development Deep Dive">
    <link rel="canonical" href="https://getdraft.dev/book/">

    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Book",
      "name": "The Draft Book",
      "alternateName": "Context-Driven Development Deep Dive",
      "description": "A comprehensive guide to Draft's Context-Driven Development methodology. 22 chapters covering specs, plans, TDD, code review, bug hunting, ACID audits, and more.",
      "url": "https://getdraft.dev/book/",
      "author": {
        "@type": "Person",
        "name": "Mayur Pise",
        "url": "https://www.linkedin.com/in/mayurpise/",
        "sameAs": ["https://github.com/mayurpise"]
      },
      "publisher": {
        "@type": "Organization",
        "name": "Draft",
        "url": "https://getdraft.dev"
      },
      "inLanguage": "en",
      "genre": "Software Development",
      "numberOfPages": 24,
      "bookFormat": "https://schema.org/EBook",
      "offers": { "@type": "Offer", "price": "0", "priceCurrency": "USD", "availability": "https://schema.org/InStock" },
      "image": "https://getdraft.dev/social-preview.png"
    }
    </script>

    <script async src="https://www.googletagmanager.com/gtag/js?id=G-F6X062B4B7"></script>
    <script>
        window.dataLayer = window.dataLayer || [];
        function gtag() { dataLayer.push(arguments); }
        gtag('js', new Date());
        gtag('config', 'G-F6X062B4B7');
    </script>

    <!-- Redirect old hash-based URLs -->
    <script>
LANDING_HEAD

    # Generate the known IDs array for the redirect script
    printf ' (function() {\n' >> "$_tmp"
    printf ' if (location.hash && location.hash.length > 1) {\n' >> "$_tmp"
    printf ' var id = location.hash.slice(1);\n' >> "$_tmp"
    printf ' var known = [' >> "$_tmp"
    local first=true
    for id in "${CHAPTER_IDS[@]}"; do
        if $first; then first=false; else printf ',' >> "$_tmp"; fi
        printf '"%s"' "$id" >> "$_tmp"
    done
    printf '];\n' >> "$_tmp"
    printf ' if (known.indexOf(id) !== -1) { location.replace(id + "/"); }\n' >> "$_tmp"
    printf ' }\n' >> "$_tmp"
    printf ' })();\n' >> "$_tmp"

    cat >> "$_tmp" <<'LANDING_REDIRECT_END'
    </script>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="preload" as="style"
        href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600&family=JetBrains+Mono:wght@400;500&display=swap"
        onload="this.onload=null;this.rel='stylesheet'">
    <noscript>
        <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    </noscript>

    <link rel="stylesheet" href="css/book.css">

    <!-- Theme: apply early to prevent flash of wrong theme -->
    <script>
    (function(){try{var t=localStorage.getItem('draft-theme');if(!t&&window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches)t='dark';if(t==='dark')document.documentElement.setAttribute('data-theme','dark');}catch(e){}})();
    </script>
</head>
<body>

    <div class="reading-progress" id="reading-progress"></div>
    <div class="sidebar-backdrop" id="sidebar-backdrop"></div>

    <header class="book-topbar">
        <div class="book-topbar-left">
            <button class="sidebar-toggle" id="sidebar-toggle" aria-label="Toggle sidebar">
                <span></span><span></span><span></span>
            </button>
            <a href="https://getdraft.dev" class="book-topbar-logo">Draft <span>Book</span></a>
        </div>
        <div class="book-topbar-right">
            <a href="https://getdraft.dev" class="book-topbar-link">Home</a>
            <a href="https://github.com/mayurpise/draft" target="_blank" rel="noopener noreferrer" class="topbar-github">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
                GitHub
            </a>
        </div>
    </header>

    <div class="book-layout">
LANDING_REDIRECT_END

    # Insert sidebar
    echo "$sidebar" >> "$_tmp"

    # Insert main content (TOC)
    cat >> "$_tmp" <<'LANDING_MAIN_START'

        <main class="book-content">
            <div class="chapter-wrapper">
                <div class="book-landing">
                    <h1><span class="gradient-text">The Draft Book</span></h1>
                    <p class="book-landing-subtitle">A comprehensive guide to Context-Driven Development — from first principles to enterprise deployment.</p>
                </div>

                <div class="book-toc">
LANDING_MAIN_START

    # Generate TOC entries
    local current_part=""
    for ((i=0; i<NUM_CHAPTERS; i++)); do
        local id="${CHAPTER_IDS[$i]}"
        local title="${CHAPTER_TITLES[$i]}"
        local num="${CHAPTER_NUMS[$i]}"

        # Determine part name
        local part=""
        if (( i == 0 )); then part="Introduction"
        elif (( i >= 1 && i <= 3 )); then part="I. Foundation"
        elif (( i >= 4 && i <= 9 )); then part="II. Track Lifecycle"
        elif (( i >= 10 && i <= 13 )); then part="III. How Draft Thinks"
        elif (( i >= 14 && i <= 17 )); then part="IV. Quality"
        elif (( i >= 18 && i <= 20 )); then part="V. Enterprise"
        elif (( i == 21 )); then part="VI. Closing"
        else part="Appendix"
        fi

        if [[ "$part" != "$current_part" ]]; then
            if [[ -n "$current_part" ]]; then
                echo ' </ul></div>' >> "$_tmp"
            fi
            echo " <div class=\"book-toc-part\"><div class=\"book-toc-part-title\">$part</div><ul class=\"book-toc-list\">" >> "$_tmp"
            current_part="$part"
        fi

        echo " <li><a href=\"${id}/\" class=\"book-toc-entry\"><span class=\"book-toc-num\">${num}.</span><span class=\"book-toc-name\">${title}</span></a></li>" >> "$_tmp"
    done
    echo ' </ul></div>' >> "$_tmp"

    cat >> "$_tmp" <<'LANDING_FOOTER'
                </div>

                <div class="book-footer">
                    <p>The Draft Book is part of the <a href="https://getdraft.dev">Draft</a> project. <a href="https://github.com/mayurpise/draft" target="_blank" rel="noopener noreferrer">View on GitHub</a>.</p>
                </div>
            </div>
        </main>
    </div>

    <script src="js/book.js"></script>
    <script src="../js/theme-toggle.js"></script>
</body>
</html>
LANDING_FOOTER
    mv -f "$_tmp" "$_out"
}

# ============================================================
# SITEMAP GENERATOR
# ============================================================
generate_sitemap() {
    local _stmp
    _stmp="$(mktemp "${SITEMAP_FILE}.XXXXXX")"

    cat > "$_stmp" <<SITEMAP_HEAD
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>https://getdraft.dev/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>weekly</changefreq>
        <priority>1.0</priority>
    </url>
    <url>
        <loc>https://getdraft.dev/book/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>weekly</changefreq>
        <priority>0.9</priority>
    </url>
    <url>
        <loc>https://getdraft.dev/blog/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>weekly</changefreq>
        <priority>0.8</priority>
    </url>
    <url>
        <loc>https://getdraft.dev/blog/blast-radius-walkthrough/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.7</priority>
    </url>
    <url>
        <loc>https://getdraft.dev/blog/decompose-payment-gateway/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.7</priority>
    </url>
    <url>
        <loc>https://getdraft.dev/blog/local-graph-engine/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.7</priority>
    </url>
    <url>
        <loc>https://getdraft.dev/blog/mcp-tool-discovery/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.7</priority>
    </url>
    <url>
        <loc>https://getdraft.dev/blog/replaced-kiro-with-free-plugin/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.7</priority>
    </url>
SITEMAP_HEAD

    for ((i=0; i<NUM_CHAPTERS; i++)); do
        local id="${CHAPTER_IDS[$i]}"
        local priority="${CHAPTER_PRIORITIES[$i]}"
        cat >> "$_stmp" <<SITEMAP_ENTRY
    <url>
        <loc>https://getdraft.dev/book/${id}/</loc>
        <lastmod>${TODAY}</lastmod>
        <changefreq>monthly</changefreq>
        <priority>${priority}</priority>
    </url>
SITEMAP_ENTRY
    done

    echo '</urlset>' >> "$_stmp"
    mv -f "$_stmp" "$SITEMAP_FILE"
}

# ============================================================
# MAIN
# ============================================================
echo "Building book pages..."

# Generate all chapter pages
for ((i=0; i<NUM_CHAPTERS; i++)); do
    generate_chapter_page "$i"
    echo " Generated: ${CHAPTER_IDS[$i]}/index.html"
done

# Generate landing page
generate_landing_page
echo " Generated: book/index.html (TOC + hash redirect)"

# Generate sitemap
generate_sitemap
echo " Generated: sitemap.xml (${NUM_CHAPTERS} chapter URLs)"

echo "Done. ${NUM_CHAPTERS} chapter pages built."
