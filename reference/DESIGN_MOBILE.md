# Mobile Design Reference: GeckoView Android Browser

> **Specification & Anti-Slop Baseline**  
> Governed by Universal Rules `rules.md` §25–§31.

---

## 1. Core Design Principles & Anti-Slop Mandate (§25.1)

Every screen and widget must be purposefully crafted. Standard AI-generated generic Flutter UI ("AI slop") is strictly forbidden.

### 1.1 Forbidden Design Patterns (Hard Bans)
Unless explicitly requested by the user in writing:
- **No Stock `ThemeData()`**: Never instantiate unconfigured themes or use un-themed components.
- **No Random Seeds**: Never use arbitrary seeds in `ColorScheme.fromSeed()` (use dynamic color or the designated brand seed only).
- **No Default `Card` Widgets**: Avoid default elevation or rectangular shapes; use custom container styling with `colorScheme.surfaceContainer` and token radii (`AppRadius.card`).
- **No `ElevatedButton` for Primary Actions**: Primary actions must use `FilledButton` with `AppShapes.pill`.
- **No Stock Material Icons or Cupertino Icons**: App icons must come exclusively from `phosphor_flutter`.
- **No Emojis as UI Icons**: Emojis must never serve as decorative UI icons.
- **No Gradients or Glassmorphism**: `LinearGradient`, `RadialGradient`, and `BackdropFilter` frosted glass cards are strictly banned.
- **No Deprecated Opacity**: Never call `.withOpacity()`; always use `.withValues(alpha:)`.
- **No Placeholder Content**: No "Lorem ipsum", "Feature 1", or dummy text. Use realistic browser domain data.
- **No Generic Symmetric Grids**: Avoid centered twin-CTA layouts and copy-pasted 3-column identical card stacks.
- **No Uniform 300ms Transitions**: Blanket duration copy-pasting is forbidden. Restraint and physics curves are mandatory.

---

## 2. Required Design Discipline (§25.2)

- **Android-First**: Optimized for modern Android form factors, gesture navigation, and system ergonomics.
- **Material 3 Expressive Baseline**: Expressive geometry, spring-physics motion, and prominent tactile hierarchies.
- **Token-Only Styling**: Every color, font style, spacing interval, radius, and duration is sourced directly from `/lib/theme/tokens/` or the ambient `ColorScheme`. Raw `Color(0x...)`, `SizedBox(height: 13)`, or inline `TextStyle` are prohibited.
- **Typography Hierarchy**: Display font (`ClashDisplay`) paired with variable body font (`RobotoFlex`). Maximum 2 weights per view.
- **4px Spacing Grid**: All padding and margins adhere to the 4px baseline in `AppSpacing`.
- **Restraint in Motion**: Physics-based springs (`AppMotion.spring`, `Curves.easeOutBack`) replace robotic linear animations.

---

## 3. Dynamic Color Strategy & Brand Seed (§25.3)

### 3.1 Material You Integration
- The application root is wrapped in `DynamicColorBuilder` (via `dynamic_color`).
- **Android 12+ (API 31+)**: The palette is automatically extracted from the user's OS wallpaper and harmonized with the brand seed via `.harmonized()`.
- **Fallback (< Android 12)**: The app falls back to a generated `ColorScheme` anchored by the brand seed.
- **Theme Modes**: Both Light and Dark modes are supported and dynamically harmonized with system settings.

### 3.2 Brand Seed Color Definition
> **Status:** The permanent brand seed color **will be defined later**.  
> The current token configuration in `AppColors.brandSeed` uses an initial placeholder (`Color(0xFF6750A4)`), which will be substituted once final branding decisions are finalized.

---

## 4. Material 3 Expressive Baseline Elements (§25.4, §28.8)

- **Shapes (`AppShapes`)**:
  - `AppShapes.pill`: Rounded 999px pill used for URL address bars, tabs, and primary action buttons.
  - `AppShapes.cookie`: Asymmetric corner rounding (`24-8-24-8`) for expressive cards, download item highlights, and action badges.
  - `AppShapes.clover`: Organic asymmetric layout rounding.
- **Motion (`AppMotion`)**:
  - Durations: `fast` (120ms), `base` (200ms), `slow` (320ms).
  - Physics Spring: `Cubic(0.34, 1.56, 0.64, 1)` for touch feedback, FAB expansions, and download progress triggers.
- **Predictive Back Navigation**:
  - Enabled via `PredictiveBackPageTransitionsBuilder` in `AppTheme`.
  - Android Manifest configured with `android:enableOnBackInvokedCallback="true"`.
- **Buttons**:
  - Primary: `FilledButton` with pill shape.
  - Secondary/Utility: Outlined or text buttons styled with `colorScheme.onSurfaceVariant`.

---

## 5. Design Token Directory Structure (§28.1)

```
lib/theme/
├── app_theme.dart                 # Unified M3 Expressive ThemeData constructor
└── tokens/
    ├── app_colors.dart            # Semantic colors (success, warning, danger, info) & brand seed
    ├── app_typography.dart        # ClashDisplay & RobotoFlex variable font scales
    ├── app_spacing.dart           # 4px modular spacing grid (x1 through x16)
    ├── app_radius.dart            # Standard input/card/modal/pill radii + M3 Expressive tokens
    ├── app_shapes.dart            # Asymmetric M3 Expressive ShapeBorder instances
    └── app_motion.dart            # Expressive physics curves and animation durations
```

---

## 6. Visual Reference & Screenshots (§25.5)

Reference screenshots, interaction patterns, and mockups are archived in:
`/reference/screenshots_mobile/`
*(3–5 reference mockups to be supplied during UI prototyping phase)*

