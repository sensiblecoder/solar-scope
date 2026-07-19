-- Match-3 gameplay scene: a 6x6 grid of color cells, drag a cell onto an
-- adjacent cell to swap. Cells are fixed, tagged objects ("tile.r{r}.c{c}");
-- only their color changes. A BOOM button provides an error path.
local composer = require("composer")
local scope = require("solar_scope")
local Board = require("game.board")

local scene = composer.newScene()

local PALETTE = {
    { 0.90, 0.30, 0.30 }, -- 1 red
    { 0.30, 0.80, 0.45 }, -- 2 green
    { 0.35, 0.55, 0.95 }, -- 3 blue
    { 0.95, 0.85, 0.30 }, -- 4 yellow
}

local ORIGIN_X = 36
local ORIGIN_Y = 250
local PITCH = 108
local CELL = 96

local function colToX(c) return ORIGIN_X + (c - 0.5) * PITCH end
local function rowToY(r) return ORIGIN_Y + (r - 0.5) * PITCH end
local function xToCol(x) return math.floor((x - ORIGIN_X) / PITCH) + 1 end
local function yToRow(y) return math.floor((y - ORIGIN_Y) / PITCH) + 1 end

function scene:create(event)
    local group = self.view

    local bg = display.newRect(group, display.contentCenterX, display.contentCenterY,
        display.contentWidth, display.contentHeight)
    bg:setFillColor(0.08, 0.10, 0.13)

    display.newText({ parent = group, text = "Color Match", x = display.contentCenterX, y = 90, fontSize = 30 })
    local scoreText = display.newText({ parent = group, text = "Score: 0   Moves: 0",
        x = display.contentCenterX, y = 160, fontSize = 22 })

    local cells = {}

    local function repaint()
        local snap = Board:snapshot()
        scoreText.text = "Score: " .. snap.score .. "   Moves: " .. snap.moves
        for r = 1, Board.ROWS do
            for c = 1, Board.COLS do
                local color = PALETTE[snap.grid[r][c]] or { 0.2, 0.2, 0.2 }
                cells[r][c]:setFillColor(color[1], color[2], color[3])
            end
        end
    end

    local function onCellTouch(evt)
        local cell = evt.target
        if evt.phase == "began" then
            display.getCurrentStage():setFocus(cell)
            cell.isFocus = true
        elseif (evt.phase == "ended" or evt.phase == "cancelled") and cell.isFocus then
            display.getCurrentStage():setFocus(nil)
            cell.isFocus = false
            local tr = yToRow(evt.y)
            local tc = xToCol(evt.x)
            if tr >= 1 and tr <= Board.ROWS and tc >= 1 and tc <= Board.COLS
                and Board:adjacent(cell.row, cell.col, tr, tc) then
                Board:trySwap(cell.row, cell.col, tr, tc)
            end
        end
        return true
    end

    for r = 1, Board.ROWS do
        cells[r] = {}
        for c = 1, Board.COLS do
            local cell = display.newRoundedRect(group, colToX(c), rowToY(r), CELL, CELL, 10)
            cell.row, cell.col = r, c
            scope.tag(cell, { id = "tile.r" .. r .. ".c" .. c, role = "tile", name = "tile " .. r .. "," .. c })
            cell:addEventListener("touch", onCellTouch)
            cells[r][c] = cell
        end
    end

    Board.onChange = repaint
    repaint()

    -- Error path.
    local boom = display.newRoundedRect(group, display.contentCenterX, display.contentHeight - 70, 170, 46, 8)
    boom:setFillColor(0.60, 0.20, 0.20)
    display.newText({ parent = group, text = "BOOM", x = display.contentCenterX, y = display.contentHeight - 70, fontSize = 18 })
    scope.tag(boom, { id = "debug.boom", role = "button", name = "Boom" })
    boom:addEventListener("tap", function()
        error("boom button handler exploded")
    end)
end

function scene:hide(event)
    if event.phase == "will" then
        Board.onChange = nil
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("hide", scene)
return scene
