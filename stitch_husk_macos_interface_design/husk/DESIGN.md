---
name: Husk
colors:
  surface: '#131314'
  surface-dim: '#131314'
  surface-bright: '#39393a'
  surface-container-lowest: '#0e0e0f'
  surface-container-low: '#1b1b1c'
  surface-container: '#1f1f20'
  surface-container-high: '#2a2a2b'
  surface-container-highest: '#353436'
  on-surface: '#e5e2e3'
  on-surface-variant: '#d6c3b3'
  inverse-surface: '#e5e2e3'
  inverse-on-surface: '#303031'
  outline: '#9e8e7f'
  outline-variant: '#514439'
  surface-tint: '#ffb86e'
  primary: '#ffc284'
  on-primary: '#492900'
  primary-container: '#e8a45c'
  on-primary-container: '#663a00'
  inverse-primary: '#87520f'
  secondary: '#77d6d2'
  on-secondary: '#003735'
  secondary-container: '#007d7a'
  on-secondary-container: '#c6fffb'
  tertiary: '#a6d8c5'
  on-tertiary: '#01382b'
  tertiary-container: '#8bbcaa'
  on-tertiary-container: '#1c4c3e'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdcbd'
  primary-fixed-dim: '#ffb86e'
  on-primary-fixed: '#2c1600'
  on-primary-fixed-variant: '#693c00'
  secondary-fixed: '#94f3ee'
  secondary-fixed-dim: '#77d6d2'
  on-secondary-fixed: '#00201f'
  on-secondary-fixed-variant: '#00504d'
  tertiary-fixed: '#bbedda'
  tertiary-fixed-dim: '#9fd1be'
  on-tertiary-fixed: '#002118'
  on-tertiary-fixed-variant: '#1f4f41'
  background: '#131314'
  on-background: '#e5e2e3'
  surface-variant: '#353436'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  data-mono:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: -0.01em
  label-caps:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  rail-width: 64px
  gutter-md: 16px
  container-padding: 24px
  card-gap: 12px
---

## Brand & Style
The design system for this product is built on a philosophy of "quiet confidence." It rejects the aggressive, fear-based metaphors of traditional system utilities in favor of an organic, maintenance-focused narrative. The visual language centers on the concept of "peeling back the husk"—removing temporary layers of data to reveal the core system. 

The aesthetic is a refined evolution of modern macOS (v15+) standards, utilizing **Liquid-Soft Glassmorphism**. It combines deep, immersive backgrounds with highly tactile, frosted surfaces. The emotional goal is to provide a calm, transparent environment where the user feels in total control of their machine without the anxiety of "threats" or "scores."

## Colors
This design system utilizes a dark-first, low-fatigue palette. 

- **Primary (Husk Amber):** Used for primary actions, selection states, and highlighting the "removable" layers.
- **Surface (Charcoal/Slate):** The foundation is a deep #1A1A1B, enhanced by subtle radial gradients to create a sense of infinite depth.
- **Typography (Oat):** Soft cream text reduces contrast harshness while maintaining high legibility.
- **Semantic Accents:** Colors are functional rather than emotional. Teal is reserved for data metrics and percentages; Green indicates a "Stable" or "Clean" state without using shield imagery.

## Typography
The system relies on a dual-font approach. For all UI labels, navigation, and headings, we use a clean, systematic sans-serif (Inter/SF Pro). For all technical data—including file sizes, percentages, memory addresses, and paths—we use **JetBrains Mono**. This distinction signals to the user when they are looking at "system fact" versus "application interface."

Headlines should be tight and authoritative, while data labels should use tabular figures to ensure that vertical columns of numbers align perfectly during real-time updates.

## Layout & Spacing
The layout follows a **Fixed Rail + Fluid Content** model. 

1.  **Vertical Rail:** A 64px wide navigation bar sits on the far left. Icons are centered with pill-shaped active states.
2.  **Detail Split:** The main content area uses a split-view layout. The left pane provides high-level categories (e.g., Caches, Logs, Build Artifacts), while the right pane shows the monospaced data table of specific files.
3.  **The "Husk" Margin:** All primary windows maintain a 24px internal margin to allow the background radial gradients to breathe around the edges of the frosted cards.

## Elevation & Depth
Depth is created through **Backdrop Blurs** rather than traditional drop shadows. 

- **The Floor:** The dark charcoal background with a soft, centered radial amber glow.
- **The Cards:** Semi-transparent surfaces with a `saturation` of 150% and a `blur` of 30px. 
- **The Borders:** Every card and button features a 0.5px inner "sheen" border (white at 10% opacity) to catch the light, mimicking the edge of a glass pane.
- **Hero Icons:** 3D rendered assets (Seed, Treemap Cubes) appear to float within the glass, utilizing internal refraction and translucency.

## Shapes
The shape language is "Liquid-Soft." While the system is precise and technical, the corners are generous to evoke an organic feel. 

- **Cards:** Use 20px - 24px corner radii to create a friendly, modern container.
- **Pill CTAs:** Primary actions are always fully rounded (pill-shaped).
- **Selection Highlights:** Use a 10px radius for list item selections, providing a snug but soft fit.

## Components

### Primary Pill CTAs
Located at the bottom-center of the main view. These are large, high-contrast buttons using the Husk Amber (#E8A45C) with black text. They should appear "heavy" and tactile.

### Frosted Glass Cards
The primary container for all information. Cards do not have background colors; they use a background-blur material. Borders are thin, 1px strokes with a linear gradient from top-left (light) to bottom-right (dark).

### Semantic Chips
Small, non-interactive indicators for state.
- **Safe:** Forest Green text on a 10% opacity Green fill. No icons.
- **Review:** Husk Amber text on a 10% opacity Amber fill.
- **Caution:** Orange text on a 10% opacity Orange fill.

### Monospaced Data Tables
Rows should be clean with no vertical dividers. Use alternating subtle row highlights (zebra striping) at 2% white opacity. Align all numeric values to the right using JetBrains Mono.

### Navigation Rail
Vertical icons using SF Symbols (Weight: Semibold). The active state is a vertical "squircle" or pill behind the icon in a low-opacity amber.