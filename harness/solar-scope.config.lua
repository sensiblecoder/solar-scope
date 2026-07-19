-- SolarScope configuration for the harness game.
-- An empty/absent config must still allow Tier 0 features; everything here is
-- optional and grows across phases.

return {
    -- Boot the SolarScope runtime (also enables the MCP hot-reload command
    -- channel). A shipping game would gate this behind its own debug flag.
    testMode = true,

    -- Module to autorun on launch. nil (default) means "just show the game" so
    -- the harness is immediately playable by a human; drive tests via the MCP
    -- tools (run_solar_scope_test / rerun_solar_scope_test) instead. Set this to
    -- a module string to autorun a test on every plain launch.
    autorun = nil,

    -- Timeouts.
    timeout = 5000,        -- per-assertion wait budget
    locatorTimeout = 2000, -- lazy-locator auto-wait
    watchdog = 30000,      -- global wall-clock backstop

    -- Scene adapter (Composer). Resolved from this module path by SolarScope.
    sceneAdapter = "solar_scope.adapters.composer",

    -- Structured state reader (Tier 3). Dotted paths in expectState resolve here.
    state = function()
        return require("game.board"):snapshot()
    end,

    -- Named game controls (Tier 3), invokable and recordable via t:control(...).
    controls = {
        swap_demo = function()
            require("game.board"):trySwap(3, 3, 3, 4)
        end,
    },
}
