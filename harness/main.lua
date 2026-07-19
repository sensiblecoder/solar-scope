-- SolarScope validation harness — entry point.
-- Boots the game (menu scene), then in test mode boots the SolarScope runtime.

-- The config filename contains a dot, so load it by path rather than require().
local function loadConfig()
    local path = system.pathForFile("solar-scope.config.lua", system.ResourceDirectory)
    if not path then
        return {}
    end
    local chunk = loadfile(path)
    if not chunk then
        return {}
    end
    return chunk() or {}
end

local config = loadConfig()

-- Start the game — the app under test.
-- (The solar2d MCP injects _mcp_* helper requires here at runtime; those files
-- are gitignored and re-created on each MCP launch.)
local composer = require("composer")
require("game.state").reset()
composer.gotoScene("scenes.menu")

if config.testMode then
    local scope = require("solar_scope")
    require("game.test_support")(scope) -- register fixture loaders before autorun
    scope.bootstrap({
        autorun = config.testScript,
        config = config,
    })
end
