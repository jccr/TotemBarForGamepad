# Developing Totem Bar for Gamepad

## Repo layout

```
src/        the addon, exactly as it's installed (TOC, Lua, XML, Media/)
  GamepadKit/   embedded, addon-agnostic gamepad library
test/       offline test suite (see test/README.md)
assets/     the full-size logo (the addon ships a small icon in src/Media)
  screenshots/  the README's screenshots
Justfile    test and build recipes
CHANGELOG.md  what changed in each version
DEVELOPMENT.md  this file
.github/    the release workflow
```

## Building

Requirements: [just](https://github.com/casey/just) and Node.js. Install just
with `brew install just`.

```sh
just test     # run the offline test suite against src/
just build    # test, then install src/ into the game's AddOns folder
```

`just build` copies `src/` to
`/Applications/World of Warcraft/_forever_/Interface/AddOns/TotemBarForGamepad`,
mirroring it so removed files are removed there too. If any test fails, nothing
is copied. After a build, `/reload` in game. Saved settings are kept: they live
in the game's `WTF` folder, not the addon folder.

Edit the code in `src/` only. The installed copy is overwritten on every build.

`just test path/to/addon` tests another copy, such as the installed one.

## Releasing

1. Add the version's section to `CHANGELOG.md` (`## 1.2.3`), written for
   players.
2. Set `## Version: 1.2.3` in `src/TotemBarForGamepad.toc`.
3. Commit, tag and push:

   ```sh
   git tag -a v1.2.3 -m "Totem Bar for Gamepad 1.2.3"
   git push origin main v1.2.3
   ```

Pushing the tag runs `.github/workflows/release.yml`. It checks the tag
against the TOC version and the changelog, runs the tests, and publishes a
GitHub release with `TotemBarForGamepad-1.2.3.zip` (unzips into
`Interface/AddOns`) and that version's changelog section as the notes.

## Testing

The tests run the addon's real Lua outside the game. They load it into
fengari, a Lua VM written in JS, on top of WoW API stubs and a small
secure-environment simulator. They catch syntax errors, broken secure
snippets, leaked globals, load errors and regressions in the gamepad logic.
Taint, art, layout and sound still need checking in game. See
[test/README.md](test/README.md).
