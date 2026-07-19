# SolarScope — Architecture

> **SolarScope** is a reusable *"Playwright for Solar2D"*: it executes hot-reloadable
> Lua tests **inside** a running Solar2D game. Tests are ordinary Lua; the AI (or a
> human) writes Lua rather than issuing thousands of low-level MCP commands.
>
> This document is the revised architecture, derived from
> `SolarTestKit_Architecture_Proposal_v3.md` with corrections baked in (see
> [Deviations from the original proposal](#deviations-from-the-original-proposal)).
> The module and brand are renamed **`solar_testkit` → `solar_scope`**.

---

## Goals

- AI generates **Lua** instead of issuing thousands of low-level MCP round-trips.
- **Deterministic, reproducible** testing.
- **Drop-in** support for existing Solar2D games (progressive adoption).
- Turn **player bug reports into regression tests**.

## Core principles

- Lua-first execution
- Minimal MCP round-trips
- Semantic APIs over coordinates
- Structured state over screenshots
- Deterministic execution
- Progressive enhancement (works at Tier 0, improves as the game integrates)
- Reusable across Solar2D projects

---

## Runtime model

```text
AI ──generates──▶ Lua test / probe / scenario
                        │
                        ▼
                 SolarScope runtime (in-game)
                 ├── hot-reload the test module
                 ├── load fixture or save
                 ├── run the test as a coroutine (yields across frames)
                 ├── collect assertions
                 ├── capture traces (screenshots, logs, display tree, state)
                 └── write a STRUCTURED RESULT to disk
                        │
                        ▼
              solar2d MCP  (existing server — we reuse it)
              ├── run_solar2d_project      (launch)
              ├── read_solar2d_logs        (find the sentinel + result path)
              └── get_simulator_screenshot (artifacts)
```

The test runs on Solar2D's `enterFrame` loop. A coroutine lets a test *await*
across frames (`waitFrames`, `waitUntil`, retrying assertions) without blocking
the main loop.

### Result transport (decided)

Tests write their structured result as **JSON to
`system.DocumentsDirectory/solar_scope/result.latest.json`** (plus a timestamped
copy). On completion the runner prints a single **sentinel line** to the console:

```
###SOLAR_SCOPE_RESULT### {"status":"pass","file":"result.latest.json","path":"/…/Documents/solar_scope/result.latest.json"}
```

The MCP driver reads the JSON file from disk (a `###SOLAR_SCOPE_RESULT###` sentinel
line is also printed). This keeps the app decoupled from any transport.

> **MCP surface (thin).** The original proposal listed a large bespoke MCP surface
> (`write_test_file`, `run_test`, …). We instead added **three thin tools to the
> existing `solar2d` server** — no new server:
> - `run_solar_scope_test(project, module)` — launch running a specific test.
> - `rerun_solar_scope_test(project, module)` — hot-reload a test into the running
>   sim (no relaunch) via the command channel.
> - `get_solar_scope_result(project, wait_seq?)` — read the structured result,
>   optionally waiting for a specific run.
>
> Everything else stays in Lua. (MCP servers load at process start, so these tools
> require a Claude Code restart to become available.)

### Command channel (hot-reload)

To iterate without relaunching the simulator, an external driver writes a small
JSON command file the running app polls each ~250ms:

```text
<project>/.solar_scope/command.json   { "seq": N, "action": "run", "module": "tests..." }
```

The project dir is chosen deliberately: both the MCP (knows `project_path`) and the
app (reads via `ResourceDirectory`) know it, with no sandbox-hash guessing. Only a
`seq` greater than the last handled one acts, so a launch picks up a pending command
exactly once and later reruns fire on each bump. Absent a command file, the app runs
`config.testScript` as before (fully backward compatible). Results carry the `seq`,
so the driver can correlate a result with the run it requested.

---

## Integration tiers (progressive adoption)

| Tier | Game changes | Unlocks |
|------|--------------|---------|
| **0 — Zero integration** | none | coordinate tap/drag, screenshots, frame waits, log capture, display-tree inspection, `expectNoErrors` |
| **1 — Automatic introspection** | none | `findByText`/`findByRole` via display-tree walk, inferred targets |
| **2 — Semantic instrumentation** | `tag(obj,{id,role,name})` on meaningful objects | durable `findById`, self-healing replay |
| **3 — Game-state integration** | register `state`/fixtures/helpers/events | `expectState`, fixtures, probes without screenshots |
| **4 — Deterministic runtime** | centralize RNG + time + stepping | fixed seeds, virtual clock, frame stepping, sim hashes *(built later — see build plan)* |

Locator priority (self-healing order): `id` → `role+name` → `text` →
inferred object → coordinates.

---

## Public API

### Framework (module-level)

`bootstrap(opts)` · `configure(opts)` · `tag(object, meta)` · `register(id, object, meta)` ·
`extend(fn)` · `useSceneAdapter(adapter)` · `registerFixtureLoader(name, fn)` ·
`registerCleanup(fn)`

### Test context (`t`)

`tap(x,y)` · `drag(x1,y1,x2,y2,frames)` · `waitFrames(n)` · `waitUntil(pred,opts)` ·
`findById(id)` · `findByRole(role,name)` · `findByText(text)` · `expect(v,label)` ·
`expectState(path)` · `expectNoErrors()` · `eventually(fn,opts)` ·
`loadFixture(name)` · `loadSave(path)` · `screenshot(name)` · `report(tbl)` ·
`setSeed(n)` · `getState(path)` · `control(name)`

Locators are **lazy**: `findById("x")` returns an element handle that resolves
(and briefly retries) at **action time** (`:tap()`, `:dragTo()`, `:expect()`), so
tests aren't flaky against objects that register a frame or two late.

---

## Test shape

```lua
-- tests/generated/current_test.lua
return function(t)
    t:findById("main-menu.start"):tap()
    t:waitForScene("gameplay")

    t:findById("inventory.laser_t2")
        :dragTo(t:findById("ship.slot.2"))

    t:expectState("ship.powerUsed"):toEqual(13)
    t:expectNoErrors()
end
```

A test module returns either a `function(t)` or a table
`{ name, fixture, seed, run = function(t) … end }`.

---

## Determinism & replay (Phases 2–4)

Every run captures **save reference · random seed · game version · platform**.
Randomness flows through **one RNG abstraction** (`solar_scope.rng`) so a seed
reproduces a run. This is the seam Phase 4 later extends into a virtual clock and
frame stepping.

**Replay bundle** (`.sscope`, renamed from `.stkrepro`):

```text
player-8421.sscope/
├── manifest.json      # schemaVersion, gameVersion, platform, device, seed
├── save.dat
├── interactions.json  # compact semantic log (self-healing)
├── screenshots/
└── diagnostics/
```

**Self-healing interaction log** records semantic targets with coordinate
fallback, so replays survive layout changes:

```jsonc
{ "action": "tap", "timestamp": 4125,
  "target": { "id": "inventory.laser_t2", "role": "item", "name": "Laser II",
              "fallback": { "x": 534, "y": 287 } } }
```

Resolution order on replay: `id` → `role+name` → `text` → coordinates.

**Pipeline:** player save + seed + interaction log + version → replay → AI
investigates → generate Lua test → engineer fixes → promote to regression suite.
Recordings and regression tests stay **separate**: logs stay tiny, generated Lua
stays readable.

---

## Deviations from the original proposal

These are the corrections baked into this architecture (rationale in the build plan):

1. **Renamed** `solar_testkit` → `solar_scope`; `.stkrepro` → `.sscope`.
2. **Input simulation is hit-tested, not stage-dispatched.** The proposal's
   `tap()` dispatched a synthetic touch to `display.getCurrentStage()`, which only
   fires listeners on the stage itself and does **not** route to the object under
   `(x,y)`. SolarScope walks the display tree to find the topmost object whose
   `contentBounds` contain the point and dispatches to it (handling both `touch`
   and `tap` listener types, and parent bubbling).
3. **Result transport is specified**: JSON to `DocumentsDirectory` + a console
   sentinel line (the original said "return structured result" with no transport).
4. **Locators are lazy/auto-waiting** rather than eager `nil`-returning, matching
   Playwright semantics and removing a timing footgun.
5. **State assertions auto-retry** by default; `getState(path)` dotted-path
   resolver is a defined core primitive (it was referenced but undefined).
6. **Runner has a watchdog**: a wall-clock deadline guards against a test that
   loops without yielding and hangs the simulator.
7. **`expectNoErrors` has a defined capture mechanism**: an
   `unhandledError` Runtime listener installed at `bootstrap`.
8. **No new MCP server**: reuse the existing `solar2d` MCP + files on disk; added
   only three thin tools (`run_solar_scope_test`, `rerun_solar_scope_test`,
   `get_solar_scope_result`) plus a project-dir command file for hot-reload.

---

## Suggested project layout

```text
solar-scope/
├── docs/                         # this doc + build plan
├── solar_scope.lua               # the framework's public entry (require("solar_scope"))
├── solar_scope/                  # the framework internals (reusable, drop-in)
│   ├── core/
│   │   ├── runner.lua            # coroutine runner + watchdog
│   │   ├── context.lua           # the `t` object
│   │   ├── assertions.lua        # retrying + immediate assertions
│   │   ├── locators.lua          # lazy element handles
│   │   ├── display_tree.lua      # walk + hit-test
│   │   ├── registry.lua          # semantic tag registry (weak refs)
│   │   ├── reporter.lua          # structured result → disk + sentinel
│   │   ├── errors.lua            # unhandledError capture
│   │   ├── rng.lua               # RNG abstraction (Phase 2, Phase-4 seam)
│   │   ├── recorder.lua          # self-healing interaction recording (Phase 3)
│   │   ├── replay.lua            # log resolution + replay (Phase 3)
│   │   └── trace.lua             # trace artifacts (Phase 3)
│   ├── adapters/
│   │   └── composer.lua          # Composer scene adapter (reference)
│   └── fixtures.lua              # fixture-loader registry
├── harness/                      # the minimal validation game (Composer)
│   ├── main.lua
│   ├── config.lua
│   ├── build.settings
│   ├── solar-scope.config.lua
│   ├── scenes/
│   ├── game/                     # game state, rng usage, save system, test_support
│   ├── tests/
│   │   ├── generated/current_test.lua
│   │   ├── regression/
│   │   ├── probes/
│   │   └── fixtures/
│   └── repros/
└── tools/                        # host-side helpers (translate log→Lua, bundle IO)
```

The framework (`solar_scope/`) is drop-in and game-agnostic. The `harness/` is the
throwaway game we validate against — a **minimal match-3 color game** (a 6×6 grid
of colored tiles; drag a tile onto an adjacent tile to swap; runs of 3+ clear,
cascade, and score). Its seeded, RNG-driven board doubles as the target for the
determinism work in Phases 2–4. The API examples above (ship builder, inventory
slots) are generic illustrations of the framework, not the harness.

> **Packaging note (learned during Phase 0):** Solar2D's `package.path` does **not**
> include `?/init.lua`, so `require("solar_scope")` will not resolve a folder. The
> public entry is therefore a top-level file `solar_scope.lua` sitting beside the
> `solar_scope/` folder. Dropping SolarScope into a game means copying **both** the
> `solar_scope.lua` file and the `solar_scope/` folder. The harness gets them via two
> symlinks (`harness/solar_scope.lua`, `harness/solar_scope`).
>
> **Result transport works; log scraping is unreliable.** In this environment the
> MCP's `read_solar2d_logs` truncated output, so validation reads the result JSON
> directly from the sandbox `Documents/solar_scope/` — which is exactly why the
> file-on-disk transport (not console-only) was the right call.
