-- Harness game state exposed to the SolarScope state reader.
-- Delegates to the match-3 board so expectState paths like "score" / "moves"
-- resolve against live game state.
local Board = require("game.board")

local State = {}

function State.reset()
    Board:reset(Board.DEFAULT_SEED)
end

function State.snapshot()
    return Board:snapshot()
end

return State
