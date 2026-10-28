# Ember — Design Handoff

This document is the implementation brief for porting the Ember prototype to the
native Minecraft launcher. The React prototype in `src/App.tsx` and
`src/index.css` is the visual source of truth.

## 1. Product direction

Ember should feel like returning to a familiar world at dusk:

- calm rather than technical;
- warm rather than neon;
- cinematic but never distracting;
- recognizably Minecraft-inspired without copying Mojang branding;
- dark OLED surfaces with violet shadow and orange firelight.

The launcher should explain technical choices in friendly language. Prefer
“Balanced at 6 GB” to raw JVM terminology unless the user opens an advanced
section.

## 2. Information architecture

Primary navigation:

1. **Home** — resume the selected instance and choose a version/story.
2. **Instances** — browse, filter, create, launch, and manage instances.
3. **Mods** — discover content and check compatibility before installing.
4. **Skins** — preview, import, and equip skins.
5. **Settings** — player, runtime, downloads, appearance, and application info.

Global elements:

- Ember logo at the top of the sidebar;
- account/profile control in the top-right;
- Java runtime status;
- system-health status in the footer;
- background ambience shared by all screens.

## 3. Visual tokens

### Color

| Role | Value | Usage |
| --- | --- | --- |
| OLED background | `#080808` | Main application background |
| Surface | `#111110` | Cards and panels |
| Elevated surface | `#171517` | Inputs, rows, active controls |
| Border | `#242321` | Default dividers and card outlines |
| Primary text | `#EEEAE3` | Titles and important values |
| Secondary text | `#817A73` | Descriptions |
| Muted text | `#5F5A55` | Metadata |
| Ember | `#F0A062` | Primary action and active state |
| Ember deep | `#D97B48` | Gradient endpoint |
| Violet | `#A875B8` | Ambient depth and secondary accent |
| Success | `#94A978` | Healthy/compatible/installed |
| Danger | `#A96B68` | Destructive actions |

Use orange for action and warmth. Use violet for atmosphere and depth. Do not
use both as competing primary actions.

### Typography

- Interface: **Manrope**, weights 400–800.
- Metadata: **DM Mono**, weights 400–500.
- Major display titles use tight tracking and line height.
- Uppercase mono labels identify sections, state, and metadata.

Native fallback:

- SwiftUI interface: `.system(.body, design: .rounded)` with adjusted tracking.
- Metadata: `.system(.caption, design: .monospaced)`.

### Shape and depth

- Main hero radius: 20.
- Standard card radius: 16.
- Compact control radius: 9–12.
- Pills use a full capsule.
- Borders should remain more visible than shadows.
- Shadows are black and broad; colored glow is reserved for Ember actions.

### Spacing

Use a 4-point base grid:

- 4: icon/internal micro spacing;
- 8: compact control gap;
- 12: related control gap;
- 16: standard card padding;
- 24: section/card padding;
- 32: major section spacing;
- 48–72: page-level breathing room.

## 4. Logo

The primary mark is defined by `EmberLogo` in `src/App.tsx` and mirrored in
`public/favicon.svg`.

- rounded dark tile;
- centered diamond;
- diamond transitions from violet to warm orange;
- no wordmark is required in compact navigation;
- do not add Minecraft grass, creeper faces, or official brand elements.

Use the symbol at 28–36 points in navigation and 64+ points in onboarding.

## 5. Shared components

Implement these as reusable SwiftUI views:

- `EmberLogo`
- `SidebarNavigation`
- `TopBar`
- `PageIntro`
- `PrimaryButton`
- `SecondaryButton`
- `IconButton`
- `FilterPill`
- `SearchField`
- `StatusBadge`
- `InstanceCard`
- `ModCard`
- `SettingRow`
- `Toggle`
- `ModalShell`
- `ProgressState`
- `EmptyState`
- `Toast`

All clickable elements need hover, pressed, focus, disabled, and loading states.

## 6. Screens

### Home

Purpose: emotional return point and fastest path into the game.

- “Welcome home” header.
- Large cabin-at-dusk hero.
- Last-played metadata.
- Instance, loader, and playtime summary.
- Version selector.
- Instance settings shortcut.
- Primary Play button with idle, preparing, and ready states.

Each selected version can use a different hero story:

- stable Vanilla: favorite world;
- older Vanilla: player-character return;
- Fabric: rotating world memories;
- snapshot: abstract experimental world.

The visual atmosphere remains consistent across stories.

### Instances

- Filter by All, Vanilla, Fabric, and Snapshot.
- Search by instance name.
- Two-column card grid at wide sizes.
- Each card contains generated world artwork, version, loader, playtime, quick
  launch, and Manage.
- “New instance” is the primary page action.

Instance detail panel:

- Overview, Mods, Worlds, Logs tabs.
- Playtime, version, and allocated memory.
- Open folder, back up world, and delete.
- Destructive actions require confirmation.

### New instance flow

Three steps:

1. Name the instance.
2. Choose Minecraft version and loader.
3. Review name, version, loader, and memory.

After confirmation, show a dedicated installation state with current task,
percentage, and time estimate. The user can safely dismiss only if the native
installer supports background continuation.

### Mods

- Featured, Modpacks, Shaders, and Resources filters.
- Modrinth search.
- Cards include icon, category, description, downloads, and install state.
- “Details” opens a side/modal panel.

Mod detail panel:

- Author and category.
- Description.
- Downloads and followers.
- Compatibility result for the selected instance.
- Install button.

Compatibility states:

- ready;
- dependencies required;
- incompatible loader;
- no compatible version;
- already installed.

### Skins

- Large player preview.
- Import action.
- Saved-skin collection.
- Selected/equipped state.
- Native implementation should support drag rotation and scroll zoom.

### Settings

Settings should feel reassuring, not like a developer console.

- Begin with an Ember health card: Java, memory, and backups.
- Group settings into General, Java & memory, Downloads, Appearance, About.
- Save changes automatically.
- Show a quiet save confirmation below the settings.

Memory control:

- Do not use a continuous slider.
- Offer Light 4 GB, Balanced 6 GB, Modded 8 GB, and Heavy 12 GB presets.
- Keep minus/plus controls for exact adjustment.
- Explain that Ember preserves memory for the rest of the system.

## 7. Overlays and system states

Required overlays:

- profile/account;
- new instance;
- instance details;
- mod details;
- update available;
- backup/rollback confirmation;
- delete confirmation;
- game log;
- crash report.

Required application states:

- loading;
- empty library;
- no search results;
- offline;
- network timeout;
- insufficient disk space;
- incompatible content;
- installation failed;
- installation complete;
- game currently running;
- update ready to install.

Modal behavior:

- dark blurred backdrop;
- close button in top-right;
- Escape closes when safe;
- backdrop click closes non-destructive dialogs;
- focus remains trapped inside;
- destructive progress cannot be dismissed accidentally.

## 8. Motion

Motion should be “noticeable when observed, calm during normal use.”

Global ambience:

- violet aurora drift: 18–23 seconds;
- orange/violet embers: 15–27 seconds;
- background glow drift: 13–16 seconds.

Home scene:

- tree sway: 5 seconds;
- sun/firelight breathing: 5 seconds;
- firefly drift: 4 seconds;
- player arrival: 2.2 seconds with a soft deceleration.

Interface:

- hover/press: 150–220 ms;
- modal entrance: 280 ms;
- page transition: 250–350 ms;
- toast: 220 ms in, 180 ms out.

Respect Reduce Motion. Replace translation, scaling, and parallax with opacity
changes when reduced motion is enabled.

## 9. Responsive behavior

Desktop is the primary native target.

- Sidebar: 84 points wide, 64 points in compact mode.
- Recommended minimum native window: 900 × 600.
- Content maximum width: approximately 1120.
- Collapse two-column grids below approximately 760.
- Hide nonessential profile copy and runtime chip in compact layouts.
- Never truncate the primary instance name without a tooltip.

## 10. Accessibility

- Minimum interactive target: 40 × 40 points.
- Every icon-only action needs an accessibility label and tooltip.
- Never communicate compatibility or errors with color alone.
- Maintain visible keyboard focus.
- Support full keyboard navigation.
- Announce installation progress and launch-state changes.
- Test text scaling and long Ukrainian/Russian strings.

## 11. Mapping to the native launcher

Suggested correspondence with the existing Swift project:

| Ember design | Native area |
| --- | --- |
| Application shell | `RootView` |
| Home | `PlayScreen` |
| Instances | `LibraryScreen` |
| New instance | `NewInstanceModal` |
| Instance panel | `InstanceSettingsModal` |
| Mods | `ModsScreen` |
| Version changes | `VersionModal` |
| Logs | `GameLogModal` |
| Health/crashes | `SessionDiagnosticsView` |
| Settings | `SettingsScreen` |

Keep launcher logic in `LauncherCore`. SwiftUI views should subscribe to
observable controllers and render the states defined above.

## 12. Implementation sequence

1. Add tokens and shared controls.
2. Replace the native shell, sidebar, and top bar.
3. Port Home and launch states.
4. Port Instances and New Instance.
5. Port Mods and compatibility states.
6. Port Settings.
7. Port Skins.
8. Add overlays, errors, and empty states.
9. Add motion and reduced-motion behavior.
10. Run accessibility, localization, and window-size QA.

## 13. Acceptance checklist

- Every primary navigation destination is implemented.
- Every asynchronous action has idle, progress, success, and error states.
- No native control remains visually unstyled.
- Memory uses presets rather than a continuous slider.
- The Ember logo appears consistently.
- Orange remains the primary action color.
- Background animation never reduces text readability.
- Reduce Motion disables spatial animation.
- UI works from 900 × 600 upward.
- English, Ukrainian, and Russian strings fit or adapt.
- All keyboard and screen-reader paths are functional.
