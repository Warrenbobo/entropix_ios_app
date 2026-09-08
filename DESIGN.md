# Entropix — Design Principle Specification

> Cross-platform design principles, visual language, and UX rules for **all Entropix (Processor) client apps** — iOS, Android, and future surfaces.
>
> This document defines **what** the product should look and feel like, and **how** interaction should behave. It does **not** prescribe platform frameworks, file layouts, or class names. Platform engineering maps these principles to native implementation.

| Version | Edit Date  | Notes                                                                 |
|---------|------------|-----------------------------------------------------------------------|
| 1.0.0   | 2026-08-06 | Initial iOS-oriented design system & product UX guide                 |
| 2.0.0   | 2026-08-10 | Reframed as cross-platform design principle specification             |

**Current version:** `2.0.0` · **Last edit:** `2026-08-10`

---

## Table of Contents

1. [How to Use This Document](#1-how-to-use-this-document)
2. [Product Intent](#2-product-intent)
3. [Design Principles](#3-design-principles)
4. [Visual Language](#4-visual-language)
5. [Typography & Spacing](#5-typography--spacing)
6. [Shared Components](#6-shared-components)
7. [Screen Patterns](#7-screen-patterns)
8. [Camera & Photography UX](#8-camera--photography-ux)
9. [Agent / Coaching UX](#9-agent--coaching-ux)
10. [Navigation & Information Architecture](#10-navigation--information-architecture)
11. [Internationalization, Flags & Offline](#11-internationalization-flags--offline)
12. [Ads & Monetization Placement](#12-ads--monetization-placement)
13. [Accessibility & Platform Conventions](#13-accessibility--platform-conventions)
14. [Cross-Platform Parity](#14-cross-platform-parity)
15. [Do’s and Don’ts](#15-dos-and-donts)

---

## 1. How to Use This Document

| Audience | Use |
|----------|-----|
| **Design** | Source of truth for color, type, spacing, component behavior, and screen composition. |
| **Product** | Guardrails for IA, monetization placement, and coaching interaction. |
| **Engineering (any platform)** | Implement these principles with native APIs; keep behavior and tokens aligned across clients. |

**Separation of concerns**

- **This file** — product design principles and visual/UX contracts.
- **Platform docs** — implementation plans, reuse inventories, changelogs, and native architecture notes live beside each client codebase or under platform doc folders. Do not paste native type names or source paths into this specification.

**Units**

Unless noted otherwise, sizes are **density-independent** (points on iOS, dp on Android). Platforms scale to device density; the numeric values here are the shared design baseline.

**When tokens or UX change**, bump the version table above and update the affected sections so every client stays aligned.

---

## 2. Product Intent

Entropix is a **camera-first photography coach**. The home experience is live capture with composition guidance (Inspire Me, Agent coaching, AR overlays) — not a multi-tab content dashboard.

| Pillar | Meaning |
|--------|---------|
| **Camera-first** | App root opens Camera. Profile, settings, and secondary flows are destinations you leave Camera for and return via a persistent floating camera control. |
| **Coach, don’t clutter** | Overlays teach composition; they must not bury the live preview or fight the shutter. |
| **Parity where it matters** | Agent HUD, score display, framing honesty, and accent tokens stay consistent across platforms. Layout chrome may follow platform conventions; coaching behavior must not diverge without an explicit product decision. |
| **Reuse over rewrite** | Prefer extending shared framing, orientation, alerts, page shells, and API layers already established on each platform — do not invent parallel UX for the same job. |

---

## 3. Design Principles

### 3.1 Single responsibility

Each component owns one job (preview surface, alert shell, storage, orientation, coaching bubble, score overlay). Prefer extending an existing role over a second parallel control that does the same thing differently.

### 3.2 Componentization

- High cohesion, low coupling.
- Shared chrome (alerts, top bars, validated fields, floating camera return) is reusable across product pages.
- Camera-only chrome (shutter, side rail, coaching HUD) stays on the camera surface and is not reused as generic marketing UI.

### 3.3 Responsive layout

- Design width baseline: **375**.
- Always respect system safe areas (status bar, home indicator / navigation bar insets).
- Prefer **full-bleed** photography surfaces on Camera; avoid inset “card heroes,” rounded media panels, or floating marketing frames over live preview.

### 3.4 Theme consistency

- Colors come from the documented token set — not one-off hex values scattered in views.
- Primary product UI uses the **system UI typeface** on each platform (San Francisco on Apple platforms; Roboto / platform default on Android). Do not introduce custom display families for core product chrome unless product explicitly expands the brand system.
- Gradients are defined once as tokens and applied through shared helpers, not ad-hoc paints per screen.

### 3.5 Orientation honesty

Physical device hold is not the same as interface orientation. Capture, AR guidance, Inspire Me, and score sampling **lock orientation at the start of the user event** (tap, tick, or instruct) so ML and overlays stay honest to what the user saw.

### 3.6 Main-thread / UI-thread updates

All coaching HUD, alert, and toast updates run on the platform UI thread. Background work never mutates visible chrome directly.

### 3.7 Clarity over decoration

Motion supports hierarchy and presence (aspect changes, glass materials, state transitions). Avoid noise: pill clusters, stat strips, promo stickers, and competing text blocks on the capture surface.

---

## 4. Visual Language

### 4.1 Product (light) palette

Used on Mine, settings, auth, web, and other light product pages.

| Token | Value | Role |
|-------|-------|------|
| Background | `#FFFFFF` | Pages, navigation bars |
| Text | `#09244F` | Primary navy copy |
| Content text | `#5B7999` | Body / secondary content |
| Grey text | `#9DA0A5` | Muted labels |
| Link text | `#7BA9E8` | Links |
| Button / tint text | `#0A84FF` | Bar actions and interactive tint (system-blue-like) |
| Placeholder | `#B7BAC1` | Input placeholders |
| Button gradient | `#70BFFF` → `#0A84FF` | Primary CTA gradient |
| Highlight | `#F85C00` | Accent highlight |
| Time / urgency | `#FF453A` | Countdown and urgency |
| Progress | `#EA0000` | Progress emphasis |
| Shadow | `#B2CFEB` @ 0.4 alpha | Soft blue shadow |
| Membership accents | `#FFE0BA`, `#9F3E00`, `#BEA493`, `#FE3434`, … | VIP / membership UI |
| Checkout | WeChat `#35CD68` · Alipay `#3476FE` · pay CTA `#FF863C` → `#FE3434` → `#EA2B2B` | Payment affordances |

### 4.2 Agent / Liquid Glass accent

Shared across Inspire Me, floating camera return control, alert accents, and Agent borders:

| Token | Value | Role |
|-------|-------|------|
| Agent accent gradient | `#6680E6` → `#9966E6` | Primary coaching / glass accent |
| Agent border stack | `#6680E6` / `#7BA9E8` / `#9966E6` @ ~0.68–0.78 alpha | Bubble and HUD edges |
| Finish border | ≈ `#4CD964` | Coaching round complete |

### 4.3 Camera chrome

| Element | Spec |
|---------|------|
| Canvas | Black, full-bleed preview, aspect-fill |
| Shutter | White circle (~70 diameter, ~4 border) |
| Focus ring | System yellow |
| Score rings | System blue / teal / orange; gray track when no person is detected |
| Icons & labels on canvas | White (or white at documented opacity) on dark |

### 4.4 Alert dialog

| Element | Spec |
|---------|------|
| Scrim | Black @ 0.5 |
| Card | White, corner radius **24**, horizontal inset **32**, padding **24** |
| Title | `#333333` · 22 bold |
| Message | `#808080` · 16 regular |
| Buttons | Height **52**, radius **12**; cancel/normal fill `#F2F2F2`; destructive `#DE5C5C` · 18 semibold |

Use one shared alert shell across the product. Do not invent a second modal appearance for the same job.

---

## 5. Typography & Spacing

### 5.1 Typography

| Context | Spec |
|---------|------|
| System | Platform UI typeface only for core chrome |
| Light nav title (default stock) | **24 bold** `#09244F`; large titles exist but are **off** by default |
| Profile / Mine title | **24 bold**, primary label color, left-aligned |
| White-theme nav title | **18 medium**, white |
| Auth field title | **18 semibold**; field text **16**; error **14** system red |
| Coaching bubble — instruction | **15 semibold**, white @ ~0.92 |
| Coaching bubble — reasoning | **12 regular**, white @ ~0.58 |
| Coaching action pill | **11 medium** |
| Inspire Me label | **16 bold** |
| Icons | Prefer platform symbol sets; documented exception: Agent toggle may use a dedicated stroke asset where symbols are insufficient |

### 5.2 Spacing & hit targets

| Metric | Value |
|--------|-------|
| Design width baseline | **375** |
| Nav content height | safe-area top + **44** |
| Tab / bottom bar height | safe-area bottom + **49** |
| Top bar horizontal inset | **20** |
| Minimum hit target | **44 × 44** |
| Camera top chrome | **44** |
| Camera bottom chrome | **90** |
| Coaching bubble gap under status strip | **4**; collapsed height **40** |
| Score donut | **72** diameter; leading **12**; fixed Y under bubble strip (default) |
| Alert / auth corner radii | Alert card **24**; fields and buttons **12** |
| Preview aspects | Default **3:4**; also **1:1** and **9:16** |

Put new metrics into the shared token tables for each client — do not scatter magic numbers in feature views.

---

## 6. Shared Components

Describe each component by **role and behavior**. Implementations may differ by platform; the contract below should not.

### 6.1 Page shell

Light product screens sit inside a consistent page shell that owns background, safe-area handling, and optional custom top inset when the system navigation bar is replaced.

### 6.2 Navigation shell

Stacks that own a navigation controller / host wrap content so push, pop, and back affordances behave uniformly. Prefer platform-native back behavior; do not restyle critical back controls in ways that break glass or material systems.

### 6.3 Processor top bar

Mine-style chrome may hide the system bar and use a product top bar: left-aligned title, horizontal inset **20**, content height **44** below the status safe area. Pages that use this pattern extend top safe-area insets so content does not collide with the bar.

### 6.4 Validated input field

Auth and form fields share one control: height **50**, corner radius **12**, neutral fill that shifts to tint on focus and system red on error, maximum length **50**. Titles and error text follow the typography table.

### 6.5 Toast

Short, non-blocking feedback: centered, ~**3 seconds**, theme-aware. Prefer toast for transient status; prefer the alert dialog for decisions.

### 6.6 Alert dialog

Single product modal: scrim, white card, title, message, one or two actions (normal / destructive). All confirmations that need a choice use this shell.

### 6.7 Floating camera return

A persistent floating control with the Agent accent gradient returns the user from Mine / settings / secondary flows to Camera. It is a navigation affordance, not a marketing badge.

### 6.8 Camera preview surface

Full-bleed black canvas with optional rule-of-thirds grid, tap-to-focus, pinch zoom, and focus ring. The preview is the hero; overlays attach to it, they do not replace it.

### 6.9 Camera side rail

Vertical control strip on the trailing edge (~**80** wide): Agent toggle, flash, aspect, timer, Live (where supported), grid, flip. Controls stay icon-first and sparse.

### 6.10 Shutter control

Centered white circle in the bottom chrome. In Agent mode it becomes the primary coaching CTA (see §9). Visual roles: plain capture, instruct-ready, instruct-running, and finish (green ring).

### 6.11 My Reference

Trailing bottom control that opens personal reference selection. Must not compete with shutter centering.

### 6.12 Inspire Me control

Top-of-camera glass control under the status strip. Uses Agent accent / Liquid Glass treatment. Starts composition inspiration without covering the preview with marketing cards.

### 6.13 Coaching bubble

Full-width instruction panel under the status bar: single-line instruction by default; reasoning expands **downward** without shifting the top edge. Trailing edge stops before the Log affordance so Log stays tappable. Skip appears only on a **final** instruction. Finish state uses the green finish border. Hidden until the first instruct action in a session, then persists for that session.

### 6.14 Score donut

Independent overlay (not embedded in the bubble): three concentric rings plus a center score. Default position: leading side, fixed Y from safe-area top, above the bubble layer. Gray human ring when no person is detected. May support drag reposition where product enables it; visibility follows Agent UI visibility.

### 6.15 Coaching action pill

Compact secondary action chip (e.g. Skip) associated with the bubble, using pill typography and Agent materials.

### 6.16 Suggestions / reference carousel

Post–Inspire Me (or demo) horizontal selection of composition references. Selecting a reference enters composition-selected Camera with Agent available.

### 6.17 Photo preview / review

After capture: still or Live Photo review, with save/share paths that can apply brand watermark. Does not host ads.

### 6.18 Brand watermark

Applied on save/share through a shared image asset pipeline — not drawn ad hoc in unrelated screens.

---

## 7. Screen Patterns

### 7.1 Light product pages (Mine, settings, auth, web)

1. Use the page shell and, when owning a stack, the navigation shell.
2. Mine-style screens: product top bar + extended top safe area.
3. Forms: validated input field pattern.
4. Feedback: toast or alert dialog — never a one-off modal look.

### 7.2 Camera page

- Hide system navigation chrome; use custom white back and overlay controls.
- Preview fills the band between top chrome (**44**) and bottom chrome (**90**).
- Right rail for tools; bottom row centers shutter and places My Reference trailing.
- Aspect ratio changes animate with a short spring (~**0.35 s**, damping ~**0.85**).

### 7.3 Post-capture

Review stills / Live Photos, then persist to gallery / ideas storage. Watermark on save or share when brand policy requires it.

### 7.4 Composition-selected (reference + Agent)

When a reference is active: Agent defaults ON, coaching bubble and score donut may appear per §9, shutter adopts Agent roles, side rail shows Agent toggle. Leaving this mode clears Agent HUD so normal Camera is not left in a broken pseudo-suggestions state.

---

## 8. Camera & Photography UX

| Rule | Guidance |
|------|----------|
| Preview is the hero | Full-bleed black canvas; no marketing cards, banners, or dense chrome on the preview plane. |
| Grid | Rule-of-thirds overlay — toggleable, not permanent clutter. |
| Focus / zoom | Tap-to-focus and pinch zoom on the preview; reuse the preview surface’s APIs. |
| Capture payload | One shared capture result shape per platform — do not invent parallel photo payload types. |
| Live frames for ML | Build bitmaps / images through the shared preview framing pipeline with **locked orientation** sampled at tap or tick start. |
| Still / album frames | Prefer the shared still / reference framing path. |
| EXIF / orientation | Prefer shared orientation helpers — do not copy EXIF switch logic into new feature files. |
| Lifecycle | Start and stop physical orientation monitoring with the camera session lifecycle. |

---

## 9. Agent / Coaching UX

Coaching UI is a **shared product contract** across clients. Key rules:

| Topic | Rule |
|-------|------|
| Default | Agent ON when composition-selected. |
| Bubble | Full-width under status bar; instruction single-line; reasoning expands down without moving the top edge. |
| Skip | Only when a **final** instruction is shown — not during thinking or idle. |
| Bubble vs Log | Bubble trailing edge stops before Log; Log stays tappable. |
| Score donut | Independent overlay; fixed default Y from safe-area top; above bubble layer; gray human ring when no person. |
| Shutter roles | Capture / instruct-ready / instruct-running / finish (green ring). Instruct uses an intelligence / Agent visual with the Agent accent. |
| Bubble visibility | Hidden until first instruct tap; then persists for the session. |
| Box / LineArt overlays | Driven by agent execution tools — not a manual cycle by the user. |
| Finish | Green finish border on the bubble. |
| Materials | Prefer Liquid Glass / material blur where the OS supports it; fall back to dark system material. Respect reduced transparency. |
| Soft reset | Turning Agent OFF → ON on the same reference soft-resets the instruction session; score cache may be retained per TTL policy. |
| Policy copy | Coaching strings and numeric thresholds load from shared config — do not hardcode policy numbers in views. |

---

## 10. Navigation & Information Architecture

```
Splash → (optional App Open ad) → Camera (home root)
                                      │
                                      ├─ push: suggestions, photo preview, coaching log, …
                                      └─ destinations: Mine / settings / auth
                                           └─ return via floating camera control
```

| Rule | Detail |
|------|--------|
| Home root | Camera stack — not a multi-destination tab dashboard |
| Tabs | If a tab host exists, treat it as camera-rooted (effectively one primary child) |
| Push | Hide bottom chrome when pushing secondary pages |
| Pop gesture | Interactive edge-pop may be enabled or disabled per page when custom chrome conflicts |
| Bar buttons | Prefer behavioral styles that keep critical back controls stable under material / glass systems |

---

## 11. Internationalization, Flags & Offline

### 11.1 Internationalization

- All user-visible strings go through the shared language layer / catalog.
- When adding copy, ship **en + zh-Hans + zh-Hant** together.
- Agent / LLM language lines are constrained by the language manager so model output language stays consistent with UI locale.

### 11.2 Feature flags

Gate experiments through a single feature-flag manager — do not sprinkle ad-hoc preference keys across pages.

| Flag (conceptual) | Typical default | Meaning |
|-------------------|-----------------|---------|
| Backend API | **OFF** in demo-oriented builds | Offline / demo mode when disabled |
| Neural geometric scorers | **ON** | On-device neural path vs lighter vision fallback |

### 11.3 Offline / demo

When backend is off:

- Skip network wait / guest login; use a local demo user where appropriate.
- Inspire Me → local demo suggestion carousel.
- Favorites / results stay local in on-device photo storage.

### 11.4 Config constants

Hosts, ad unit IDs, asset names, and Agent LLM defaults live in one config surface per client — not hardcoded in feature UI.

---

## 12. Ads & Monetization Placement

| Placement | Rule |
|-----------|------|
| App Open | After splash, **before** Camera is visible — never interrupt live camera |
| Banner | **Mine only** — never on Camera, Agent HUD, or photo preview |
| Fail / timeout | Must not block forever; fall through to Camera |
| Demo ad unit IDs | Study / test only — **replace before Release** |
| Watermark | Brand watermark on save / share via the shared image pipeline |
| Subscription | Platform store APIs; VIP colors from the membership token set |

---

## 13. Accessibility & Platform Conventions

| Preference | Guidance |
|------------|----------|
| Hit targets | ≥ **44 × 44** |
| Safe area | All chrome and banners respect insets |
| Symbols | Prefer platform symbol / icon sets |
| Semantics | Prefer semantic colors (label, system background) on newer light UI where they improve Dynamic Type / dark-mode readiness without breaking brand navy pages |
| Glass HUD | Respect reduced transparency / accessibility; material fallbacks are required |
| Tracking / ATT | Request platform tracking permission only when ads require it, via the package / consent entry point |
| Permissions | Reuse existing Camera / Photos permission flows — do not silent-fail |
| Content insets | Adjust scroll content insets when custom top bars replace system bars |

Platform clients should feel native in navigation chrome and system dialogs, while coaching and capture UX stay product-identical.

---

## 14. Cross-Platform Parity

| Must match | May differ |
|------------|------------|
| Color tokens, Agent accent, finish green | System fonts and symbol sets |
| Camera IA (home = Camera; return FAB) | Navigation controller vs Compose / Activity host details |
| Coaching bubble / donut / shutter role rules | Exact material APIs (Liquid Glass vs Material You blur) |
| Orientation lock at event start for ML | Sensor / CameraX / AVFoundation wiring |
| Ad placement rules | Ad SDK integration code |
| i18n locale set for new strings | String resource file format |
| Offline demo behavior for Inspire Me | Asset packaging paths |

When one platform revises Agent layout or shutter roles, update this specification **and** the peer client so users do not learn two products.

---

## 15. Do’s and Don’ts

### Do

- Keep Camera black, full-bleed, and uncluttered; use Liquid Glass / materials only for coaching and Inspire HUD.
- Centralize new colors and metrics in each client’s theme / constant tokens that mirror this document.
- Route strings through the language layer; add all required locales together.
- Share one framing pipeline for every live ML path; lock orientation at the user event.
- Use the shared page shell and alert dialog for new light screens and confirmations.
- Gate backend and neural scorers with the feature-flag manager.
- Match Agent bubble / donut / shutter rules across platforms when changing coaching UI.
- Prefer composing existing managers over new singletons for the same concern.

### Don’t

- Don’t place ads, banners, or promo strips on Camera, Agent HUD, or capture preview.
- Don’t invent new alert shells, EXIF maps, or preview-to-image converters when shared ones exist.
- Don’t hardcode hosts, ad unit IDs, or LLM endpoints outside the config surface.
- Don’t hardcode English-only UI strings.
- Don’t implement a second score framing path or silent depth “fake” maps.
- Don’t show Skip during thinking; don’t leave Instruct shutter stuck after a round.
- Don’t ship demo ad unit IDs in Release builds.
- Don’t treat multi-tab IA as the product — home is Camera.
- Don’t put platform source paths or type names into this document; keep implementation detail in platform engineering docs.

---

*This specification is the design contract across Entropix clients. When product UX or visual tokens change, bump the version table and update the affected sections so design and every platform implementation stay aligned.*
