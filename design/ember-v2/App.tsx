import { useEffect, useState } from 'react'

type IconName = 'home' | 'grid' | 'shirt' | 'settings' | 'download' | 'play' | 'chevron'

const Icon = ({ name, size = 20 }: { name: IconName; size?: number }) => {
  const paths: Record<IconName, React.ReactNode> = {
    home: <><path d="m3 10 9-7 9 7" /><path d="M5 9v11h14V9M9 20v-7h6v7" /></>,
    grid: <><rect x="4" y="4" width="6" height="6" rx="1" /><rect x="14" y="4" width="6" height="6" rx="1" /><rect x="4" y="14" width="6" height="6" rx="1" /><rect x="14" y="14" width="6" height="6" rx="1" /></>,
    shirt: <path d="m8 4-5 3 3 5 2-1v9h8v-9l2 1 3-5-5-3a4 4 0 0 1-8 0Z" />,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" /></>,
    download: <><path d="M12 3v12m-5-5 5 5 5-5" /><path d="M5 20h14" /></>,
    play: <path d="m9 7 8 5-8 5Z" fill="currentColor" />,
    chevron: <path d="m9 10 3 3 3-3" />,
  }
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>
}

const EmberLogo = ({ size = 32 }: { size?: number }) => (
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
)

const navItems: { icon: IconName; label: string }[] = [
  { icon: 'home', label: 'Home' },
  { icon: 'grid', label: 'Instances' },
  { icon: 'download', label: 'Mods' },
  { icon: 'shirt', label: 'Skins' },
]

const PageIntro = ({ eyebrow, title, copy, action, onAction }: { eyebrow: string; title: string; copy: string; action?: string; onAction?: () => void }) => (
  <div className="page-intro">
    <div><p className="eyebrow">{eyebrow}</p><h2>{title}</h2><p>{copy}</p></div>
    {action && <button className="primary-small" onClick={onAction}>＋ {action}</button>}
  </div>
)

const InstancesScreen = ({ onPlay, onNew, onOpen }: { onPlay: () => void; onNew: () => void; onOpen: () => void }) => {
  const [filter, setFilter] = useState('All')
  const worlds = [
    ['Birch Hollow', '1.21.4', 'Vanilla', '24h 18m', 'dusk'],
    ['Ember Valley', '1.21.4', 'Fabric · 42 mods', '8h 42m', 'violet'],
    ['First Shelter', '1.20.6', 'Vanilla', '3h 06m', 'gold'],
    ['The In-Between', '24w14', 'Snapshot', '48m', 'void'],
  ]
  return <div className="page-screen">
    <PageIntro eyebrow="YOUR WORLDS" title="Instances" copy="Every world, safe and ready when you are." action="New instance" onAction={onNew} />
    <div className="toolbar">
      <div className="filter-row">{['All', 'Vanilla', 'Fabric', 'Snapshot'].map(item => <button className={filter === item ? 'active' : ''} onClick={() => setFilter(item)} key={item}>{item}</button>)}</div>
      <label className="search-field"><span>⌕</span><input placeholder="Search instances" /></label>
    </div>
    <div className="instance-grid">
      {worlds.filter(world => filter === 'All' || world[2].includes(filter)).map(world => <article className="instance-card" key={world[0]}>
        <div className={`instance-art ${world[4]}`}><span className="mini-sun" /><i /><i /><i /></div>
        <div className="instance-info"><div><h3>{world[0]}</h3><p>{world[1]} · {world[2]}</p></div><button onClick={onPlay} aria-label={`Play ${world[0]}`}><Icon name="play" size={16} /></button></div>
        <div className="card-meta"><span>LAST PLAYED</span><button onClick={onOpen}>Manage</button><strong>{world[3]}</strong></div>
      </article>)}
    </div>
  </div>
}

const ModsScreen = ({ onOpen }: { onOpen: () => void }) => {
  const [installed, setInstalled] = useState<string[]>(['Sodium'])
  const mods = [
    ['Sodium', 'A modern rendering engine for dramatically improved performance.', 'PERFORMANCE', '8.4M'],
    ['Iris Shaders', 'Beautiful shaders with excellent compatibility and speed.', 'VISUAL', '5.1M'],
    ['Create', 'Building, decoration, and automation through kinetic machinery.', 'TECH', '3.8M'],
    ['Nature’s Compass', 'Find biomes without losing the joy of exploration.', 'WORLD', '2.2M'],
  ]
  return <div className="page-screen">
    <PageIntro eyebrow="DISCOVER" title="Mods" copy="Thoughtful additions for the way you like to play." />
    <div className="toolbar"><div className="filter-row"><button className="active">Featured</button><button>Modpacks</button><button>Shaders</button><button>Resources</button></div><label className="search-field"><span>⌕</span><input placeholder="Search Modrinth" /></label></div>
    <div className="mods-grid">{mods.map((mod, index) => <article className="mod-card" key={mod[0]}>
      <div className={`mod-icon mod-${index}`}><span /></div>
      <div className="mod-copy"><span>{mod[2]}</span><h3>{mod[0]}</h3><p>{mod[1]}</p><small>↓ {mod[3]} downloads</small></div>
      <div className="mod-actions"><button className="text-action" onClick={onOpen}>Details</button><button className={installed.includes(mod[0]) ? 'installed' : ''} onClick={() => setInstalled(value => value.includes(mod[0]) ? value : [...value, mod[0]])}>{installed.includes(mod[0]) ? 'Installed' : 'Install'}</button></div>
    </article>)}</div>
  </div>
}

const SkinsScreen = () => {
  const [skin, setSkin] = useState(0)
  return <div className="page-screen skins-screen">
    <PageIntro eyebrow="WARDROBE" title="Skins" copy="Choose how you arrive in every world." action="Import skin" />
    <div className="skin-layout">
      <div className="skin-stage"><div className={`skin-model skin-${skin}`}><span className="skin-head" /><span className="skin-torso" /><span className="skin-leg left" /><span className="skin-leg right" /><span className="skin-arm left" /><span className="skin-arm right" /></div><div className="stage-shadow" /><p>Drag to rotate · Scroll to zoom</p></div>
      <div className="wardrobe"><p className="eyebrow">YOUR COLLECTION</p><div className="skin-list">{['Ember', 'Wanderer', 'Nightfall', 'Classic'].map((name, index) => <button className={skin === index ? 'active' : ''} onClick={() => setSkin(index)} key={name}><span className={`skin-thumb skin-${index}`} /><strong>{name}</strong><small>{index === 0 ? 'Currently equipped' : 'Saved skin'}</small></button>)}</div></div>
    </div>
  </div>
}

const SettingsScreen = () => {
  const [memory, setMemory] = useState(6)
  const [autoUpdate, setAutoUpdate] = useState(true)
  const [closeOnLaunch, setCloseOnLaunch] = useState(false)
  return <div className="page-screen settings-screen">
    <PageIntro eyebrow="YOUR SPACE" title="Settings" copy="A few thoughtful choices to make Ember feel like yours." />
    <div className="settings-layout">
      <div className="settings-nav"><button className="active">General</button><button>Java & memory</button><button>Downloads</button><button>Appearance</button><button>About Ember</button></div>
      <div className="settings-content">
        <div className="comfort-card">
          <div className="comfort-orb"><span /></div>
          <div><small>EMBER IS READY</small><strong>Everything feels good.</strong><p>Java 21 is healthy, memory is balanced, and your worlds are safely backed up.</p></div>
          <span className="comfort-check">✓</span>
        </div>
        <section className="settings-group"><p className="eyebrow">PLAYER</p><div className="setting-row"><div><strong>Display name</strong><small>Used for offline and local worlds</small></div><input value="Conlee" readOnly /></div><div className="setting-row"><div><strong>Language</strong><small>Launcher interface language</small></div><button className="setting-select">English <Icon name="chevron" size={15} /></button></div></section>
        <section className="settings-group"><p className="eyebrow">PERFORMANCE <span className="recommended-pill">RECOMMENDED</span></p><div className="setting-row memory-row"><div><strong>Memory allocation</strong><small>Ember keeps enough memory free for the rest of your Mac</small></div><div className="memory-stepper"><button onClick={() => setMemory(Math.max(2, memory - 1))}>−</button><span><strong>{memory}</strong><small>GB</small></span><button onClick={() => setMemory(Math.min(16, memory + 1))}>＋</button></div><div className="memory-presets">{[[4, 'Light'], [6, 'Balanced'], [8, 'Modded'], [12, 'Heavy']].map(([amount, label]) => <button className={memory === amount ? 'active' : ''} onClick={() => setMemory(Number(amount))} key={amount}><strong>{amount} GB</strong><small>{label}</small></button>)}</div></div></section>
        <section className="settings-group"><p className="eyebrow">BEHAVIOR</p><div className="setting-row"><div><strong>Automatic updates</strong><small>Keep Ember and game metadata current</small></div><button className={`toggle ${autoUpdate ? 'on' : ''}`} onClick={() => setAutoUpdate(!autoUpdate)}><span /></button></div><div className="setting-row"><div><strong>Close launcher after start</strong><small>Save resources while Minecraft is running</small></div><button className={`toggle ${closeOnLaunch ? 'on' : ''}`} onClick={() => setCloseOnLaunch(!closeOnLaunch)}><span /></button></div></section>
        <p className="autosave-note"><i /> Changes are saved automatically</p>
      </div>
    </div>
  </div>
}

const NewInstanceFlow = ({ onClose }: { onClose: () => void }) => {
  const [step, setStep] = useState(1)
  const [installing, setInstalling] = useState(false)
  const next = () => {
    if (step < 3) setStep(step + 1)
    else {
      setInstalling(true)
      window.setTimeout(onClose, 2200)
    }
  }
  return <div className="flow">
    <div className="flow-head"><div><p className="eyebrow">NEW INSTANCE</p><h2>{installing ? 'Preparing your world' : ['Name your adventure', 'Choose a foundation', 'Ready to create'][step - 1]}</h2></div><button onClick={onClose}>×</button></div>
    <div className="stepper">{[1, 2, 3].map(item => <span className={item <= step ? 'active' : ''} key={item}><i />{item < 3 && <b />}</span>)}</div>
    {installing ? <div className="install-state"><div className="install-cube"><span /></div><strong>Installing Minecraft 1.21.4</strong><p>Downloading libraries and preparing Java…</p><div className="progress"><i /></div><small>68% · About 20 seconds remaining</small></div> : <>
      <div className="flow-body">
        {step === 1 && <><label className="field-label">INSTANCE NAME<input defaultValue="A quiet new world" autoFocus /></label><div className="world-name-preview"><span className="version-icon"><span /></span><div><small>YOUR NEW INSTANCE</small><strong>A quiet new world</strong></div></div></>}
        {step === 2 && <><div className="choice-grid">{[['Vanilla', 'The original experience'], ['Fabric', 'Lightweight and mod-friendly'], ['Forge', 'Built for expansive modpacks'], ['NeoForge', 'Modern community loader']].map((item, index) => <button className={index === 1 ? 'selected' : ''} key={item[0]}><i /><strong>{item[0]}</strong><small>{item[1]}</small></button>)}</div><label className="field-label">MINECRAFT VERSION<button className="flow-select">1.21.4 <Icon name="chevron" size={16} /></button></label></>}
        {step === 3 && <div className="summary-card"><div><span>NAME</span><strong>A quiet new world</strong></div><div><span>VERSION</span><strong>Minecraft 1.21.4</strong></div><div><span>LOADER</span><strong>Fabric</strong></div><div><span>MEMORY</span><strong>6 GB · Recommended</strong></div></div>}
      </div>
      <div className="flow-footer"><button className="secondary" onClick={() => step === 1 ? onClose() : setStep(step - 1)}>{step === 1 ? 'Cancel' : 'Back'}</button><button className="primary-small" onClick={next}>{step === 3 ? 'Create instance' : 'Continue'} →</button></div>
    </>}
  </div>
}

const DetailPanel = ({ kind, onClose }: { kind: 'instance' | 'mod' | 'profile'; onClose: () => void }) => (
  <div className="detail-panel">
    <div className="flow-head"><div><p className="eyebrow">{kind === 'instance' ? 'INSTANCE DETAILS' : kind === 'mod' ? 'MODRINTH PROJECT' : 'YOUR PROFILE'}</p><h2>{kind === 'instance' ? 'Birch Hollow' : kind === 'mod' ? 'Sodium' : 'Conlee'}</h2></div><button onClick={onClose}>×</button></div>
    {kind === 'instance' ? <><div className="detail-hero"><span className="mini-sun" /></div><div className="detail-tabs"><button className="active">Overview</button><button>Mods</button><button>Worlds</button><button>Logs</button></div><div className="detail-stats"><div><span>PLAYTIME</span><strong>24h 18m</strong></div><div><span>VERSION</span><strong>1.21.4</strong></div><div><span>MEMORY</span><strong>6 GB</strong></div></div><div className="panel-actions"><button>Open folder</button><button>Back up world</button><button className="danger">Delete instance</button></div></> :
    kind === 'mod' ? <><div className="project-title"><div className="mod-icon mod-0"><span /></div><div><span>PERFORMANCE</span><strong>Sodium</strong><small>by CaffeineMC</small></div></div><p className="project-description">A modern rendering engine for Minecraft that greatly improves frame rates and micro-stutter while preserving the familiar visual experience.</p><div className="compatibility"><i /> Compatible with Birch Hollow · Fabric 1.21.4</div><div className="detail-stats"><div><span>DOWNLOADS</span><strong>8.4M</strong></div><div><span>FOLLOWERS</span><strong>128K</strong></div></div><button className="wide-install">Install to Birch Hollow</button></> :
    <><div className="profile-large"><span className="avatar"><span className="face-eye left" /><span className="face-eye right" /><span className="face-mouth" /></span><div><strong>Conlee</strong><small>Online · Offline profile</small></div></div><div className="panel-actions"><button>Manage account</button><button>Switch profile</button><button>Sign out</button></div><p className="panel-note">Microsoft account support can be connected here when authentication is implemented.</p></>}
  </div>
)

export default function App() {
  const [active, setActive] = useState('Home')
  const [heroMode, setHeroMode] = useState('world')
  const [memoryIndex, setMemoryIndex] = useState(0)
  const [version, setVersion] = useState('Minecraft 1.21.4')
  const [versionsOpen, setVersionsOpen] = useState(false)
  const [status, setStatus] = useState<'idle' | 'launching' | 'ready'>('idle')
  const [modal, setModal] = useState<null | 'new' | 'instance' | 'mod' | 'profile'>(null)
  const versions = [
    { version: 'Minecraft 1.21.4', mode: 'world', title: <>THE QUIET<br />WILDERNESS</>, copy: 'Your favorite world is warm, quiet, and ready for you.', instance: 'Birch Hollow', loader: 'Vanilla · Survival' },
    { version: 'Minecraft 1.20.6', mode: 'player', title: <>YOUR STORY,<br />YOUR SKIN</>, copy: 'A familiar face returns to a world still waiting.', instance: 'Homecoming', loader: 'Vanilla · Creative' },
    { version: 'Fabric 1.21.4', mode: 'carousel', title: <>PLACES YOU<br />REMEMBER</>, copy: 'Every world leaves a little light behind.', instance: 'Ember Valley', loader: 'Fabric · 42 mods' },
    { version: 'Snapshot 24w14', mode: 'abstract', title: <>A STRANGE NEW<br />BEGINNING</>, copy: 'Experimental worlds deserve a little mystery.', instance: 'The In-Between', loader: 'Snapshot · Experimental' },
  ]
  const story = versions.find((item) => item.version === version) ?? versions[0]

  useEffect(() => {
    if (heroMode !== 'carousel') return
    const timer = window.setInterval(() => setMemoryIndex((value) => (value + 1) % 3), 4500)
    return () => window.clearInterval(timer)
  }, [heroMode])

  const launch = () => {
    if (status !== 'idle') return
    setStatus('launching')
    window.setTimeout(() => setStatus('ready'), 1800)
    window.setTimeout(() => setStatus('idle'), 4200)
  }

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
          <EmberLogo size={32} />
        </div>

        <nav className="nav-list" aria-label="Primary navigation">
          {navItems.map((item) => (
            <button
              className={`nav-button ${active === item.label ? 'active' : ''}`}
              key={item.label}
              onClick={() => setActive(item.label)}
              aria-label={item.label}
              title={item.label}
            >
              <Icon name={item.icon} />
            </button>
          ))}
        </nav>

        <button className="nav-button settings-button" aria-label="Settings" title="Settings" onClick={() => setActive('Settings')}>
          <Icon name="settings" />
        </button>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">WELCOME BACK</p>
            <h1>{active === 'Home' ? 'Welcome home.' : active}</h1>
          </div>
          <span className="runtime-chip">Java 21</span>
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
        </header>

        <div className={`content ${active !== 'Home' ? 'page-content' : ''}`}>
          {active === 'Home' ? <>
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
                    <button key={item.version} className={version === item.version ? 'selected' : ''} onClick={() => { setVersion(item.version); setHeroMode(item.mode); setVersionsOpen(false) }}>{item.version}</button>
                  ))}
                </div>
              )}
            </div>
            <button className="instance-settings" aria-label="Instance settings" title="Instance settings" onClick={() => setActive('Settings')}>
              <Icon name="settings" size={19} />
            </button>
            <button className={`play-button ${status}`} onClick={launch}>
              <span className="play-icon"><Icon name={status === 'idle' ? 'play' : 'download'} size={20} /></span>
              <span>
                <strong>{status === 'idle' ? 'PLAY' : status === 'launching' ? 'PREPARING' : 'GAME READY'}</strong>
                <small>{status === 'idle' ? 'Birch Hollow' : status === 'launching' ? 'Checking files…' : 'Opening Minecraft'}</small>
              </span>
            </button>
          </section>
          </> : active === 'Instances' ? <InstancesScreen onPlay={launch} onNew={() => setModal('new')} onOpen={() => setModal('instance')} /> : active === 'Mods' ? <ModsScreen onOpen={() => setModal('mod')} /> : active === 'Skins' ? <SkinsScreen /> : <SettingsScreen />}
          <footer>
            <span><i className="status-dot" /> All systems operational</span>
            <span>Ember Launcher · 2.4.1</span>
          </footer>
        </div>
      </section>
      {modal && <div className="modal-backdrop" onMouseDown={event => { if (event.target === event.currentTarget) setModal(null) }}>
        {modal === 'new' ? <NewInstanceFlow onClose={() => setModal(null)} /> : <DetailPanel kind={modal} onClose={() => setModal(null)} />}
      </div>}
    </main>
  )
}
