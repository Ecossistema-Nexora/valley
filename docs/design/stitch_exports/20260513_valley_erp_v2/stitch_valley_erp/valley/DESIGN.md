---
name: Valley
PROPOSITO: Preservar os tokens visuais exportados pelo Stitch como referencia de design Valley.
CONTEXTO: Este arquivo alimenta a aplicacao visual dos templates ERP, admin e superficies web/mobile.
REGRAS: Manter tokens coerentes com a identidade Valley e evitar alteracoes manuais sem nova validacao visual.
colors:
  surface: '#fcf8fa'
  surface-dim: '#dcd9db'
  surface-bright: '#fcf8fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f5'
  surface-container: '#f0edef'
  surface-container-high: '#eae7e9'
  surface-container-highest: '#e4e2e4'
  on-surface: '#1b1b1d'
  on-surface-variant: '#45464d'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#76777d'
  outline-variant: '#c6c6cd'
  surface-tint: '#565e74'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#131b2e'
  on-primary-container: '#7c839b'
  inverse-primary: '#bec6e0'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#001a42'
  on-tertiary-container: '#3980f4'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2fd'
  primary-fixed-dim: '#bec6e0'
  on-primary-fixed: '#131b2e'
  on-primary-fixed-variant: '#3f465c'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#d8e2ff'
  tertiary-fixed-dim: '#adc6ff'
  on-tertiary-fixed: '#001a42'
  on-tertiary-fixed-variant: '#004395'
  background: '#fcf8fa'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e4'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  title-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-bold:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  mono-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 1.5rem
  gutter: 1rem
  dense-gap: 0.5rem
  max-width: 1600px
---

## Brand & Style
This design system is engineered for high-stakes commercial operations, prioritizing information density and functional clarity. It targets enterprise users who require a "cockpit" experience—where data visibility is maximized without sacrificing legibility. 

The visual style is **Corporate Modern** with a focus on structural integrity. It utilizes a "Sheet & Pane" metaphor where the interface is treated as a series of nested logical containers. The aesthetic is defined by surgical precision: hairline borders, a restrained color palette, and a focus on alignment. The emotional response is one of reliability, authority, and efficiency, utilizing subtle purple and cool-blue accents to provide a modern, tech-forward edge to traditional enterprise foundations.

## Colors
The palette is rooted in **Deep Navy** (#0F172A) for primary branding and text, providing a stable, high-contrast anchor. **Corporate Blue** (#3B82F6) serves as the functional action color for links and primary buttons, while **Emerald Green** (#10B981) is reserved for success states and positive operational KPIs.

To align with the reference aesthetic, **Indigo/Purple** (#6366F1) is used sparingly as an accent for active tab indicators, data visualization highlights, and progress bars. The background uses a sophisticated range of cool grays (Slate) to differentiate between the workspace and the global navigation, ensuring that the "dense" content remains digestible through subtle tonal shifts rather than aggressive color blocks.

## Typography
The system utilizes **Inter** for all UI elements to ensure maximum readability at small scale. The hierarchy is intentionally flat; font sizes do not vary wildly, instead using weight (Semibold vs. Regular) and color (Navy vs. Slate) to denote importance. 

For tabular data and operational IDs, a secondary monospace font is used for alignment precision. Label styles use uppercase tracking to distinguish field headers from user input. This density-first approach ensures that more data can be displayed on a single screen without overwhelming the user's cognitive load.

## Layout & Spacing
The layout follows a **12-column fluid grid** housed within a max-width container of 1600px. A 4px baseline grid governs all internal component spacing to maintain a "dense" feel.

- **Desktop:** 24px margins, 16px gutters.
- **Tablet:** 16px margins, 12px gutters.
- **Sidebars:** Fixed-width 240px (when present), though the primary navigation is horizontal.

Components are packed tightly using the `dense-gap` (8px) for related elements like filter chips or button groups. Large "white space" is avoided in favor of "structured space," where borders and subtle background fills provide the necessary separation.

## Elevation & Depth
This system eschews heavy shadows in favor of **Tonal Layers** and **Hairline Borders**. Depth is communicated through a 3-tier stacking model:
1.  **Level 0 (Canvas):** The base background (#F8FAFC).
2.  **Level 1 (Panes):** White surfaces (#FFFFFF) with a 1px border (#E2E8F0).
3.  **Level 2 (Popovers/Modals):** White surfaces with a refined 8px/12% opacity shadow and a 1px border.

Interaction depth is subtle: buttons move from a flat state to a 1px "pressed" shadow, and cards may use a slight indigo-tinted glow on hover to indicate interactivity.

## Shapes
The shape language is **Soft-Square**. A standard radius of 4px (Soft) is applied to all primary UI elements (inputs, buttons, cards). This provides a professional, "tooled" look that feels more precise than rounder consumer styles. 

**Exceptions:**
- **Chips/Pills:** 100px radius for status indicators.
- **Inner Elements:** Elements nested inside containers use a 2px radius to maintain visual harmony with the parent container's 4px radius.

## Components

### Navigation & Headers
- **TopNavigation:** A persistent Navy-background bar containing the logo, global search, and utility icons. Directly below, a secondary white bar houses horizontal **Tabs** for primary modules.
- **WorkspaceHeader:** A high-density area containing **Breadcrumbs** (sm label style) and the page title, flanked by the **ActionBar**.
- **ActionBar:** A right-aligned cluster of primary and secondary actions (e.g., Export, Create, Sync).

### Data & Operations
- **KpiGrid:** A horizontal row of 4-6 cards. Each card contains a small-label title, a bold display-md value, and a sparkline or percentage chip.
- **FilterBar:** A grey-tinted horizontal strip above data tables. It uses **Chips** for active filters and "Ghost" style buttons for adding new criteria.
- **DataTable:** The core of the system. High-density rows (32px height), subtle zebra-striping, and sticky headers. Statuses are indicated by small colored dots or pill-shaped chips.
- **ChartPanel:** White containers with 1px borders housing simplified data visualizations using the primary, secondary, and accent-purple colors.

### Forms & Integrations
- **OperationalForm:** Two-column layouts for desktop. Labels are positioned above inputs to save horizontal space. Includes inline validation.
- **IntegrationCard:** A specialized card for third-party connections. Features the service logo, a toggle switch, and a "Last Synced" timestamp in mono-sm font.
- **OperationalHistory:** A vertical timeline component located in side-drawers or bottom-panels, using small typography and connector lines to show system logs.

### Grid System
- **ResponsiveAppGrid:** A standard container that reflows from a 4-column layout on desktop to a 1-column layout on mobile, ensuring that ERP dashboards remain functional across devices.
