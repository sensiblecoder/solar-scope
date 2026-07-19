-- Menu scene: a title and a tagged Start button that transitions to the game.
local composer = require("composer")
local scope = require("solar_scope")

local scene = composer.newScene()

function scene:create(event)
    local group = self.view

    local bg = display.newRect(group, display.contentCenterX, display.contentCenterY,
        display.contentWidth, display.contentHeight)
    bg:setFillColor(0.10, 0.12, 0.16)

    display.newText({
        parent = group, text = "SolarScope Harness",
        x = display.contentCenterX, y = 180, fontSize = 34,
    })

    -- Start button as a group (rect + label); the tap listener is on the group,
    -- the semantic tag is on the rect. Bubbling dispatch connects them.
    local btn = display.newGroup()
    group:insert(btn)

    local rect = display.newRoundedRect(btn, display.contentCenterX, display.contentCenterY, 260, 84, 14)
    rect:setFillColor(0.20, 0.50, 0.90)
    display.newText({
        parent = btn, text = "Start Game",
        x = display.contentCenterX, y = display.contentCenterY, fontSize = 26,
    })

    scope.tag(rect, { id = "main-menu.start", role = "button", name = "Start Game" })

    btn:addEventListener("tap", function()
        composer.gotoScene("scenes.game", { effect = "fade", time = 120 })
        return true
    end)
end

scene:addEventListener("create", scene)
return scene
