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

    -- Start button: the touch listener lives on the hittable rect LEAF (not a
    -- parent group), so real human input — which is delivered to the hit object,
    -- not bubbled up to groups — actually triggers it. The label has no listener,
    -- so a tap on it falls through to the rect behind.
    local rect = display.newRoundedRect(group, display.contentCenterX, display.contentCenterY, 260, 84, 14)
    rect:setFillColor(0.20, 0.50, 0.90)
    display.newText({
        parent = group, text = "Start Game",
        x = display.contentCenterX, y = display.contentCenterY, fontSize = 26,
    })

    scope.tag(rect, { id = "main-menu.start", role = "button", name = "Start Game" })

    local function withinBounds(o, x, y)
        local b = o.contentBounds
        return x >= b.xMin and x <= b.xMax and y >= b.yMin and y <= b.yMax
    end

    rect:addEventListener("touch", function(e)
        local o = e.target
        if e.phase == "began" then
            display.getCurrentStage():setFocus(o)
        elseif e.phase == "ended" or e.phase == "cancelled" then
            display.getCurrentStage():setFocus(nil)
            if e.phase == "ended" and withinBounds(o, e.x, e.y) then
                composer.gotoScene("scenes.game", { effect = "fade", time = 120 })
            end
        end
        return true
    end)
end

scene:addEventListener("create", scene)
return scene
