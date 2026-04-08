---
layout: default
title: Farty Bobo
---

<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --yellow: #97C459;
    --black: #0e0c1a;
    --off-black: #14112a;
    --dim: #1c1836;
    --border: #2a2550;
    --text: #e8e6f5;
    --muted: #7f77aa;
    --font-display: 'Bebas Neue', Impact, sans-serif;
    --font-body: 'JetBrains Mono', 'Courier New', monospace;
  }

  .fb-page {
    font-family: var(--font-body);
    color: var(--text);
    background: var(--black);
    width: 100%;
    overflow-x: hidden;
  }

  /* ── HERO ── */
  .fb-hero {
    position: relative;
    width: 100%;
    padding: 72px 6vw 72px;
    border-bottom: 3px solid var(--yellow);
    overflow: hidden;
  }

  .fb-hero::before {
    content: '';
    position: absolute;
    inset: 0;
    background: repeating-linear-gradient(
      -55deg,
      transparent 0,
      transparent 80px,
      rgba(127,119,221,0.04) 80px,
      rgba(127,119,221,0.04) 81px
    );
    pointer-events: none;
  }

  .fb-hero-inner {
    position: relative;
    z-index: 1;
    display: flex;
    align-items: center;
    gap: 5vw;
  }

  .fb-mascot {
    flex: 0 0 auto;
    width: clamp(140px, 18vw, 260px);
    filter: drop-shadow(0 0 36px rgba(127,119,221,0.4));
    animation: fb-float 4s ease-in-out infinite;
  }

  @keyframes fb-float {
    0%, 100% { transform: translateY(0) rotate(-1deg); }
    50%       { transform: translateY(-10px) rotate(1deg); }
  }

  .fb-title-block { flex: 1 1 auto; }

  .fb-wordmark {
    display: block;
    width: clamp(220px, 36vw, 520px);
    margin-bottom: 12px;
    filter: none;
  }

  .fb-tagline {
    font-family: var(--font-display);
    font-size: clamp(2rem, 5vw, 4.5rem);
    color: var(--yellow);
    letter-spacing: 0.03em;
    line-height: 1;
    margin-bottom: 24px;
    text-transform: uppercase;
  }

  .fb-desc {
    font-size: clamp(0.75rem, 1.1vw, 0.88rem);
    color: var(--muted);
    max-width: 480px;
    line-height: 1.75;
  }

  .fb-desc a { color: var(--yellow); text-decoration: none; border-bottom: 1px solid rgba(245,230,66,0.35); }
  .fb-desc a:hover { border-bottom-color: var(--yellow); }

  /* ── CONTENT GRID ── */
  .fb-content {
    width: 100%;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0;
  }

  .fb-section {
    background: var(--off-black);
    border-top: 3px solid var(--border);
    border-right: 1px solid var(--border);
    padding: 48px 5vw;
    transition: background 0.2s;
  }

  .fb-section:last-child { border-right: none; }
  .fb-section:hover { background: var(--dim); }

  .fb-section h2 {
    font-family: var(--font-display);
    font-size: 2rem;
    color: var(--yellow);
    letter-spacing: 0.06em;
    margin-bottom: 28px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--border);
  }

  .fb-items { list-style: none; }

  .fb-items li {
    display: flex;
    gap: 20px;
    padding: 12px 0;
    border-bottom: 1px solid var(--border);
    font-size: 0.82rem;
    line-height: 1.55;
  }

  .fb-items li:last-child { border-bottom: none; }

  .fb-item-key {
    flex: 0 0 130px;
    color: var(--yellow);
    font-weight: 700;
  }

  .fb-item-val { color: var(--muted); }

  .fb-codeblock {
    background: #000;
    border: 1px solid var(--border);
    border-left: 3px solid var(--yellow);
    padding: 20px 24px;
    font-size: 0.8rem;
    line-height: 2;
    color: #bbb;
    overflow-x: auto;
    margin-bottom: 28px;
  }

  .fb-codeblock .cmd { color: var(--yellow); }
  .fb-codeblock .arg { color: #888; }

  .fb-link {
    display: inline-block;
    font-family: var(--font-display);
    font-size: 1.1rem;
    letter-spacing: 0.08em;
    color: var(--black);
    background: var(--yellow);
    padding: 10px 28px;
    text-decoration: none;
    transition: opacity 0.15s;
  }
  .fb-link:hover { opacity: 0.85; }

  /* ── FOOTER ── */
  .fb-footer {
    width: 100%;
    text-align: center;
    padding: 24px;
    font-size: 0.65rem;
    color: #333;
    border-top: 1px solid var(--border);
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  @media (max-width: 680px) {
    .fb-hero-inner { flex-direction: column; align-items: flex-start; }
    .fb-mascot { width: 120px; }
    .fb-content { grid-template-columns: 1fr; }
    .fb-section { border-right: none; border-bottom: 1px solid var(--border); }
  }
</style>

<div class="fb-page">

  <section class="fb-hero">
    <div class="fb-hero-inner">
      <img
        class="fb-mascot"
        src="{{ '/logos/fartybobo_angry_mascot.svg' | relative_url }}"
        alt="Farty Bobo mascot"
      />
      <div class="fb-title-block">
        <img
          class="fb-wordmark"
          src="{{ '/logos/fartybobo_angry_wordmark.svg' | relative_url }}"
          alt="Farty Bobo"
        />
        <p class="fb-tagline">We Got the f***ing Gas</p>
        <p class="fb-desc">
          Every machine you own is a different hellscape of broken configs and
          missing context. This fixes that. It's <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>
          — but opinionated, angry, and actually set up right.
          Clone it. Symlink it. Stop suffering.
        </p>
      </div>
    </div>
  </section>

  <div class="fb-content">

    <div class="fb-section">
      <h2>What the Hell's In Here</h2>
      <ul class="fb-items">
        <li>
          <span class="fb-item-key">CLAUDE.md</span>
          <span class="fb-item-val">Tells Claude who the f*** it is and how to behave. Non-negotiable.</span>
        </li>
        <li>
          <span class="fb-item-key">settings.json</span>
          <span class="fb-item-val">Model, hooks, permissions. Don't touch it unless you know what you're doing.</span>
        </li>
        <li>
          <span class="fb-item-key">skills/</span>
          <span class="fb-item-val">Real slash commands. Not the useless defaults that ship out of the box.</span>
        </li>
        <li>
          <span class="fb-item-key">hooks/</span>
          <span class="fb-item-val">Shell scripts that fire before/after edits so you don't shoot yourself in the foot.</span>
        </li>
        <li>
          <span class="fb-item-key">commands/</span>
          <span class="fb-item-val">Status line and other crap Claude needs to actually function.</span>
        </li>
      </ul>
    </div>

    <div class="fb-section">
      <h2>Just Do It Already</h2>
      <div class="fb-codeblock">
        <span class="cmd">git clone</span> <span class="arg">https://github.com/fartybobo/farty-bobo ~/dev/farty-bobo</span><br/>
        <span class="cmd">cd</span> <span class="arg">~/dev/farty-bobo</span><br/>
        <span class="cmd">./setup.sh</span>
      </div>
      <a class="fb-link" href="https://github.com/fartybobo/farty-bobo">Read the Damn Docs →</a>
    </div>

  </div>

  <footer class="fb-footer">Farty Bobo &mdash; We Got the f***ing Gas</footer>

</div>
