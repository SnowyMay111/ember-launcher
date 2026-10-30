import re

with open('design/ember-v2/exact_styles.css', 'r', encoding='utf-8') as f:
    css_content = f.read()

# Additional styles for pure vanilla interactive preview
extra_css = """
/* Tab switching and modal display styles */
.tab-content { display: none; height: 100%; flex-direction: column; }
.tab-content.active { display: flex; }

.modal-overlay { display: none; }
.modal-overlay.open { display: flex; }

.friends-drawer-panel { display: none; }
.drawer-backdrop { display: none; }
.friends-drawer-panel.open { display: flex; }
.drawer-backdrop.open { display: block; }
"""

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Ember Launcher</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Manrope:wght@400;500;600;700;800&family=Playfair+Display:wght@500;600;700&display=swap" rel="stylesheet">
  <style>
{css_content}
{extra_css}
  </style>
</head>
<body>
  <div class="app-container">
    <div class="grid-overlay"></div>
    <div class="ambient-glow glow-purple"></div>
    <div class="ambient-glow glow-amber"></div>

    <!-- Sidebar -->
    <aside class="sidebar">
      <div class="traffic-lights">
        <span class="traffic-dot dot-red"></span>
        <span class="traffic-dot dot-yellow"></span>
        <span class="traffic-dot dot-green"></span>
      </div>

      <!-- Ember Diamond Tile Logo -->
      <svg class="sidebar-logo" viewBox="0 0 64 64" fill="none">
        <defs>
          <linearGradient id="emberTile" x1="10" y1="8" x2="54" y2="58" gradientUnits="userSpaceOnUse">
            <stop stop-color="#462c42"/>
            <stop offset="1" stop-color="#442a22"/>
          </linearGradient>
          <linearGradient id="emberGem" x1="32" y1="16" x2="32" y2="48" gradientUnits="userSpaceOnUse">
            <stop stop-color="#c87fe2"/>
            <stop offset="0.5" stop-color="#d989b5"/>
            <stop offset="1" stop-color="#f2a064"/>
          </linearGradient>
        </defs>
        <rect x="4" y="4" width="56" height="56" rx="16" fill="#1e181c"/>
        <rect x="6" y="6" width="52" height="52" rx="14" fill="url(#emberTile)"/>
        <path d="M32 16L48 32L32 48L16 32Z" fill="url(#emberGem)"/>
      </svg>

      <div class="nav-group">
        <button class="nav-item active" data-tab="Home" title="Play (1)">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </button>
        <button class="nav-item" data-tab="Instances" title="Library (2)">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="3" width="7" height="7" rx="1.5"/>
            <rect x="14" y="3" width="7" height="7" rx="1.5"/>
            <rect x="3" y="14" width="7" height="7" rx="1.5"/>
            <rect x="14" y="14" width="7" height="7" rx="1.5"/>
          </svg>
        </button>
        <button class="nav-item" data-tab="Social" title="Social (3)">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
            <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
          </svg>
        </button>
        <button class="nav-item" data-tab="Explore" title="Explore (4)">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 3v12"/>
            <path d="m7 10 5 5 5-5"/>
            <path d="M5 21h14"/>
          </svg>
        </button>
        <button class="nav-item" data-tab="Skins" title="Skins (5)">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M20.38 3.46 16 2a4 4 0 0 1-8 0L3.62 3.46a2 2 0 0 0-1.34 2.23l.58 3.5a2 2 0 0 0 1.5 1.63L6 11.2V20a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-8.8l1.64-.38a2 2 0 0 0 1.5-1.63l.58-3.5a2 2 0 0 0-1.34-2.23z"/>
          </svg>
        </button>
      </div>

      <div class="sidebar-bottom">
        <span class="status-indicator" title="All systems operational"></span>
        <button class="nav-item" data-tab="Settings" title="Settings (6)">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="3"/>
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
          </svg>
        </button>
      </div>
    </aside>

    <!-- Workspace -->
    <main class="workspace">
      <!-- TopBar -->
      <header class="topbar">
        <div class="topbar-titles">
          <p class="eyebrow">Welcome back</p>
          <h1 id="screenTitle">Welcome home.</h1>
        </div>

        <div class="topbar-actions">
          <!-- Friends Pill -->
          <button class="pill-button" id="btnFriendsDrawer">
            <div class="avatar-bubbles">
              <span class="avatar-m">M</span>
              <span class="avatar-l">L</span>
              <span class="avatar-n">N</span>
            </div>
            <div class="pill-text">
              <strong>3 online</strong>
              <small>Friends</small>
            </div>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="6 9 12 15 18 9"/>
            </svg>
          </button>

          <!-- Profile Pill -->
          <button class="pill-button" id="btnProfile">
            <div class="pixel-steve"></div>
            <div class="pill-text">
              <strong id="topbarDisplayName">kotiki</strong>
              <small style="color: var(--success)">Online</small>
            </div>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="6 9 12 15 18 9"/>
            </svg>
          </button>
        </div>
      </header>

      <!-- Content Area -->
      <div class="content-area">
        <!-- TAB 1: HOME -->
        <div class="tab-content active" id="tabHome">
          <div class="home-layout">
            <div class="hero-viewport">
              <div class="hero-celestial"></div>
              <div class="hero-terrain">
                <div class="terrain-slope-far"></div>
                <div class="terrain-slope-near"></div>
                <span class="pine-silhouette pine-1"></span>
                <span class="pine-silhouette pine-2"></span>
                <span class="pine-silhouette pine-3"></span>
                <span class="pine-silhouette pine-4"></span>
              </div>

              <div class="hero-info-card">
                <h2 class="hero-instance-title" id="heroInstanceName">111</h2>
                <div class="hero-instance-meta">
                  <span class="amber-dot"></span>
                  <span class="meta-tag">LAST PLAYED</span>
                  <span class="meta-value" id="heroLastPlayed">Never played</span>
                  <span class="meta-divider"></span>
                  <span class="meta-loader" id="heroLoader">NeoForge · 0 mods</span>
                </div>
              </div>
            </div>

            <div class="launch-bar">
              <div class="version-card" id="btnVersionCard">
                <div class="voxel-icon-box">
                  <div class="voxel-block"></div>
                </div>
                <div class="version-texts">
                  <span class="version-label">Version</span>
                  <strong class="version-name" id="heroVersionLabel">NeoForge 26.3</strong>
                </div>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                  <polyline points="6 9 12 15 18 9"/>
                </svg>
              </div>

              <button class="settings-btn-card" id="btnOpenInstSettings" title="Instance settings">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <circle cx="12" cy="12" r="3"/>
                  <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
                </svg>
              </button>

              <button class="play-btn-card" id="btnLaunchPlay">
                <div class="play-circle">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                    <polygon points="5 3 19 12 5 21 5 3"/>
                  </svg>
                </div>
                <div class="play-texts">
                  <span class="play-title" id="playBtnTitle">Play</span>
                  <span class="play-subtitle" id="playBtnSub">111</span>
                </div>
              </button>
            </div>
          </div>
        </div>

        <!-- TAB 2: INSTANCES -->
        <div class="tab-content" id="tabInstances">
          <div class="section-header">
            <div class="section-header-left">
              <p class="section-eyebrow">Your worlds</p>
              <h2>Instances</h2>
              <p>Every world, safe and ready when you are.</p>
            </div>
            <button class="btn-primary-pill" id="btnNewInstanceModal">
              ＋ New instance
            </button>
          </div>

          <div class="search-input-box">
            <span>⌕</span>
            <input placeholder="Search instances" />
          </div>

          <div class="filters-bar">
            <div class="filter-capsules">
              <span class="filter-capsule active">All</span>
              <span class="filter-capsule">Vanilla</span>
              <span class="filter-capsule">Fabric</span>
              <span class="filter-capsule">Forge</span>
              <span class="filter-capsule">NeoForge</span>
              <span class="filter-capsule">All versions</span>
            </div>
            <span class="instances-count-text">3 instances · 0 h 0 min · 0 mods</span>
          </div>

          <div class="instances-cards-grid">
            <!-- Card 1 -->
            <div class="instance-item-card">
              <div class="card-banner">
                <span class="banner-badge">● Vanilla</span>
                <div class="banner-moon"></div>
              </div>
              <div class="card-content">
                <div class="card-row-top">
                  <div class="card-title-group">
                    <h3>уцй</h3>
                    <p>26.3 · Vanilla</p>
                  </div>
                  <button class="btn-card-play" onclick="selectAndPlay('уцй', '26.3 · Vanilla', 'Vanilla')">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg> Play
                  </button>
                </div>
                <div class="card-chips-row">
                  <span class="meta-chip">🧩 0 mods</span>
                  <span class="meta-chip">💾 6 GB RAM</span>
                  <span class="meta-chip">⏱ 0 h 0 min</span>
                </div>
                <div class="card-footer-row">
                  <span>Never played</span>
                  <div class="card-footer-actions" onclick="openInstSettings('уцй')">
                    <span>Manage</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Card 2 -->
            <div class="instance-item-card">
              <div class="card-banner">
                <span class="banner-badge">● Vanilla</span>
                <div class="banner-moon"></div>
              </div>
              <div class="card-content">
                <div class="card-row-top">
                  <div class="card-title-group">
                    <h3>уцйуй</h3>
                    <p>1.21.11 · Vanilla</p>
                  </div>
                  <button class="btn-card-play" onclick="selectAndPlay('уцйуй', '1.21.11 · Vanilla', 'Vanilla')">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg> Play
                  </button>
                </div>
                <div class="card-chips-row">
                  <span class="meta-chip">🧩 0 mods</span>
                  <span class="meta-chip">💾 6 GB RAM</span>
                  <span class="meta-chip">⏱ 0 h 0 min</span>
                </div>
                <div class="card-footer-row">
                  <span>Never played</span>
                  <div class="card-footer-actions" onclick="openInstSettings('уцйуй')">
                    <span>Manage</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Card 3 -->
            <div class="instance-item-card">
              <div class="card-banner">
                <span class="banner-badge">● NeoForge</span>
                <div class="banner-moon"></div>
              </div>
              <div class="card-content">
                <div class="card-row-top">
                  <div class="card-title-group">
                    <h3>111</h3>
                    <p>26.3 · NeoForge</p>
                  </div>
                  <button class="btn-card-play" onclick="selectAndPlay('111', '26.3 · NeoForge', 'NeoForge')">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg> Play
                  </button>
                </div>
                <div class="card-chips-row">
                  <span class="meta-chip">🧩 0 mods</span>
                  <span class="meta-chip">💾 6 GB RAM</span>
                  <span class="meta-chip">⏱ 0 h 0 min</span>
                </div>
                <div class="card-footer-row">
                  <span>Never played</span>
                  <div class="card-footer-actions" onclick="openInstSettings('111')">
                    <span>Manage</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- TAB 3: SOCIAL -->
        <div class="tab-content" id="tabSocial">
          <div class="section-header">
            <div class="section-header-left">
              <p class="section-eyebrow">PLAY TOGETHER</p>
              <h2>Social</h2>
              <p>A quiet place for friends, invitations, and temporary worlds.</p>
            </div>
            <button class="btn-primary-pill" onclick="alert('Temporary peer multiplayer lobby created on port 25565!')">
              ＋ Create lobby
            </button>
          </div>

          <div class="social-panels-grid">
            <!-- Col 1: Friends -->
            <div class="social-column-card">
              <div class="social-column-header">
                <h4>FRIENDS</h4>
                <span>3 online</span>
              </div>
              <div class="friend-row">
                <div class="friend-row-left">
                  <div class="avatar-square">M</div>
                  <div class="friend-names">
                    <strong>Mossy</strong>
                    <small>Building in 1.21.4</small>
                  </div>
                </div>
                <span class="friend-dot"></span>
              </div>
              <div class="friend-row">
                <div class="friend-row-left">
                  <div class="avatar-square" style="background: #3c4c36">L</div>
                  <div class="friend-names">
                    <strong>Luna</strong>
                    <small>In the main menu</small>
                  </div>
                </div>
                <span class="friend-dot"></span>
              </div>
              <div class="friend-row">
                <div class="friend-row-left">
                  <div class="avatar-square" style="background: #4a384c">N</div>
                  <div class="friend-names">
                    <strong>North</strong>
                    <small>Exploring Ember Valley</small>
                  </div>
                </div>
                <span class="friend-dot"></span>
              </div>
              <div class="friend-row">
                <div class="friend-row-left">
                  <div class="avatar-square" style="background: #332f33">R</div>
                  <div class="friend-names">
                    <strong>Rowan</strong>
                    <small>Offline · 2h ago</small>
                  </div>
                </div>
                <span class="friend-dot offline"></span>
              </div>
              <div style="margin-top: auto; padding-top: 10px;">
                <span style="font-size: 10px; color: var(--text-muted); cursor: pointer">View all friends →</span>
              </div>
            </div>

            <!-- Col 2: Active Lobbies -->
            <div class="social-column-card">
              <div class="social-column-header">
                <h4>ACTIVE LOBBIES</h4>
                <span>Friends only</span>
              </div>
              <div class="lobby-feature-card">
                <div class="lobby-feature-banner">
                  <div class="banner-moon"></div>
                </div>
                <div class="lobby-feature-body">
                  <span class="lobby-players-count">2 / 8 PLAYERS</span>
                  <h4 class="lobby-title">Birch Hollow evening</h4>
                  <p class="lobby-subtitle">Mossy is hosting · Fabric 1.21.4</p>
                  <div class="lobby-avatars-row">
                    <div class="avatar-bubbles">
                      <span class="avatar-m">M</span>
                      <span class="avatar-l">L</span>
                    </div>
                    <span>+ invite</span>
                  </div>
                  <button class="btn-primary-pill" style="width: 100%; justify-content: center; margin-top: 6px;">
                    Join lobby
                  </button>
                </div>
              </div>

              <div class="dashed-create-box">
                <div>
                  <strong>Start from your world</strong>
                  <small>Friends join without changing your instance.</small>
                </div>
                <button class="btn-dark-pill" onclick="alert('Lobby created!')">Create</button>
              </div>
            </div>

            <!-- Col 3: Invites -->
            <div class="social-column-card">
              <div class="social-column-header">
                <h4>INVITES</h4>
                <span>1 new</span>
              </div>
              <div style="background: #181618; border: 1px solid #282428; border-radius: 12px; padding: 14px;">
                <div style="display: flex; gap: 10px; align-items: center;">
                  <div class="avatar-square" style="background: #453545">N</div>
                  <div>
                    <strong style="font-size: 11px; display: block;">North invited you</strong>
                    <small style="font-size: 9px; color: var(--text-muted)">Old Pines · Vanilla 1.21.4</small>
                  </div>
                </div>
                <div style="display: flex; gap: 8px; margin-top: 12px;">
                  <button class="btn-primary-pill" style="flex: 1; justify-content: center;">Accept</button>
                  <button class="btn-dark-pill" style="flex: 1; justify-content: center;">Later</button>
                </div>
              </div>

              <div style="margin-top: 16px;">
                <span style="font-size: 9px; font-family: 'DM Mono'; color: var(--text-dim); letter-spacing: 0.08em;">RECENT PLAYERS</span>
                <div style="display: flex; flex-direction: column; gap: 6px; margin-top: 8px; font-size: 10px; color: var(--text-muted);">
                  <div>Luna · 2 days ago</div>
                  <div>Rowan · 5 days ago</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- TAB 4: EXPLORE (MODS) -->
        <div class="tab-content" id="tabExplore">
          <div class="section-header">
            <div class="section-header-left">
              <p class="section-eyebrow">Discover</p>
              <h2>Mods</h2>
              <p>For 111 · 26.3 · NeoForge</p>
            </div>
            <button class="btn-dark-pill">Check for updates</button>
          </div>

          <div class="filter-capsules" style="margin-bottom: 40px;">
            <span class="filter-capsule active">Installed</span>
            <span class="filter-capsule">Browse</span>
          </div>

          <div style="text-align: center; padding: 60px 0; color: var(--text-dim); font-size: 13px;">
            No mods yet. Open Browse to add some.
          </div>
        </div>

        <!-- TAB 5: SKINS -->
        <div class="tab-content" id="tabSkins">
          <div class="section-header">
            <div class="section-header-left">
              <p class="section-eyebrow">WARDROBE</p>
              <h2>Skins</h2>
              <p>Choose how you arrive in every world.</p>
            </div>
            <div style="display: flex; gap: 10px;">
              <button class="btn-dark-pill">✦ Skin Catalog</button>
              <button class="btn-primary-pill">＋ Import skin</button>
            </div>
          </div>

          <div class="skins-view-grid">
            <div class="skin-stage-box">
              <div class="skin-stage-toggles">
                <div class="segmented-control">
                  <button class="segment-btn active">3D Boba</button>
                  <button class="segment-btn">2D Flat</button>
                </div>
                <button class="btn-dark-pill" style="padding: 4px 10px; font-size: 10px;">✦ Catalog</button>
              </div>

              <!-- Canvas 3D Character -->
              <canvas id="skinCanvas" width="320" height="340" style="cursor: grab;"></canvas>

              <div class="stage-foot-note">
                <strong style="color: var(--text-muted); display: block; margin-bottom: 2px;">c1b51b81eb682f6e · Slim</strong>
                Drag with mouse to rotate Boba 360° · Double-click to reset<br />
                Skins are stored on this Mac. In offline mode the game shows its default skin; your selection is applied after Microsoft sign-in.
              </div>
            </div>

            <div class="wardrobe-column">
              <div class="wardrobe-collection-box">
                <h4 class="collection-header">YOUR COLLECTION</h4>
                <div class="skin-item-row">
                  <div class="skin-preview-thumb"></div>
                  <div class="skin-item-names">
                    <strong>95e4178fde89ceec</strong>
                    <small>Saved skin</small>
                  </div>
                </div>
                <div class="skin-item-row active">
                  <div class="skin-preview-thumb" style="background: #d4987b"></div>
                  <div class="skin-item-names">
                    <strong>c1b51b81eb682f6e</strong>
                    <small style="color: var(--accent)">Currently equipped</small>
                  </div>
                </div>
                <div class="skin-item-row">
                  <div class="skin-preview-thumb" style="background: #5a463a"></div>
                  <div class="skin-item-names">
                    <strong>uzbek</strong>
                    <small>Saved skin</small>
                  </div>
                </div>

                <div class="model-toggle-row">
                  <span>Model</span>
                  <div class="segmented-control">
                    <button class="segment-btn">Classic (4px)</button>
                    <button class="segment-btn active">Slim (3px)</button>
                  </div>
                </div>

                <button class="btn-dark-pill" style="justify-content: center; padding: 10px;">
                  ✓ Currently equipped
                </button>

                <div style="display: flex; gap: 8px;">
                  <button class="btn-dark-pill" style="flex: 1; justify-content: center;">Rename</button>
                  <button class="btn-dark-pill" style="flex: 1; justify-content: center;">Remove</button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- TAB 6: SETTINGS -->
        <div class="tab-content" id="tabSettings">
          <div class="section-header">
            <div class="section-header-left">
              <p class="section-eyebrow">YOUR SPACE</p>
              <h2>Settings</h2>
              <p>A few thoughtful choices to make Ember feel like yours.</p>
            </div>
          </div>

          <div class="settings-grid-layout">
            <div class="settings-nav-list">
              <button class="settings-nav-btn active">General</button>
              <button class="settings-nav-btn">Java & memory</button>
              <button class="settings-nav-btn">Downloads</button>
              <button class="settings-nav-btn">Appearance</button>
              <button class="settings-nav-btn">AI</button>
              <button class="settings-nav-btn">About Ember</button>
            </div>

            <div class="settings-cards-col">
              <div class="settings-banner-card">
                <div class="settings-banner-left">
                  <svg class="sidebar-logo" viewBox="0 0 64 64" fill="none" style="margin: 0; width: 28px; height: 28px;">
                    <rect x="4" y="4" width="56" height="56" rx="16" fill="#1e181c"/>
                    <rect x="6" y="6" width="52" height="52" rx="14" fill="url(#emberTile)"/>
                    <path d="M32 16L48 32L32 48L16 32Z" fill="url(#emberGem)"/>
                  </svg>
                  <div>
                    <span style="font-size: 9px; font-family: 'DM Mono'; color: var(--text-muted)">GENERAL</span>
                    <strong style="display: block; font-size: 13px;">Everything feels good.</strong>
                    <small style="color: var(--text-muted)">Your profile, worlds, and launcher behavior in one calm place.</small>
                  </div>
                </div>
                <span style="color: var(--success); font-size: 16px;">✓</span>
              </div>

              <div class="settings-section-card">
                <div class="settings-card-head">PLAYER</div>
                <div class="settings-row-item">
                  <div>
                    <strong>Display name</strong>
                    <small>Used for offline and local worlds.</small>
                  </div>
                  <input class="settings-text-input" id="inputDisplayName" value="kotiki" />
                </div>
              </div>

              <div class="settings-section-card">
                <div class="settings-card-head">BEHAVIOR</div>
                <div class="settings-row-item">
                  <div>
                    <strong>Automatic updates</strong>
                    <small>Keep Ember and game metadata current.</small>
                  </div>
                  <div class="switch-control active" onclick="this.classList.toggle('active')">
                    <span class="switch-knob"></span>
                  </div>
                </div>
                <div class="settings-row-item">
                  <div>
                    <strong>Close launcher after start</strong>
                    <small>Save resources while Minecraft is running.</small>
                  </div>
                  <div class="switch-control active" onclick="this.classList.toggle('active')">
                    <span class="switch-knob"></span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Friends Sliding Drawer -->
    <div class="drawer-backdrop" id="drawerBackdrop"></div>
    <aside class="friends-drawer-panel" id="friendsDrawerPanel">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <span style="font-size: 9px; font-family: 'DM Mono'; color: var(--text-muted)">FRIENDS</span>
          <h3 style="margin: 2px 0 0 0; font-size: 15px;">3 people online</h3>
        </div>
        <button class="modal-close-btn" id="btnCloseFriendsDrawer">×</button>
      </div>

      <div style="background: #181618; border: 1px solid #282428; border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 10px;">
        <div style="display: flex; justify-content: space-between; font-size: 9px; font-family: 'DM Mono'; color: var(--text-muted);">
          <span>YOUR GROUP</span>
          <span>Quiet Crew · 3/8</span>
        </div>
        <div class="avatar-bubbles">
          <span class="avatar-m">M</span>
          <span class="avatar-l" style="background: #3f4e54">C</span>
          <span class="avatar-l">L</span>
          <span style="background: #262226; border: 1px solid #3c363c; color: #999">+</span>
        </div>
        <button class="btn-dark-pill" style="justify-content: center; padding: 6px 10px; font-size: 10px;">
          Create lobby for group
        </button>
      </div>

      <div style="display: flex; flex-direction: column; gap: 8px;">
        <div class="friend-row">
          <div class="friend-row-left">
            <div class="avatar-square">M</div>
            <div class="friend-names">
              <strong>Mossy</strong>
              <small>Building in 1.21.4</small>
            </div>
          </div>
          <span class="friend-dot"></span>
        </div>
        <div class="friend-row">
          <div class="friend-row-left">
            <div class="avatar-square" style="background: #3c4c36">L</div>
            <div class="friend-names">
              <strong>Luna</strong>
              <small>In the main menu</small>
            </div>
          </div>
          <span class="friend-dot"></span>
        </div>
        <div class="friend-row">
          <div class="friend-row-left">
            <div class="avatar-square" style="background: #4a384c">N</div>
            <div class="friend-names">
              <strong>North</strong>
              <small>Exploring Ember Valley</small>
            </div>
          </div>
          <span class="friend-dot"></span>
        </div>
        <div class="friend-row">
          <div class="friend-row-left">
            <div class="avatar-square" style="background: #332f33">R</div>
            <div class="friend-names">
              <strong>Rowan</strong>
              <small>Offline · 2h ago</small>
            </div>
          </div>
          <span class="friend-dot offline"></span>
        </div>
      </div>

      <div style="margin-top: auto; border-top: 1px solid #1f1c1f; paddingTop: 14px;">
        <span style="font-size: 11px; color: var(--text-muted); cursor: pointer" id="btnOpenSocialFromDrawer">
          Open Social center →
        </span>
      </div>
    </aside>

    <!-- Instance Settings Modal -->
    <div class="modal-overlay" id="instSettingsModal">
      <div class="modal-dialog">
        <div class="modal-head">
          <div>
            <h3>Instance settings</h3>
            <p id="modalInstSubtitle">26.3 · NeoForge</p>
          </div>
          <button class="modal-close-btn" id="btnCloseInstSettings">×</button>
        </div>

        <div class="modal-body">
          <div class="field-box">
            <span class="field-title">Name</span>
            <input class="field-input" id="inputInstName" value="111" />
          </div>

          <div class="field-box">
            <span class="field-title">Group</span>
            <select class="field-input" style="appearance: none">
              <option>Mods</option>
              <option>Vanilla</option>
            </select>
          </div>

          <div class="field-box">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span class="field-title">Memory</span>
              <strong style="font-size: 11px; color: var(--text-main);" id="sliderMemoryVal">6 GB</strong>
            </div>
            <input type="range" min="2" max="16" value="6" id="inputInstMemory" style="accent-color: var(--accent); cursor: pointer;" />
            <span class="field-help">Recommended: 6-8 GB</span>
          </div>

          <div class="field-box">
            <span class="field-title">Garbage collector</span>
            <select class="field-input" style="appearance: none">
              <option>Automatic</option>
              <option>Tuned G1GC</option>
              <option>ZGC (Low latency)</option>
            </select>
            <span class="field-help">Automatic picks ZGC on Java 21+ with 16 GB or more, G1 otherwise.</span>
          </div>

          <div class="field-box">
            <span class="field-title">Java arguments</span>
            <input class="field-input" value="-XX:+UseG1GC" />
          </div>

          <div class="pill-actions-grid">
            <button class="action-pill-btn">Optimize</button>
            <button class="action-pill-btn" onclick="alert('Folder opened in Explorer: %APPDATA%\\\\.ember\\\\instances\\\\111')">Open folder</button>
            <button class="action-pill-btn">Duplicate</button>
            <button class="action-pill-btn" onclick="alert('Live console log viewer opened')">Logs</button>
            <button class="action-pill-btn">Export .mrpack</button>
            <button class="action-pill-btn" style="color: var(--danger)">Delete</button>
          </div>
        </div>

        <div class="modal-footer">
          <button class="text-link-btn" id="btnCancelInstSettings">Cancel</button>
          <button class="btn-primary-pill" id="btnSaveInstSettings">Save</button>
        </div>
      </div>
    </div>

    <!-- New Instance Modal -->
    <div class="modal-overlay" id="newInstanceModal">
      <div class="modal-dialog">
        <div class="modal-head">
          <div>
            <span style="font-size: 9px; font-family: 'DM Mono'; color: var(--text-muted)">NEW INSTANCE</span>
            <h3 style="margin: 2px 0 0 0;">Name your adventure</h3>
          </div>
          <button class="modal-close-btn" id="btnCloseNewInstance">×</button>
        </div>

        <div class="modal-body">
          <div style="display: flex; align-items: center; justify-content: center; gap: 8px; margin: 4px 0 12px 0;">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: var(--accent)"></span>
            <span style="width: 30px; height: 1px; background: #332f33"></span>
            <span style="width: 6px; height: 6px; border-radius: 50%; background: #332f33"></span>
            <span style="width: 30px; height: 1px; background: #332f33"></span>
            <span style="width: 6px; height: 6px; border-radius: 50%; background: #332f33"></span>
          </div>

          <div style="display: flex; gap: 6px;">
            <span class="filter-capsule active" style="flex: 1; text-align: center;">Custom</span>
            <span class="filter-capsule" style="flex: 1; text-align: center;">Import .mrpack</span>
            <span class="filter-capsule" style="flex: 1; text-align: center;">Describe with AI</span>
          </div>

          <div class="field-box" style="margin-top: 12px;">
            <span class="field-title">Instance name</span>
            <input class="field-input" value="Vanilla 26.3" />
          </div>

          <div style="background: #181618; border: 1px solid #282428; border-radius: 12px; padding: 14px; display: flex; align-items: center; gap: 12px;">
            <div style="width: 34px; height: 34px; border-radius: 9px; background: var(--accent); display: flex; align-items: center; justify-content: center;">
              <div style="width: 14px; height: 14px; background: #1c120c; border-radius: 4px;"></div>
            </div>
            <div>
              <span style="font-size: 8px; font-family: 'DM Mono'; color: var(--text-muted)">YOUR NEW INSTANCE</span>
              <strong style="display: block; font-size: 12px;">Vanilla 26.3</strong>
            </div>
          </div>
        </div>

        <div class="modal-footer">
          <button class="text-link-btn" id="btnCancelNewInstance">Cancel</button>
          <button class="btn-primary-pill" id="btnContinueNewInstance">Continue →</button>
        </div>
      </div>
    </div>
  </div>

  <script>
    // Tab Navigation
    const tabs = ['Home', 'Instances', 'Social', 'Explore', 'Skins', 'Settings'];
    const titles = {{
      Home: 'Welcome home.',
      Instances: 'Instances',
      Social: 'Social',
      Explore: 'Explore',
      Skins: 'Skins',
      Settings: 'Settings',
    }};

    function switchTab(name) {{
      tabs.forEach(t => {{
        const btn = document.querySelector(`[data-tab="${{t}}"]`);
        const content = document.getElementById(`tab${{t}}`);
        if (t === name) {{
          btn.classList.add('active');
          content.classList.add('active');
        }} else {{
          btn.classList.remove('active');
          content.classList.remove('active');
        }}
      }});
      document.getElementById('screenTitle').innerText = titles[name] || name;
    }}

    document.querySelectorAll('.nav-item[data-tab]').forEach(btn => {{
      btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    }});

    // TopBar Profile click
    document.getElementById('btnProfile').addEventListener('click', () => switchTab('Settings'));
    document.getElementById('inputDisplayName').addEventListener('input', (e) => {{
      document.getElementById('topbarDisplayName').innerText = e.target.value;
    }});

    // Friends Drawer
    const drawer = document.getElementById('friendsDrawerPanel');
    const backdrop = document.getElementById('drawerBackdrop');
    document.getElementById('btnFriendsDrawer').addEventListener('click', () => {{
      drawer.classList.add('open');
      backdrop.classList.add('open');
    }});
    document.getElementById('btnCloseFriendsDrawer').addEventListener('click', () => {{
      drawer.classList.remove('open');
      backdrop.classList.remove('open');
    }});
    backdrop.addEventListener('click', () => {{
      drawer.classList.remove('open');
      backdrop.classList.remove('open');
    }});
    document.getElementById('btnOpenSocialFromDrawer').addEventListener('click', () => {{
      drawer.classList.remove('open');
      backdrop.classList.remove('open');
      switchTab('Social');
    }});

    // Instance Settings Modal
    const instModal = document.getElementById('instSettingsModal');
    function openInstSettings(name) {{
      document.getElementById('inputInstName').value = name;
      document.getElementById('modalInstSubtitle').innerText = name === '111' ? '26.3 · NeoForge' : '26.3 · Vanilla';
      instModal.classList.add('open');
    }}
    document.getElementById('btnOpenInstSettings').addEventListener('click', () => openInstSettings('111'));
    document.getElementById('btnCloseInstSettings').addEventListener('click', () => instModal.classList.remove('open'));
    document.getElementById('btnCancelInstSettings').addEventListener('click', () => instModal.classList.remove('open'));
    document.getElementById('btnSaveInstSettings').addEventListener('click', () => {{
      const n = document.getElementById('inputInstName').value;
      document.getElementById('heroInstanceName').innerText = n;
      document.getElementById('playBtnSub').innerText = n;
      instModal.classList.remove('open');
    }});
    document.getElementById('inputInstMemory').addEventListener('input', (e) => {{
      document.getElementById('sliderMemoryVal').innerText = `${{e.target.value}} GB`;
    }});

    // New Instance Modal
    const newModal = document.getElementById('newInstanceModal');
    document.getElementById('btnNewInstanceModal').addEventListener('click', () => newModal.classList.add('open'));
    document.getElementById('btnCloseNewInstance').addEventListener('click', () => newModal.classList.remove('open'));
    document.getElementById('btnCancelNewInstance').addEventListener('click', () => newModal.classList.remove('open'));
    document.getElementById('btnContinueNewInstance').addEventListener('click', () => newModal.classList.remove('open'));

    // Launch button feedback
    let isLaunching = false;
    document.getElementById('btnLaunchPlay').addEventListener('click', () => {{
      if (isLaunching) return;
      isLaunching = true;
      document.getElementById('playBtnTitle').innerText = 'PREPARING...';
      document.getElementById('playBtnSub').innerText = 'Checking files...';
      setTimeout(() => {{
        isLaunching = false;
        document.getElementById('playBtnTitle').innerText = 'Play';
        document.getElementById('playBtnSub').innerText = document.getElementById('heroInstanceName').innerText;
      }}, 3000);
    }});

    // Select and Play from Instances
    window.selectAndPlay = function(name, ver, loader) {{
      document.getElementById('heroInstanceName').innerText = name;
      document.getElementById('heroVersionLabel').innerText = ver;
      document.getElementById('heroLoader').innerText = `${{loader}} · 0 mods`;
      document.getElementById('playBtnSub').innerText = name;
      switchTab('Home');
    }};

    // Lightweight 3D Skin Renderer on Canvas
    const canvas = document.getElementById('skinCanvas');
    if (canvas) {{
      const ctx = canvas.getContext('2d');
      let angle = 0.2;
      let isDragging = false;
      let startX = 0;

      canvas.addEventListener('mousedown', (e) => {{ isDragging = true; startX = e.clientX; }});
      window.addEventListener('mousemove', (e) => {{
        if (!isDragging) return;
        angle += (e.clientX - startX) * 0.02;
        startX = e.clientX;
      }});
      window.addEventListener('mouseup', () => {{ isDragging = false; }});

      function drawChar() {{
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const cx = canvas.width / 2;
        const cy = canvas.height / 2 + 10;

        if (!isDragging) angle += 0.008;
        const cos = Math.cos(angle);
        const sin = Math.sin(angle);

        // Ground shadow
        ctx.fillStyle = 'rgba(0,0,0,0.35)';
        ctx.beginPath();
        ctx.ellipse(cx, cy + 100, 45, 16, 0, 0, Math.PI * 2);
        ctx.fill();

        ctx.save();
        ctx.translate(cx, cy);

        // Isometric pseudo-3D blocky figure
        // Legs
        ctx.fillStyle = '#546b63';
        ctx.fillRect(-18 + sin * 4, 30, 16, 65);
        ctx.fillStyle = '#445b53';
        ctx.fillRect(2 - sin * 4, 30, 16, 65);

        // Torso
        ctx.fillStyle = '#82a59a';
        ctx.fillRect(-22, -35, 44, 65);

        // Arms
        ctx.fillStyle = '#72958a';
        ctx.fillRect(-36 - sin * 6, -35, 14, 65);
        ctx.fillStyle = '#92b5aa';
        ctx.fillRect(22 + sin * 6, -35, 14, 65);

        // Head
        ctx.fillStyle = '#c8987b';
        ctx.fillRect(-24, -90, 48, 48);

        // Eyes & Hair
        ctx.fillStyle = '#4a2c16';
        ctx.fillRect(-24, -90, 48, 14); // Hair
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(-14 + cos * 6, -68, 8, 6); // Left eye
        ctx.fillRect(6 + cos * 6, -68, 8, 6);  // Right eye

        ctx.restore();
        requestAnimationFrame(drawChar);
      }}
      drawChar();
    }}
  </script>
</body>
</html>
"""

with open('windows/preview.html', 'w', encoding='utf-8') as f:
    f.write(html)
print(f"Generated 100% self-contained windows/preview.html ({len(html)} bytes)")
