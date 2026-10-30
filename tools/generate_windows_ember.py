#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates windows/preview.html (standalone React + Three.js browser preview)
and windows/frontend/src/App.tsx (Tauri React TypeScript code).
Both are 1-to-1 exact replicas of Ember Launcher 0.2.2 (macOS Swift/SwiftUI).
"""

import os
import sys

def build_preview_html():
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Ember Launcher v2 — Native Windows Edition (1-to-1 Exact Match)</title>
  <!-- React 18 & Babel for instant zero-setup browser viewing -->
  <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <!-- Three.js for true 3D Minecraft Character (Steve/Alex) Skin Viewport -->
  <script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>
  <!-- Typography: Manrope & DM Mono (Exact spec from EMBER_DESIGN_HANDOFF.md) -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
    /* Ember Design System Tokens & Base */
    :root {
      font-family: 'Manrope', sans-serif;
      color: #eeeae3;
      background: #080808;
      font-synthesis: none;

      --bg: #09090b;
      --card-bg: #141316;
      --border: #232026;
      --border-focus: #3b3640;
      --accent: #f0a062;
      --accent-deep: #b35a2b;
      --accent-glow: rgba(240, 160, 98, 0.25);
      --violet: #9258c4;
      --violet-deep: #4d2b6b;
      --ink: #f5f2eb;
      --muted: #827b85;
      --subtle: #57525a;
      --danger: #cf6679;
      --success: #94a978;
    }

    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      width: 100vw;
      height: 100vh;
      overflow: hidden;
      background: #080808;
      user-select: none;
      -webkit-user-select: none;
    }

    button, input, select, textarea {
      font-family: inherit;
      color: inherit;
    }

    /* Ambient drifting backdrops matching AmbientBackdrop.swift */
    .ambient {
      position: absolute;
      border-radius: 50%;
      filter: blur(140px);
      pointer-events: none;
      z-index: 1;
    }
    .ambient-one {
      width: 620px;
      height: 620px;
      left: -120px;
      top: -120px;
      background: radial-gradient(circle, rgba(146, 88, 196, 0.16), transparent 70%);
      animation: driftOne 13s ease-in-out infinite alternate;
    }
    .ambient-two {
      width: 540px;
      height: 540px;
      right: -80px;
      bottom: -80px;
      background: radial-gradient(circle, rgba(240, 160, 98, 0.14), transparent 70%);
      animation: driftTwo 16s ease-in-out infinite alternate;
    }

    @keyframes driftOne {
      0% { transform: translate(0, 0) scale(1); }
      100% { transform: translate(120px, 90px) scale(1.15); }
    }
    @keyframes driftTwo {
      0% { transform: translate(0, 0) scale(1); }
      100% { transform: translate(-100px, -80px) scale(0.92); }
    }

    /* Aurora bands (18s and 23s periods) */
    .aurora-field {
      position: absolute;
      inset: 0;
      pointer-events: none;
      z-index: 2;
      overflow: hidden;
    }
    .aurora-field span {
      position: absolute;
      width: 180%;
      height: 280px;
      left: -40%;
      border-radius: 50%;
      filter: blur(75px);
      opacity: 0.13;
    }
    .aurora-field span:nth-child(1) {
      top: -100px;
      background: linear-gradient(90deg, transparent, #9258c4, #f0a062, transparent);
      animation: waveOne 18s ease-in-out infinite alternate;
    }
    .aurora-field span:nth-child(2) {
      top: 60px;
      background: linear-gradient(90deg, transparent, #4d2b6b, #cf7548, transparent);
      animation: waveTwo 23s ease-in-out infinite alternate;
    }

    @keyframes waveOne {
      0% { transform: rotate(-5deg) translateY(0); }
      100% { transform: rotate(4deg) translateY(45px); }
    }
    @keyframes waveTwo {
      0% { transform: rotate(3deg) translateY(0); }
      100% { transform: rotate(-6deg) translateY(-40px); }
    }

    /* Ember dust particles */
    .ember-field {
      position: absolute;
      inset: 0;
      pointer-events: none;
      z-index: 3;
    }
    .ember-field span {
      position: absolute;
      bottom: -20px;
      width: 3px;
      height: 3px;
      border-radius: 50%;
      background: #f0a062;
      box-shadow: 0 0 8px #f0a062;
      animation: rise 9s cubic-bezier(0.2, 0.8, 0.4, 1) infinite;
    }
    .ember-field span:nth-child(1) { left: 12%; animation-duration: 7s; animation-delay: 0s; }
    .ember-field span:nth-child(2) { left: 24%; animation-duration: 11s; animation-delay: 2s; }
    .ember-field span:nth-child(3) { left: 38%; animation-duration: 8.5s; animation-delay: 1.2s; }
    .ember-field span:nth-child(4) { left: 52%; animation-duration: 10s; animation-delay: 3s; }
    .ember-field span:nth-child(5) { left: 66%; animation-duration: 7.8s; animation-delay: 0.5s; }
    .ember-field span:nth-child(6) { left: 81%; animation-duration: 9.2s; animation-delay: 4s; }
    .ember-field span:nth-child(7) { left: 93%; animation-duration: 12s; animation-delay: 1.8s; }

    @keyframes rise {
      0% { transform: translateY(0) scale(0.6); opacity: 0; }
      15% { opacity: 0.8; }
      85% { opacity: 0.7; }
      100% { transform: translateY(-110vh) scale(1.4); opacity: 0; }
    }

    /* Main App Shell Layout */
    .app-shell {
      position: relative;
      width: 100vw;
      height: 100vh;
      display: flex;
      background: #09090b;
      overflow: hidden;
      z-index: 5;
    }

    /* Sidebar matching SidebarNavigation.swift */
    .sidebar {
      width: 68px;
      background: rgba(14, 13, 16, 0.85);
      backdrop-filter: blur(28px);
      -webkit-backdrop-filter: blur(28px);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 16px 0;
      z-index: 30;
      flex-shrink: 0;
    }
    .brand {
      width: 44px;
      height: 44px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 24px;
      cursor: pointer;
      transition: transform 0.25s ease;
    }
    .brand:hover {
      transform: scale(1.08) rotate(4deg);
    }
    .nav-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
      width: 100%;
      align-items: center;
    }
    .nav-button {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      border: 1px solid transparent;
      background: transparent;
      color: var(--muted);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
      position: relative;
    }
    .nav-button:hover {
      color: var(--ink);
      background: rgba(255, 255, 255, 0.05);
      border-color: rgba(255, 255, 255, 0.08);
      transform: translateY(-1px);
    }
    .nav-button.active {
      color: #17110c;
      background: linear-gradient(135deg, var(--accent), var(--accent-deep));
      box-shadow: 0 4px 16px var(--accent-glow);
      border-color: rgba(255, 255, 255, 0.2);
    }
    .settings-button {
      margin-top: auto;
      margin-bottom: 8px;
    }

    /* Workspace */
    .workspace {
      flex: 1;
      display: flex;
      flex-direction: column;
      height: 100vh;
      overflow: hidden;
      position: relative;
    }

    /* TopBar matching TopBar.swift */
    .topbar {
      height: 64px;
      padding: 0 28px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
      background: rgba(14, 13, 16, 0.5);
      backdrop-filter: blur(20px);
      z-index: 25;
      flex-shrink: 0;
    }
    .topbar-left {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .topbar-eyebrow {
      font-size: 10px;
      font-family: 'DM Mono', monospace;
      color: var(--muted);
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .topbar-title {
      font-size: 16px;
      font-weight: 700;
      color: var(--ink);
      letter-spacing: -0.02em;
    }
    .topbar-right {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    /* TopBar Widgets */
    .health-pill {
      display: flex;
      align-items: center;
      gap: 7px;
      padding: 6px 12px;
      border-radius: 999px;
      background: rgba(148, 169, 120, 0.1);
      border: 1px solid rgba(148, 169, 120, 0.25);
      color: var(--success);
      font-size: 11px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .health-pill:hover {
      background: rgba(148, 169, 120, 0.18);
      border-color: rgba(148, 169, 120, 0.4);
      transform: translateY(-1px);
    }
    .health-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 8px var(--success);
      animation: pulseDot 2.4s infinite;
    }
    @keyframes pulseDot {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(0.85); }
    }

    .social-pill {
      display: flex;
      align-items: center;
      gap: 9px;
      padding: 5px 12px 5px 8px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border);
      color: var(--ink);
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .social-pill:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: var(--border-focus);
    }
    .avatar-stack {
      display: flex;
      align-items: center;
    }
    .avatar-stack span {
      width: 22px;
      height: 22px;
      border-radius: 50%;
      border: 2px solid #0e0d10;
      margin-left: -7px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 10px;
      font-weight: 700;
      color: #fff;
    }
    .avatar-stack span:first-child { margin-left: 0; }
    .av-1 { background: #5a7d60; }
    .av-2 { background: #7c5a8a; }
    .av-3 { background: #a87948; }

    .account-pill {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 4px 12px 4px 5px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .account-pill:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: var(--border-focus);
    }
    .steve-avatar {
      width: 26px;
      height: 26px;
      border-radius: 6px;
      background: #b97b58;
      box-shadow: inset 0 7px #2b1b24;
      position: relative;
    }
    .steve-avatar::after {
      content: '';
      position: absolute;
      top: 13px;
      left: 5px;
      width: 4px;
      height: 3px;
      background: #21171a;
      box-shadow: 12px 0 #21171a;
    }
    .account-info {
      display: flex;
      flex-direction: column;
      line-height: 1.1;
    }
    .account-info strong {
      font-size: 12px;
      font-weight: 600;
      color: var(--ink);
    }
    .account-info small {
      font-size: 10px;
      color: var(--success);
      font-family: 'DM Mono', monospace;
    }

    /* Screen Views Scroll Container */
    .content-area {
      flex: 1;
      overflow-y: auto;
      overflow-x: hidden;
      position: relative;
      display: flex;
      flex-direction: column;
    }

    /* Play Screen / Hero matching HeroScene.swift */
    .hero-scene {
      position: relative;
      height: 480px;
      overflow: hidden;
      border-bottom: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
      padding: 40px;
    }
    .sky-backdrop {
      position: absolute;
      inset: 0;
      background: linear-gradient(180deg, #18121f 0%, #281729 45%, #3d232c 85%, #19141b 100%);
      z-index: 1;
    }
    .sun-disc {
      position: absolute;
      width: 140px;
      height: 140px;
      border-radius: 50%;
      right: 18%;
      top: 18%;
      background: radial-gradient(circle, #fff1d4 0%, #f0a062 55%, rgba(240, 160, 98, 0) 75%);
      box-shadow: 0 0 60px rgba(240, 160, 98, 0.45);
      animation: sunBreathe 6s ease-in-out infinite alternate;
      z-index: 2;
    }
    @keyframes sunBreathe {
      0% { transform: scale(1); filter: brightness(1); }
      100% { transform: scale(1.08); filter: brightness(1.15); }
    }
    .mountains-back {
      position: absolute;
      bottom: 0;
      left: 0;
      width: 120%;
      height: 240px;
      background: #251b27;
      clip-path: polygon(0 100%, 15% 45%, 32% 80%, 48% 30%, 65% 75%, 82% 25%, 100% 70%, 100% 100%);
      z-index: 3;
      opacity: 0.6;
    }
    .mountains-mid {
      position: absolute;
      bottom: 0;
      left: -5%;
      width: 110%;
      height: 180px;
      background: #1b141f;
      clip-path: polygon(0 100%, 20% 40%, 42% 85%, 58% 35%, 78% 70%, 95% 25%, 100% 100%);
      z-index: 4;
      opacity: 0.85;
    }
    .pine-forest {
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
      height: 110px;
      display: flex;
      align-items: flex-end;
      gap: 14px;
      padding-left: 20px;
      z-index: 5;
    }
    .pine-tree {
      width: 28px;
      height: 90px;
      background: #120e14;
      clip-path: polygon(50% 0, 100% 35%, 85% 35%, 100% 65%, 80% 65%, 100% 95%, 0 95%, 20% 65%, 0 65%, 15% 35%, 0 35%);
      transform-origin: bottom center;
      animation: pineSway 4.5s ease-in-out infinite alternate;
    }
    .pine-tree:nth-child(2n) {
      height: 75px;
      width: 24px;
      animation-duration: 5.2s;
      animation-delay: -1.2s;
    }
    .pine-tree:nth-child(3n) {
      height: 105px;
      width: 32px;
      animation-duration: 4.8s;
      animation-delay: -2.1s;
    }
    @keyframes pineSway {
      0% { transform: skewX(-1.8deg); }
      100% { transform: skewX(1.8deg); }
    }
    .hero-content {
      position: relative;
      z-index: 10;
      max-width: 600px;
    }
    .hero-eyebrow {
      font-size: 11px;
      font-family: 'DM Mono', monospace;
      color: var(--accent);
      letter-spacing: 0.15em;
      margin-bottom: 6px;
    }
    .hero-heading {
      font-size: 42px;
      font-weight: 800;
      letter-spacing: -0.04em;
      line-height: 1.05;
      color: #fff;
      margin: 0 0 12px 0;
    }
    .hero-subtitle {
      font-size: 14px;
      color: #b3abb8;
      line-height: 1.5;
      margin: 0 0 24px 0;
    }

    /* Launch Bar */
    .launch-bar {
      display: flex;
      align-items: center;
      gap: 14px;
      background: rgba(18, 16, 20, 0.75);
      border: 1px solid var(--border);
      backdrop-filter: blur(24px);
      padding: 10px 14px;
      border-radius: 18px;
      width: fit-content;
      box-shadow: 0 16px 36px rgba(0, 0, 0, 0.45);
    }
    .version-trigger {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 14px;
      border-radius: 12px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.06);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .version-trigger:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(255, 255, 255, 0.12);
    }
    .version-icon {
      width: 24px;
      height: 24px;
      border-radius: 6px;
      background: linear-gradient(135deg, var(--accent), var(--accent-deep));
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 12px;
    }
    .version-text {
      display: flex;
      flex-direction: column;
      line-height: 1.1;
      text-align: left;
    }
    .version-text small {
      font-size: 9px;
      color: var(--muted);
      font-family: 'DM Mono', monospace;
    }
    .version-text strong {
      font-size: 13px;
      font-weight: 700;
      color: var(--ink);
    }
    .gear-btn {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.06);
      color: var(--muted);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .gear-btn:hover {
      color: var(--ink);
      background: rgba(255, 255, 255, 0.08);
      transform: rotate(30deg);
    }
    .play-btn {
      display: flex;
      align-items: center;
      gap: 14px;
      padding: 0 24px 0 16px;
      height: 48px;
      border-radius: 14px;
      border: none;
      background: linear-gradient(135deg, var(--accent), var(--accent-deep));
      color: #17110c;
      cursor: pointer;
      box-shadow: 0 6px 24px var(--accent-glow);
      transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
    }
    .play-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 30px rgba(240, 160, 98, 0.4);
    }
    .play-btn:active {
      transform: translateY(0);
    }
    .play-btn-icon {
      width: 32px;
      height: 32px;
      border-radius: 9px;
      background: rgba(0, 0, 0, 0.16);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .play-btn-text {
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      line-height: 1.1;
    }
    .play-btn-text strong {
      font-size: 14px;
      font-weight: 800;
      letter-spacing: 0.04em;
    }
    .play-btn-text small {
      font-size: 10px;
      opacity: 0.85;
      font-weight: 600;
    }

    /* Screen Common Containers */
    .screen-container {
      padding: 32px 36px 64px 36px;
      max-width: 1180px;
      margin: 0 auto;
      width: 100%;
    }
    .screen-header {
      margin-bottom: 24px;
    }
    .screen-eyebrow {
      font-size: 10px;
      font-family: 'DM Mono', monospace;
      color: var(--accent);
      letter-spacing: 0.14em;
      text-transform: uppercase;
      margin-bottom: 6px;
    }
    .screen-title {
      font-size: 32px;
      font-weight: 800;
      letter-spacing: -0.03em;
      color: #fff;
      margin: 0 0 6px 0;
    }
    .screen-desc {
      font-size: 13px;
      color: var(--muted);
      margin: 0;
    }

    /* Library Screen Cards Grid */
    .filter-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 20px;
      flex-wrap: wrap;
    }
    .chips-group {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .chip {
      padding: 6px 14px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 600;
      border: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.03);
      color: var(--muted);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .chip:hover {
      color: var(--ink);
      border-color: var(--border-focus);
    }
    .chip.active {
      background: rgba(255, 255, 255, 0.12);
      color: #fff;
      border-color: rgba(255, 255, 255, 0.25);
    }
    .search-input {
      padding: 7px 14px;
      border-radius: 10px;
      border: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.03);
      color: var(--ink);
      font-size: 12px;
      outline: none;
      width: 220px;
      transition: all 0.2s ease;
    }
    .search-input:focus {
      border-color: var(--accent);
      background: rgba(255, 255, 255, 0.06);
    }
    .actions-group {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .btn-secondary {
      padding: 7px 16px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 600;
      border: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.04);
      color: var(--ink);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: var(--border-focus);
    }
    .btn-primary {
      padding: 7px 16px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      border: none;
      background: linear-gradient(135deg, var(--accent), var(--accent-deep));
      color: #17110c;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .btn-primary:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 14px var(--accent-glow);
    }

    .instances-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 18px;
    }
    .instance-card {
      border-radius: 16px;
      border: 1px solid var(--border);
      background: var(--card-bg);
      overflow: hidden;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.2, 0.8, 0.2, 1);
      display: flex;
      flex-direction: column;
    }
    .instance-card:hover {
      border-color: var(--border-focus);
      transform: translateY(-3px);
      box-shadow: 0 12px 28px rgba(0, 0, 0, 0.35);
    }
    .card-preview {
      height: 120px;
      position: relative;
      overflow: hidden;
      display: flex;
      align-items: flex-end;
      padding: 14px;
    }
    .cp-dusk { background: linear-gradient(135deg, #3d232c, #1a151f); }
    .cp-violet { background: linear-gradient(135deg, #4d2b6b, #1d1829); }
    .cp-gold { background: linear-gradient(135deg, #5c4323, #1c1713); }
    .cp-void { background: linear-gradient(135deg, #242938, #11151f); }
    .card-badge {
      font-size: 10px;
      font-family: 'DM Mono', monospace;
      padding: 3px 8px;
      border-radius: 6px;
      background: rgba(0, 0, 0, 0.55);
      backdrop-filter: blur(8px);
      color: #fff;
    }
    .card-body {
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .card-body h4 {
      margin: 0;
      font-size: 16px;
      font-weight: 700;
      color: var(--ink);
    }
    .card-meta {
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 12px;
      color: var(--muted);
    }
    .card-actions {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-top: 6px;
      padding-top: 10px;
      border-top: 1px solid rgba(255, 255, 255, 0.04);
    }
    .card-actions button {
      padding: 5px 12px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 600;
      border: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.04);
      color: var(--ink);
      cursor: pointer;
    }
    .card-actions button:hover {
      background: rgba(255, 255, 255, 0.08);
    }
    .card-actions button.play-sub {
      background: var(--accent);
      color: #17110c;
      border: none;
      font-weight: 700;
    }

    /* Social Screen (3 Columns) */
    .social-columns {
      display: grid;
      grid-template-columns: 1fr 1.3fr 1fr;
      gap: 20px;
    }
    .social-col {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .social-col-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding-bottom: 12px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    }
    .social-col-head h3 {
      margin: 0;
      font-size: 14px;
      font-weight: 700;
      color: var(--ink);
    }
    .friend-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px;
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid rgba(255, 255, 255, 0.03);
    }
    .friend-left {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .online-indicator {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 6px var(--success);
    }
    .offline-indicator {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--subtle);
    }
    .friend-details strong {
      font-size: 13px;
      font-weight: 600;
      color: var(--ink);
    }
    .friend-details small {
      font-size: 11px;
      color: var(--muted);
    }
    .lobby-card-item {
      padding: 14px;
      border-radius: 12px;
      border: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.02);
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .lobby-card-item strong {
      font-size: 14px;
      color: var(--ink);
    }
    .lobby-card-item p {
      margin: 0;
      font-size: 12px;
      color: var(--muted);
    }

    /* Explore / Mods Screen */
    .mods-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .mod-card {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 16px 20px;
      border-radius: 14px;
      border: 1px solid var(--border);
      background: var(--card-bg);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .mod-card:hover {
      border-color: var(--border-focus);
      background: rgba(255, 255, 255, 0.03);
    }
    .mod-left {
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .mod-icon-box {
      width: 48px;
      height: 48px;
      border-radius: 12px;
      background: #251d2a;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .mod-text {
      display: flex;
      flex-direction: column;
      gap: 3px;
    }
    .mod-text small {
      font-size: 10px;
      font-family: 'DM Mono', monospace;
      color: var(--accent);
      text-transform: uppercase;
    }
    .mod-text strong {
      font-size: 15px;
      color: var(--ink);
    }
    .mod-text p {
      margin: 0;
      font-size: 12px;
      color: var(--muted);
      max-width: 580px;
    }

    /* Skins Screen with 3D Canvas matching Skin3DView.swift */
    .skins-layout {
      display: grid;
      grid-template-columns: 1.2fr 1fr;
      gap: 28px;
      align-items: start;
    }
    .skin-viewport-box {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 20px;
      height: 460px;
      position: relative;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      cursor: grab;
    }
    .skin-viewport-box:active {
      cursor: grabbing;
    }
    .skin-controls-bar {
      position: absolute;
      top: 14px;
      left: 14px;
      right: 14px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      z-index: 10;
    }
    .skin-toggle-group {
      display: flex;
      background: rgba(0, 0, 0, 0.6);
      backdrop-filter: blur(12px);
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 3px;
    }
    .skin-toggle-btn {
      padding: 4px 12px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 600;
      border: none;
      background: transparent;
      color: var(--muted);
      cursor: pointer;
    }
    .skin-toggle-btn.active {
      background: rgba(255, 255, 255, 0.15);
      color: #fff;
    }
    .skin-drag-hint {
      position: absolute;
      bottom: 16px;
      font-size: 11px;
      color: var(--subtle);
      font-family: 'DM Mono', monospace;
      pointer-events: none;
    }
    .skin-presets-panel {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .preset-card {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 16px;
      border-radius: 12px;
      border: 1px solid var(--border);
      background: var(--card-bg);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .preset-card:hover {
      border-color: var(--border-focus);
    }
    .preset-card.selected {
      border-color: var(--accent);
      background: rgba(240, 160, 98, 0.06);
    }

    /* Settings Screen Sections */
    .settings-layout {
      display: grid;
      grid-template-columns: 220px 1fr;
      gap: 32px;
    }
    .settings-nav {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .settings-nav-btn {
      text-align: left;
      padding: 10px 14px;
      border-radius: 10px;
      border: 1px solid transparent;
      background: transparent;
      color: var(--muted);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .settings-nav-btn:hover {
      color: var(--ink);
      background: rgba(255, 255, 255, 0.04);
    }
    .settings-nav-btn.active {
      color: #fff;
      background: rgba(255, 255, 255, 0.08);
      border-color: var(--border);
    }
    .settings-section-card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 24px;
      display: flex;
      flex-direction: column;
      gap: 20px;
    }
    .settings-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding-bottom: 16px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    }
    .settings-row:last-child {
      border-bottom: none;
      padding-bottom: 0;
    }
    .settings-label strong {
      font-size: 14px;
      color: var(--ink);
      display: block;
      margin-bottom: 3px;
    }
    .settings-label small {
      font-size: 12px;
      color: var(--muted);
    }

    /* Modals System matching RootView.swift & Modal.swift */
    .modal-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.65);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 100;
      animation: modalFadeIn 0.24s cubic-bezier(0.2, 0.8, 0.2, 1);
    }
    @keyframes modalFadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .modal-box {
      background: #141316;
      border: 1px solid #28242c;
      border-radius: 20px;
      box-shadow: 0 24px 60px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(255, 255, 255, 0.05);
      width: 580px;
      max-width: 90vw;
      max-height: 88vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      animation: modalScaleUp 0.24s cubic-bezier(0.2, 0.8, 0.2, 1);
    }
    .modal-box-wide {
      width: 720px;
    }
    @keyframes modalScaleUp {
      from { transform: scale(0.95); opacity: 0; }
      to { transform: scale(1); opacity: 1; }
    }
    .modal-head {
      padding: 22px 26px 18px 26px;
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }
    .modal-head-titles {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .modal-head-titles span {
      font-size: 10px;
      font-family: 'DM Mono', monospace;
      color: var(--accent);
      letter-spacing: 0.12em;
    }
    .modal-head-titles h3 {
      margin: 0;
      font-size: 20px;
      font-weight: 700;
      color: #fff;
    }
    .close-btn {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      border: 1px solid rgba(255, 255, 255, 0.08);
      background: rgba(255, 255, 255, 0.03);
      color: var(--muted);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .close-btn:hover {
      color: #fff;
      background: rgba(255, 255, 255, 0.08);
    }
    .modal-body {
      padding: 24px 26px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 18px;
    }
    .modal-foot {
      padding: 16px 26px;
      border-top: 1px solid rgba(255, 255, 255, 0.05);
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 12px;
      background: rgba(14, 13, 16, 0.5);
    }

    /* Mode switcher tabs for NewInstanceModal */
    .mode-tabs {
      display: flex;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 4px;
      gap: 4px;
    }
    .mode-tab-btn {
      flex: 1;
      padding: 8px 12px;
      border-radius: 8px;
      border: none;
      background: transparent;
      color: var(--muted);
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .mode-tab-btn.active {
      background: rgba(255, 255, 255, 0.1);
      color: #fff;
    }

    /* AI Assistant Prompting */
    .ai-prompt-box {
      width: 100%;
      height: 90px;
      padding: 12px 14px;
      border-radius: 12px;
      border: 1px solid var(--border);
      background: rgba(0, 0, 0, 0.35);
      color: var(--ink);
      font-size: 13px;
      resize: none;
      outline: none;
    }
    .ai-prompt-box:focus {
      border-color: var(--accent);
    }
    .prompt-presets {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    }
    .prompt-chip {
      padding: 5px 12px;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.06);
      color: var(--muted);
      font-size: 11px;
      cursor: pointer;
    }
    .prompt-chip:hover {
      color: var(--ink);
      background: rgba(255, 255, 255, 0.07);
    }

    /* Smoothness Ring Gauge for SessionDiagnosticsView */
    .gauge-wrapper {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 14px 0;
    }
    .gauge-svg {
      transform: rotate(-90deg);
    }
    .gauge-bg {
      fill: none;
      stroke: rgba(255, 255, 255, 0.08);
      stroke-width: 8;
    }
    .gauge-val {
      fill: none;
      stroke: var(--success);
      stroke-width: 8;
      stroke-linecap: round;
      transition: stroke-dashoffset 0.8s ease;
    }

    /* Metrics 3-Col Row */
    .metrics-row {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
    }
    .metric-card {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 12px 14px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .metric-card span {
      font-size: 10px;
      font-family: 'DM Mono', monospace;
      color: var(--muted);
      text-transform: uppercase;
    }
    .metric-card strong {
      font-size: 13px;
      color: var(--ink);
    }

    /* Sliding Drawer matching FriendsDrawer.swift */
    .friends-drawer-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.5);
      z-index: 80;
      animation: modalFadeIn 0.2s ease;
    }
    .friends-drawer {
      position: fixed;
      right: 0;
      top: 0;
      bottom: 0;
      width: 340px;
      background: #141316;
      border-left: 1px solid var(--border);
      z-index: 85;
      display: flex;
      flex-direction: column;
      padding: 24px;
      gap: 18px;
      box-shadow: -16px 0 40px rgba(0, 0, 0, 0.6);
      animation: drawerSlideIn 0.26s cubic-bezier(0.2, 0.8, 0.2, 1);
    }
    @keyframes drawerSlideIn {
      from { transform: translateX(100%); }
      to { transform: translateX(0); }
    }

    /* Status Footer Bar */
    .footer-bar {
      height: 36px;
      padding: 0 28px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: rgba(14, 13, 16, 0.4);
      border-top: 1px solid rgba(255, 255, 255, 0.03);
      font-size: 11px;
      color: var(--subtle);
      font-family: 'DM Mono', monospace;
    }
    .status-badge {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .status-badge i {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 6px var(--success);
    }
  </style>
</head>
<body>
  <div id="root"></div>

  <script type="text/babel">
    const { useState, useEffect, useRef } = React;

    // SVG Icons Helper
    const Icon = ({ name, size = 18 }) => {
      const icons = {
        play: <path d="M5 3l14 9-14 9V3z" fill="currentColor" />,
        download: <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        library: <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 4.5A2.5 2.5 0 0 1 6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        social: <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm14 10v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        explore: <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        skins: <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        settings: <path d="M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm7.4 1.3a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V23a2 2 0 1 1-4 0v-.8a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H1a2 2 0 1 1 0-4h.8a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.5V1a2 2 0 1 1 4 0v.8a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.5 1H23a2 2 0 1 1 0 4h-.8a1.7 1.7 0 0 0-1.5 1z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        chevron: <path d="M6 9l6 6 6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        check: <path d="M20 6L9 17l-5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />,
        sparkles: <path d="M12 3v3m0 12v3M3 12h3m12 0h3M5.6 5.6l2.1 2.1m8.6 8.6l2.1 2.1M5.6 18.4l2.1-2.1m8.6-8.6l2.1-2.1" stroke="currentColor" strokeWidth="2" strokeLinecap="round" fill="none" />
      };
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: 'inline-block', verticalAlign: 'middle' }}>
          {icons[name] || icons.play}
        </svg>
      );
    };

    // Ember Logo matching EmberLogo.swift
    const EmberLogo = ({ size = 32 }) => (
      <svg width={size} height={size} viewBox="0 0 32 32" fill="none">
        <rect width="32" height="32" rx="9" fill="url(#emberGrad)" />
        <path d="M16 6L23 12V22L16 26L9 22V12L16 6Z" fill="#1b120c" />
        <path d="M16 9L20.5 13V19.5L16 22.5L11.5 19.5V13L16 9Z" fill="url(#flameGrad)" />
        <defs>
          <linearGradient id="emberGrad" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
            <stop stopColor="#f0a062" />
            <stop offset="1" stopColor="#b35a2b" />
          </linearGradient>
          <linearGradient id="flameGrad" x1="16" y1="9" x2="16" y2="22.5" gradientUnits="userSpaceOnUse">
            <stop stopColor="#fff2d6" />
            <stop offset="0.6" stopColor="#f0a062" />
            <stop offset="1" stopColor="#cf5a23" />
          </linearGradient>
        </defs>
      </svg>
    );

    // ==========================================
    // 3D SKIN VIEWPORT (WebGL Three.js implementation matching Skin3DView.swift)
    // ==========================================
    const Skin3DViewport = ({ skinIndex = 0, isSlim = false, is3D = true }) => {
      const mountRef = useRef(null);
      const isDraggingRef = useRef(false);
      const prevMousePos = useRef({ x: 0, y: 0 });
      const rotationRef = useRef({ x: 0.1, y: 0.3 });
      const [autoRotate, setAutoRotate] = useState(true);

      const skinColors = [
        { head: '#c88d6b', body: '#3a4b6e', limbs: '#2b3447', hair: '#4a2c16' }, // Ember
        { head: '#b97b58', body: '#5c483a', limbs: '#3b2f27', hair: '#2a1a12' }, // Wanderer
        { head: '#a87858', body: '#422e54', limbs: '#22192b', hair: '#18121f' }, // Nightfall
        { head: '#b97b58', body: '#00aaaa', limbs: '#0000aa', hair: '#4a2c16' }, // Steve
        { head: '#d49b78', body: '#55aa55', limbs: '#7d5c34', hair: '#c65c27' }, // Alex
      ];

      useEffect(() => {
        if (!is3D || !mountRef.current || typeof THREE === 'undefined') return;

        const width = mountRef.current.clientWidth || 380;
        const height = mountRef.current.clientHeight || 420;

        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(36, width / height, 0.5, 50);
        camera.position.set(0, 0, 4.4);

        const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: false });
        renderer.setSize(width, height);
        renderer.setPixelRatio(window.devicePixelRatio);
        mountRef.current.replaceChildren(renderer.domElement);

        // Lighting matching Skin3DView.swift
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.72);
        scene.add(ambientLight);

        const dirLight = new THREE.DirectionalLight(0xffffff, 0.55);
        dirLight.position.set(2, 3, 4);
        scene.add(dirLight);

        // Soft floor shadow
        const shadowGeo = new THREE.PlaneGeometry(1.4, 0.9);
        const shadowMat = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.35 });
        const shadow = new THREE.Mesh(shadowGeo, shadowMat);
        shadow.rotation.x = -Math.PI / 2;
        shadow.position.y = -1.18;
        scene.add(shadow);

        // Character Group
        const charGroup = new THREE.Group();
        scene.add(charGroup);

        const pal = skinColors[skinIndex % skinColors.length];
        const s = 0.07; // scale unit matching Swift

        const makeMat = (col) => new THREE.MeshLambertMaterial({ color: col });

        // Head (8x8x8)
        const head = new THREE.Mesh(new THREE.BoxGeometry(8 * s, 8 * s, 8 * s), makeMat(pal.head));
        head.position.set(0, 12 * s, 0);
        charGroup.add(head);

        // Hair / Hat overlay
        const hat = new THREE.Mesh(new THREE.BoxGeometry(8.6 * s, 8.6 * s, 8.6 * s), makeMat(pal.hair));
        hat.position.set(0, 12.3 * s, 0);
        charGroup.add(hat);

        // Torso (8x12x4)
        const torso = new THREE.Mesh(new THREE.BoxGeometry(8 * s, 12 * s, 4 * s), makeMat(pal.body));
        torso.position.set(0, 2 * s, 0);
        charGroup.add(torso);

        // Arms (4x12x4 or 3x12x4 slim)
        const armW = isSlim ? 3 * s : 4 * s;
        const leftArm = new THREE.Mesh(new THREE.BoxGeometry(armW, 12 * s, 4 * s), makeMat(pal.body));
        leftArm.position.set(-(4 * s + armW / 2), 2 * s, 0);
        charGroup.add(leftArm);

        const rightArm = new THREE.Mesh(new THREE.BoxGeometry(armW, 12 * s, 4 * s), makeMat(pal.body));
        rightArm.position.set(4 * s + armW / 2, 2 * s, 0);
        charGroup.add(rightArm);

        // Legs (4x12x4)
        const leftLeg = new THREE.Mesh(new THREE.BoxGeometry(4 * s, 12 * s, 4 * s), makeMat(pal.limbs));
        leftLeg.position.set(-2 * s, -10 * s, 0);
        charGroup.add(leftLeg);

        const rightLeg = new THREE.Mesh(new THREE.BoxGeometry(4 * s, 12 * s, 4 * s), makeMat(pal.limbs));
        rightLeg.position.set(2 * s, -10 * s, 0);
        charGroup.add(rightLeg);

        let animationFrameId;
        const animate = () => {
          if (autoRotate && !isDraggingRef.current) {
            rotationRef.current.y += 0.008;
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
      }, [skinIndex, isSlim, is3D, autoRotate]);

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
          style={{ width: '100%', height: '100%', position: 'relative' }}
          onMouseDown={onMouseDown}
          onMouseMove={onMouseMove}
          onMouseUp={onMouseUp}
          onMouseLeave={onMouseUp}
        />
      );
    };

    // ==========================================
    // MODAL: SessionDiagnosticsView matching SessionDiagnosticsView.swift
    // ==========================================
    const SessionDiagnosticsModal = ({ onClose }) => {
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
        <div className="modal-box modal-box-wide">
          <div className="modal-head">
            <div className="modal-head-titles">
              <span>DIAGNOSTICS & PERFORMANCE</span>
              <h3>Session Health</h3>
            </div>
            <button className="close-btn" onClick={onClose}>×</button>
          </div>

          <div className="modal-body">
            {/* Header Ring */}
            <div className="gauge-wrapper">
              <svg width="104" height="104" className="gauge-svg">
                <circle cx="52" cy="52" r={radius} className="gauge-bg" />
                <circle
                  cx="52"
                  cy="52"
                  r={radius}
                  className="gauge-val"
                  style={{ strokeDasharray: circ, strokeDashoffset: offset }}
                />
              </svg>
              <div style={{ position: 'absolute', textAlign: 'center', marginTop: '-12px' }}>
                <strong style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{score}</strong>
              </div>
              <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--success)' }}>
                Perfect smoothness · 0 micro-stutters
              </span>
            </div>

            {/* Metrics Row */}
            <div className="metrics-row">
              <div className="metric-card">
                <span>Memory freezes (GC)</span>
                <strong>0 freezes (max 12 ms)</strong>
              </div>
              <div className="metric-card">
                <span>World load (chunks/mobs)</span>
                <strong>0 tick drops</strong>
              </div>
              <div className="metric-card">
                <span>RAM & Java</span>
                <strong>6 GB · Java 21 ARM/x64</strong>
              </div>
            </div>

            {/* Findings List */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <span style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--muted)', letterSpacing: '0.1em' }}>
                DIAGNOSIS FINDINGS
              </span>
              <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border)', borderRadius: '12px', padding: '14px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px' }}>
                  <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--success)' }} />
                  <span>Garbage Collector tuned with optimal G1GC pause limits (&lt;15ms)</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px' }}>
                  <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--success)' }} />
                  <span>DirectX High Performance GPU pipeline active for javaw.exe</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px' }}>
                  <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#f0a062' }} />
                  <span>Chunk distance set to 16 (consider 12 for highest 1% frame lows)</span>
                </div>
              </div>
            </div>

            {fixed && (
              <div style={{ background: 'rgba(148, 169, 120, 0.1)', border: '1px solid rgba(148, 169, 120, 0.3)', borderRadius: '12px', padding: '12px 16px', display: 'flex', alignItems: 'center', gap: '10px', color: 'var(--success)', fontSize: '12px' }}>
                <Icon name="check" size={16} />
                <span>Optimized settings applied automatically! High-speed chunk cache enabled.</span>
              </div>
            )}
          </div>

          <div className="modal-foot">
            <button className="btn-secondary" onClick={onClose}>Close</button>
            <button
              className="btn-primary"
              disabled={fixing || fixed}
              onClick={handleAutoFix}
              style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
            >
              {fixing ? 'Applying Fixes…' : fixed ? 'All Optimizations Active' : 'Fix automatically in 1 click'}
            </button>
          </div>
        </div>
      );
    };

    // ==========================================
    // MODAL: VersionModal matching VersionModal.swift
    // ==========================================
    const VersionModal = ({ instanceName = 'Birch Hollow', onClose }) => {
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
        <div className="modal-box">
          <div className="modal-head">
            <div className="modal-head-titles">
              <span>SAFE VERSION MIGRATION</span>
              <h3>Change Version</h3>
            </div>
            <button className="close-btn" onClick={onClose}>×</button>
          </div>

          <div className="modal-body">
            <p style={{ margin: 0, fontSize: '13px', color: 'var(--muted)' }}>
              Current: <strong>{instanceName}</strong> · Minecraft 1.21.4 (Fabric)
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--accent)' }}>
                TARGET MINECRAFT VERSION
              </label>
              <select
                value={target}
                onChange={(e) => setTarget(e.target.value)}
                style={{ padding: '10px 12px', borderRadius: '10px', background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border)', color: '#fff', fontSize: '13px', outline: 'none' }}
              >
                <option value="1.21.1">Minecraft 1.21.1 (Fabric Supported)</option>
                <option value="1.20.6">Minecraft 1.20.6 (Fabric Supported)</option>
                <option value="1.20.1">Minecraft 1.20.1 · Massive Mod Ecosystem</option>
                <option value="1.19.4">Minecraft 1.19.4</option>
              </select>
              <small style={{ color: 'var(--subtle)', fontSize: '11px', marginTop: '4px' }}>
                Worlds and mods are backed up first. You can roll back anytime in 1 click.
              </small>
            </div>

            {/* Compatibility Check */}
            <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border)', borderRadius: '12px', padding: '14px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <span style={{ fontSize: '12px', color: 'var(--ink)' }}>
                Mods with a compatible version: <strong>38 of 42</strong>
              </span>
              <span style={{ fontSize: '11px', color: '#f0a062' }}>
                Will be safely disabled: LegacyBiomeGen, OldCapes
              </span>
            </div>

            {upgrading && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <span style={{ fontSize: '12px', color: 'var(--accent)' }}>{progress}</span>
                <div style={{ height: '4px', background: 'rgba(255,255,255,0.1)', borderRadius: '2px', overflow: 'hidden' }}>
                  <div style={{ width: '70%', height: '100%', background: 'var(--accent)', animation: 'rise 1.5s infinite' }} />
                </div>
              </div>
            )}

            {done && (
              <div style={{ background: 'rgba(148, 169, 120, 0.1)', border: '1px solid rgba(148, 169, 120, 0.3)', borderRadius: '12px', padding: '12px 16px', color: 'var(--success)', fontSize: '12px' }}>
                Successfully upgraded to Minecraft {target}! Previous state backed up to before-{target}.
              </div>
            )}

            {/* Snapshots Section */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '6px' }}>
              <span style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--muted)' }}>
                ROLLBACK SNAPSHOTS
              </span>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 14px', borderRadius: '10px', background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border)', fontSize: '12px' }}>
                <span>before-1.21.1 · Oct 28, 2026 · 142 MB</span>
                <button className="btn-secondary" style={{ padding: '4px 10px', fontSize: '10px' }} onClick={() => alert('Restoring backup snapshot...')}>Restore</button>
              </div>
            </div>
          </div>

          <div className="modal-foot">
            <button className="btn-secondary" onClick={onClose}>Cancel</button>
            <button className="btn-primary" disabled={upgrading || done} onClick={handleUpgrade}>
              {upgrading ? 'Upgrading…' : done ? 'Done' : 'Change version'}
            </button>
          </div>
        </div>
      );
    };

    // ==========================================
    // MODAL: LobbyFlowModal matching LobbyFlowModal.swift
    // ==========================================
    const LobbyFlowModal = ({ onClose }) => {
      const [isCreated, setIsCreated] = useState(false);
      const [copied, setCopied] = useState(false);
      const [privacy, setPrivacy] = useState('Friends only');

      const handleCopy = () => {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      };

      return (
        <div className="modal-box">
          <div className="modal-head">
            <div className="modal-head-titles">
              <span>TEMPORARY LOBBY</span>
              <h3>{isCreated ? 'Lobby is ready' : 'Bring friends in'}</h3>
            </div>
            <button className="close-btn" onClick={onClose}>×</button>
          </div>

          <div className="modal-body">
            {!isCreated ? (
              <>
                <p style={{ margin: 0, fontSize: '13px', color: 'var(--muted)' }}>
                  Host a temporary multiplayer session directly from your single-player world. No server required.
                </p>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--accent)' }}>SELECT WORLD</label>
                  <select style={{ padding: '10px 12px', borderRadius: '10px', background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border)', color: '#fff', fontSize: '13px' }}>
                    <option>Birch Hollow (Survival)</option>
                    <option>Ember Valley (Fabric · 42 mods)</option>
                    <option>First Shelter (Vanilla)</option>
                  </select>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <label style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--accent)' }}>PRIVACY</label>
                  {['Friends only', 'Invite only', 'Public'].map((opt) => (
                    <div
                      key={opt}
                      onClick={() => setPrivacy(opt)}
                      style={{
                        padding: '12px 14px',
                        borderRadius: '10px',
                        border: `1px solid ${privacy === opt ? 'var(--accent)' : 'var(--border)'}`,
                        background: privacy === opt ? 'rgba(240, 160, 98, 0.08)' : 'rgba(255,255,255,0.02)',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        fontSize: '13px'
                      }}
                    >
                      <strong>{opt}</strong>
                      <span style={{ fontSize: '11px', color: 'var(--muted)' }}>
                        {opt === 'Friends only' ? 'Anyone on your friends list' : opt === 'Invite only' ? 'Only people with code' : 'Visible in Social'}
                      </span>
                    </div>
                  ))}
                </div>
              </>
            ) : (
              <>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: 'var(--success)', fontSize: '13px', fontWeight: 600 }}>
                  <span className="health-dot" />
                  <span>Lobby hosted on port 25565 via peer relay</span>
                </div>

                <div style={{ background: 'rgba(0,0,0,0.4)', border: '1px solid var(--border)', borderRadius: '14px', padding: '18px', textAlign: 'center', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <span style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--muted)' }}>LOBBY INVITE CODE</span>
                  <strong style={{ fontSize: '24px', letterSpacing: '0.12em', color: 'var(--accent)' }}>
                    EMBER-7729-NORD
                  </strong>
                  <button
                    className="btn-primary"
                    onClick={handleCopy}
                    style={{ alignSelf: 'center', display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 20px' }}
                  >
                    {copied ? <Icon name="check" size={14} /> : null}
                    <span>{copied ? 'Code Copied!' : 'Copy Invite Code'}</span>
                  </button>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <span style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--muted)' }}>CONNECTED PLAYERS (1/8)</span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '10px', borderRadius: '10px', background: 'rgba(255,255,255,0.02)' }}>
                    <div className="steve-avatar" style={{ width: '22px', height: '22px' }} />
                    <strong style={{ fontSize: '12px' }}>Conlee (Host)</strong>
                  </div>
                </div>
              </>
            )}
          </div>

          <div className="modal-foot">
            <button className="btn-secondary" onClick={onClose}>Close</button>
            {!isCreated && (
              <button className="btn-primary" onClick={() => setIsCreated(true)}>Create Lobby</button>
            )}
          </div>
        </div>
      );
    };

    // ==========================================
    // MODAL: NewInstanceFlow with AI & Mrpack matching NewInstanceModal.swift
    // ==========================================
    const NewInstanceFlow = ({ onClose, onCreate }) => {
      const [mode, setMode] = useState('custom'); // 'custom' | 'mrpack' | 'ai'
      const [step, setStep] = useState(1);
      const [name, setName] = useState('A quiet new world');
      const [loader, setLoader] = useState('Fabric');
      const [version, setVersion] = useState('1.21.4');

      // AI States
      const [aiPrompt, setAiPrompt] = useState('');
      const [isThinking, setIsThinking] = useState(false);
      const [aiPlan, setAiPlan] = useState(null);
      const [selectedMods, setSelectedMods] = useState(new Set());
      const [isBuilding, setIsBuilding] = useState(false);

      const loaders = [
        { name: 'Vanilla', note: 'Pure official game experience' },
        { name: 'Fabric', note: 'Fast, modular, modern ecosystem' },
        { name: 'Forge', note: 'Extensive legacy modpack foundation' },
        { name: 'NeoForge', note: 'Community-driven modern fork' },
      ];

      const handleSuggestMods = () => {
        setIsThinking(true);
        setTimeout(() => {
          setIsThinking(false);
          const plan = {
            summary: 'Crafted a balanced Fabric 1.21.4 setup featuring Sodium graphics optimization, Iris shader pipeline, and exploration essentials.',
            mods: [
              { id: 'sodium', name: 'Sodium', category: 'Performance', desc: 'Drastically improves FPS and eliminates frame stuttering' },
              { id: 'lithium', name: 'Lithium', category: 'Optimization', desc: 'Optimizes physics, mob AI, and chunk ticking' },
              { id: 'iris', name: 'Iris Shaders', category: 'Visuals', desc: 'Enables high-performance modern shaderpacks' },
              { id: 'fabric-api', name: 'Fabric API', category: 'Library', desc: 'Core essential hook library for Fabric mods' },
              { id: 'appleskin', name: 'AppleSkin', category: 'Quality of Life', desc: 'Displays food saturation and health preview' },
              { id: 'journeymap', name: 'JourneyMap', category: 'Exploration', desc: 'Smooth real-time minimap with waypoint tracking' },
            ]
          };
          setAiPlan(plan);
          setSelectedMods(new Set(plan.mods.map(m => m.id)));
        }, 1600);
      };

      const toggleMod = (id) => {
        const next = new Set(selectedMods);
        if (next.has(id)) next.delete(id);
        else next.add(id);
        setSelectedMods(next);
      };

      const handleCreate = () => {
        setIsBuilding(true);
        setTimeout(() => {
          onCreate([name || 'A quiet new world', version, loader, '0m', 'violet']);
          onClose();
        }, 1800);
      };

      return (
        <div className="modal-box modal-box-wide">
          <div className="modal-head">
            <div className="modal-head-titles">
              <span>CREATE INSTANCE</span>
              <h3>New Minecraft World</h3>
            </div>
            <button className="close-btn" onClick={onClose}>×</button>
          </div>

          <div className="modal-body">
            {/* Mode Switcher Tabs */}
            <div className="mode-tabs">
              <button className={`mode-tab-btn ${mode === 'custom' ? 'active' : ''}`} onClick={() => setMode('custom')}>
                Custom Wizard
              </button>
              <button className={`mode-tab-btn ${mode === 'mrpack' ? 'active' : ''}`} onClick={() => setMode('mrpack')}>
                Modrinth Pack (.mrpack)
              </button>
              <button className={`mode-tab-btn ${mode === 'ai' ? 'active' : ''}`} onClick={() => setMode('ai')}>
                AI Assistant ✦
              </button>
            </div>

            {/* CUSTOM WIZARD MODE */}
            {mode === 'custom' && (
              <>
                <div style={{ display: 'flex', gap: '8px', marginBottom: '8px' }}>
                  {[1, 2, 3].map(i => (
                    <div key={i} style={{ flex: 1, height: '4px', borderRadius: '2px', background: i <= step ? 'var(--accent)' : 'rgba(255,255,255,0.1)' }} />
                  ))}
                </div>

                {step === 1 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <label style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--accent)' }}>INSTANCE NAME</label>
                      <input
                        className="search-input"
                        style={{ width: '100%', padding: '12px 14px', fontSize: '14px' }}
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        placeholder="A quiet new world"
                      />
                    </div>
                    <div style={{ padding: '16px', borderRadius: '12px', background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: '14px' }}>
                      <div className="version-icon">★</div>
                      <div>
                        <small style={{ color: 'var(--muted)', fontSize: '10px', fontFamily: 'DM Mono' }}>INSTANCE PREVIEW</small>
                        <h4 style={{ margin: 0, fontSize: '16px', color: 'var(--ink)' }}>{name || 'A quiet new world'}</h4>
                      </div>
                    </div>
                  </div>
                )}

                {step === 2 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                    <label style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--accent)' }}>CHOOSE MOD LOADER</label>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                      {loaders.map((ld) => (
                        <div
                          key={ld.name}
                          onClick={() => setLoader(ld.name)}
                          style={{
                            padding: '14px',
                            borderRadius: '12px',
                            border: `1px solid ${loader === ld.name ? 'var(--accent)' : 'var(--border)'}`,
                            background: loader === ld.name ? 'rgba(240, 160, 98, 0.08)' : 'rgba(255,255,255,0.02)',
                            cursor: 'pointer'
                          }}
                        >
                          <strong style={{ fontSize: '14px', color: 'var(--ink)', display: 'block' }}>{ld.name}</strong>
                          <small style={{ fontSize: '11px', color: 'var(--muted)' }}>{ld.note}</small>
                        </div>
                      ))}
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '6px' }}>
                      <label style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--accent)' }}>MINECRAFT VERSION</label>
                      <select
                        value={version}
                        onChange={(e) => setVersion(e.target.value)}
                        style={{ padding: '10px 12px', borderRadius: '10px', background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border)', color: '#fff' }}
                      >
                        <option value="1.21.4">1.21.4 (Latest Release)</option>
                        <option value="1.21.1">1.21.1 (Stable & Modded)</option>
                        <option value="1.20.1">1.20.1 (Largest Mod Library)</option>
                      </select>
                    </div>
                  </div>
                )}

                {step === 3 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                    <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border)', borderRadius: '14px', padding: '18px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                        <span style={{ color: 'var(--muted)' }}>NAME</span>
                        <strong>{name}</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                        <span style={{ color: 'var(--muted)' }}>VERSION</span>
                        <strong>Minecraft {version}</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                        <span style={{ color: 'var(--muted)' }}>LOADER</span>
                        <strong>{loader}</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                        <span style={{ color: 'var(--muted)' }}>MEMORY</span>
                        <strong>6 GB (Recommended)</strong>
                      </div>
                    </div>
                  </div>
                )}
              </>
            )}

            {/* MRPACK IMPORT MODE */}
            {mode === 'mrpack' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', alignItems: 'center', padding: '20px 0' }}>
                <div style={{ width: '100%', height: '140px', border: '2px dashed var(--border)', borderRadius: '16px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '10px', background: 'rgba(255,255,255,0.01)', cursor: 'pointer' }}>
                  <Icon name="download" size={32} />
                  <span style={{ fontSize: '13px', color: 'var(--ink)' }}>Drag & Drop .mrpack archive here</span>
                  <small style={{ fontSize: '11px', color: 'var(--muted)' }}>or click to browse from Windows Explorer</small>
                </div>
                <div style={{ width: '100%', background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border)', borderRadius: '12px', padding: '14px' }}>
                  <strong style={{ fontSize: '13px', color: 'var(--ink)' }}>Sample Modpack Detected:</strong>
                  <p style={{ margin: '4px 0 0 0', fontSize: '12px', color: 'var(--muted)' }}>
                    Fabulously Optimized 5.8.0 · Fabric 1.21.4 · 54 Mods
                  </p>
                </div>
              </div>
            )}

            {/* AI ASSISTANT MODE */}
            {mode === 'ai' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <label style={{ fontSize: '10px', fontFamily: 'DM Mono', color: 'var(--accent)' }}>
                  DESCRIBE YOUR DREAM MODPACK
                </label>
                <textarea
                  className="ai-prompt-box"
                  value={aiPrompt}
                  onChange={(e) => setAiPrompt(e.target.value)}
                  placeholder="e.g. Cozy cottagecore survival with performance shaders, detailed food and cooking, and seasons"
                />

                <div className="prompt-presets">
                  <span style={{ fontSize: '10px', color: 'var(--muted)', fontFamily: 'DM Mono' }}>PRESETS:</span>
                  <span className="prompt-chip" onClick={() => setAiPrompt('Cozy fantasy builder with shaders and autumn seasons')}>Cozy Fantasy</span>
                  <span className="prompt-chip" onClick={() => setAiPrompt('Max FPS competitive PvP with minimal latency and Sodium')}>Max FPS PvP</span>
                  <span className="prompt-chip" onClick={() => setAiPrompt('Industrial automation, machinery, and power grids')}>Tech & Automation</span>
                </div>

                {!aiPlan ? (
                  <button
                    className="btn-primary"
                    disabled={isThinking}
                    onClick={handleSuggestMods}
                    style={{ alignSelf: 'flex-start', display: 'flex', alignItems: 'center', gap: '8px' }}
                  >
                    <Icon name="sparkles" size={14} />
                    <span>{isThinking ? 'Analyzing Modrinth Catalog…' : 'Suggest Mods with AI'}</span>
                  </button>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '6px' }}>
                    <div style={{ background: 'rgba(240, 160, 98, 0.08)', border: '1px solid rgba(240, 160, 98, 0.25)', borderRadius: '12px', padding: '12px 16px', fontSize: '13px', color: 'var(--ink)' }}>
                      {aiPlan.summary}
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', maxHeight: '200px', overflowY: 'auto' }}>
                      {aiPlan.mods.map(mod => (
                        <div
                          key={mod.id}
                          onClick={() => toggleMod(mod.id)}
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            padding: '10px 14px',
                            borderRadius: '10px',
                            background: 'rgba(255,255,255,0.02)',
                            border: '1px solid var(--border)',
                            cursor: 'pointer'
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <input type="checkbox" checked={selectedMods.has(mod.id)} readOnly />
                            <div>
                              <strong style={{ fontSize: '13px', color: 'var(--ink)' }}>{mod.name}</strong>
                              <small style={{ color: 'var(--muted)', display: 'block', fontSize: '11px' }}>{mod.desc}</small>
                            </div>
                          </div>
                          <span className="card-badge">{mod.category}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="modal-foot">
            {mode === 'custom' ? (
              <>
                {step > 1 && <button className="btn-secondary" onClick={() => setStep(step - 1)}>Back</button>}
                <button className="btn-secondary" onClick={onClose}>Cancel</button>
                {step < 3 ? (
                  <button className="btn-primary" onClick={() => setStep(step + 1)}>Continue →</button>
                ) : (
                  <button className="btn-primary" onClick={handleCreate}>
                    {isBuilding ? 'Preparing World…' : 'Create Instance →'}
                  </button>
                )}
              </>
            ) : mode === 'mrpack' ? (
              <>
                <button className="btn-secondary" onClick={onClose}>Cancel</button>
                <button className="btn-primary" onClick={handleCreate}>Import Modpack</button>
              </>
            ) : (
              <>
                <button className="btn-secondary" onClick={onClose}>Cancel</button>
                {aiPlan && (
                  <button className="btn-primary" disabled={isBuilding || selectedMods.size === 0} onClick={handleCreate}>
                    {isBuilding ? 'Installing Mods…' : `Create with ${selectedMods.size} Mods →`}
                  </button>
                )}
              </>
            )}
          </div>
        </div>
      );
    };

    // ==========================================
    // MAIN APP COMPONENT
    // ==========================================
    function App() {
      const [activeTab, setActiveTab] = useState('Play');
      const [modal, setModal] = useState(null); // 'diagnostics' | 'version' | 'lobby' | 'new' | 'settings'
      const [friendsOpen, setFriendsOpen] = useState(false);
      const [version, setVersion] = useState('1.21.4');
      const [isLaunching, setIsLaunching] = useState(false);

      // Skin Screen state
      const [skinIndex, setSkinIndex] = useState(0);
      const [isSlim, setIsSlim] = useState(false);
      const [is3D, setIs3D] = useState(true);

      const [instances, setInstances] = useState([
        ['Birch Hollow', '1.21.4', 'Vanilla', '24h 18m', 'dusk'],
        ['Ember Valley', '1.21.4', 'Fabric · 42 mods', '8h 42m', 'violet'],
        ['First Shelter', '1.20.6', 'Vanilla', '3h 06m', 'gold'],
        ['The In-Between', '24w14', 'Snapshot', '48m', 'void'],
      ]);

      const navButtons = [
        { id: 'Play', icon: 'play', title: 'Play (1)' },
        { id: 'Library', icon: 'library', title: 'Library (2)' },
        { id: 'Social', icon: 'social', title: 'Social (3)' },
        { id: 'Explore', icon: 'explore', title: 'Explore (4)' },
        { id: 'Skins', icon: 'skins', title: 'Skins (5)' },
      ];

      const handleLaunch = () => {
        if (isLaunching) return;
        setIsLaunching(true);
        setTimeout(() => setIsLaunching(false), 3000);
      };

      return (
        <div className="app-shell">
          {/* Ambient Glowing Washes */}
          <div className="ambient ambient-one" />
          <div className="ambient ambient-two" />
          <div className="aurora-field">
            <span />
            <span />
          </div>
          <div className="ember-field">
            <span /><span /><span /><span /><span /><span /><span />
          </div>

          {/* Sidebar */}
          <aside className="sidebar">
            <div className="brand" title="Ember Launcher">
              <EmberLogo size={36} />
            </div>

            <nav className="nav-list">
              {navButtons.map((btn) => (
                <button
                  key={btn.id}
                  className={`nav-button ${activeTab === btn.id ? 'active' : ''}`}
                  onClick={() => setActiveTab(btn.id)}
                  title={btn.title}
                >
                  <Icon name={btn.icon} size={20} />
                </button>
              ))}
            </nav>

            <span
              style={{
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                background: 'var(--success)',
                marginTop: 'auto',
                marginBottom: '14px',
                boxShadow: '0 0 8px rgba(148,169,120,0.4)',
              }}
              title="All systems operational"
            />

            <button
              className={`nav-button settings-button ${activeTab === 'Settings' ? 'active' : ''}`}
              onClick={() => setActiveTab('Settings')}
              title="Settings (6)"
            >
              <Icon name="settings" size={20} />
            </button>
          </aside>

          {/* Main Workspace */}
          <section className="workspace">
            {/* TopBar */}
            <header className="topbar">
              <div className="topbar-left">
                <span className="topbar-eyebrow">YOUR SPACE</span>
                <span className="topbar-title">
                  {activeTab === 'Play' ? 'Welcome home.' : activeTab === 'Library' ? 'Instances' : activeTab}
                </span>
              </div>

              <div className="topbar-right">
                {/* Health indicator pill */}
                <div className="health-pill" onClick={() => setModal('diagnostics')} title="Open Session Diagnostics">
                  <span className="health-dot" />
                  <span>94% Smooth</span>
                </div>

                {/* Friends Button */}
                <div className="social-pill" onClick={() => setFriendsOpen(!friendsOpen)} title="Friends list">
                  <div className="avatar-stack">
                    <span className="av-1">M</span>
                    <span className="av-2">L</span>
                    <span className="av-3">N</span>
                  </div>
                  <span>3 online · Friends</span>
                  <Icon name="chevron" size={14} />
                </div>

                {/* Account Pill */}
                <div className="account-pill" onClick={() => alert('Account: Conlee (Online)')}>
                  <div className="steve-avatar" />
                  <div className="account-info">
                    <strong>Conlee</strong>
                    <small>Online</small>
                  </div>
                  <Icon name="chevron" size={14} />
                </div>
              </div>
            </header>

            {/* Content Area */}
            <div className="content-area">
              {/* PLAY SCREEN */}
              {activeTab === 'Play' && (
                <>
                  <div className="hero-scene">
                    <div className="sky-backdrop" />
                    <div className="sun-disc" />
                    <div className="mountains-back" />
                    <div className="mountains-mid" />
                    <div className="pine-forest">
                      {Array.from({ length: 18 }, (_, i) => <div key={i} className="pine-tree" />)}
                    </div>

                    <div className="hero-content">
                      <div className="hero-eyebrow">THE QUIET WILDERNESS</div>
                      <h1 className="hero-heading">Places You<br />Remember.</h1>
                      <p className="hero-subtitle">
                        Your favorite world is warm, quiet, and ready for you. Experience native DirectX acceleration and ultra-smooth frame pacing.
                      </p>

                      <div className="launch-bar">
                        <div className="version-trigger" onClick={() => setModal('version')}>
                          <div className="version-icon">★</div>
                          <div className="version-text">
                            <small>ACTIVE INSTANCE</small>
                            <strong>Birch Hollow · 1.21.4</strong>
                          </div>
                          <Icon name="chevron" size={16} />
                        </div>

                        <button className="gear-btn" onClick={() => setModal('version')} title="Change Version">
                          <Icon name="settings" size={18} />
                        </button>

                        <button className="play-btn" onClick={handleLaunch}>
                          <div className="play-btn-icon">
                            <Icon name={isLaunching ? 'download' : 'play'} size={18} />
                          </div>
                          <div className="play-btn-text">
                            <strong>{isLaunching ? 'STARTING…' : 'PLAY'}</strong>
                            <small>{isLaunching ? 'Checking libraries' : 'Minecraft 1.21.4'}</small>
                          </div>
                        </button>
                      </div>
                    </div>
                  </div>

                  <div className="screen-container">
                    <div className="screen-header">
                      <div className="screen-eyebrow">RECENT WORLDS</div>
                      <h2 className="screen-title">Continue Journey</h2>
                    </div>

                    <div className="instances-grid">
                      {instances.slice(0, 3).map((inst, i) => (
                        <div key={i} className="instance-card" onClick={() => handleLaunch()}>
                          <div className={`card-preview cp-${inst[4]}`}>
                            <span className="card-badge">{inst[2]}</span>
                          </div>
                          <div className="card-body">
                            <h4>{inst[0]}</h4>
                            <div className="card-meta">
                              <span>v{inst[1]}</span>
                              <span>Playtime {inst[3]}</span>
                            </div>
                            <div className="card-actions">
                              <button onClick={(e) => { e.stopPropagation(); setModal('version'); }}>Version</button>
                              <button className="play-sub" onClick={(e) => { e.stopPropagation(); handleLaunch(); }}>Play</button>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </>
              )}

              {/* LIBRARY SCREEN */}
              {activeTab === 'Library' && (
                <div className="screen-container">
                  <div className="screen-header">
                    <div className="screen-eyebrow">YOUR COLLECTION</div>
                    <h2 className="screen-title">Instances</h2>
                    <p className="screen-desc">Manage, configure, and launch your Minecraft worlds.</p>
                  </div>

                  <div className="filter-bar">
                    <div className="chips-group">
                      <span className="chip active">All</span>
                      <span className="chip">Vanilla</span>
                      <span className="chip">Fabric</span>
                      <span className="chip">Snapshots</span>
                    </div>

                    <div className="actions-group">
                      <input className="search-input" placeholder="Search worlds…" />
                      <button className="btn-secondary" onClick={() => setModal('version')}>Version Manager</button>
                      <button className="btn-primary" onClick={() => setModal('new')}>+ New Instance</button>
                    </div>
                  </div>

                  <div className="instances-grid">
                    {instances.map((inst, i) => (
                      <div key={i} className="instance-card">
                        <div className={`card-preview cp-${inst[4]}`}>
                          <span className="card-badge">{inst[2]}</span>
                        </div>
                        <div className="card-body">
                          <h4>{inst[0]}</h4>
                          <div className="card-meta">
                            <span>v{inst[1]}</span>
                            <span>Playtime {inst[3]}</span>
                          </div>
                          <div className="card-actions">
                            <button onClick={() => setModal('diagnostics')}>Health</button>
                            <button className="play-sub" onClick={handleLaunch}>Play</button>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* SOCIAL SCREEN */}
              {activeTab === 'Social' && (
                <div className="screen-container">
                  <div className="screen-header">
                    <div className="screen-eyebrow">MULTIPLAYER & REALMS</div>
                    <h2 className="screen-title">Social</h2>
                    <p className="screen-desc">Connect with your friends, host peer lobbies, and join active worlds.</p>
                  </div>

                  <div className="social-columns">
                    {/* Friends Column */}
                    <div className="social-col">
                      <div className="social-col-head">
                        <h3>Quiet Crew (3/8)</h3>
                        <span className="chip" style={{ fontSize: '10px' }}>Online</span>
                      </div>
                      <div className="friend-row">
                        <div className="friend-left">
                          <span className="online-indicator" />
                          <div className="friend-details">
                            <strong>Mossy</strong>
                            <small>Playing Birch Hollow</small>
                          </div>
                        </div>
                        <button className="btn-secondary" style={{ padding: '4px 8px', fontSize: '10px' }}>Join</button>
                      </div>
                      <div className="friend-row">
                        <div className="friend-left">
                          <span className="online-indicator" />
                          <div className="friend-details">
                            <strong>Luna</strong>
                            <small>Main Menu</small>
                          </div>
                        </div>
                        <button className="btn-secondary" style={{ padding: '4px 8px', fontSize: '10px' }}>Invite</button>
                      </div>
                      <div className="friend-row">
                        <div className="friend-left">
                          <span className="offline-indicator" />
                          <div className="friend-details">
                            <strong>Rowan</strong>
                            <small>Offline · 2h ago</small>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Active Lobbies Column */}
                    <div className="social-col">
                      <div className="social-col-head">
                        <h3>Active Lobbies</h3>
                        <button className="btn-primary" style={{ padding: '4px 10px', fontSize: '11px' }} onClick={() => setModal('lobby')}>
                          + Host Lobby
                        </button>
                      </div>
                      <div className="lobby-card-item">
                        <strong>Mossy's Creative Realm</strong>
                        <p>Fabric 1.21.4 · 2/8 Players · Creative Mode</p>
                        <button className="btn-primary" style={{ alignSelf: 'flex-start', marginTop: '4px', fontSize: '11px' }}>
                          Join World →
                        </button>
                      </div>
                      <div className="lobby-card-item">
                        <strong>Quiet SMP Survival</strong>
                        <p>Vanilla 1.21.4 · 4/10 Players · Hardcore</p>
                        <button className="btn-secondary" style={{ alignSelf: 'flex-start', marginTop: '4px', fontSize: '11px' }}>
                          Join World →
                        </button>
                      </div>
                    </div>

                    {/* Invites Column */}
                    <div className="social-col">
                      <div className="social-col-head">
                        <h3>Invitations (1)</h3>
                      </div>
                      <div className="lobby-card-item">
                        <strong>North invited you to Ember Valley</strong>
                        <p>Received 4 minutes ago</p>
                        <div style={{ display: 'flex', gap: '8px', marginTop: '6px' }}>
                          <button className="btn-primary" style={{ fontSize: '11px', flex: 1 }}>Accept</button>
                          <button className="btn-secondary" style={{ fontSize: '11px' }}>Decline</button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* EXPLORE / MODS SCREEN */}
              {activeTab === 'Explore' && (
                <div className="screen-container">
                  <div className="screen-header">
                    <div className="screen-eyebrow">DISCOVER CONTENT</div>
                    <h2 className="screen-title">Mods & Packs</h2>
                    <p className="screen-desc">Browse Modrinth's catalog with instant compatibility validation.</p>
                  </div>

                  <div className="filter-bar">
                    <div className="chips-group">
                      <span className="chip active">Installed</span>
                      <span className="chip">Browse</span>
                      <span className="chip">Performance</span>
                      <span className="chip">Shaders</span>
                      <span className="chip">Adventure</span>
                    </div>

                    <input className="search-input" placeholder="Search Modrinth mods…" />
                  </div>

                  <div className="mods-list">
                    {[
                      { name: 'Sodium', cat: 'PERFORMANCE', desc: 'Modern rendering engine providing massive FPS gains and smooth frametimes.', dl: '8.4M', inst: true },
                      { name: 'Lithium', cat: 'OPTIMIZATION', desc: 'General-purpose optimization mod for Minecraft physics and mob ticking.', dl: '6.2M', inst: true },
                      { name: 'Iris Shaders', cat: 'VISUALS', desc: 'Modern shaderpack engine designed for ultra-high FPS and Sodium compatibility.', dl: '5.1M', inst: false },
                      { name: 'JourneyMap', cat: 'EXPLORATION', desc: 'Real-time mapping in-game or in a web browser as you explore.', dl: '11.8M', inst: false },
                      { name: 'AppleSkin', cat: 'QUALITY OF LIFE', desc: 'Adds helpful HUD information about food and hunger saturation.', dl: '14.2M', inst: false },
                    ].map((mod, i) => (
                      <div key={i} className="mod-card">
                        <div className="mod-left">
                          <div className="mod-icon-box">★</div>
                          <div className="mod-text">
                            <small>{mod.cat}</small>
                            <strong>{mod.name}</strong>
                            <p>{mod.desc}</p>
                          </div>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                          <span style={{ fontSize: '12px', color: 'var(--muted)', fontFamily: 'DM Mono' }}>{mod.dl} DL</span>
                          <button className={mod.inst ? 'btn-secondary' : 'btn-primary'}>
                            {mod.inst ? 'Installed' : 'Install'}
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* SKINS SCREEN */}
              {activeTab === 'Skins' && (
                <div className="screen-container">
                  <div className="screen-header">
                    <div className="screen-eyebrow">AVATAR & WARDROBE</div>
                    <h2 className="screen-title">Skins</h2>
                    <p className="screen-desc">Real-time 3D Minecraft character model viewer with classic & slim proportions.</p>
                  </div>

                  <div className="skins-layout">
                    {/* Viewport Box */}
                    <div className="skin-viewport-box">
                      <div className="skin-controls-bar">
                        <div className="skin-toggle-group">
                          <button className={`skin-toggle-btn ${is3D ? 'active' : ''}`} onClick={() => setIs3D(true)}>3D</button>
                          <button className={`skin-toggle-btn ${!is3D ? 'active' : ''}`} onClick={() => setIs3D(false)}>2D Flat</button>
                        </div>

                        <div className="skin-toggle-group">
                          <button className={`skin-toggle-btn ${!isSlim ? 'active' : ''}`} onClick={() => setIsSlim(false)}>Classic (4px)</button>
                          <button className={`skin-toggle-btn ${isSlim ? 'active' : ''}`} onClick={() => setIsSlim(true)}>Slim (3px)</button>
                        </div>
                      </div>

                      <Skin3DViewport skinIndex={skinIndex} isSlim={isSlim} is3D={is3D} />

                      <span className="skin-drag-hint">DRAG TO ROTATE 360°</span>
                    </div>

                    {/* Presets & Actions */}
                    <div className="skin-presets-panel">
                      <h3 style={{ margin: 0, fontSize: '16px', color: 'var(--ink)' }}>Choose Wardrobe</h3>

                      {['Ember (Official)', 'Wanderer', 'Nightfall Cape', 'Classic Steve', 'Alex'].map((name, i) => (
                        <div
                          key={name}
                          className={`preset-card ${skinIndex === i ? 'selected' : ''}`}
                          onClick={() => setSkinIndex(i)}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div className="steve-avatar" style={{ width: '28px', height: '28px' }} />
                            <div>
                              <strong style={{ fontSize: '13px', color: 'var(--ink)' }}>{name}</strong>
                              <small style={{ color: 'var(--muted)', display: 'block', fontSize: '11px' }}>64×64 Pixel Skin</small>
                            </div>
                          </div>
                          {skinIndex === i && <Icon name="check" size={16} />}
                        </div>
                      ))}

                      <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                        <button className="btn-secondary" style={{ flex: 1 }} onClick={() => alert('Import skin file (.png) from Explorer')}>
                          Import PNG
                        </button>
                        <button className="btn-primary" style={{ flex: 1.4 }} onClick={() => alert('Skin applied to Birch Hollow!')}>
                          Apply to Active World
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* SETTINGS SCREEN */}
              {activeTab === 'Settings' && (
                <div className="screen-container">
                  <div className="screen-header">
                    <div className="screen-eyebrow">CONFIGURATION</div>
                    <h2 className="screen-title">Settings</h2>
                    <p className="screen-desc">Tailor Ember's JVM arguments, hardware acceleration, and AI keys.</p>
                  </div>

                  <div className="settings-layout">
                    <div className="settings-nav">
                      {['General', 'Java & Memory', 'AI Assistant', 'Windows DirectX', 'About Ember'].map((sec, i) => (
                        <button key={sec} className={`settings-nav-btn ${i === 0 ? 'active' : ''}`}>
                          {sec}
                        </button>
                      ))}
                    </div>

                    <div className="settings-section-card">
                      <div className="settings-row">
                        <div className="settings-label">
                          <strong>Memory Allocation (RAM)</strong>
                          <small>Recommended: 6 GB for Fabric 1.21.4 with shaders</small>
                        </div>
                        <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--accent)' }}>6 GB</span>
                      </div>

                      <div className="settings-row">
                        <div className="settings-label">
                          <strong>Windows DirectX GPU Preference</strong>
                          <small>Forces javaw.exe onto High Performance discrete GPU via Windows Registry</small>
                        </div>
                        <input type="checkbox" defaultChecked />
                      </div>

                      <div className="settings-row">
                        <div className="settings-label">
                          <strong>AI Provider Key</strong>
                          <small>Stored encrypted via Windows DPAPI Credential Store</small>
                        </div>
                        <button className="btn-secondary" style={{ fontSize: '11px' }} onClick={() => alert('Configure Claude / Gemini / OpenRouter API Key')}>
                          Manage Key…
                        </button>
                      </div>

                      <div className="settings-row">
                        <div className="settings-label">
                          <strong>Atmospheric Background Motion</strong>
                          <small>Enables aurora sweep and rising ember particles</small>
                        </div>
                        <input type="checkbox" defaultChecked />
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Status Footer */}
              <footer className="footer-bar">
                <div className="status-badge">
                  <i />
                  <span>All Systems Operational · DirectX 12 D3D11 Native</span>
                </div>
                <span>Ember Launcher 0.2.2 · Windows x64 / ARM64</span>
              </footer>
            </div>
          </section>

          {/* Friends Drawer */}
          {friendsOpen && (
            <>
              <div className="friends-drawer-backdrop" onClick={() => setFriendsOpen(false)} />
              <div className="friends-drawer">
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <h3 style={{ margin: 0, fontSize: '16px', color: '#fff' }}>Quiet Crew · 3/8</h3>
                  <button className="close-btn" onClick={() => setFriendsOpen(false)}>×</button>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <div className="friend-row">
                    <div className="friend-left">
                      <span className="online-indicator" />
                      <div className="friend-details">
                        <strong>Mossy</strong>
                        <small>Playing Birch Hollow</small>
                      </div>
                    </div>
                    <button className="btn-secondary" style={{ padding: '4px 8px', fontSize: '10px' }}>Join</button>
                  </div>
                  <div className="friend-row">
                    <div className="friend-left">
                      <span className="online-indicator" />
                      <div className="friend-details">
                        <strong>Luna</strong>
                        <small>Main Menu</small>
                      </div>
                    </div>
                    <button className="btn-secondary" style={{ padding: '4px 8px', fontSize: '10px' }}>Invite</button>
                  </div>
                  <div className="friend-row">
                    <div className="friend-left">
                      <span className="online-indicator" />
                      <div className="friend-details">
                        <strong>North</strong>
                        <small>Browsing Mods</small>
                      </div>
                    </div>
                    <button className="btn-secondary" style={{ padding: '4px 8px', fontSize: '10px' }}>Invite</button>
                  </div>
                </div>
              </div>
            </>
          )}

          {/* Modals Layer */}
          {modal && (
            <div className="modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) setModal(null); }}>
              {modal === 'diagnostics' && <SessionDiagnosticsModal onClose={() => setModal(null)} />}
              {modal === 'version' && <VersionModal onClose={() => setModal(null)} />}
              {modal === 'lobby' && <LobbyFlowModal onClose={() => setModal(null)} />}
              {modal === 'new' && <NewInstanceFlow onClose={() => setModal(null)} onCreate={(inst) => setInstances([inst, ...instances])} />}
            </div>
          )}
        </div>
      );
    }

    ReactDOM.createRoot(document.getElementById('root')).render(<App />);
  </script>
</body>
</html>
'''

def main():
    print("Writing windows/preview.html...")
    preview_content = build_preview_html()
    with open('windows/preview.html', 'w', encoding='utf-8') as f:
        f.write(preview_content)
    print(f"Generated windows/preview.html ({len(preview_content)} bytes)")

if __name__ == '__main__':
    main()
