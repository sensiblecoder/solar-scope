# SolarScope

A reusable **"Playwright for Solar2D"**: hot-reloadable Lua tests that run *inside*
a Solar2D game. Tests are ordinary Lua; an AI (or a human) writes Lua instead of
issuing thousands of low-level MCP commands. The framework drives real UI via
hit-tested input, asserts on structured game state, and turns player interactions
into replayable `.sscope` bundles and generated regression tests.

- **Design:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- **Build plan (phases 0–4):** [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md)

## Why

- **Lua-first.** Tests are plain Lua that runs on the game's own frame loop — no
  brittle screen-coordinate scripts.
- **Real input, real hit-testing.** `tap`/`drag` walk the display tree and dispatch
  to the actual object under the point (with parent-chain bubbling), so buttons and
  drag handlers fire like they do for a player.
- **Auto-waiting.** Lazy locators and retrying assertions remove timing flakiness.
- **Structured state over screenshots.** Assert on `expectState("score")`, not pixels.
- **Deterministic.** Randomness flows through one seedable RNG; a seed reproduces a run.
- **Record → replay → regress.** Interactions record as self-healing `.sscope` bundles
  (semantic ids + coordinate fallback), replay to reproduce a bug, and translate into
  a readable Lua regression test.
- **Hot-reload loop.** Swap a test into the *running* simulator in tens of ms via the
  `solar2d` MCP — no relaunch.
- **Progressive adoption.** Works at Tier 0 (zero integration) and gets stronger as a
  game adds tags, state readers, and a seeded RNG.

## A test looks like this

```lua
-- menu -> start -> swap two tiles to make a match -> assert score
return function(t)
    t:findByText("Start Game"):tap()
    t:waitForScene("scenes.game")

    t:findById("tile.r3.c3")
        :dragTo(t:findById("tile.r3.c4"))

    t:expectState("score"):toBeGreaterThan(0)
    t:expectNoErrors()
end
```

## Layout

```
solar_scope.lua        # framework entry — require("solar_scope")
solar_scope/           # framework internals (core/, adapters/, fixtures.lua)
tools/translate.lua    # host-side: interaction log -> readable Lua test
harness/               # minimal match-3 color game we validate against
docs/                  # architecture + build plan
```

The framework is drop-in: copy `solar_scope.lua` + the `solar_scope/` folder into a
game (Solar2D's `package.path` has no `?/init.lua`, hence the top-level entry file).
The harness vendors both via symlinks.

## The validation game

A minimal **match-3 color game** (Composer): a 6×6 grid of colored tiles; drag a
tile onto an adjacent tile to swap. A swap forming a run of 3+ clears, cascades,
and scores; otherwise it reverts. The board is seeded through the shared RNG, so
runs reproduce — which is what makes it a good target for the determinism work.

## Running tests

Tests run inside the simulator. The result JSON is the source of truth (`status`,
`message`, `errors`, `artifacts`, probe `report`, `seq`); a `###SOLAR_SCOPE_RESULT###`
sentinel line is also printed.

### Via the MCP tools (recommended)

Three thin tools on the `solar2d` MCP drive SolarScope:

```
run_solar_scope_test(project, "tests.regression.record_replay")   # launch running a test
rerun_solar_scope_test(project, "tests.regression.invalid_swap")  # hot-reload, no relaunch
get_solar_scope_result(project, wait_seq=<seq>)                    # read the result
```

`run_*` launches (or relaunches) the sim on the chosen test; `rerun_*` swaps a test
into the **already-running** sim via the command channel (much faster). Both return a
`seq`; pass it to `get_solar_scope_result` to wait for that specific run.

> These tools live in the `solar2d` MCP server
> (`~/PycharmProjects/Solar2DMCP/tools/solar_scope.py`). **MCP servers load at start,
> so restart Claude Code once for them to appear.**

### Manually (no MCP tools)

1. Set `autorun = "tests.regression.<name>"` in `harness/solar-scope.config.lua`.
2. Launch `harness/` in the simulator (`run_solar2d_project`).
3. Read `~/Library/Application Support/Corona Simulator/harness-*/Documents/solar_scope/result.latest.json`.

### Just playing it

A plain launch (with `autorun = nil`, the default) lands on the menu and is fully
playable: tap **Start Game**, then swap adjacent tiles — either drag one onto a
neighbour, or tap a tile to select it and tap an adjacent tile. Runs of 3+ clear,
cascade, and score.

### Tests included

- `tests/generated/current_test.lua` — green E2E (menu → swap → assert score)
- `tests/regression/match_clears.lua` — valid swap scores
- `tests/regression/invalid_swap.lua` — non-matching swap is a no-op
- `tests/regression/deterministic.lua` — same seed reproduces the board
- `tests/regression/fixture_load.lua` — `loadFixture` a mid-game board
- `tests/regression/save_load.lua` — `loadSave` a bundled `.save`
- `tests/regression/record_replay.lua` — record → `.sscope` bundle → replay → translate
- `tests/regression/control_replay.lua` — named control record & replay
- `tests/probes/inspect_swap.lua` — probe returning structured diagnostics
- Red (expected-fail) demos: `score_mismatch`, `error_detection`, `async_error`

## Status

| Phase | Scope | State |
|-------|-------|-------|
| 0 | Foundations: runner + watchdog + result transport | ✅ built & validated |
| 1 | Input (hit-tested), lazy locators, assertions, error capture, scenes | ✅ built & validated |
| 2 | Fixtures, save/load, RNG abstraction + seed, semantic registry | ✅ built & validated |
| 3 | Recording, `.sscope` bundles, replay, log→Lua translate, probes, traces | ✅ built & validated |
| — | MCP hot-reload: command channel + `run/rerun/get_result` tools | ✅ built & validated |
| 4 | Deterministic runtime: virtual clock, frame stepping, sim hashes | ⛔ **paused for review** |

Every phase gate was exercised by launching the harness in the simulator and
reading the result file — not by reasoning alone.

### Known caveats

- **Host CLI for `tools/translate.lua` is unexercised** — no standalone `lua`/`luajit`
  on this machine. The `translate()` function itself is validated in-sim (the
  `record_replay` test asserts the generated Lua). The embedded JSON decoder in the
  CLI path is therefore untested end-to-end.
- **MCP `read_solar2d_logs` was unreliable here** (truncated output); the file-on-disk
  result transport is authoritative and is why we chose it.
- **New MCP tools need a Claude Code restart** to load. They were validated this
  session by invoking the handler functions directly against a live sim (the exact
  handler code), not through a reloaded server.

### Phase 4 intent (not yet built)

Phases 0–3 were built to leave the seams Phase 4 needs: a single-step runner loop,
one shared RNG source (`solar_scope/core/rng.lua`), and funnelled state reads.
Phase 4 extends these into a controllable virtual clock (`system.getTimer`,
`timer.*`, `transition.*` interception), frame stepping (`pauseClock`,
`advanceFrames`, `advanceMilliseconds`), and simulation hashing — the most invasive
work, deliberately deferred for explicit review.
