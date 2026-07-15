# FLUTTER DESIGN DNA — my-new-app

> ⚠️ This file must be filled in before any UI work begins.
> Agents MUST read this before writing any widget, color, or animation.

---

## Color System (AppColors)

All colors defined in `packages/shared/lib/src/theme/app_colors.dart` (or app-local equivalent).
**Never hardcode hex values. Always use `AppColors.*` tokens.**

| Token | Hex | Usage |
|:------|:----|:------|
| `AppColors.primary` | `#??????` | Primary CTAs, nav |
| `AppColors.accent` | `#??????` | Energy accent, badges |
| `AppColors.background` | `#??????` | Scaffold background |
| `AppColors.surface` | `#??????` | Card backgrounds |
| `AppColors.textPrimary` | `#??????` | Headlines, body |
| `AppColors.textSecondary` | `#??????` | Labels, metadata |
| `AppColors.success` | `#??????` | Success states |
| `AppColors.error` | `#??????` | Error, validation |

---

## Typography (AppTypography)

Font family: **[Choose font]** via `google_fonts`.
All styles in `packages/shared/lib/src/theme/app_typography.dart`.

| Token | Size | Weight | Usage |
|:------|:-----|:-------|:------|
| `AppTypography.h1` | ??pt | w??? | Page titles |
| `AppTypography.h2` | ??pt | w??? | Section headings |
| `AppTypography.bodyLarge` | ??pt | w??? | Primary body |
| `AppTypography.bodyMedium` | ??pt | w??? | Secondary body |
| `AppTypography.buttonText` | ??pt | w??? | CTA buttons |

---

## Spacing Grid (4dp base)

```
xs: 4dp | sm: 8dp | md: 12dp | base: 16dp | lg: 24dp | xl: 32dp
```

---

## Animation Standards

| Interaction | Duration | Curve |
|:------------|:---------|:------|
| Screen entrance | 300ms | easeOutCubic |
| Button press | 120ms | easeOut |
| List item deletion | 200ms | easeOutCubic |
| Bottom sheet entry | 250ms | easeOutCubic |
