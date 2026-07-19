-- Tiny save system for the match-3 board: serialize/apply board state + seed.
local Board = require("game.board")
local Rng = require("solar_scope.core.rng")
local json = require("json")

local Save = {}

function Save.serialize()
    local snap = Board:snapshot()
    return json.encode({
        score = snap.score,
        moves = snap.moves,
        seed = Rng.getSeed(),
        grid = snap.grid,
    })
end

function Save.write(path, baseDir)
    local full = system.pathForFile(path, baseDir or system.DocumentsDirectory)
    local f = assert(io.open(full, "w"))
    f:write(Save.serialize())
    f:close()
end

function Save.read(path, baseDir)
    local full = system.pathForFile(path, baseDir or system.ResourceDirectory)
    local f = full and io.open(full, "r")
    if not f then
        error("save not found: " .. tostring(path), 0)
    end
    local body = f:read("*a")
    f:close()
    return json.decode(body)
end

function Save.apply(data)
    if data.seed then
        Rng.seed(data.seed)
    end
    Board:setGrid(data.grid)      -- resets score/moves to 0
    Board.score = data.score or 0 -- then restore them
    Board.moves = data.moves or 0
    Board:notify()
end

return Save
