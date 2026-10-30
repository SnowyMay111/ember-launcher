import re

css_path = 'design/ember-v2/exact_styles.css'
with open(css_path, 'r', encoding='utf-8') as f:
    css_content = f.read()

react_app = """
const { useState, useEffect, useRef } = React;

// Feather & System SVG Icons
const Icons = {
  home: (props) => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
      <polyline points="9 22 9 12 15 12 15 22"/>
    </svg>
  ),
  grid: (props) => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <rect x="3" y="3" width="7" height="7" rx="1.5"/>
      <rect x="14" y="3" width="7" height="7" rx="1.5"/>
      <rect x="3" y="14" width="7" height="7" rx="1.5"/>
      <rect x="14" y="14" width="7" height="7" rx="1.5"/>
    </svg>
  ),
  social: (props) => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
      <circle cx="9" cy="7" r="4"/>
      <path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
      <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
    </svg>
  ),
  download: (props) => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M12 3v12"/>
      <path d="m7 10 5 5 5-5"/>
      <path d="M5 21h14"/>
    </svg>
  ),
  shirt: (props) => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M20.38 3.46 16 2a4 4 0 0 1-8 0L3.62 3.46a2 2 0 0 0-1.34 2.23l.58 3.5a2 2 0 0 0 1.5 1.63L6 11.2V20a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-8.8l1.64-.38a2 2 0 0 0 1.5-1.63l.58-3.5a2 2 0 0 0-1.34-2.23z"/>
    </svg>
  ),
  settings: (props) => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <circle cx="12" cy="12" r="3"/>
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
    </svg>
  ),
  chevronDown: (props) => (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <polyline points="6 9 12 15 18 9"/>
    </svg>
  ),
  play: (props) => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" {...props}>
      <polygon points="5 3 19 12 5 21 5 3"/>
    </svg>
  ),
  folder: (props) => (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z"/>
    </svg>
  ),
  sliders: (props) => (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <line x1="4" x2="4" y1="21" y2="14"/>
      <line x1="4" x2="4" y1="10" y2="3"/>
      <line x1="12" x2="12" y1="21" y2="12"/>
      <line x1="12" x2="12" y1="8" y2="3"/>
      <line x1="20" x2="20" y1="21" y2="16"/>
      <line x1="20" x2="20" y1="12" y2="3"/>
      <line x1="1" x2="7" y1="14" y2="14"/>
      <line x1="9" x2="15" y1="8" y2="8"/>
      <line x1="17" x2="23" y1="16" y2="16"/>
    </svg>
  )
};

// Ember Logo SVG
const EmberLogo = () => (
  <svg className="sidebar-logo" viewBox="0 0 64 64" fill="none">
    <defs>
      <linearGradient id="emberTile" x1="10" y1="8" x2="54" y2="58" gradientUnits="userSpaceOnUse">
        <stop stopColor="#462c42"/>
        <stop offset="1" stopColor="#442a22"/>
      </linearGradient>
      <linearGradient id="emberGem" x1="32" y1="16" x2="32" y2="48" gradientUnits="userSpaceOnUse">
        <stop stopColor="#c87fe2"/>
        <stop offset="0.5" stopColor="#d989b5"/>
        <stop offset="1" stopColor="#f2a064"/>
      </linearGradient>
    </defs>
    <rect x="4" y="4" width="56" height="56" rx="16" fill="#1e181c"/>
    <rect x="6" y="6" width="52" height="52" rx="14" fill="url(#emberTile)"/>
    <path d="M32 16L48 32L32 48L16 32Z" fill="url(#emberGem)"/>
  </svg>
);

// 3D Minecraft Character Canvas using Three.js
const ThreeSkinViewer = ({ skinColor = 0xb97b58 }) => {
  const mountRef = useRef(null);

  useEffect(() => {
    if (!mountRef.current || typeof THREE === 'undefined') return;
    const width = mountRef.current.clientWidth || 320;
    const height = mountRef.current.clientHeight || 340;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(34, width / height, 0.5, 50);
    camera.position.set(0, 0, 4.3);

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: false });
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio || 1);
    mountRef.current.replaceChildren(renderer.domElement);

    const amb = new THREE.AmbientLight(0xffffff, 0.75);
    scene.add(amb);
    const dir = new THREE.DirectionalLight(0xffffff, 0.65);
    dir.position.set(3, 4, 4);
    scene.add(dir);

    const group = new THREE.Group();
    scene.add(group);

    const s = 0.07;
    const skinMat = new THREE.MeshLambertMaterial({ color: 0xc8987b });
    const hairMat = new THREE.MeshLambertMaterial({ color: 0x4a2c16 });
    const shirtMat = new THREE.MeshLambertMaterial({ color: 0x82a59a });
    const pantsMat = new THREE.MeshLambertMaterial({ color: 0x546b63 });

    // Head & Hair
    const head = new THREE.Mesh(new THREE.BoxGeometry(8*s, 8*s, 8*s), skinMat);
    head.position.y = 12*s;
    group.add(head);

    // Torso
    const torso = new THREE.Mesh(new THREE.BoxGeometry(8*s, 12*s, 4*s), shirtMat);
    torso.position.y = 2*s;
    group.add(torso);

    // Arms
    const lArm = new THREE.Mesh(new THREE.BoxGeometry(3*s, 12*s, 4*s), shirtMat);
    lArm.position.set(-5.5*s, 2*s, 0);
    group.add(lArm);
    const rArm = new THREE.Mesh(new THREE.BoxGeometry(3*s, 12*s, 4*s), shirtMat);
    rArm.position.set(5.5*s, 2*s, 0);
    group.add(rArm);

    // Legs
    const lLeg = new THREE.Mesh(new THREE.BoxGeometry(4*s, 12*s, 4*s), pantsMat);
    lLeg.position.set(-2*s, -10*s, 0);
    group.add(lLeg);
    const rLeg = new THREE.Mesh(new THREE.BoxGeometry(4*s, 12*s, 4*s), pantsMat);
    rLeg.position.set(2*s, -10*s, 0);
    group.add(rLeg);

    // Shadow plane
    const shadowMat = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.35 });
    const shadow = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 0.8), shadowMat);
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = -1.18;
    scene.add(shadow);

    let isDown = false;
    let prevX = 0, prevY = 0;
    let rotY = 0.2, rotX = 0.08;

    const onDown = (e) => { isDown = true; prevX = e.clientX; prevY = e.clientY; };
    const onMove = (e) => {
      if (!isDown) return;
      rotY += (e.clientX - prevX) * 0.015;
      rotX = Math.max(-0.5, Math.min(0.5, rotX + (e.clientY - prevY) * 0.015));
      prevX = e.clientX; prevY = e.clientY;
    };
    const onUp = () => { isDown = false; };

    const dom = renderer.domElement;
    dom.addEventListener('mousedown', onDown);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);

    let frameId;
    const animate = () => {
      if (!isDown) rotY += 0.005;
      group.rotation.y = rotY;
      group.rotation.x = rotX;
      renderer.render(scene, camera);
      frameId = requestAnimationFrame(animate);
    };
    animate();

    return () => {
      cancelAnimationFrame(frameId);
      dom.removeEventListener('mousedown', onDown);
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
      renderer.dispose();
    };
  }, [skinColor]);

  return <div ref={mountRef} style={{ width: '100%', height: '340px', cursor: 'grab' }} />;
};

function App() {
  const [tab, setTab] = useState('Home'); // 'Home' | 'Instances' | 'Social' | 'Explore' | 'Skins' | 'Settings'
  const [friendsDrawer, setFriendsDrawer] = useState(false);
  const [settingsModal, setSettingsModal] = useState(false);
  const [newInstanceModal, setNewInstanceModal] = useState(false);
  const [activeInstance, setActiveInstance] = useState({ name: '111', loader: 'NeoForge · 0 mods', version: 'NeoForge 26.3', played: 'Never played' });
  const [launching, setLaunching] = useState(false);

  // Settings states
  const [settingsTab, setSettingsTab] = useState('General');
  const [displayName, setDisplayName] = useState('kotiki');
  const [autoUpdate, setAutoUpdate] = useState(true);
  const [closeAfterStart, setCloseAfterStart] = useState(true);

  // Instance Settings Modal states
  const [instName, setInstName] = useState('111');
  const [instMemory, setInstMemory] = useState(6);
  const [instGc, setInstGc] = useState('Automatic');
  const [instArgs, setInstArgs] = useState('-XX:+UseG1GC');

  // Instances list
  const [instances, setInstances] = useState([
    { name: 'уцй', version: '26.3 · Vanilla', loaderBadge: 'Vanilla', mods: '0 mods', ram: '6 GB RAM', time: '0 h 0 min', last: 'Never played' },
    { name: 'уцйуй', version: '1.21.11 · Vanilla', loaderBadge: 'Vanilla', mods: '0 mods', ram: '6 GB RAM', time: '0 h 0 min', last: 'Never played' },
    { name: '111', version: '26.3 · NeoForge', loaderBadge: 'NeoForge', mods: '0 mods', ram: '6 GB RAM', time: '0 h 0 min', last: 'Never played' },
  ]);

  const handleLaunch = () => {
    if (launching) return;
    setLaunching(true);
    setTimeout(() => setLaunching(false), 3000);
  };

  const navTitles = {
    Home: 'Welcome home.',
    Instances: 'Instances',
    Social: 'Social',
    Explore: 'Explore',
    Skins: 'Skins',
    Settings: 'Settings',
  };

  return (
    <div className="app-container">
      <div className="grid-overlay" />
      <div className="ambient-glow glow-purple" />
      <div className="ambient-glow glow-amber" />

      {/* Sidebar */}
      <aside className="sidebar">
        <div className="traffic-lights">
          <span className="traffic-dot dot-red" />
          <span className="traffic-dot dot-yellow" />
          <span className="traffic-dot dot-green" />
        </div>

        <EmberLogo />

        <div className="nav-group">
          <button className={`nav-item ${tab === 'Home' ? 'active' : ''}`} onClick={() => setTab('Home')} title="Play (1)">
            <Icons.home />
          </button>
          <button className={`nav-item ${tab === 'Instances' ? 'active' : ''}`} onClick={() => setTab('Instances')} title="Library (2)">
            <Icons.grid />
          </button>
          <button className={`nav-item ${tab === 'Social' ? 'active' : ''}`} onClick={() => setTab('Social')} title="Social (3)">
            <Icons.social />
          </button>
          <button className={`nav-item ${tab === 'Explore' ? 'active' : ''}`} onClick={() => setTab('Explore')} title="Explore (4)">
            <Icons.download />
          </button>
          <button className={`nav-item ${tab === 'Skins' ? 'active' : ''}`} onClick={() => setTab('Skins')} title="Skins (5)">
            <Icons.shirt />
          </button>
        </div>

        <div className="sidebar-bottom">
          <span className="status-indicator" title="All systems operational" />
          <button className={`nav-item ${tab === 'Settings' ? 'active' : ''}`} onClick={() => setTab('Settings')} title="Settings (6)">
            <Icons.settings />
          </button>
        </div>
      </aside>

      {/* Workspace */}
      <main className="workspace">
        {/* TopBar */}
        <header className="topbar">
          <div className="topbar-titles">
            <p className="eyebrow">Welcome back</p>
            <h1>{navTitles[tab]}</h1>
          </div>

          <div className="topbar-actions">
            {/* Friends Pill */}
            <button className="pill-button" onClick={() => setFriendsDrawer(true)}>
              <div className="avatar-bubbles">
                <span className="avatar-m">M</span>
                <span className="avatar-l">L</span>
                <span className="avatar-n">N</span>
              </div>
              <div className="pill-text">
                <strong>3 online</strong>
                <small>Friends</small>
              </div>
              <Icons.chevronDown />
            </button>

            {/* Profile Pill */}
            <button className="pill-button" onClick={() => setTab('Settings')}>
              <div className="pixel-steve" />
              <div className="pill-text">
                <strong>{displayName}</strong>
                <small style={{ color: 'var(--success)' }}>Online</small>
              </div>
              <Icons.chevronDown />
            </button>
          </div>
        </header>

        {/* Dynamic Content Viewport */}
        <div className="content-area">
          {tab === 'Home' && (
            <div className="home-layout">
              <div className="hero-viewport">
                <div className="hero-celestial" />
                <div className="hero-terrain">
                  <div className="terrain-slope-far" />
                  <div className="terrain-slope-near" />
                  <span className="pine-silhouette pine-1" />
                  <span className="pine-silhouette pine-2" />
                  <span className="pine-silhouette pine-3" />
                  <span className="pine-silhouette pine-4" />
                </div>

                <div className="hero-info-card">
                  <h2 className="hero-instance-title">{activeInstance.name}</h2>
                  <div className="hero-instance-meta">
                    <span className="amber-dot" />
                    <span className="meta-tag">LAST PLAYED</span>
                    <span className="meta-value">{activeInstance.played}</span>
                    <span className="meta-divider" />
                    <span className="meta-loader">{activeInstance.loader}</span>
                  </div>
                </div>
              </div>

              <div className="launch-bar">
                <div className="version-card" onClick={() => setTab('Instances')}>
                  <div className="voxel-icon-box">
                    <div className="voxel-block" />
                  </div>
                  <div className="version-texts">
                    <span className="version-label">Version</span>
                    <strong className="version-name">{activeInstance.version}</strong>
                  </div>
                  <Icons.chevronDown />
                </div>

                <button className="settings-btn-card" onClick={() => setSettingsModal(true)} title="Instance settings">
                  <Icons.settings />
                </button>

                <button className="play-btn-card" onClick={handleLaunch}>
                  <div className="play-circle">
                    <Icons.play />
                  </div>
                  <div className="play-texts">
                    <span className="play-title">{launching ? 'PREPARING...' : 'Play'}</span>
                    <span className="play-subtitle">{launching ? 'Checking files...' : activeInstance.name}</span>
                  </div>
                </button>
              </div>
            </div>
          )}

          {tab === 'Instances' && (
            <div>
              <div className="section-header">
                <div className="section-header-left">
                  <p className="section-eyebrow">Your worlds</p>
                  <h2>Instances</h2>
                  <p>Every world, safe and ready when you are.</p>
                </div>
                <button className="btn-primary-pill" onClick={() => setNewInstanceModal(true)}>
                  ＋ New instance
                </button>
              </div>

              <div className="search-input-box">
                <span>⌕</span>
                <input placeholder="Search instances" />
              </div>

              <div className="filters-bar">
                <div className="filter-capsules">
                  <span className="filter-capsule active">All</span>
                  <span className="filter-capsule">Vanilla</span>
                  <span className="filter-capsule">Fabric</span>
                  <span className="filter-capsule">Forge</span>
                  <span className="filter-capsule">NeoForge</span>
                  <span className="filter-capsule">All versions</span>
                </div>
                <span className="instances-count-text">3 instances · 0 h 0 min · 0 mods</span>
              </div>

              <div className="instances-cards-grid">
                {instances.map((inst) => (
                  <div className="instance-item-card" key={inst.name}>
                    <div className="card-banner">
                      <span className="banner-badge">● {inst.loaderBadge}</span>
                      <div className="banner-moon" />
                    </div>
                    <div className="card-content">
                      <div className="card-row-top">
                        <div className="card-title-group">
                          <h3>{inst.name}</h3>
                          <p>{inst.version}</p>
                        </div>
                        <button className="btn-card-play" onClick={() => { setActiveInstance({ ...inst, loader: `${inst.loaderBadge} · 0 mods` }); setTab('Home'); }}>
                          <Icons.play /> Play
                        </button>
                      </div>

                      <div className="card-chips-row">
                        <span className="meta-chip">🧩 {inst.mods}</span>
                        <span className="meta-chip">💾 {inst.ram}</span>
                        <span className="meta-chip">⏱ {inst.time}</span>
                      </div>

                      <div className="card-footer-row">
                        <span>{inst.last}</span>
                        <div className="card-footer-actions" onClick={() => { setInstName(inst.name); setSettingsModal(true); }}>
                          <Icons.folder />
                          <Icons.sliders />
                          <strong>Manage</strong>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {tab === 'Social' && (
            <div>
              <div className="section-header">
                <div className="section-header-left">
                  <p className="section-eyebrow">PLAY TOGETHER</p>
                  <h2>Social</h2>
                  <p>A quiet place for friends, invitations, and temporary worlds.</p>
                </div>
                <button className="btn-primary-pill" onClick={() => alert('Temporary peer lobby created on port 25565!')}>
                  ＋ Create lobby
                </button>
              </div>

              <div className="social-panels-grid">
                {/* Column 1: Friends */}
                <div className="social-column-card">
                  <div className="social-column-header">
                    <h4>FRIENDS</h4>
                    <span>3 online</span>
                  </div>
                  {[
                    { name: 'Mossy', status: 'Building in 1.21.4', online: true },
                    { name: 'Luna', status: 'In the main menu', online: true },
                    { name: 'North', status: 'Exploring Ember Valley', online: true },
                    { name: 'Rowan', status: 'Offline · 2h ago', online: false },
                  ].map((f) => (
                    <div className="friend-row" key={f.name}>
                      <div className="friend-row-left">
                        <div className="avatar-square">{f.name[0]}</div>
                        <div className="friend-names">
                          <strong>{f.name}</strong>
                          <small>{f.status}</small>
                        </div>
                      </div>
                      <span className={`friend-dot ${f.online ? '' : 'offline'}`} />
                    </div>
                  ))}
                  <div style={{ marginTop: 'auto', paddingTop: '10px' }}>
                    <span style={{ fontSize: '10px', color: 'var(--text-muted)', cursor: 'pointer' }}>View all friends →</span>
                  </div>
                </div>

                {/* Column 2: Active Lobbies */}
                <div className="social-column-card">
                  <div className="social-column-header">
                    <h4>ACTIVE LOBBIES</h4>
                    <span>Friends only</span>
                  </div>
                  <div className="lobby-feature-card">
                    <div className="lobby-feature-banner">
                      <div className="banner-moon" />
                    </div>
                    <div className="lobby-feature-body">
                      <span className="lobby-players-count">2 / 8 PLAYERS</span>
                      <h4 className="lobby-title">Birch Hollow evening</h4>
                      <p className="lobby-subtitle">Mossy is hosting · Fabric 1.21.4</p>
                      <div className="lobby-avatars-row">
                        <div className="avatar-bubbles">
                          <span className="avatar-m">M</span>
                          <span className="avatar-l">L</span>
                        </div>
                        <span>+ invite</span>
                      </div>
                      <button className="btn-primary-pill" style={{ width: '100%', justifyContent: 'center', marginTop: '6px' }}>
                        Join lobby
                      </button>
                    </div>
                  </div>

                  <div className="dashed-create-box">
                    <div>
                      <strong>Start from your world</strong>
                      <small>Friends join without changing your instance.</small>
                    </div>
                    <button className="btn-dark-pill" onClick={() => alert('Lobby started!')}>Create</button>
                  </div>
                </div>

                {/* Column 3: Invites */}
                <div className="social-column-card">
                  <div className="social-column-header">
                    <h4>INVITES</h4>
                    <span>1 new</span>
                  </div>
                  <div style={{ background: '#181618', border: '1px solid #282428', borderRadius: '12px', padding: '14px' }}>
                    <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                      <div className="avatar-square" style={{ background: '#453545' }}>N</div>
                      <div>
                        <strong style={{ fontSize: '11px', display: 'block' }}>North invited you</strong>
                        <small style={{ fontSize: '9px', color: 'var(--text-muted)' }}>Old Pines · Vanilla 1.21.4</small>
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: '8px', marginTop: '12px' }}>
                      <button className="btn-primary-pill" style={{ flex: 1, justifyContent: 'center' }}>Accept</button>
                      <button className="btn-dark-pill" style={{ flex: 1, justifyContent: 'center' }}>Later</button>
                    </div>
                  </div>

                  <div style={{ marginTop: '16px' }}>
                    <span style={{ fontSize: '9px', fontFamily: 'DM Mono', color: 'var(--text-dim)', letterSpacing: '0.08em' }}>RECENT PLAYERS</span>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '8px', fontSize: '10px', color: 'var(--text-muted)' }}>
                      <div>Luna · 2 days ago</div>
                      <div>Rowan · 5 days ago</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {tab === 'Explore' && (
            <div>
              <div className="section-header">
                <div className="section-header-left">
                  <p className="section-eyebrow">Discover</p>
                  <h2>Mods</h2>
                  <p>For 111 · 26.3 · NeoForge</p>
                </div>
                <button className="btn-dark-pill">Check for updates</button>
              </div>

              <div className="filter-capsules" style={{ marginBottom: '40px' }}>
                <span className="filter-capsule active">Installed</span>
                <span className="filter-capsule">Browse</span>
              </div>

              <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text-dim)', fontSize: '13px' }}>
                No mods yet. Open Browse to add some.
              </div>
            </div>
          )}

          {tab === 'Skins' && (
            <div>
              <div className="section-header">
                <div className="section-header-left">
                  <p className="section-eyebrow">WARDROBE</p>
                  <h2>Skins</h2>
                  <p>Choose how you arrive in every world.</p>
                </div>
                <div style={{ display: 'flex', gap: '10px' }}>
                  <button className="btn-dark-pill">✦ Skin Catalog</button>
                  <button className="btn-primary-pill">＋ Import skin</button>
                </div>
              </div>

              <div className="skins-view-grid">
                <div className="skin-stage-box">
                  <div className="skin-stage-toggles">
                    <div className="segmented-control">
                      <button className="segment-btn active">3D Boba</button>
                      <button className="segment-btn">2D Flat</button>
                    </div>
                    <button className="btn-dark-pill" style={{ padding: '4px 10px', fontSize: '10px' }}>✦ Catalog</button>
                  </div>

                  <ThreeSkinViewer />

                  <div className="stage-foot-note">
                    <strong style={{ color: 'var(--text-muted)', display: 'block', marginBottom: '2px' }}>c1b51b81eb682f6e · Slim</strong>
                    Drag with mouse to rotate Boba 360° · Double-click to reset<br />
                    Skins are stored on this Mac. In offline mode the game shows its default skin; your selection is applied after Microsoft sign-in.
                  </div>
                </div>

                <div className="wardrobe-column">
                  <div className="wardrobe-collection-box">
                    <h4 className="collection-header">YOUR COLLECTION</h4>
                    <div className="skin-item-row">
                      <div className="skin-preview-thumb" />
                      <div className="skin-item-names">
                        <strong>95e4178fde89ceec</strong>
                        <small>Saved skin</small>
                      </div>
                    </div>
                    <div className="skin-item-row active">
                      <div className="skin-preview-thumb" style={{ background: '#d4987b' }} />
                      <div className="skin-item-names">
                        <strong>c1b51b81eb682f6e</strong>
                        <small style={{ color: 'var(--accent)' }}>Currently equipped</small>
                      </div>
                    </div>
                    <div className="skin-item-row">
                      <div className="skin-preview-thumb" style={{ background: '#5a463a' }} />
                      <div className="skin-item-names">
                        <strong>uzbek</strong>
                        <small>Saved skin</small>
                      </div>
                    </div>

                    <div className="model-toggle-row">
                      <span>Model</span>
                      <div className="segmented-control">
                        <button className="segment-btn">Classic (4px)</button>
                        <button className="segment-btn active">Slim (3px)</button>
                      </div>
                    </div>

                    <button className="btn-dark-pill" style={{ justifyContent: 'center', padding: '10px' }}>
                      ✓ Currently equipped
                    </button>

                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button className="btn-dark-pill" style={{ flex: 1, justifyContent: 'center' }}>Rename</button>
                      <button className="btn-dark-pill" style={{ flex: 1, justifyContent: 'center' }}>Remove</button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {tab === 'Settings' && (
            <div>
              <div className="section-header">
                <div className="section-header-left">
                  <p className="section-eyebrow">YOUR SPACE</p>
                  <h2>Settings</h2>
                  <p>A few thoughtful choices to make Ember feel like yours.</p>
                </div>
              </div>

              <div className="settings-grid-layout">
                <div className="settings-nav-list">
                  {['General', 'Java & memory', 'Downloads', 'Appearance', 'AI', 'About Ember'].map((s) => (
                    <button
                      className={`settings-nav-btn ${settingsTab === s ? 'active' : ''}`}
                      key={s}
                      onClick={() => setSettingsTab(s)}
                    >
                      {s}
                    </button>
                  ))}
                </div>

                <div className="settings-cards-col">
                  <div className="settings-banner-card">
                    <div className="settings-banner-left">
                      <EmberLogo />
                      <div>
                        <span style={{ fontSize: '9px', fontFamily: 'DM Mono', color: 'var(--text-muted)' }}>GENERAL</span>
                        <strong style={{ display: 'block', fontSize: '13px' }}>Everything feels good.</strong>
                        <small style={{ color: 'var(--text-muted)' }}>Your profile, worlds, and launcher behavior in one calm place.</small>
                      </div>
                    </div>
                    <span style={{ color: 'var(--success)', fontSize: '16px' }}>✓</span>
                  </div>

                  <div className="settings-section-card">
                    <div className="settings-card-head">PLAYER</div>
                    <div className="settings-row-item">
                      <div>
                        <strong>Display name</strong>
                        <small>Used for offline and local worlds.</small>
                      </div>
                      <input
                        className="settings-text-input"
                        value={displayName}
                        onChange={(e) => setDisplayName(e.target.value)}
                      />
                    </div>
                  </div>

                  <div className="settings-section-card">
                    <div className="settings-card-head">BEHAVIOR</div>
                    <div className="settings-row-item">
                      <div>
                        <strong>Automatic updates</strong>
                        <small>Keep Ember and game metadata current.</small>
                      </div>
                      <div
                        className={`switch-control ${autoUpdate ? 'active' : ''}`}
                        onClick={() => setAutoUpdate(!autoUpdate)}
                      >
                        <span className="switch-knob" />
                      </div>
                    </div>
                    <div className="settings-row-item">
                      <div>
                        <strong>Close launcher after start</strong>
                        <small>Save resources while Minecraft is running.</small>
                      </div>
                      <div
                        className={`switch-control ${closeAfterStart ? 'active' : ''}`}
                        onClick={() => setCloseAfterStart(!closeAfterStart)}
                      >
                        <span className="switch-knob" />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Friends Sliding Drawer */}
      {friendsDrawer && (
        <>
          <div className="drawer-backdrop" onClick={() => setFriendsDrawer(false)} />
          <aside className="friends-drawer-panel">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <span style={{ fontSize: '9px', fontFamily: 'DM Mono', color: 'var(--text-muted)' }}>FRIENDS</span>
                <h3 style={{ margin: '2px 0 0 0', fontSize: '15px' }}>3 people online</h3>
              </div>
              <button className="modal-close-btn" onClick={() => setFriendsDrawer(false)}>×</button>
            </div>

            <div style={{ background: '#181618', border: '1px solid #282428', borderRadius: '12px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px', fontFamily: 'DM Mono', color: 'var(--text-muted)' }}>
                <span>YOUR GROUP</span>
                <span>Quiet Crew · 3/8</span>
              </div>
              <div className="avatar-bubbles">
                <span className="avatar-m">M</span>
                <span className="avatar-l" style={{ background: '#3f4e54' }}>C</span>
                <span className="avatar-l">L</span>
                <span style={{ background: '#262226', border: '1px solid #3c363c', color: '#999' }}>+</span>
              </div>
              <button className="btn-dark-pill" style={{ justifyContent: 'center', padding: '6px 10px', fontSize: '10px' }}>
                Create lobby for group
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {[
                { name: 'Mossy', status: 'Building in 1.21.4', online: true },
                { name: 'Luna', status: 'In the main menu', online: true },
                { name: 'North', status: 'Exploring Ember Valley', online: true },
                { name: 'Rowan', status: 'Offline · 2h ago', online: false },
              ].map((f) => (
                <div className="friend-row" key={f.name}>
                  <div className="friend-row-left">
                    <div className="avatar-square">{f.name[0]}</div>
                    <div className="friend-names">
                      <strong>{f.name}</strong>
                      <small>{f.status}</small>
                    </div>
                  </div>
                  <span className={`friend-dot ${f.online ? '' : 'offline'}`} />
                </div>
              ))}
            </div>

            <div style={{ marginTop: 'auto', borderTop: '1px solid #1f1c1f', paddingTop: '14px' }}>
              <span style={{ fontSize: '11px', color: 'var(--text-muted)', cursor: 'pointer' }} onClick={() => { setFriendsDrawer(false); setTab('Social'); }}>
                Open Social center →
              </span>
            </div>
          </aside>
        </>
      )}

      {/* Instance Settings Modal matching /tmp/ember_real_mac.png */}
      {settingsModal && (
        <div className="modal-overlay" onClick={() => setSettingsModal(false)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <div>
                <h3>Instance settings</h3>
                <p>26.3 · NeoForge</p>
              </div>
              <button className="modal-close-btn" onClick={() => setSettingsModal(false)}>×</button>
            </div>

            <div className="modal-body">
              <div className="field-box">
                <span className="field-title">Name</span>
                <input
                  className="field-input"
                  value={instName}
                  onChange={(e) => setInstName(e.target.value)}
                />
              </div>

              <div className="field-box">
                <span className="field-title">Group</span>
                <select className="field-input" style={{ appearance: 'none' }}>
                  <option>Mods</option>
                  <option>Vanilla</option>
                </select>
              </div>

              <div className="field-box">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span className="field-title">Memory</span>
                  <strong style={{ fontSize: '11px', color: 'var(--text-main)' }}>{instMemory} GB</strong>
                </div>
                <input
                  type="range"
                  min="2"
                  max="16"
                  value={instMemory}
                  onChange={(e) => setInstMemory(Number(e.target.value))}
                  style={{ accentColor: 'var(--accent)', cursor: 'pointer' }}
                />
                <span className="field-help">Recommended: 6-8 GB</span>
              </div>

              <div className="field-box">
                <span className="field-title">Garbage collector</span>
                <select className="field-input" value={instGc} onChange={(e) => setInstGc(e.target.value)} style={{ appearance: 'none' }}>
                  <option>Automatic</option>
                  <option>Tuned G1GC</option>
                  <option>ZGC (Low latency)</option>
                </select>
                <span className="field-help">Automatic picks ZGC on Java 21+ with 16 GB or more, G1 otherwise.</span>
              </div>

              <div className="field-box">
                <span className="field-title">Java arguments</span>
                <input
                  className="field-input"
                  value={instArgs}
                  onChange={(e) => setInstArgs(e.target.value)}
                />
              </div>

              <div className="pill-actions-grid">
                <button className="action-pill-btn">Optimize</button>
                <button className="action-pill-btn" onClick={() => alert('Folder opened in Explorer: %APPDATA%\\.ember\\instances\\111')}>Open folder</button>
                <button className="action-pill-btn">Duplicate</button>
                <button className="action-pill-btn" onClick={() => alert('Live game logs viewer opened')}>Logs</button>
                <button className="action-pill-btn">Export .mrpack</button>
                <button className="action-pill-btn" style={{ color: 'var(--danger)' }}>Delete</button>
              </div>
            </div>

            <div className="modal-footer">
              <button className="text-link-btn" onClick={() => setSettingsModal(false)}>Cancel</button>
              <button className="btn-primary-pill" onClick={() => { setActiveInstance(prev => ({ ...prev, name: instName })); setSettingsModal(false); }}>
                Save
              </button>
            </div>
          </div>
        </div>
      )}

      {/* New Instance Modal matching /tmp/ember_new_instance.png */}
      {newInstanceModal && (
        <div className="modal-overlay" onClick={() => setNewInstanceModal(false)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <div>
                <span style={{ fontSize: '9px', fontFamily: 'DM Mono', color: 'var(--text-muted)' }}>NEW INSTANCE</span>
                <h3 style={{ margin: '2px 0 0 0' }}>Name your adventure</h3>
              </div>
              <button className="modal-close-btn" onClick={() => setNewInstanceModal(false)}>×</button>
            </div>

            <div className="modal-body">
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', margin: '4px 0 12px 0' }}>
                <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--accent)' }} />
                <span style={{ width: '30px', height: '1px', background: '#332f33' }} />
                <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#332f33' }} />
                <span style={{ width: '30px', height: '1px', background: '#332f33' }} />
                <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#332f33' }} />
              </div>

              <div style={{ display: 'flex', gap: '6px' }}>
                <span className="filter-capsule active" style={{ flex: 1, textAlign: 'center' }}>Custom</span>
                <span className="filter-capsule" style={{ flex: 1, textAlign: 'center' }}>Import .mrpack</span>
                <span className="filter-capsule" style={{ flex: 1, textAlign: 'center' }}>Describe with AI</span>
              </div>

              <div className="field-box" style={{ marginTop: '12px' }}>
                <span className="field-title">Instance name</span>
                <input className="field-input" defaultValue="Vanilla 26.3" />
              </div>

              <div style={{ background: '#181618', border: '1px solid #282428', borderRadius: '12px', padding: '14px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{ width: '34px', height: '34px', borderRadius: '9px', background: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <div style={{ width: '14px', height: '14px', background: '#1c120c', borderRadius: '4px' }} />
                </div>
                <div>
                  <span style={{ fontSize: '8px', fontFamily: 'DM Mono', color: 'var(--text-muted)' }}>YOUR NEW INSTANCE</span>
                  <strong style={{ display: 'block', fontSize: '12px' }}>Vanilla 26.3</strong>
                </div>
              </div>
            </div>

            <div className="modal-footer">
              <button className="text-link-btn" onClick={() => setNewInstanceModal(false)}>Cancel</button>
              <button className="btn-primary-pill" onClick={() => setNewInstanceModal(false)}>
                Continue →
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
"""

# Build preview.html
preview_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Ember Launcher</title>
  <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Manrope:wght@400;500;600;700;800&family=Playfair+Display:wght@500;600;700&display=swap" rel="stylesheet">
  <style>
{css_content}
  </style>
</head>
<body>
  <div id="root"></div>
  <script type="text/babel">
{react_app}
    ReactDOM.createRoot(document.getElementById('root')).render(<App />);
  </script>
</body>
</html>
"""

with open('windows/preview.html', 'w', encoding='utf-8') as f:
    f.write(preview_html)
print(f"Generated windows/preview.html ({len(preview_html)} bytes)")

# Build windows/frontend/src/App.tsx
app_tsx = f"""import React from 'react';
import './index.css';

{react_app}

export default App;
"""
with open('windows/frontend/src/App.tsx', 'w', encoding='utf-8') as f:
    f.write(app_tsx)
print(f"Generated windows/frontend/src/App.tsx ({len(app_tsx)} bytes)")

with open('windows/frontend/src/index.css', 'w', encoding='utf-8') as f:
    f.write(css_content)
print(f"Generated windows/frontend/src/index.css ({len(css_content)} bytes)")
