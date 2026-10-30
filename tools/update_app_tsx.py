#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys

def main():
    with open('windows/frontend/src/App.tsx', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add SessionDiagnosticsModal, VersionModal, and LobbyFlowModal before InstancesScreen
    new_modals = '''
// Session Diagnostics View Modal (matching SessionDiagnosticsView.swift)
const SessionDiagnosticsModal: React.FC<{ onClose: () => void }> = ({ onClose }) => {
  const [fixing, setFixing] = useState(false);
  const [fixed, setFixed] = useState(false);

  const handleAutoFix = () => {
    setFixing(true);
    setTimeout(() => {
      setFixing(false);
      setFixed(true);
    }, 1400);
  };

  const score = 94;
  const radius = 38;
  const circ = 2 * Math.PI * radius;
  const offset = circ - (circ * score) / 100;

  return (
    <div className="flow" style={{ maxWidth: '640px' }}>
      <div className="flow-head">
        <div>
          <p className="eyebrow">DIAGNOSTICS & PERFORMANCE</p>
          <h2>Session Health</h2>
        </div>
        <button onClick={onClose} aria-label="Close">×</button>
      </div>

      <div className="flow-body" style={{ gap: '18px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative', padding: '12px 0' }}>
          <svg width="104" height="104" style={{ transform: 'rotate(-90deg)' }}>
            <circle cx="52" cy="52" r={radius} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="8" />
            <circle
              cx="52"
              cy="52"
              r={radius}
              fill="none"
              stroke="#94a978"
              strokeWidth="8"
              strokeLinecap="round"
              strokeDasharray={circ}
              strokeDashoffset={offset}
              style={{ transition: 'stroke-dashoffset 0.8s ease' }}
            />
          </svg>
          <div style={{ position: 'absolute', textAlign: 'center', marginTop: '-8px' }}>
            <strong style={{ fontSize: '28px', fontWeight: 800, color: '#eeeae3' }}>{score}</strong>
          </div>
          <span style={{ fontSize: '13px', fontWeight: 600, color: '#94a978', marginTop: '8px' }}>
            Perfect smoothness · 0 micro-stutters
          </span>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
          <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid #28242c', borderRadius: '10px', padding: '12px' }}>
            <span style={{ fontSize: '10px', color: '#827b85', fontFamily: 'DM Mono' }}>GC FREEZES</span>
            <strong style={{ display: 'block', fontSize: '12px', marginTop: '4px' }}>0 (max 12ms)</strong>
          </div>
          <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid #28242c', borderRadius: '10px', padding: '12px' }}>
            <span style={{ fontSize: '10px', color: '#827b85', fontFamily: 'DM Mono' }}>WORLD LOAD</span>
            <strong style={{ display: 'block', fontSize: '12px', marginTop: '4px' }}>0 tick drops</strong>
          </div>
          <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid #28242c', borderRadius: '10px', padding: '12px' }}>
            <span style={{ fontSize: '10px', color: '#827b85', fontFamily: 'DM Mono' }}>JVM MEMORY</span>
            <strong style={{ display: 'block', fontSize: '12px', marginTop: '4px' }}>6 GB · Java 21</strong>
          </div>
        </div>

        <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid #28242c', borderRadius: '12px', padding: '14px', display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#94a978' }} />
            <span>Garbage Collector tuned with optimal G1GC pause limits (&lt;15ms)</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#94a978' }} />
            <span>DirectX High Performance discrete GPU pipeline active</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#f0a062' }} />
            <span>Chunk distance set to 16 (consider 12 for highest 1% frame lows)</span>
          </div>
        </div>

        {fixed && (
          <div style={{ background: 'rgba(148, 169, 120, 0.1)', border: '1px solid rgba(148, 169, 120, 0.3)', borderRadius: '10px', padding: '10px 14px', color: '#94a978', fontSize: '12px' }}>
            High-speed chunk cache enabled and memory thresholds tuned!
          </div>
        )}
      </div>

      <div className="flow-actions">
        <button className="secondary" onClick={onClose}>Close</button>
        <button className="primary" disabled={fixing || fixed} onClick={handleAutoFix}>
          {fixing ? 'Applying Fixes…' : fixed ? 'All Optimizations Active' : 'Fix automatically in 1 click'}
        </button>
      </div>
    </div>
  );
};

// Version Change Modal (matching VersionModal.swift)
const VersionModal: React.FC<{ instanceName: string; onClose: () => void }> = ({ instanceName, onClose }) => {
  const [target, setTarget] = useState('1.21.1');
  const [upgrading, setUpgrading] = useState(false);
  const [progress, setProgress] = useState('');
  const [done, setDone] = useState(false);

  const handleUpgrade = () => {
    setUpgrading(true);
    setProgress('Backing up worlds and mods…');
    setTimeout(() => setProgress(`Installing Minecraft ${target} and Fabric…`), 1000);
    setTimeout(() => {
      setUpgrading(false);
      setDone(true);
    }, 2200);
  };

  return (
    <div className="flow" style={{ maxWidth: '580px' }}>
      <div className="flow-head">
        <div>
          <p className="eyebrow">SAFE VERSION MIGRATION</p>
          <h2>Change Version</h2>
        </div>
        <button onClick={onClose} aria-label="Close">×</button>
      </div>

      <div className="flow-body" style={{ gap: '14px' }}>
        <p style={{ margin: 0, fontSize: '13px', color: '#827b85' }}>
          Current: <strong>{instanceName}</strong> · Minecraft 1.21.4 (Fabric)
        </p>

        <label className="field-label">
          TARGET MINECRAFT VERSION
          <select
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            style={{ width: '100%', padding: '10px 12px', borderRadius: '10px', background: 'rgba(255,255,255,0.04)', border: '1px solid #28242c', color: '#eeeae3' }}
          >
            <option value="1.21.1">Minecraft 1.21.1 (Fabric Supported)</option>
            <option value="1.20.6">Minecraft 1.20.6 (Fabric Supported)</option>
            <option value="1.20.1">Minecraft 1.20.1 · Massive Mod Ecosystem</option>
            <option value="1.19.4">Minecraft 1.19.4</option>
          </select>
        </label>

        <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid #28242c', borderRadius: '12px', padding: '14px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
          <span style={{ fontSize: '12px', color: '#eeeae3' }}>Mods with a compatible version: <strong>38 of 42</strong></span>
          <span style={{ fontSize: '11px', color: '#f0a062' }}>Will be safely disabled: LegacyBiomeGen, OldCapes</span>
        </div>

        {upgrading && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ fontSize: '12px', color: '#f0a062' }}>{progress}</span>
            <div className="progress"><i /></div>
          </div>
        )}

        {done && (
          <div style={{ background: 'rgba(148, 169, 120, 0.1)', border: '1px solid rgba(148, 169, 120, 0.3)', borderRadius: '10px', padding: '10px 14px', color: '#94a978', fontSize: '12px' }}>
            Upgraded to Minecraft {target}! Restorable snapshot created.
          </div>
        )}
      </div>

      <div className="flow-actions">
        <button className="secondary" onClick={onClose}>Cancel</button>
        <button className="primary" disabled={upgrading || done} onClick={handleUpgrade}>
          {upgrading ? 'Upgrading…' : done ? 'Done' : 'Change version'}
        </button>
      </div>
    </div>
  );
};

// Temporary Multiplayer Lobby Modal (matching LobbyFlowModal.swift)
const LobbyFlowModal: React.FC<{ onClose: () => void }> = ({ onClose }) => {
  const [isCreated, setIsCreated] = useState(false);
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="flow" style={{ maxWidth: '540px' }}>
      <div className="flow-head">
        <div>
          <p className="eyebrow">TEMPORARY LOBBY</p>
          <h2>{isCreated ? 'Lobby is ready' : 'Bring friends in'}</h2>
        </div>
        <button onClick={onClose} aria-label="Close">×</button>
      </div>

      <div className="flow-body" style={{ gap: '14px' }}>
        {!isCreated ? (
          <>
            <p style={{ margin: 0, fontSize: '13px', color: '#827b85' }}>
              Host a peer multiplayer session directly from your single-player world. No server required.
            </p>
            <label className="field-label">
              SELECT WORLD
              <select style={{ width: '100%', padding: '10px 12px', borderRadius: '10px', background: 'rgba(255,255,255,0.04)', border: '1px solid #28242c', color: '#eeeae3' }}>
                <option>Birch Hollow (Survival)</option>
                <option>Ember Valley (Fabric · 42 mods)</option>
              </select>
            </label>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <span style={{ fontSize: '10px', fontFamily: 'DM Mono', color: '#f0a062' }}>PRIVACY</span>
              <div style={{ padding: '12px', borderRadius: '10px', border: '1px solid #f0a062', background: 'rgba(240,160,98,0.06)', fontSize: '13px', display: 'flex', justifyContent: 'space-between' }}>
                <strong>Friends only</strong>
                <span style={{ color: '#827b85', fontSize: '11px' }}>Anyone on your friends list</span>
              </div>
            </div>
          </>
        ) : (
          <div style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', gap: '14px', padding: '10px 0' }}>
            <span style={{ color: '#94a978', fontSize: '12px', fontWeight: 600 }}>● Lobby active on port 25565 via peer relay</span>
            <div style={{ background: 'rgba(0,0,0,0.3)', padding: '20px', borderRadius: '14px', border: '1px solid #28242c' }}>
              <span style={{ fontSize: '10px', fontFamily: 'DM Mono', color: '#827b85' }}>INVITE CODE</span>
              <h3 style={{ fontSize: '24px', letterSpacing: '0.12em', color: '#f0a062', margin: '8px 0 14px 0' }}>EMBER-7729-NORD</h3>
              <button className="primary" onClick={handleCopy} style={{ margin: '0 auto', padding: '8px 20px' }}>
                {copied ? 'Code Copied!' : 'Copy Invite Code'}
              </button>
            </div>
          </div>
        )}
      </div>

      <div className="flow-actions">
        <button className="secondary" onClick={onClose}>Close</button>
        {!isCreated && (
          <button className="primary" onClick={() => setIsCreated(true)}>Create Lobby</button>
        )}
      </div>
    </div>
  );
};
'''

    if 'const SessionDiagnosticsModal' not in content:
        content = content.replace('const InstancesScreen:', new_modals + '\nconst InstancesScreen:')

    # 2. Update modal condition branch to include sessionHealth, versionModal, lobby
    target_modal_branch = '''          ) : modal === 'allVersions' ? (
            <AllVersionsModal
              onClose={() => setModal(null)}
              onSelectVersion={(ver) => {
                setVersion(`Minecraft ${ver}`);
                setModal(null);
              }}
            />'''

    replacement_modal_branch = '''          ) : modal === 'allVersions' ? (
            <AllVersionsModal
              onClose={() => setModal(null)}
              onSelectVersion={(ver) => {
                setVersion(`Minecraft ${ver}`);
                setModal(null);
              }}
            />
          ) : modal === 'sessionHealth' ? (
            <SessionDiagnosticsModal onClose={() => setModal(null)} />
          ) : modal === 'versionModal' ? (
            <VersionModal instanceName={(modalData ? modalData[0] : 'Birch Hollow')} onClose={() => setModal(null)} />
          ) : modal === 'lobby' ? (
            <LobbyFlowModal onClose={() => setModal(null)} />'''

    if 'modal === \'sessionHealth\'' not in content:
        content = content.replace(target_modal_branch, replacement_modal_branch)

    # 3. Add health pill to TopBar if not present
    health_pill = '''          {/* Session Health Quick Indicator */}
          <div
            className="flex items-center gap-2 px-3 py-1.5 rounded-full cursor-pointer transition-all"
            style={{ background: 'rgba(148, 169, 120, 0.1)', border: '1px solid rgba(148, 169, 120, 0.25)', color: '#94a978', fontSize: '11px', fontWeight: 600 }}
            onClick={() => setModal('sessionHealth')}
            title="Session Smoothness & Health"
          >
            <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#94a978', boxShadow: '0 0 6px #94a978' }} />
            <span>94% Smooth</span>
          </div>'''

    if 'Session Smoothness & Health' not in content:
        content = content.replace('<div className="topbar-actions">', '<div className="topbar-actions">\n' + health_pill)

    with open('windows/frontend/src/App.tsx', 'w', encoding='utf-8') as f:
        f.write(content)

    print("windows/frontend/src/App.tsx successfully updated!")

if __name__ == '__main__':
    main()
