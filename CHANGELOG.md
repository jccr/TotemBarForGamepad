# Changelog

## 0.2.3

### Fixed

- **Steam Deck and Steam Input showed numbered button glyphs** (1, 2, 3)
  instead of A, B, X, Y. Generic gamepads now get Blizzard's Xbox art.

### Changed

- **Button glyphs.** D-pad up and down, the shoulder buttons and the
  triggers now use Blizzard's button art, like the face buttons.

## 0.2.2

### Fixed

- **Empty totem bar slots could show a totem** when the game's deprecated
  API fallbacks are off. The addon now uses the current action bar API.

## 0.2.1

### Changed

- **Totem Expired alert is off by default** (None). Choose a sound for it
  in Options → AddOns.

## 0.2.0

### New

- **Gamepad Macros dialog.** Every TBG macro in one place: Totem Bar Focus
  and the direct-cast macros for each element and the weapon enhancement.
  Press A to bind one to a gamepad button, or drag it to an action bar.
  Open it from Options → AddOns or the welcome guide. Opening it from
  Options closes Options, so LB + RB + D-pad paging works while binding.
- **Logo.** Shown next to the addon's name in the AddOns list.

### Changed

- **Welcome guide.** The D-pad moves through a 2×2 grid: the macro and
  Open Edit Mode, then Gamepad Macros and Open Options, then Done. The
  guide is more compact and opens higher on the screen.
- **Gamepad Macros dialog.** The bind and page-switching reminders are gone
  (the bind prompt explains them).
- **Default bar position.** Centered, with its bottom edge 5% of the
  screen's height above the bottom, on any screen size, UI scale, bar scale
  or orientation. Edit Mode's Reset Position returns the bar there.

### Fixed

- **Call of the Elements cast nothing** for elements the bar showed a
  totem for. The bar showed a default totem that was never put on the
  game's totem bar. It now shows the game's totem bar as it is: an empty
  slot shows as No Totem.
- **The Totem Expired sound played when recalling totems** with Totemic
  Recall.
- **Weapon enhancements showed Rank 1** in their tooltips and icons
  instead of the rank you've learned.

## 0.1.0

First release.
