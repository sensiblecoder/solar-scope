# SolarScope — Build Plan (Phases 0–4)

Each phase ends in something **runnable and validated against the harness game**
via the existing `solar2d` MCP. No big-bang. Phases 0–3 are built autonomously;
**Phase 4 is a hard pause** for user review, but 0–3 are designed with Phase 4's
determinism goals in mind (RNG indirection, clock seams).

Legend: 🎯 deliverable · ✅ validation gate.

---

## Phase 0 — Foundations

Prove the app can run a hot-reloadable Lua test and emit a machine-readable result.

🎯 Build:
- Project skeleton (`solar_scope/`, `harness/`) per the architecture layout.
- `solar_scope.init` exposing `bootstrap`/`configure`.
- **Coroutine runner** (`core/runner.lua`) on `enterFrame`, resuming one step per
  frame, with a **watchdog**: a wall-clock deadline (default from config `timeout`)
  that fails the run instead of hanging the simulator if the test never yields or
  never completes.
- Hot reload of the autorun test module (`package.loaded[name] = nil`).
- `core/reporter.lua`: write result JSON to
  `DocumentsDirectory/solar_scope/result.latest.json` (+ timestamped copy) and
  print the `###SOLAR_SCOPE_RESULT###` sentinel line.
- Minimal `harness/` that boots SolarScope in test mode and autoruns a trivial
  test that just passes.

✅ Gate: launch harness via MCP, read logs, confirm the sentinel line and a
`{"status":"pass"}` file on disk. Flip the test to fail; confirm `{"status":"fail"}`
with a message.

Phase-4 note: the runner already centralizes "advance one step per frame" — the
seam a virtual clock later hooks.

---

## Phase 1 — Core interaction & assertions (the real proof)

Prove SolarScope can drive real UI and assert on it. This is where the
architecture is validated or disproven.

🎯 Build:
- `core/display_tree.lua`: recursive walk + **hit-test** (topmost object whose
  `contentBounds` contain a point; respects visibility/alpha).
- `core/context.lua` input: `tap(x,y)`/`drag(...)` that **hit-test and dispatch to
  the real target object** (both `touch` and `tap` listener types + parent
  bubbling). Fixes the proposal's stage-dispatch bug.
- `waitFrames`, `waitUntil` (coroutine yields).
- `core/locators.lua`: **lazy** element handles from `findById`/`findByText`/
  `findByRole`; resolve + short auto-wait at action time; `:tap()`, `:dragTo()`.
- `core/assertions.lua`: `expect(v,label)` immediate + `expectState`/`eventually`
  auto-retrying; `getState(path)` dotted-path resolver.
- `core/errors.lua`: install `Runtime:addEventListener("unhandledError", …)` at
  bootstrap; `expectNoErrors()` checks the collected list.
- Screenshot-on-failure hook (via reporter; actual capture through MCP artifact).
- `adapters/composer.lua` + `useSceneAdapter`; `waitForScene`.
- **Harness game** — a minimal **match-3 color game** (Composer): a menu scene
  with a "Start" button, a 6×6 grid of tagged color cells, drag-a-tile-onto-an-
  adjacent-tile to swap (a swap forming a run of 3+ clears/cascades and scores;
  otherwise it reverts), a seeded board, and a **BOOM** error button. The board
  exposes `setGrid` as a test hook for deterministic swaps.
- Tests committed under `tests/`: green E2E (`current_test`), `match_clears`,
  `invalid_swap` (no-op), plus red tests `score_mismatch`, `error_detection`,
  `async_error`.

✅ Gate: MCP-run the green test → pass file; the red test → fail file with a useful
message and a failure screenshot reference. `findByText("Start")` taps the real
button and triggers the transition.

---

## Phase 2 — Fixtures, state & determinism hooks

Make tests state-driven and lay the determinism groundwork.

🎯 Build:
- `fixtures.lua`: `registerFixtureLoader`, `loadFixture(name)`, `loadSave(path)`.
- Harness `game/state.lua` with structured **state readers** wired via
  `configure{ state = … }`; richer `expectState` paths.
- Harness `game/save.lua`: tiny serialize/apply (`SaveSystem.read/apply`) + a
  couple of `.save` fixtures under `tests/fixtures` / `repros/`.
- `core/rng.lua`: **RNG abstraction** all harness randomness flows through;
  `t:setSeed(n)` seeds it. (This is the Phase-4 seam — keep the interface small and
  swappable for a deterministic source.)
- `core/registry.lua` + `tag()`: semantic instrumentation on harness objects
  (Tier 2). Durable `findById`.

✅ Gate: a test that `loadFixture`/`loadSave`s a known state, asserts
`expectState`, sets a seed and observes a reproducible RNG-driven outcome across
two runs.

Phase-4 note: RNG is the first determinism source. Do **not** yet intercept
`system.getTimer`/`timer.*`/`transition.*` — that's Phase 4 — but keep any
time reads funnelled through a single helper so Phase 4 has one place to hook.

---

## Phase 3 — Recording & replay

Turn interactions into artifacts and regression tests.

🎯 Build:
- `core/recorder.lua`: **self-healing interaction recording** — capture semantic
  target (`id`/`role`/`name`) with coordinate `fallback` for taps/drags/controls.
- Compact on-disk log format (array-of-arrays) + expansion.
- `core/replay.lua`: resolution order `id → role+name → text → coordinates`;
  replay a log against the game.
- `.sscope` **replay bundle** read/write (manifest + save + interactions +
  screenshots/diagnostics dirs).
- `tools/translate.lua` (host-side): interaction log → readable Lua test.
- **Probe scripts**: `type="probe"` modules that `report()` structured diagnostics
  instead of pass/fail.
- `core/trace.lua`: trace artifact bundle (screenshots, logs, display tree, state,
  event timeline, interaction log, seed, save ref, diagnostics).

✅ Gate: record a short interaction in the harness → produce a `.sscope` bundle →
replay it reproducing the same end state → translate the log into a Lua regression
test that passes. A probe returns structured before/after diagnostics.

---

## Phase 4 — Deterministic runtime  ⛔ PAUSE FOR USER

**Not built during the autonomous run.** Documented here so 0–3 leave the right seams.

Scope (high-effort, invasive):
- Fixed RNG seeds end-to-end (extends Phase 2's `rng.lua`).
- **Virtual clock**: intercept `system.getTimer`, drive `timer.*` and
  `transition.*` from a controllable clock.
- Frame stepping: `pauseClock`, `advanceFrames`, `advanceMilliseconds`.
- Deterministic timers; simulation hashes; multiplayer convergence.

Why paused: intercepting Solar2D's time/timer/transition subsystems is
substantially more invasive than everything in 0–3 and deserves explicit review of
approach and risk before we touch it. The seams from Phases 0–2 (single-step
runner, single RNG source, funnelled time reads) are what make it tractable later.

---

## Cross-cutting conventions

- **Namespace:** module `solar_scope`; tag fields `testId`/`testRole`/`testName`;
  bundle extension `.sscope`; result sentinel `###SOLAR_SCOPE_RESULT###`.
- **Test-mode gating:** the harness only boots SolarScope when
  `config.testMode`/`solar-scope.config.lua` says so, so shipping games stay clean.
- **Validation is real:** every phase gate is exercised by launching the harness
  through the `solar2d` MCP and reading the result file — not just by reasoning.
