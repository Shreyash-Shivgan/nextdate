---
name: NextDate Core
colors:
  surface: '#051424'
  surface-dim: '#051424'
  surface-bright: '#2c3a4c'
  surface-container-lowest: '#010f1f'
  surface-container-low: '#0d1c2d'
  surface-container: '#122131'
  surface-container-high: '#1c2b3c'
  surface-container-highest: '#273647'
  on-surface: '#d4e4fa'
  on-surface-variant: '#e0bfbb'
  inverse-surface: '#d4e4fa'
  inverse-on-surface: '#233143'
  outline: '#a78a86'
  outline-variant: '#58413e'
  surface-tint: '#ffb4aa'
  primary: '#ffb4aa'
  on-primary: '#690004'
  primary-container: '#ff6f61'
  on-primary-container: '#6f0205'
  inverse-primary: '#ac332a'
  secondary: '#bec6e0'
  on-secondary: '#283044'
  secondary-container: '#3f465c'
  on-secondary-container: '#adb4ce'
  tertiary: '#7bd1fa'
  on-tertiary: '#003547'
  tertiary-container: '#4da7ce'
  on-tertiary-container: '#00394d'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad5'
  primary-fixed-dim: '#ffb4aa'
  on-primary-fixed: '#410001'
  on-primary-fixed-variant: '#8b1a16'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#c0e8ff'
  tertiary-fixed-dim: '#7bd1fa'
  on-tertiary-fixed: '#001e2b'
  on-tertiary-fixed-variant: '#004d66'
  background: '#051424'
  on-background: '#d4e4fa'
  surface-variant: '#273647'
typography:
  display-lg:
    fontFamily: Outfit
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Outfit
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Outfit
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Outfit
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Outfit
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  quote-italic:
    fontFamily: Outfit
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  label-sm:
    fontFamily: Outfit
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  container-margin: 24px
  gutter: 16px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
  section-gap: 48px
---

## Brand & Style
The design system is built for a premium, high-energy date-discovery experience tailored to a Gen Z audience. It balances the intimacy of romance with the immersive, fast-paced nature of modern social media. 

The aesthetic is **Immersive Dark-Mode**, heavily utilizing **Glassmorphism** and vibrant **Neon Glows**. It draws inspiration from high-engagement platforms like Spotify and TikTok, prioritizing full-bleed imagery, tactile feedback, and a sense of "digital nightlife." The interface should feel alive, using depth and translucency to create a layered, cinematic environment that feels premium yet approachable.

## Colors
The palette is rooted in a deep, nocturnal foundation to allow visual content and accents to pop.

- **Primary (Sunset Pink):** Used for main actions, active states, and brand-defining moments. It evokes warmth and modern romance.
- **Background (Deep Navy):** A rich, dark charcoal-navy that serves as the canvas for glass effects and neon glows.
- **Status/Score Colors:** Used specifically for "Match Scores" or compatibility ratings:
    - **Emerald (90+):** High compatibility.
    - **Azure (70+):** Strong potential.
    - **Amber (60+):** Emerging interest.
- **Glows:** Subtle radial gradients using the Primary color at 15-20% opacity should be placed behind key cards to create a "neon" depth effect.

## Typography
The typography system uses **Outfit** for its geometric yet friendly construction, which feels distinctly modern and premium. 

- **Headers:** Large and bold to command attention, mirroring the high-impact editorial style of social discovery apps.
- **Quotes:** Specifically styled in a soft grey italic to differentiate user-generated bios or prompts from UI labels.
- **Hierarchy:** Use tight tracking on larger display sizes to maintain a sleek, "designed" look. Ensure high contrast between the Sunset Pink headlines and the soft grey body text to maintain readability against dark backgrounds.

## Layout & Spacing
The layout follows a **Fluid Grid** model designed for mobile-first consumption. 

- **Margins:** A generous 24px side margin ensures content feels "framed" and premium, avoiding a cluttered edge-to-edge look.
- **Vertical Rhythm:** Content is stacked with ample breathing room (32px - 48px between major sections) to allow the background glows and glass effects to be visible.
- **Safe Areas:** On mobile, ensure all primary interactions are within the "thumb zone," utilizing bottom-anchored sheets and floating action buttons.

## Elevation & Depth
Depth is achieved through **Glassmorphism** rather than traditional drop shadows.

- **Surface Layers:** Surfaces use a semi-transparent fill (`rgba(255, 255, 255, 0.08)`) with a 20px backdrop blur.
- **Borders:** "Ghost borders" are essential. Use a 1px solid stroke with a linear gradient (top-left to bottom-right) from white at 20% opacity to white at 5% opacity. This simulates a glass edge catching the light.
- **Glows:** High-priority elements (like active match scores) should have a soft, outer "neon" bloom using the primary or status color with a 30px spread and very low (10-15%) opacity.

## Shapes
The shape language is ultra-rounded and tactile. 

- **Containers:** Large cards and glass panels use `rounded-3xl` (1.5rem to 2rem) to feel soft and approachable.
- **Buttons/Inputs:** These should be fully "Pill-shaped" to emphasize the playful, modern nature of the app.
- **Interactive States:** When pressed, shapes should subtly scale down (98%) to provide tactile, "squishy" feedback common in premium consumer apps.

## Components

- **Glass Cards:** The primary container for profiles. Features 20px backdrop blur, subtle white inner-stroke, and bottom-aligned typography overlays.
- **Primary Action Button:** Pulsing Sunset Pink background. On hover/active, the glow intensity increases. Use high-contrast white text for the label.
- **Compatibility Chips:** Small, pill-shaped indicators using status colors (Emerald, Azure, Amber). These should have a slight glow background to make the score feel "energized."
- **Input Fields:** Dark navy background with a 1px glass border. On focus, the border transitions to a Sunset Pink gradient.
- **Micro-interactions:** Use "pulsing" animations for discovery states (e.g., searching for matches) and springy physics for card swiping to mimic a physical, tactile deck of cards.
- **Bottom Navigation:** A persistent glass bar with frosted transparency, allowing the background content and glows to bleed through as the user scrolls.