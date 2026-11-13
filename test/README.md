# Totem Bar for Gamepad: offline tests

These checks run without the game. They load the addon's real Lua into
[fengari](https://github.com/fengari-lua/fengari), a Lua VM written in JS,
together with stand-ins for the WoW API. They catch syntax errors, broken
secure snippets, leaked globals, load-time errors and regressions in the
gamepad and secure logic before you `/reload`.

They can't replace testing in game. The stubs only model what the addon uses,
so taint, real secure-environment rules beyond those modeled, art, layout and
sounds still need checking in game.

## Run

From the repo root:

```sh
just test                    # tests src/
just test path/to/addon      # tests any other copy, e.g. the installed one
```

Or from this folder: `./run-all.sh [addon dir]` (default `../src`), `npm test`,
or `VERBOSE=1 ./run-all.sh` to also print each step's output. The first run
installs `node_modules` if it's missing. The exit code is the number of failed
steps.

## What runs

| Step | Script | Checks |
|---|---|---|
| parse | `checks/parse.js <addon>` | Every `.lua` file parses as Lua 5.1, and so does every `[[ ]]` string literal (secure snippets; `string.format` templates are skipped). The game only compiles snippets at runtime. |
| locals | `checks/locals.js <file>` | Each file's main chunk stays under 180 locals. Lua 5.1 refuses to load a file past 200 ("too many local variables"). |
| globals | `checks/globals.js <file> [toc] [-v]` | No file writes a global (a missing `local`) other than the TOC's SavedVariables or `SLASH_`/`BINDING_` names. `-v` also lists the globals it reads. |
| grid snippets | `checks/snippets.js <GamepadKit> <TotemBarFocus.lua>` | Builds a SecureGrid the way Totem Bar Focus does, using TotemBarFocus.lua's own `ASSIGN_SNIPPET`, and parses all 14 snippets it installs. |
| sim | `sim/run.js <GamepadKit> <scenario.lua>` | Runs a scenario against the real GamepadKit inside `lib/gridsim.lua`. That is a small secure-environment simulator: attributes, frame refs, restricted snippets (no `_` attributes; `...` holds only extra args), click registration and down/up edges, override bindings, a scripted gamepad (`PAD.buttons`) and a clock (`Advance`) that drives OnUpdate. |
| full load | `fullload.js <addon>` | Loads every file in TOC order on `lib/wowstub.lua` and fires the addon's events. Then it goes through alerts, Totem Bar Focus options, the guide, the macro row, `OnSmartNavClick` and hints, and finishes with a logout. |

### Scenarios (`sim/scenarios/`)

- `grid-*`: Totem Bar Focus (SecureGrid). Opening/closing, D-pad movement and
  order, start column and last used, A/X casts, entry row, B back, auto-close,
  and side columns.
- `nav-capture`, `nav-bindings`: FocusNav in both input modes, including
  `bindingsOnly` and `passWhileHeld` (LB+RB lets D-pad Left/Right through for paging).
- `bind-prompt`: "Bind to Action Bar". Each LT/RT layer goes to the right slot,
  reserved slots are rejected, B cancels, paging pass-through works, and closing
  leaves no bindings behind.

Scenarios print their results. A scenario fails when it raises a Lua error
(`error(...)`/`assert`) or prints a line that starts with `FAIL`. To add one,
drop a `.lua` file into `sim/scenarios/`; `run-all.sh` picks it up.

## Layout

```
run-all.sh        suite entry point
fullload.js       whole-addon load test
checks/           static checks (parse, locals, globals, snippets)
sim/run.js        scenario runner
sim/scenarios/    simulator scenarios
lib/wowstub.lua   WoW API stubs (frames, CVars, bindings, ...)
lib/gridsim.lua   secure-environment simulator used by sim/
```
