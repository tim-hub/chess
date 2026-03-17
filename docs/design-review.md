# Design Review — Chess App

_Reviewed: 2026-03-16_

---

## Current State Summary

The app has a solid functional foundation with a coherent color identity built around chess green (`#769656`) and an off-white cream background (`#F5F5F0`). The board and UI chrome share the same accent color — a smart choice that makes the game feel native. The layout hierarchy is clean and consistent across screens.

What it lacks is **depth, character, and memorability**. Right now it looks like a well-structured prototype. These suggestions aim to push it toward something that feels crafted.

---

## 1. Typography — Highest Impact Change

**Current state:** System fonts throughout. No personality.

**Suggestion:** Introduce two Google Fonts:
- **Display/Headings:** `Playfair Display` — a refined serif that evokes classic chess books, tournament programs, and prestige. Use for screen titles, game-over headlines, and the home screen logo text.
- **Body/UI:** `DM Sans` — geometric, neutral, highly legible at small sizes. Replaces the implicit system font for all chip labels, panel text, and SAN notation.

```yaml
# pubspec.yaml
google_fonts: ^6.x
```

```dart
// app_text_styles.dart
static final heading1 = GoogleFonts.playfairDisplay(
  fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  letterSpacing: -0.5,
);
static final heading2 = GoogleFonts.playfairDisplay(
  fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
);
static final body = GoogleFonts.dmSans(fontSize: 15, color: AppColors.textPrimary);
static final moveHistory = GoogleFonts.dmMono(fontSize: 13, color: AppColors.textPrimary);
```

The move history strip in particular benefits from `DM Mono` — monospaced SAN notation reads like a real scoresheet.

---

## 2. Home Screen — Needs a Presence

**Current state:** Centered logo icon + title + two buttons. Feels like a loading screen.

**Suggestion:** Give it atmosphere. Two viable directions:

### Option A — Dark, editorial
- Change scaffold background to `#1A1A1A` (dark) for home screen only
- Large chess piece silhouette (knight SVG) as a decorative background element, 60% opacity, positioned bottom-right, scale ~280px — creates visual weight without clutter
- Title "Chess" in `Playfair Display` at 48px with tight tracking
- Buttons become light-on-dark: filled button uses cream text on green, outlined uses white border

### Option B — Light, refined (stays on-brand)
- Replace the `Icons.grid_on` logo with an actual chess piece — the king SVG from the current piece set assets (`assets/pieces/cburnett/wK.svg`) at 64px in the logo container
- Add a subtle chess board pattern as the logo container background (8×8 micro grid, alternating `#E8E8E3` / `#D4D4CC`, 4px squares)
- Subtitle line under "Chess": `"Play. Solve. Improve."` in `bodySecondary` italic

Either direction is a major step up. Option B requires zero new assets.

---

## 3. Color System — Extract Inline Values

**Current state:** 10+ hardcoded hex values and `Colors.X` references scattered across widgets.

**All values to move into `AppColors`:**

```dart
// Currently inline in game_screen.dart
static const avatarInactive = Color(0xFFE0E0E0);
static const sanBadgeInactive = Color(0xFFE8E8E8);

// Currently inline in move_history_strip.dart
static const moveChipInactive = Color(0xFFF0F0F0);
static const moveChipInactiveText = Color(0xFF333333);
static const moveNumber = Color(0xFF999999);

// Currently inline in puzzle_screen.dart + _SolvedSheet
static const creditsBackground = Color(0xFFFEF3C7); // amber-100
static const creditsGold = Color(0xFFF59E0B);        // amber-500

// Currently inline in DailyPuzzleCard
static const dailyBadge = Colors.white24;

// Currently inline in puzzle_list_tile.dart (rating color scale)
static const ratingLow    = Colors.green;     // < 1200
static const ratingMid    = Colors.orange;    // < 1600
static const ratingHigh   = Colors.deepOrange; // < 2000
static const ratingElite  = Colors.red;       // ≥ 2000
```

Also: the AppBar title style in `main.dart` duplicates `AppTextStyles.heading2` manually — replace with the style reference.

---

## 4. Game Screen — Player Panels

**Current state:** Minimal rows. Active/inactive state is shown only through the avatar circle color.

**Suggestion: Stronger active state signal**

Add a left-side accent bar to the active player's panel — a 3px wide colored strip on the leading edge of the container. This is common in chess apps (Chess.com, Lichess) and reads instantly.

```dart
// In _PlayerInfoPanel
Container(
  decoration: BoxDecoration(
    border: Border(
      left: BorderSide(
        color: isActive ? AppColors.accent : Colors.transparent,
        width: 3,
      ),
    ),
  ),
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
  child: Row(...)
)
```

Also consider: a subtle background tint on the active panel — `AppColors.accent.withOpacity(0.06)` — to reinforce whose turn it is at a glance.

---

## 5. Move History Strip

**Current state:** Horizontal chip strip, 36px tall. Uses `#F0F0F0` inactive chips.

**Suggestion:** Make the active move chip feel alive:
- Add `BoxShadow` to the active chip: `BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 2))`
- Slightly increase chip height to 28px (currently feels cramped)
- The move number label (`1.`, `2.`) could be styled in `DM Mono` italic to echo a printed scoresheet

---

## 6. Puzzle List — Daily Card

**Current state:** Solid green `Card` with white text and a chevron. Functional but flat.

**Suggestion:** Elevate it to feel premium:
- Add a subtle chess texture overlay (a very faint diagonal pattern or a 15% opacity queen SVG positioned top-right)
- Use `BoxShadow` for a floating card effect: `BoxShadow(color: accent.withOpacity(0.25), blurRadius: 16, offset: Offset(0, 6))`
- Rating display: make the number larger (40px, `Playfair Display`) — it's the key stat and should dominate

---

## 7. Settings Screen

**Current state:** Standard `ListView` with `RadioListTile`s and `SwitchListTile`s. Completely generic Material.

**Suggestion:** Group settings into visual cards:

```dart
// Each section wrapped in a Card-like container
Container(
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
  ),
  child: Column(children: [...settingTiles])
)
```

The board theme swatches (currently a tiny 24×24 diagonal gradient) could be expanded to a mini 40×40 board thumbnail showing a 4×4 checker pattern — much easier to evaluate at a glance.

---

## 8. Micro-interactions

**Current state:** No transitions or motion beyond Flutter defaults.

**Targeted suggestions (low effort, high return):**

| Location | Animation | Approach |
|---|---|---|
| Player panel active state | Fade in/out the left accent bar | `AnimatedContainer` on `Border` color |
| Game over sheet | Slide + fade entrance | `showModalBottomSheet` already animates; just ensure content staggered |
| Puzzle solved checkmark | Scale-in + bounce | `AnimatedScale` or `TweenAnimationBuilder` |
| Home buttons | Subtle press scale | `GestureDetector` + `AnimatedScale(scale: 0.97)` on tap |
| Credits chip | Count-up on award | `TweenAnimationBuilder<int>` over 600ms |

Avoid animating the board itself for now — the removed piece animation was distracting. Keep board interactions instant.

---

## 9. Board Coordinate Labels

**Current state:** Labels colored using the opposite square color for contrast — correct behavior.

**Suggestion:** Use `DM Mono` or `DM Sans` at 10px with `FontWeight.w600` for coordinates. The default system font makes them feel like an afterthought. Match the label opacity to ~80% — slightly receded, not competing with pieces.

---

## 10. Quick Wins (1–2 hours each)

Ordered by effort-to-impact ratio:

1. **Add `google_fonts` + update `AppTextStyles`** — single PR, affects every screen
2. **Extract all inline colors to `AppColors`** — pure refactor, zero visual regression
3. **Left accent bar on active player panel** — 10 lines of code, huge readability gain
4. **Home screen: replace `Icons.grid_on` with actual king SVG** — requires one `SvgPicture` swap
5. **Active move chip shadow in `MoveHistoryStrip`** — 3 lines of code
6. **Board theme swatches in Settings: 4×4 checker instead of diagonal gradient** — ~20 lines

---

## Design Principles to Preserve

- **Green accent consistency** — the shared board/UI green is the app's strongest identity marker. Don't replace or dilute it.
- **Fixed-height panels** — the current approach of fixed-height player panels and controls prevents layout jumps. Keep this discipline.
- **Cream background** — works well in bright lighting (likely chess playing context). Don't switch to white; the warmth is intentional.
- **No board animations** — the decision to remove piece animations was correct. Keep the board instant-response.
