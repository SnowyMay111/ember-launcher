#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def main():
    css_content = read_file('design/ember-v2/index.css')

    extra_css = """
/* Additional styles for full Mac parity */
.social-grid { display: grid; grid-template-columns: 1fr 1.35fr 1fr; gap: 16px; margin-top: 10px; }
.social-panel { border: 1px solid #242124; border-radius: 18px; background: #111011; padding: 20px; display: flex; flex-direction: column; gap: 12px; }
.social-panel-head { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1f1c1f; padding-bottom: 10px; }
.social-panel-head h3 { margin: 0; font-size: 13px; font-weight: 600; color: #eeeae3; }
.social-row { display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; border-radius: 10px; background: #161416; border: 1px solid #232023; }
.social-row-left { display: flex; align-items: center; gap: 10px; }
.social-dot { width: 7px; height: 7px; border-radius: 50%; background: #94a978; box-shadow: 0 0 6px #94a978; }
.social-dot.offline { background: #5a5450; box-shadow: none; }
.social-name { display: flex; flex-direction: column; gap: 2px; text-align: left; }
.social-name strong { font-size: 12px; color: #eeeae3; }
.social-name small { font-size: 10px; color: #817a73; }
.btn-mini { padding: 4px 10px; border-radius: 8px; border: 1px solid #3a3531; background: #191715; color: #c0b8b0; font-size: 9px; cursor: pointer; }
.btn-mini:hover { color: var(--accent); border-color: #584236; }
.btn-mini-primary { background: linear-gradient(135deg, var(--accent), var(--accent-deep)); color: #1b110a; font-weight: 700; border: none; }

/* Friends Drawer matching FriendsDrawer.swift */
.friends-drawer-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 50; animation: modalFade .2s ease; }
.friends-drawer { position: fixed; right: 0; top: 0; bottom: 0; width: 330px; background: #111011; border-left: 1px solid #242124; z-index: 55; padding: 24px; display: flex; flex-direction: column; gap: 16px; box-shadow: -15px 0 35px rgba(0,0,0,0.5); animation: drawerSlide .24s cubic-bezier(0.2, 0.8, 0.2, 1); }
@keyframes drawerSlide { from { transform: translateX(100%); } to { transform: translateX(0); } }

/* Social TopBar Pill matching TopBar.swift */
.social-top-pill { display: flex; align-items: center; gap: 8px; padding: 4px 10px 4px 6px; height: 38px; border-radius: 8px; background: #11100e; border: 1px solid #292622; color: #eeeae3; cursor: pointer; }
.social-top-pill:hover { background: #171512; border-color: #3b352e; }
.avatar-bubbles { display: flex; align-items: center; margin-right: 2px; }
.avatar-bubbles span { width: 22px; height: 22px; border-radius: 50%; border: 2px solid #11100e; margin-left: -6px; display: grid; place-items: center; font-size: 8px; font-weight: 700; color: #fff; }
.avatar-bubbles span:first-child { margin-left: 0; }
.social-top-text { display: flex; flex-direction: column; align-items: flex-start; line-height: 1.1; }
.social-top-text strong { font-size: 10px; font-weight: 700; color: #d8d0c6; }
.social-top-text small { font-size: 9px; color: #8e8880; }

/* Status dot in sidebar */
.status-dot-sidebar { width: 8px; height: 8px; border-radius: 50%; background: #94a978; margin-top: auto; margin-bottom: 14px; box-shadow: 0 0 8px rgba(148,169,120,0.4); }

/* Diagnostics Health Gauge */
.health-gauge-box { display: flex; flex-direction: column; align-items: center; justify-content: center; position: relative; padding: 10px 0; }
.health-gauge-svg { transform: rotate(-90deg); }
.health-gauge-bg { fill: none; stroke: rgba(255,255,255,0.06); stroke-width: 8; }
.health-gauge-val { fill: none; stroke: #94a978; stroke-width: 8; stroke-linecap: round; transition: stroke-dashoffset 0.8s ease; }
.health-score-text { position: absolute; font-size: 26px; font-weight: 800; color: #eeeae3; }

/* 3D Skin Canvas in skin-stage */
.skin-3d-canvas { position: absolute; inset: 0; width: 100%; height: 100%; z-index: 2; cursor: grab; }
.skin-3d-canvas:active { cursor: grabbing; }
.skin-stage-toggles { position: absolute; top: 14px; left: 14px; right: 14px; display: flex; justify-content: space-between; z-index: 5; }
.skin-pill-group { display: flex; gap: 4px; background: rgba(14,13,14,0.75); border: 1px solid #262325; border-radius: 999px; padding: 2px 4px; backdrop-filter: blur(8px); }
.skin-pill-btn { border: 0; background: transparent; color: #777177; font-size: 9px; font-weight: 600; padding: 3px 8px; border-radius: 999px; cursor: pointer; }
.skin-pill-btn.active { background: #262128; color: #eeeae3; }

/* AI Assistant & Mode tabs in NewInstanceFlow */
.mode-switch-tabs { display: flex; gap: 6px; padding: 0 27px 14px; }
.mode-switch-btn { flex: 1; padding: 7px 10px; border-radius: 8px; border: 1px solid #282428; background: #161416; color: #888188; font-size: 10px; font-weight: 600; cursor: pointer; }
.mode-switch-btn.active { border-color: #654e68; background: #211b22; color: #eee8ee; }
.ai-prompt-area { width: 100%; height: 75px; border: 1px solid #343034; border-radius: 11px; background: #181618; color: #eee7ee; padding: 10px 14px; outline: 0; font: 500 11px 'Manrope'; resize: none; }
.ai-prompt-area:focus { border-color: #67506a; }
.ai-chips-row { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 6px; }
.ai-chip { padding: 4px 8px; border-radius: 6px; background: #191719; border: 1px solid #292629; font-size: 9px; color: #8a828a; cursor: pointer; }
.ai-chip:hover { color: #eeeae3; border-color: #443c44; }
"""
    full_css = css_content + '\n' + extra_css

    # Write windows/frontend/src/index.css
    with open('windows/frontend/src/index.css', 'w', encoding='utf-8') as f:
        f.write(full_css)
    print("Updated windows/frontend/src/index.css")

    # Read JS components template
    js_template = read_file('tools/ember_app_template.js')
    
    preview_html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Ember Launcher — Native Windows Edition (1-to-1 Exact Match)</title>
  <!-- React 18 & Babel for instant browser rendering -->
  <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <!-- Three.js for authentic 360° Minecraft Character Viewport -->
  <script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>
  <!-- Typography matching Ember design handoff: Manrope & DM Mono -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
""" + full_css + """
  </style>
</head>
<body>
  <div id="root"></div>

  <script type="text/babel">
""" + js_template + """
    ReactDOM.createRoot(document.getElementById('root')).render(<App />);
  </script>
</body>
</html>
"""

    with open('windows/preview.html', 'w', encoding='utf-8') as f:
        f.write(preview_html)
    print(f"Updated windows/preview.html ({len(preview_html)} bytes)")

    # Generate App.tsx
    app_tsx = """import React, { useEffect, useState, useRef } from 'react';
import './index.css';

// Optional Tauri v2 invoke wrapper
let invoke = async (cmd: string, args?: any): Promise<any> => {
  try {
    const tauri = await import('@tauri-apps/api/core');
    return await tauri.invoke(cmd, args);
  } catch {
    return null;
  }
};

""" + js_template + """
export default App;
"""
    with open('windows/frontend/src/App.tsx', 'w', encoding='utf-8') as f:
        f.write(app_tsx)
    print(f"Updated windows/frontend/src/App.tsx ({len(app_tsx)} bytes)")

if __name__ == '__main__':
    main()
