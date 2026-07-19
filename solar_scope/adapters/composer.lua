-- SolarScope scene adapter for Composer. The core never requires Composer; a
-- game opts in via configure{ sceneAdapter = "solar_scope.adapters.composer" }.

local composer = require("composer")

return {
    getCurrentScene = function()
        return composer.getSceneName("current")
    end,

    gotoScene = function(name, options)
        composer.gotoScene(name, options)
    end,

    restartScene = function()
        local current = composer.getSceneName("current")
        if current then
            composer.removeScene(current)
            composer.gotoScene(current)
        end
    end,

    isTransitioning = function()
        -- Composer doesn't expose this directly; waitForScene polling covers it.
        return false
    end,
}
