-- SolarScope — public entry point.
-- Drop-in "Playwright for Solar2D": hot-reloadable Lua tests that run inside the game.
--
-- Usage (harness/main.lua):
--   local scope = require("solar_scope")
--   scope.bootstrap({ autorun = "tests.generated.current_test", config = { ... } })

local Runner = require("solar_scope.core.runner")
local Errors = require("solar_scope.core.errors")
local Registry = require("solar_scope.core.registry")
local Fixtures = require("solar_scope.fixtures")
local Rng = require("solar_scope.core.rng")
local Commands = require("solar_scope.core.commands")

local M = {
    _VERSION = "0.1.0",
    -- Defaults. `timeout` is the per-assertion wait budget; `locatorTimeout` is
    -- the lazy-locator auto-wait; `watchdog` is the global wall-clock backstop;
    -- `instructionBudget` bounds a single non-yielding resume.
    _config = {
        timeout = 5000,
        locatorTimeout = 2000,
        watchdog = 30000,
        instructionBudget = 20000000,
    },
}

-- Resolve a scene adapter given as a module path string.
local function resolveAdapter(adapter)
    if type(adapter) == "string" then
        return require(adapter)
    end
    return adapter
end

-- Merge caller config over defaults.
function M.configure(opts)
    if type(opts) == "table" then
        for k, v in pairs(opts) do
            M._config[k] = v
        end
    end
    if M._config.sceneAdapter then
        M._config.sceneAdapter = resolveAdapter(M._config.sceneAdapter)
    end
    Runner.setConfig(M._config)
    return M
end

function M.useSceneAdapter(adapter)
    M._config.sceneAdapter = resolveAdapter(adapter)
    Runner.setConfig(M._config)
    return M
end

-- Semantic tagging (Tier 2). A tagged id goes into the weak-ref registry for
-- durable O(1) findById; role/name are also set as fields for tree-scan locators.
function M.tag(object, meta)
    meta = meta or {}
    if meta.role then object.testRole = meta.role end
    if meta.name then object.testName = meta.name end
    if meta.id then
        Registry.register(meta.id, object, meta)
    end
    return object
end

function M.register(id, object, meta)
    return Registry.register(id, object, meta)
end

-- Register a named fixture loader (Tier 3).
function M.registerFixtureLoader(name, fn)
    Fixtures.register(name, fn)
    return M
end

-- Seed the shared RNG abstraction (Tier 4 seam). Games route randomness through
-- `scope.rng` so a seed reproduces a run.
function M.setSeed(n)
    Rng.seed(n)
    return M
end

M.rng = Rng
M.registry = Registry

-- Boot the runtime. In a real game this is gated behind config.testMode so
-- shipping builds stay clean.
function M.bootstrap(opts)
    opts = opts or {}
    Errors.install()
    if opts.config then
        M.configure(opts.config)
    else
        Runner.setConfig(M._config)
    end

    -- Start the command channel (hot-reload) unless disabled. Its boot poll may
    -- pick up a pending command; if so, skip the normal autorun.
    local ranBootCommand = false
    if M._config.commandChannel ~= false then
        ranBootCommand = Commands.start({
            path = M._config.commandFile,
            pollMs = M._config.commandPollMs,
        })
    end

    if opts.autorun and not ranBootCommand then
        Runner.run(opts.autorun)
    end
    return M
end

M.commands = Commands

-- Manually (re)run a test module by name. Handy for MCP-driven reruns.
function M.run(moduleName)
    Runner.run(moduleName)
    return M
end

return M
