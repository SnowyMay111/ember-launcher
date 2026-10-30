const { useEffect, useState, useRef } = React;

const Icon = ({ name, size = 20 }) => {
  const paths = {
    home: <><path d="m3 10 9-7 9 7" /><path d="M5 9v11h14V9M9 20v-7h6v7" /></>,
    grid: <><rect x="4" y="4" width="6" height="6" rx="1" /><rect x="14" y="4" width="6" height="6" rx="1" /><rect x="4" y="14" width="6" height="6" rx="1" /><rect x="14" y="14" width="6" height="6" rx="1" /></>,
    shirt: <path d="m8 4-5 3 3 5 2-1v9h8v-9l2 1 3-5-5-3a4 4 0 0 1-8 0Z" />,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" /></>,
    download: <><path d="M12 3v12m-5-5 5 5 5-5" /><path d="M5 20h14" /></>,
    social: <><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></>,
    play: <path d="m9 7 8 5-8 5Z" fill="currentColor" />,
    chevron: <path d="m9 10 3 3 3-3" />,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {paths[name] || paths.home}
    </svg>
  );
};

const EmberLogo = ({ size = 32 }) => (
  <svg className="ember-logo" width={size} height={size} viewBox="0 0 64 64" fill="none" role="img" aria-label="Ember">
    <defs>
      <linearGradient id="ember-tile" x1="12" y1="8" x2="54" y2="58" gradientUnits="userSpaceOnUse">
        <stop stopColor="#4A3048" />
        <stop offset="1" stopColor="#4A2E27" />
      </linearGradient>
      <linearGradient id="ember-gem" x1="32" y1="18" x2="32" y2="46" gradientUnits="userSpaceOnUse">
        <stop stopColor="#C77FE2" />
        <stop offset=".52" stopColor="#D98AB8" />
        <stop offset="1" stopColor="#F2A164" />
      </linearGradient>
    </defs>
    <rect x="5" y="5" width="54" height="54" rx="18" fill="#211A20" />
    <rect x="7" y="7" width="50" height="50" rx="16" fill="url(#ember-tile)" />
    <path d="m32 17 15 15-15 15-15-15 15-15Z" fill="url(#ember-gem)" />
  </svg>
);

const navItems = [
  { icon: 'home', label: 'Home', title: 'Play (1)' },
  { icon: 'grid', label: 'Instances', title: 'Library (2)' },
  { icon: 'social', label: 'Social', title: 'Social (3)' },
  { icon: 'download', label: 'Mods', title: 'Explore (4)' },
  { icon: 'shirt', label: 'Skins', title: 'Skins (5)' },
];

const PageIntro = ({ eyebrow, title, copy, action, onAction }) => (
  <div className="page-intro">
    <div><p className="eyebrow">{eyebrow}</p><h2>{title}</h2><p>{copy}</p></div>
    {action && <button className="primary-small" onClick={onAction}>＋ {action}</button>}
  </div>
);

// 3D Minecraft Character (SceneKit/Three.js matching Skin3DView.swift)
const Skin3DStage = ({ skinIndex, isSlim, is3D }) => {
  const mountRef = useRef(null);
  const isDraggingRef = useRef(false);
  const prevMousePos = useRef({ x: 0, y: 0 });
  const rotationRef = useRef({ x: 0.1, y: 0.3 });

  const skinColors = [
    { head: '#c88d6b', body: '#3a4b6e', limbs: '#2b3447', hair: '#4a2c16' }, // Ember
    { head: '#b97b58', body: '#5c483a', limbs: '#3b2f27', hair: '#2a1a12' }, // Wanderer
    { head: '#a87858', body: '#422e54', limbs: '#22192b', hair: '#18121f' }, // Nightfall
    { head: '#b97b58', body: '#00aaaa', limbs: '#0000aa', hair: '#4a2c16' }, // Steve
    { head: '#d49b78', body: '#55aa55', limbs: '#7d5c34', hair: '#c65c27' }, // Alex
  ];

  useEffect(() => {
    if (!is3D || !mountRef.current || typeof THREE === 'undefined') return;

    const width = mountRef.current.clientWidth || 320;
    const height = mountRef.current.clientHeight || 380;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(36, width / height, 0.5, 50);
    camera.position.set(0, 0, 4.4);

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: false });
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio);
    mountRef.current.replaceChildren(renderer.domElement);

    const ambientLight = new THREE.AmbientLight(0xffffff, 0.72);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xffffff, 0.55);
    dirLight.position.set(2, 3, 4);
    scene.add(dirLight);

    const shadowGeo = new THREE.PlaneGeometry(1.4, 0.9);
    const shadowMat = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.35 });
    const shadow = new THREE.Mesh(shadowGeo, shadowMat);
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = -1.18;
    scene.add(shadow);

    const charGroup = new THREE.Group();
    scene.add(charGroup);

    const pal = skinColors[skinIndex % skinColors.length];
    const s = 0.07;
    const makeMat = (col) => new THREE.MeshLambertMaterial({ color: col });

    const head = new THREE.Mesh(new THREE.BoxGeometry(8 * s, 8 * s, 8 * s), makeMat(pal.head));
    head.position.set(0, 12 * s, 0);
    charGroup.add(head);

    const hat = new THREE.Mesh(new THREE.BoxGeometry(8.6 * s, 8.6 * s, 8.6 * s), makeMat(pal.hair));
    hat.position.set(0, 12.3 * s, 0);
    charGroup.add(hat);

    const torso = new THREE.Mesh(new THREE.BoxGeometry(8 * s, 12 * s, 4 * s), makeMat(pal.body));
    torso.position.set(0, 2 * s, 0);
    charGroup.add(torso);

    const armW = isSlim ? 3 * s : 4 * s;
    const leftArm = new THREE.Mesh(new THREE.BoxGeometry(armW, 12 * s, 4 * s), makeMat(pal.body));
    leftArm.position.set(-(4 * s + armW / 2), 2 * s, 0);
    charGroup.add(leftArm);

    const rightArm = new THREE.Mesh(new THREE.BoxGeometry(armW, 12 * s, 4 * s), makeMat(pal.body));
    rightArm.position.set(4 * s + armW / 2, 2 * s, 0);
    charGroup.add(rightArm);

    const leftLeg = new THREE.Mesh(new THREE.BoxGeometry(4 * s, 12 * s, 4 * s), makeMat(pal.limbs));
    leftLeg.position.set(-2 * s, -10 * s, 0);
    charGroup.add(leftLeg);

    const rightLeg = new THREE.Mesh(new THREE.BoxGeometry(4 * s, 12 * s, 4 * s), makeMat(pal.limbs));
    rightLeg.position.set(2 * s, -10 * s, 0);
    charGroup.add(rightLeg);

    let animationFrameId;
    const animate = () => {
      if (!isDraggingRef.current) {
        rotationRef.current.y += 0.007;
      }
      charGroup.rotation.y = rotationRef.current.y;
      charGroup.rotation.x = rotationRef.current.x;

      renderer.render(scene, camera);
      animationFrameId = requestAnimationFrame(animate);
    };
    animate();

    return () => {
      cancelAnimationFrame(animationFrameId);
      renderer.dispose();
    };
  }, [skinIndex, isSlim, is3D]);

  const onMouseDown = (e) => {
    isDraggingRef.current = true;
    prevMousePos.current = { x: e.clientX, y: e.clientY };
  };
  const onMouseMove = (e) => {
    if (!isDraggingRef.current) return;
    const deltaX = e.clientX - prevMousePos.current.x;
    const deltaY = e.clientY - prevMousePos.current.y;
    prevMousePos.current = { x: e.clientX, y: e.clientY };
    rotationRef.current.y += deltaX * 0.015;
    rotationRef.current.x = Math.max(-0.6, Math.min(0.6, rotationRef.current.x + deltaY * 0.015));
  };
  const onMouseUp = () => { isDraggingRef.current = false; };

  return (
    <div
      ref={mountRef}
      className="skin-3d-canvas"
      onMouseDown={onMouseDown}
      onMouseMove={onMouseMove}
      onMouseUp={onMouseUp}
      onMouseLeave={onMouseUp}
    />
  );
};

// Session Diagnostics Modal
const SessionDiagnosticsModal = ({ onClose }) => {
  const [fixed, setFixed] = useState(false);
  const score = 94;
  const radius = 36;
  const circ = 2 * Math.PI * radius;
  const offset = circ - (circ * score) / 100;

  return (
    <div className="flow" style={{ maxWidth: '560px' }}>
      <div className="flow-head">
        <div>
          <p className="eyebrow">SESSION HEALTH</p>
          <h2>Diagnostic Report</h2>
        </div>
        <button onClick={onClose}>×</button>
      </div>
      <div className="flow-body" style={{ gap: '16px' }}>
        <div className="health-gauge-box">
          <svg width="96" height="96" className="health-gauge-svg">
            <circle cx="48" cy="48" r={radius} className="health-gauge-bg" />
            <circle
              cx="48"
              cy="48"
              r={radius}
              className="health-gauge-val"
              style={{ strokeDasharray: circ, strokeDashoffset: offset }}
            />
          </svg>
          <span className="health-score-text">{score}</span>
          <small style={{ color: '#94a978', fontWeight: 600, marginTop: '8px', fontSize: '11px' }}>
            Perfect smoothness · 0 micro-freezes
          </small>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px' }}>
          <div style={{ background: '#161416', border: '1px solid #282428', borderRadius: '10px', padding: '10px' }}>
            <span style={{ fontSize: '8px', color: '#655f65', fontFamily: 'DM Mono' }}>GC FREEZES</span>
            <strong style={{ display: 'block', fontSize: '11px', marginTop: '3px' }}>0 (max 12ms)</strong>
          </div>
          <div style={{ background: '#161416', border: '1px solid #282428', borderRadius: '10px', padding: '10px' }}>
            <span style={{ fontSize: '8px', color: '#655f65', fontFamily: 'DM Mono' }}>WORLD LOAD</span>
            <strong style={{ display: 'block', fontSize: '11px', marginTop: '3px' }}>0 tick drops</strong>
          </div>
          <div style={{ background: '#161416', border: '1px solid #282428', borderRadius: '10px', padding: '10px' }}>
            <span style={{ fontSize: '8px', color: '#655f65', fontFamily: 'DM Mono' }}>JVM RAM</span>
            <strong style={{ display: 'block', fontSize: '11px', marginTop: '3px' }}>6 GB Assigned</strong>
          </div>
        </div>

        <div style={{ background: '#161416', border: '1px solid #282428', borderRadius: '11px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '11px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#94a978' }} />
            <span>Garbage Collector tuned with optimal G1GC pause thresholds (&lt;15ms)</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#94a978' }} />
            <span>DirectX High Performance GPU pipeline enabled for javaw.exe</span>
          </div>
        </div>

        {fixed && (
          <div style={{ background: 'rgba(148, 169, 120, 0.1)', border: '1px solid rgba(148, 169, 120, 0.3)', borderRadius: '9px', padding: '10px', color: '#94a978', fontSize: '11px' }}>
            High-speed chunk caching active! All issues resolved.
          </div>
        )}
      </div>
      <div className="flow-footer">
        <button className="secondary" onClick={onClose}>Close</button>
        <button className="primary-small" onClick={() => setFixed(true)}>
          {fixed ? 'Optimizations Active' : 'Fix automatically in 1 click'}
        </button>
      </div>
    </div>
  );
};

// Version Migration Modal
const VersionModal = ({ instanceName, onClose }) => {
  const [target, setTarget] = useState('1.21.1');
  const [done, setDone] = useState(false);

  return (
    <div className="flow" style={{ maxWidth: '520px' }}>
      <div className="flow-head">
        <div>
          <p className="eyebrow">SAFE UPGRADE</p>
          <h2>Change Version</h2>
        </div>
        <button onClick={onClose}>×</button>
      </div>
      <div className="flow-body" style={{ gap: '14px' }}>
        <p style={{ margin: 0, fontSize: '11px', color: '#817a73' }}>
          Current: <strong>{instanceName}</strong> · Minecraft 1.21.4 (Fabric)
        </p>
        <label className="field-label">
          NEW MINECRAFT VERSION
          <select
            className="flow-select"
            value={target}
            onChange={(e) => setTarget(e.target.value)}
          >
            <option value="1.21.1">Minecraft 1.21.1 (Fabric)</option>
            <option value="1.20.6">Minecraft 1.20.6 (Fabric)</option>
            <option value="1.20.1">Minecraft 1.20.1 (Massive Mod Ecosystem)</option>
          </select>
        </label>
        <div style={{ background: '#161416', border: '1px solid #282428', borderRadius: '11px', padding: '12px', fontSize: '11px' }}>
          <span>Mods with a compatible version: <strong>38 of 42</strong></span>
          <p style={{ margin: '4px 0 0', color: '#f0a062', fontSize: '10px' }}>
            Worlds and mods are backed up first. You can roll back anytime in 1 click.
          </p>
        </div>
        {done && (
          <div style={{ background: 'rgba(148, 169, 120, 0.1)', border: '1px solid rgba(148, 169, 120, 0.3)', borderRadius: '9px', padding: '10px', color: '#94a978', fontSize: '11px' }}>
            Upgraded to {target}! Snapshot before-{target} saved.
          </div>
        )}
      </div>
      <div className="flow-footer">
        <button className="secondary" onClick={onClose}>Cancel</button>
        <button className="primary-small" onClick={() => setDone(true)}>
          {done ? 'Done' : 'Change version'}
        </button>
      </div>
    </div>
  );
};

// Lobby Modal
const LobbyFlowModal = ({ onClose }) => {
  const [isCreated, setIsCreated] = useState(false);
  const [copied, setCopied] = useState(false);

  const copyCode = () => {
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="flow" style={{ maxWidth: '500px' }}>
      <div className="flow-head">
        <div>
          <p className="eyebrow">TEMPORARY LOBBY</p>
          <h2>{isCreated ? 'Lobby is ready' : 'Bring friends in'}</h2>
        </div>
        <button onClick={onClose}>×</button>
      </div>
      <div className="flow-body" style={{ gap: '14px' }}>
        {!isCreated ? (
          <>
            <p style={{ margin: 0, fontSize: '11px', color: '#817a73' }}>
              Host a temporary multiplayer session directly from your single-player world. No server required.
            </p>
            <label className="field-label">
              SELECT WORLD
              <select className="flow-select">
                <option>Birch Hollow (Survival)</option>
                <option>Ember Valley (Fabric · 42 mods)</option>
              </select>
            </label>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <span style={{ fontSize: '8px', color: '#6c666d', fontFamily: 'DM Mono' }}>PRIVACY</span>
              <div style={{ padding: '10px 14px', borderRadius: '10px', border: '1px solid #654e68', background: '#211b22', display: 'flex', justifyContent: 'space-between', fontSize: '11px' }}>
                <strong>Friends only</strong>
                <span style={{ color: '#817a73', fontSize: '10px' }}>Anyone on your friends list</span>
              </div>
            </div>
          </>
        ) : (
          <div style={{ textAlign: 'center', padding: '10px 0' }}>
            <span style={{ color: '#94a978', fontSize: '11px', fontWeight: 600 }}>● Lobby open on port 25565</span>
            <div style={{ background: '#161416', padding: '16px', borderRadius: '12px', border: '1px solid #282428', margin: '14px 0' }}>
              <span style={{ fontSize: '8px', fontFamily: 'DM Mono', color: '#817a73' }}>SHARE CODE</span>
              <h3 style={{ fontSize: '22px', letterSpacing: '0.1em', color: '#f0a062', margin: '6px 0 12px 0' }}>EMBER-7729-NORD</h3>
              <button className="primary-small" onClick={copyCode}>
                {copied ? 'Code Copied!' : 'Copy Invite Code'}
              </button>
            </div>
          </div>
        )}
      </div>
      <div className="flow-footer">
        <button className="secondary" onClick={onClose}>Close</button>
        {!isCreated && <button className="primary-small" onClick={() => setIsCreated(true)}>Create Lobby</button>}
      </div>
    </div>
  );
};

// New Instance Flow Modal
const NewInstanceFlow = ({ onClose, onCreate }) => {
  const [mode, setMode] = useState('custom'); // 'custom' | 'mrpack' | 'ai'
  const [step, setStep] = useState(1);
  const [name, setName] = useState('A quiet new world');
  const [loaderIndex, setLoaderIndex] = useState(1);
  const [version, setVersion] = useState('1.21.4');
  const [installing, setInstalling] = useState(false);

  const [aiPrompt, setAiPrompt] = useState('');
  const [aiPlan, setAiPlan] = useState(null);
  const [thinking, setThinking] = useState(false);

  const loaders = [
    ['Vanilla', 'The original experience'],
    ['Fabric', 'Lightweight and mod-friendly'],
    ['Forge', 'Built for expansive modpacks'],
    ['NeoForge', 'Modern community loader'],
  ];

  const handleSuggestAI = () => {
    setThinking(true);
    setTimeout(() => {
      setThinking(false);
      setAiPlan({
        summary: 'A cozy fantasy exploration pack with performance shaders, seasonal vegetation, and expanded campfire cooking.',
        mods: ['Sodium', 'Lithium', 'Iris Shaders', 'Fabric API', 'AppleSkin', 'JourneyMap']
      });
    }, 1400);
  };

  const next = () => {
    if (step < 3) {
      setStep(step + 1);
    } else {
      setInstalling(true);
      setTimeout(() => {
        onCreate([
          name || 'A quiet new world',
          version,
          loaders[loaderIndex][0],
          '0m',
          loaderIndex === 1 ? 'violet' : loaderIndex === 2 ? 'gold' : 'dusk'
        ]);
        onClose();
      }, 2200);
    }
  };

  return (
    <div className="flow">
      <div className="flow-head">
        <div>
          <p className="eyebrow">NEW INSTANCE</p>
          <h2>{installing ? 'Preparing your world' : ['Name your adventure', 'Choose a foundation', 'Ready to create'][step - 1]}</h2>
        </div>
        <button onClick={onClose}>×</button>
      </div>

      <div className="mode-switch-tabs">
        <button className={`mode-switch-btn ${mode === 'custom' ? 'active' : ''}`} onClick={() => setMode('custom')}>Custom Wizard</button>
        <button className={`mode-switch-btn ${mode === 'mrpack' ? 'active' : ''}`} onClick={() => setMode('mrpack')}>Import .mrpack</button>
        <button className={`mode-switch-btn ${mode === 'ai' ? 'active' : ''}`} onClick={() => setMode('ai')}>AI Assistant ✦</button>
      </div>

      {mode === 'custom' && (
        <div className="stepper">
          {[1, 2, 3].map(item => (
            <span className={item <= step ? 'active' : ''} key={item}>
              <i />{item < 3 && <b />}
            </span>
          ))}
        </div>
      )}

      {installing ? (
        <div className="install-state">
          <div className="install-cube"><span /></div>
          <strong>Installing Minecraft {version} ({loaders[loaderIndex][0]})</strong>
          <p>Downloading libraries and preparing Java…</p>
          <div className="progress"><i /></div>
          <small>68% · About 20 seconds remaining</small>
        </div>
      ) : mode === 'custom' ? (
        <>
          <div className="flow-body">
            {step === 1 && (
              <>
                <label className="field-label">
                  INSTANCE NAME
                  <input
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="A quiet new world"
                    autoFocus
                  />
                </label>
                <div className="world-name-preview">
                  <span className="version-icon"><span /></span>
                  <div>
                    <small>YOUR NEW INSTANCE</small>
                    <strong>{name || 'A quiet new world'}</strong>
                  </div>
                </div>
              </>
            )}
            {step === 2 && (
              <>
                <div className="choice-grid">
                  {loaders.map((item, index) => (
                    <button
                      key={item[0]}
                      className={loaderIndex === index ? 'selected' : ''}
                      onClick={() => setLoaderIndex(index)}
                    >
                      <i />
                      <strong>{item[0]}</strong>
                      <small>{item[1]}</small>
                    </button>
                  ))}
                </div>
                <label className="field-label">
                  MINECRAFT VERSION
                  <select className="flow-select" value={version} onChange={(e) => setVersion(e.target.value)}>
                    <option value="1.21.4">Minecraft 1.21.4</option>
                    <option value="1.21.1">Minecraft 1.21.1</option>
                    <option value="1.20.6">Minecraft 1.20.6</option>
                    <option value="1.20.1">Minecraft 1.20.1</option>
                  </select>
                </label>
              </>
            )}
            {step === 3 && (
              <div className="summary-card">
                <div><span>NAME</span><strong>{name || 'A quiet new world'}</strong></div>
                <div><span>VERSION</span><strong>Minecraft {version}</strong></div>
                <div><span>LOADER</span><strong>{loaders[loaderIndex][0]}</strong></div>
                <div><span>MEMORY</span><strong>6 GB (Balanced)</strong></div>
              </div>
            )}
          </div>
          <div className="flow-footer">
            <button className="secondary" onClick={() => step > 1 ? setStep(step - 1) : onClose()}>
              {step > 1 ? 'Back' : 'Cancel'}
            </button>
            <button className="primary-small" onClick={next}>
              {step === 3 ? 'Create instance →' : 'Continue →'}
            </button>
          </div>
        </>
      ) : mode === 'mrpack' ? (
        <>
          <div className="flow-body">
            <div style={{ border: '2px dashed #343034', borderRadius: '14px', padding: '36px', textAlign: 'center', background: '#161416', cursor: 'pointer' }}>
              <p style={{ margin: '0 0 6px 0', fontSize: '13px', color: '#eeeae3' }}>Drop .mrpack archive here</p>
              <small style={{ color: '#817a73', fontSize: '10px' }}>or click to select from Windows Explorer</small>
            </div>
            <div style={{ background: '#161416', border: '1px solid #282428', borderRadius: '11px', padding: '14px', marginTop: '14px' }}>
              <strong style={{ fontSize: '12px' }}>Fabulously Optimized 5.8.0</strong>
              <p style={{ margin: '4px 0 0 0', color: '#817a73', fontSize: '10px' }}>Fabric 1.21.4 · 54 mods · Iris + Sodium</p>
            </div>
          </div>
          <div className="flow-footer">
            <button className="secondary" onClick={onClose}>Cancel</button>
            <button className="primary-small" onClick={() => { next(); setMode('custom'); setStep(3); }}>Import Pack</button>
          </div>
        </>
      ) : (
        <>
          <div className="flow-body">
            <label className="field-label">
              DESCRIBE YOUR DREAM MODPACK
              <textarea
                className="ai-prompt-area"
                value={aiPrompt}
                onChange={(e) => setAiPrompt(e.target.value)}
                placeholder="e.g. Cozy cottagecore survival with performance shaders, detailed food and cooking, and seasons"
              />
            </label>
            <div className="ai-chips-row">
              <span className="ai-chip" onClick={() => setAiPrompt('Cozy fantasy builder with shaders and autumn seasons')}>Cozy Fantasy</span>
              <span className="ai-chip" onClick={() => setAiPrompt('Max FPS competitive PvP with minimal latency and Sodium')}>Max FPS PvP</span>
              <span className="ai-chip" onClick={() => setAiPrompt('Industrial automation, machinery, and power grids')}>Tech & Automation</span>
            </div>
            {!aiPlan ? (
              <button className="primary-small" style={{ alignSelf: 'flex-start', marginTop: '14px' }} onClick={handleSuggestAI}>
                {thinking ? 'Thinking…' : 'Suggest mods with AI'}
              </button>
            ) : (
              <div style={{ marginTop: '14px', background: '#161416', border: '1px solid #282428', borderRadius: '11px', padding: '12px', fontSize: '11px' }}>
                <p style={{ margin: '0 0 8px 0', color: '#d8d0c6' }}>{aiPlan.summary}</p>
                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                  {aiPlan.mods.map(m => <span key={m} style={{ padding: '3px 7px', background: '#211b22', border: '1px solid #654e68', borderRadius: '6px', fontSize: '9px', color: '#eee8ee' }}>✓ {m}</span>)}
                </div>
              </div>
            )}
          </div>
          <div className="flow-footer">
            <button className="secondary" onClick={onClose}>Cancel</button>
            {aiPlan && <button className="primary-small" onClick={() => { next(); setMode('custom'); setStep(3); }}>Create with {aiPlan.mods.length} mods →</button>}
          </div>
        </>
      )}
    </div>
  );
};

// Detail Panel Drawer
const DetailPanel = ({ kind, data, onClose, onOpenSettings }) => {
  const [activeTab, setActiveTab] = useState('Overview');

  return (
    <aside className="detail-panel">
      <div className="flow-head">
        <div>
          <p className="eyebrow">
            {kind === 'instance' ? 'INSTANCE DETAILS' : kind === 'mod' ? 'MODRINTH PROJECT' : 'PLAYER PROFILE'}
          </p>
          <h2>
            {kind === 'instance' ? (data ? data[0] : 'Birch Hollow') :
             kind === 'mod' ? (data ? data[0] : 'Sodium') : 'Conlee'}
          </h2>
        </div>
        <button onClick={onClose}>×</button>
      </div>

      {kind === 'instance' && (
        <>
          <div className="detail-hero"><span className="mini-sun" /></div>
          <div className="detail-tabs">
            {['Overview', 'Mods', 'Worlds', 'Logs'].map(tab => (
              <button key={tab} className={activeTab === tab ? 'active' : ''} onClick={() => setActiveTab(tab)}>{tab}</button>
            ))}
          </div>
          <div className="detail-stats">
            <div><span>PLAYTIME</span><strong>{data ? data[3] : '24h 18m'}</strong></div>
            <div><span>VERSION</span><strong>{data ? data[1] : '1.21.4'}</strong></div>
            <div><span>MEMORY</span><strong>6 GB</strong></div>
          </div>
          <div className="panel-actions">
            <button onClick={() => { onClose(); if (onOpenSettings) onOpenSettings(data); }}>
              Configure Instance Settings & JVM
            </button>
            <button onClick={() => alert('World folder opened in Windows Explorer: %APPDATA%\\.ember\\instances')}>
              Open folder in Explorer
            </button>
            <button onClick={() => alert('Backup created safely!')}>
              Back up world
            </button>
            <button className="danger" onClick={() => alert('Confirm deleting this instance?')}>
              Delete instance
            </button>
          </div>
        </>
      )}

      {kind === 'mod' && (
        <>
          <div className="project-title">
            <div className="mod-icon mod-0"><span /></div>
            <div>
              <span>{data ? data[2] : 'PERFORMANCE'}</span>
              <strong>{data ? data[0] : 'Sodium'}</strong>
              <small>by CaffeineMC</small>
            </div>
          </div>
          <p className="project-description">
            {data ? data[1] : 'A modern rendering engine for Minecraft that greatly improves frame rates and micro-stutter while preserving the familiar visual experience.'}
          </p>
          <div className="compatibility">
            <i /> Compatible with Birch Hollow · Fabric 1.21.4
          </div>
          <div className="detail-stats">
            <div><span>DOWNLOADS</span><strong>{data ? data[3] : '8.4M'}</strong></div>
            <div><span>FOLLOWERS</span><strong>128K</strong></div>
          </div>
          <button className="wide-install" onClick={() => { alert(`Installed ${data ? data[0] : 'mod'} to active instance!`); onClose(); }}>
            Install to Birch Hollow
          </button>
        </>
      )}

      {kind === 'profile' && (
        <>
          <div className="profile-large">
            <span className="avatar">
              <span className="face-eye left" />
              <span className="face-eye right" />
              <span className="face-mouth" />
            </span>
            <div>
              <strong>Conlee</strong>
              <small>Offline UUID · Ready to play</small>
            </div>
          </div>
          <p className="panel-note">
            Your nickname and character are stored locally in Windows DPAPI credentials.
          </p>
        </>
      )}
    </aside>
  );
};

// Instances Screen
const InstancesScreen = ({ instances, onPlay, onNew, onOpen, onAllVersions }) => {
  const [filter, setFilter] = useState('All');
  const [search, setSearch] = useState('');

  const filtered = instances.filter(world => {
    const matchesFilter = filter === 'All' || world[2].includes(filter);
    const matchesSearch = !search || world[0].toLowerCase().includes(search.toLowerCase());
    return matchesFilter && matchesSearch;
  });

  return (
    <div className="page-screen">
      <PageIntro
        eyebrow="YOUR WORLDS"
        title="Instances"
        copy="Every world, safe and ready when you are."
        action="New instance"
        onAction={onNew}
      />
      <div className="toolbar">
        <div className="filter-row">
          {['All', 'Vanilla', 'Fabric', 'Snapshot'].map(item => (
            <button
              className={filter === item ? 'active' : ''}
              onClick={() => setFilter(item)}
              key={item}
            >
              {{item}}
            </button>
          ))}
          <button onClick={onAllVersions} style={{ marginLeft: 'auto', border: '1px solid #342e34', background: '#171517' }}>
            All versions
          </button>
        </div>
        <label className="search-field">
          <span>⌕</span>
          <input
            placeholder="Search instances"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </label>
      </div>
      <div className="instance-grid">
        {filtered.map(world => (
          <article className="instance-card" key={world[0]}>
            <div className={`instance-art ${world[4]}`}>
              <span className="mini-sun" /><i /><i /><i />
            </div>
            <div className="instance-info">
              <div>
                <h3>{world[0]}</h3>
                <p>{world[1]} · {world[2]}</p>
              </div>
              <button onClick={() => onPlay(world[0])} aria-label={`Play ${world[0]}`}>
                <Icon name="play" size={16} />
              </button>
            </div>
            <div className="card-meta">
              <span>LAST PLAYED</span>
              <button onClick={() => onOpen(world)}>Manage</button>
              <strong>{world[3]}</strong>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
};

// Social Screen
const SocialScreen = ({ onHostLobby }) => {
  const friends = [
    { name: 'Mossy', status: 'Building in 1.21.4', isOnline: true },
    { name: 'Luna', status: 'In the main menu', isOnline: true },
    { name: 'North', status: 'Exploring Ember Valley', isOnline: true },
    { name: 'Rowan', status: 'Offline · 2h ago', isOnline: false },
  ];

  return (
    <div className="page-screen">
      <PageIntro
        eyebrow="PLAY TOGETHER"
        title="Social"
        copy="A quiet place for friends, invitations, and temporary worlds."
        action="Create lobby"
        onAction={onHostLobby}
      />

      <div className="social-grid">
        <div className="social-panel">
          <div className="social-panel-head">
            <h3>Quiet Crew (3/8)</h3>
            <span className="btn-mini">Online</span>
          </div>
          {friends.map(f => (
            <div key={f.name} className="social-row">
              <div className="social-row-left">
                <span className={`social-dot ${f.isOnline ? '' : 'offline'}`} />
                <div className="social-name">
                  <strong>{f.name}</strong>
                  <small>{f.status}</small>
                </div>
              </div>
              {f.isOnline && <button className="btn-mini">Join</button>}
            </div>
          ))}
        </div>

        <div className="social-panel">
          <div className="social-panel-head">
            <h3>Active Lobbies</h3>
            <button className="btn-mini-primary" onClick={onHostLobby}>＋ Host</button>
          </div>
          <div className="social-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: '8px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
              <strong style={{ fontSize: '13px' }}>Mossy's Creative Realm</strong>
              <small style={{ color: '#94a978' }}>2/8 Players</small>
            </div>
            <p style={{ margin: 0, fontSize: '10px', color: '#817a73' }}>Fabric 1.21.4 · Creative Mode · Fast Redstone</p>
            <button className="btn-mini-primary" style={{ alignSelf: 'flex-start', marginTop: '4px' }}>Join World →</button>
          </div>
          <div className="social-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: '8px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
              <strong style={{ fontSize: '13px' }}>Quiet SMP Survival</strong>
              <small style={{ color: '#94a978' }}>4/10 Players</small>
            </div>
            <p style={{ margin: 0, fontSize: '10px', color: '#817a73' }}>Vanilla 1.21.4 · Hardcore Survival</p>
            <button className="btn-mini" style={{ alignSelf: 'flex-start', marginTop: '4px' }}>Join World →</button>
          </div>
        </div>

        <div className="social-panel">
          <div className="social-panel-head">
            <h3>Invitations (1)</h3>
          </div>
          <div className="social-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: '8px' }}>
            <strong style={{ fontSize: '12px' }}>North invited you to Ember Valley</strong>
            <small style={{ color: '#817a73' }}>Received 4m ago</small>
            <div style={{ display: 'flex', gap: '6px', width: '100%', marginTop: '4px' }}>
              <button className="btn-mini-primary" style={{ flex: 1 }}>Accept</button>
              <button className="btn-mini" style={{ flex: 1 }}>Decline</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// Mods Screen
const ModsScreen = ({ onOpen }) => {
  const [installed, setInstalled] = useState(['Sodium']);
  const mods = [
    ['Sodium', 'A modern rendering engine for dramatically improved performance.', 'PERFORMANCE', '8.4M'],
    ['Iris Shaders', 'Beautiful shaders with excellent compatibility and speed.', 'VISUAL', '5.1M'],
    ['Create', 'Building, decoration, and automation through kinetic machinery.', 'TECH', '3.8M'],
    ['Lithium', 'General-purpose optimization mod for physics and chunk loading.', 'OPTIMIZE', '6.2M'],
    ['JourneyMap', 'Real-time mapping in-game or in a web browser as you explore.', 'EXPLORE', '11.8M'],
    ['AppleSkin', 'Adds helpful HUD information about food and hunger saturation.', 'QUALITY', '14.2M'],
  ];

  const toggleInstall = (name) => {
    if (installed.includes(name)) {
      setInstalled(installed.filter(m => m !== name));
    } else {
      setInstalled([...installed, name]);
    }
  };

  return (
    <div className="page-screen">
      <PageIntro
        eyebrow="MODRINTH COMPATIBILITY"
        title="Explore Mods"
        copy="Every mod is checked against your loader, game version, and active mods."
      />
      <div className="toolbar">
        <div className="filter-row">
          {['Featured', 'Performance', 'Visuals', 'Tech'].map((item, index) => (
            <button className={index === 0 ? 'active' : ''} key={item}>{item}</button>
          ))}
        </div>
        <label className="search-field">
          <span>⌕</span>
          <input placeholder="Search mods or paste a Modrinth link" />
        </label>
      </div>
      <div className="mods-grid">
        {mods.map((mod, index) => (
          <article className="mod-card" key={mod[0]}>
            <div className={`mod-icon mod-${index % 4}`}><span /></div>
            <div className="mod-copy">
              <span>{mod[2]}</span>
              <h3>{mod[0]}</h3>
              <p>{mod[1]}</p>
              <small>{mod[3]} downloads · Verified for Birch Hollow</small>
            </div>
            <div className="mod-actions">
              <button
                className={installed.includes(mod[0]) ? 'installed' : ''}
                onClick={() => toggleInstall(mod[0])}
              >
                {installed.includes(mod[0]) ? 'Installed' : 'Install'}
              </button>
              <button className="text-action" onClick={() => onOpen(mod)}>Details</button>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
};

// Skins Screen
const SkinsScreen = () => {
  const [skin, setSkin] = useState(0);
  const [isSlim, setIsSlim] = useState(false);
  const [is3D, setIs3D] = useState(true);

  const skinNames = ['Ember', 'Wanderer', 'Nightfall', 'Classic Steve', 'Alex'];

  return (
    <div className="page-screen">
      <PageIntro
        eyebrow="PLAYER APPEARANCE"
        title="Skins"
        copy="Classic and slim models supported. Drop a PNG or select from your wardrobe."
      />
      <div className="skin-layout">
        <div className="skin-stage">
          <div className="skin-stage-toggles">
            <div className="skin-pill-group">
              <button className={`skin-pill-btn ${is3D ? 'active' : ''}`} onClick={() => setIs3D(true)}>3D Model</button>
              <button className={`skin-pill-btn ${!is3D ? 'active' : ''}`} onClick={() => setIs3D(false)}>2D Flat</button>
            </div>
            <div className="skin-pill-group">
              <button className={`skin-pill-btn ${!isSlim ? 'active' : ''}`} onClick={() => setIsSlim(false)}>Classic (4px)</button>
              <button className={`skin-pill-btn ${isSlim ? 'active' : ''}`} onClick={() => setIsSlim(true)}>Slim (3px)</button>
            </div>
          </div>

          {is3D ? (
            <Skin3DStage skinIndex={skin} isSlim={isSlim} is3D={is3D} />
          ) : (
            <>
              <div className={`skin-model skin-${skin}`}>
                <span className="skin-head" />
                <span className="skin-torso" />
                <span className="skin-arm left" />
                <span className="skin-arm right" />
                <span className="skin-leg left" />
                <span className="skin-leg right" />
              </div>
              <div className="stage-shadow" />
            </>
          )}
          <p>DRAG CHARACTER TO ROTATE 360°</p>
        </div>
        <div className="wardrobe">
          <h3>Wardrobe</h3>
          <div className="skin-list">
            {skinNames.map((name, index) => (
              <button
                className={skin === index ? 'active' : ''}
                onClick={() => setSkin(index)}
                key={name}
              >
                <span className={`skin-preview skin-${index}`} />
                <div>
                  <strong>{name}</strong>
                  <small>Equipped · 64×64 pixel skin</small>
                </div>
              </button>
            ))}
          </div>
          <div className="wardrobe-actions">
            <button className="primary-small" onClick={() => alert('Applied skin to active instance!')}>Apply Skin</button>
            <button className="secondary" onClick={() => alert('Import skin PNG from Explorer')}>Import PNG</button>
          </div>
        </div>
      </div>
    </div>
  );
};

// Settings Screen
const SettingsScreen = ({ onOpenOptimize, onOpenDiagnostics }) => {
  const [activeTab, setActiveTab] = useState('General');
  const [memory, setMemory] = useState(6);
  const [closeOnLaunch, setCloseOnLaunch] = useState(false);
  const [gpuHighPerf, setGpuHighPerf] = useState(true);
  const [discordRpc, setDiscordRpc] = useState(true);

  const navs = ['General', 'Java & Memory', 'AI Assistant', 'Windows DirectX', 'About Ember'];

  return (
    <div className="page-screen">
      <PageIntro
        eyebrow="CONFIGURATION"
        title="Settings"
        copy="Balanced defaults for performance, atmospheric comfort, and low-latency play."
      />
      <div className="settings-layout">
        <nav className="settings-nav">
          {navs.map((name) => (
            <button
              key={name}
              className={activeTab === name ? 'active' : ''}
              onClick={() => setActiveTab(name)}
            >
              {name}
            </button>
          ))}
        </nav>

        <div className="settings-card">
          {activeTab === 'General' && (
            <>
              <div className="settings-row">
                <div>
                  <strong>Player Nickname</strong>
                  <small>Offline player profile name</small>
                </div>
                <strong style={{ color: 'var(--accent)' }}>Conlee</strong>
              </div>
              <div className="settings-row">
                <div>
                  <strong>Close Launcher on Game Start</strong>
                  <small>Frees system RAM while Minecraft is running</small>
                </div>
                <button className={`toggle ${closeOnLaunch ? 'on' : ''}`} onClick={() => setCloseOnLaunch(!closeOnLaunch)}>
                  <span />
                </button>
              </div>
              <div className="settings-row">
                <div>
                  <strong>Discord Rich Presence</strong>
                  <small>Display current world, modpack, and playtime in Discord</small>
                </div>
                <button className={`toggle ${discordRpc ? 'on' : ''}`} onClick={() => setDiscordRpc(!discordRpc)}>
                  <span />
                </button>
              </div>
            </>
          )}

          {activeTab === 'Java & Memory' && (
            <>
              <div className="settings-row">
                <div>
                  <strong>Allocated RAM</strong>
                  <small>Recommended: 6 GB for modern Fabric 1.21.4 worlds</small>
                </div>
                <strong style={{ color: 'var(--accent)', fontSize: '13px' }}>{memory} GB</strong>
              </div>
              <div className="memory-presets">
                {[4, 6, 8, 12].map(g => (
                  <button key={g} className={memory === g ? 'active' : ''} onClick={() => setMemory(g)}>
                    <strong>{g} GB</strong>
                    <small>{g === 6 ? 'Recommended' : g === 4 ? 'Vanilla' : 'Heavy Packs'}</small>
                  </button>
                ))}
              </div>
              <div className="settings-row" style={{ marginTop: '14px' }}>
                <div>
                  <strong>Session Diagnostics</strong>
                  <small>Analyze GC micro-freezes, tick drops, and auto-tune JVM</small>
                </div>
                <button className="primary-small" onClick={onOpenDiagnostics}>Run Diagnostics</button>
              </div>
            </>
          )}

          {activeTab === 'Windows DirectX' && (
            <>
              <div className="settings-row">
                <div>
                  <strong>Force Discrete GPU (High Performance)</strong>
                  <small>Applies Windows Registry UserGpuPreferences to javaw.exe</small>
                </div>
                <button className={`toggle ${gpuHighPerf ? 'on' : ''}`} onClick={() => setGpuHighPerf(!gpuHighPerf)}>
                  <span />
                </button>
              </div>
              <div className="settings-row">
                <div>
                  <strong>DirectX Optimization Presets</strong>
                  <small>Fast D3D11 / OpenGL pipeline with Iris Shader integration</small>
                </div>
                <button className="primary-small" onClick={onOpenOptimize}>Configure GPU</button>
              </div>
            </>
          )}

          {activeTab === 'AI Assistant' && (
            <>
              <div className="settings-row">
                <div>
                  <strong>AI Provider</strong>
                  <small>Choose Claude, Gemini, OpenRouter, or Groq</small>
                </div>
                <span style={{ fontSize: '11px', color: 'var(--accent)' }}>Gemini 1.5 Flash</span>
              </div>
              <div className="settings-row">
                <div>
                  <strong>API Key</strong>
                  <small>Encrypted via Windows DPAPI Credential Store</small>
                </div>
                <button className="secondary" onClick={() => alert('Key configured securely in Windows Credential Store')}>Manage Key…</button>
              </div>
            </>
          )}

          {activeTab === 'About Ember' && (
            <>
              <div className="settings-row">
                <div>
                  <strong>Ember Launcher Native</strong>
                  <small>Version 0.2.2 · Windows x64 / ARM64</small>
                </div>
                <button className="primary-small" onClick={() => alert('You are on the latest version!')}>Check for updates</button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

// Main App Component
function App() {
  const [active, setActive] = useState('Home');
  const [heroMode, setHeroMode] = useState('world');
  const [memoryIndex, setMemoryIndex] = useState(0);
  const [version, setVersion] = useState('Minecraft 1.21.4');
  const [versionsOpen, setVersionsOpen] = useState(false);
  const [status, setStatus] = useState('idle');
  const [modal, setModal] = useState(null);
  const [modalData, setModalData] = useState(null);
  const [friendsOpen, setFriendsOpen] = useState(false);

  const [instances, setInstances] = useState([
    ['Birch Hollow', '1.21.4', 'Vanilla', '24h 18m', 'dusk'],
    ['Ember Valley', '1.21.4', 'Fabric · 42 mods', '8h 42m', 'violet'],
    ['First Shelter', '1.20.6', 'Vanilla', '3h 06m', 'gold'],
    ['The In-Between', '24w14', 'Snapshot', '48m', 'void'],
  ]);

  const versions = [
    { version: 'Minecraft 1.21.4', mode: 'world', title: <>THE QUIET<br />WILDERNESS</>, copy: 'Your favorite world is warm, quiet, and ready for you.', instance: 'Birch Hollow', loader: 'Vanilla · Survival' },
    { version: 'Minecraft 1.20.6', mode: 'player', title: <>YOUR STORY,<br />YOUR SKIN</>, copy: 'A familiar face returns to a world still waiting.', instance: 'Homecoming', loader: 'Vanilla · Creative' },
    { version: 'Fabric 1.21.4', mode: 'carousel', title: <>PLACES YOU<br />REMEMBER</>, copy: 'Every world leaves a little light behind.', instance: 'Ember Valley', loader: 'Fabric · 42 mods' },
    { version: 'Snapshot 24w14', mode: 'abstract', title: <>A STRANGE NEW<br />BEGINNING</>, copy: 'Experimental worlds deserve a little mystery.', instance: 'The In-Between', loader: 'Snapshot · Experimental' },
  ];
  const story = versions.find((item) => item.version === version) ?? versions[0];

  useEffect(() => {
    if (heroMode !== 'carousel') return;
    const timer = setInterval(() => setMemoryIndex((value) => (value + 1) % 3), 4500);
    return () => clearInterval(timer);
  }, [heroMode]);

  const launch = () => {
    if (status !== 'idle') return;
    setStatus('launching');
    setTimeout(() => setStatus('ready'), 1800);
    setTimeout(() => setStatus('idle'), 4200);
  };

  const handleCreateInstance = (newInst) => {
    setInstances(prev => [newInst, ...prev]);
  };

  return (
    <main className="app-shell" data-hero={heroMode}>
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />
      <div className="aurora-field" aria-hidden="true"><span /><span /></div>
      <div className="ember-field" aria-hidden="true">
        {Array.from({ length: 10 }, (_, index) => <span key={index} />)}
      </div>

      <aside className="sidebar">
        <div className="brand" aria-label="Ember launcher">
          <EmberLogo size={36} />
        </div>

        <nav className="nav-list" aria-label="Primary navigation">
          {navItems.map((item) => (
            <button
              className={`nav-button ${active === item.label ? 'active' : ''}`}
              key={item.label}
              onClick={() => setActive(item.label)}
              aria-label={item.title}
              title={item.title}
            >
              <Icon name={item.icon} />
            </button>
          ))}
        </nav>

        <span className="status-dot-sidebar" title="All systems operational" />

        <button
          className={`nav-button settings-button ${active === 'Settings' ? 'active' : ''}`}
          aria-label="Settings"
          title="Settings (6)"
          onClick={() => setActive('Settings')}
          style={{ marginBottom: '18px' }}
        >
          <Icon name="settings" />
        </button>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">WELCOME BACK</p>
            <h1>{active === 'Home' ? 'Welcome home.' : active}</h1>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginLeft: 'auto' }}>
            <span className="runtime-chip">Java 21</span>

            {/* Social Top Button */}
            <button className="social-top-pill" onClick={() => setFriendsOpen(!friendsOpen)}>
              <div className="avatar-bubbles">
                <span style={{ background: '#664b3c' }}>M</span>
                <span style={{ background: '#535e47' }}>L</span>
                <span style={{ background: '#5d485e' }}>N</span>
              </div>
              <div className="social-top-text">
                <strong>3 online</strong>
                <small>Friends</small>
              </div>
              <Icon name="chevron" size={14} />
            </button>

            {/* Profile Pill */}
            <button className="profile" onClick={() => setModal('profile')}>
              <span className="avatar" aria-hidden="true">
                <span className="face-eye left" />
                <span className="face-eye right" />
                <span className="face-mouth" />
              </span>
              <span className="profile-copy">
                <strong>Conlee</strong>
                <small>Online</small>
              </span>
              <Icon name="chevron" size={17} />
            </button>
          </div>
        </header>

        <div className={`content ${active !== 'Home' ? 'page-content' : ''}`}>
          {active === 'Home' ? (
            <>
              <article className="hero-card">
                <div className="hero-text">
                  <div className="hero-meta"><span className="live-dot" /> LAST PLAYED · 2 DAYS AGO</div>
                  <h2>{story.title}</h2>
                  <p>{story.copy}</p>
                  <div className="world-stats">
                    <div><span>INSTANCE</span><strong>{heroMode === 'carousel' ? ['Ember Valley', 'Old Pines', 'First Shelter'][memoryIndex] : story.instance}</strong></div>
                    <div><span>LOADER</span><strong>{story.loader}</strong></div>
                    <div><span>PLAYTIME</span><strong>24h 18m</strong></div>
                  </div>
                </div>
                <div className="landscape" aria-hidden="true">
                  <div className="sun" />
                  <div className="mountain far" />
                  <div className="mountain near" />
                  <div className="terrain">
                    <span className="tree t1" /><span className="tree t2" /><span className="tree t3" /><span className="tree t4" />
                  </div>
                  <div className="player-figure"><span className="player-head" /><span className="player-body" /><span className="player-arm" /></div>
                  <div className="abstract-cubes"><span /><span /><span /></div>
                  <div className="carousel-dots">{[0, 1, 2].map((dot) => <span className={memoryIndex === dot ? 'active' : ''} key={dot} />)}</div>
                </div>
              </article>

              <section className="launch-panel">
                <div className="version-wrap">
                  <button className="version-select" onClick={() => setVersionsOpen(!versionsOpen)} aria-expanded={versionsOpen}>
                    <span className="version-icon"><span /></span>
                    <span><small>VERSION</small><strong>{version}</strong></span>
                    <Icon name="chevron" size={18} />
                  </button>
                  {versionsOpen && (
                    <div className="version-menu">
                      {versions.map((item) => (
                        <button
                          key={item.version}
                          className={version === item.version ? 'selected' : ''}
                          onClick={() => {
                            setVersion(item.version);
                            setHeroMode(item.mode);
                            setVersionsOpen(false);
                          }}
                        >
                          {item.version}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
                <button
                  className="instance-settings"
                  aria-label="Instance settings"
                  title="Instance settings"
                  onClick={() => {
                    const currentInst = instances.find(i => i[0] === story.instance) || instances[0];
                    setModalData(currentInst);
                    setModal('versionModal');
                  }}
                >
                  <Icon name="settings" size={19} />
                </button>
                <button className={`play-button ${status}`} onClick={() => launch()}>
                  <span className="play-icon"><Icon name={status === 'idle' ? 'play' : 'download'} size={20} /></span>
                  <span>
                    <strong>{status === 'idle' ? 'PLAY' : status === 'launching' ? 'PREPARING' : 'GAME READY'}</strong>
                    <small>{status === 'idle' ? story.instance : status === 'launching' ? 'Checking files…' : 'Opening Minecraft'}</small>
                  </span>
                </button>
              </section>
            </>
          ) : active === 'Instances' ? (
            <InstancesScreen
              instances={instances}
              onPlay={() => launch()}
              onNew={() => setModal('new')}
              onOpen={(inst) => { setModalData(inst); setModal('instance'); }}
              onAllVersions={() => setModal('versionModal')}
            />
          ) : active === 'Social' ? (
            <SocialScreen onHostLobby={() => setModal('lobby')} />
          ) : active === 'Mods' ? (
            <ModsScreen onOpen={(mod) => { setModalData(mod); setModal('mod'); }} />
          ) : active === 'Skins' ? (
            <SkinsScreen />
          ) : (
            <SettingsScreen
              onOpenOptimize={() => setModal('diagnostics')}
              onOpenDiagnostics={() => setModal('diagnostics')}
            />
          )}

          <footer>
            <span><i className="status-dot" /> All systems operational</span>
            <span>Ember Launcher · 0.2.2 (Windows Native Edition)</span>
          </footer>
        </div>
      </section>

      {/* Friends Drawer */}
      {friendsOpen && (
        <>
          <div className="friends-drawer-backdrop" onClick={() => setFriendsOpen(false)} />
          <div className="friends-drawer">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid #1f1c1f', paddingBottom: '12px' }}>
              <h3 style={{ margin: 0, fontSize: '14px', color: '#eeeae3' }}>Quiet Crew · 3/8</h3>
              <button onClick={() => setFriendsOpen(false)} style={{ border: 0, background: 'transparent', color: '#888', fontSize: '18px', cursor: 'pointer' }}>×</button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {[
                ['Mossy', 'Playing Birch Hollow', true],
                ['Luna', 'In the main menu', true],
                ['North', 'Exploring Ember Valley', true],
                ['Rowan', 'Offline · 2h ago', false],
              ].map(f => (
                <div key={f[0]} className="social-row">
                  <div className="social-row-left">
                    <span className={`social-dot ${f[2] ? '' : 'offline'}`} />
                    <div className="social-name">
                      <strong>{f[0]}</strong>
                      <small>{f[1]}</small>
                    </div>
                  </div>
                  {f[2] && <button className="btn-mini">Invite</button>}
                </div>
              ))}
            </div>
          </div>
        </>
      )}

      {/* Modals Layer */}
      {modal && (
        <div
          className="modal-backdrop"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) setModal(null);
          }}
        >
          {modal === 'new' ? (
            <NewInstanceFlow
              onClose={() => setModal(null)}
              onCreate={handleCreateInstance}
            />
          ) : modal === 'instance' ? (
            <DetailPanel
              kind="instance"
              data={modalData}
              onClose={() => setModal(null)}
              onOpenSettings={(inst) => { setModalData(inst); setModal('versionModal'); }}
            />
          ) : modal === 'mod' ? (
            <DetailPanel
              kind="mod"
              data={modalData}
              onClose={() => setModal(null)}
            />
          ) : modal === 'profile' ? (
            <DetailPanel
              kind="profile"
              onClose={() => setModal(null)}
            />
          ) : modal === 'diagnostics' ? (
            <SessionDiagnosticsModal onClose={() => setModal(null)} />
          ) : modal === 'versionModal' ? (
            <VersionModal instanceName={(modalData ? modalData[0] : 'Birch Hollow')} onClose={() => setModal(null)} />
          ) : modal === 'lobby' ? (
            <LobbyFlowModal onClose={() => setModal(null)} />
          ) : null}
        </div>
      )}
    </main>
  );
}
