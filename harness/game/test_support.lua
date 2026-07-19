-- Harness test-support: registers fixture loaders with SolarScope.
-- Called once at boot: require("game.test_support")(scope)
local Board = require("game.board")
local Save = require("game.save")

return function(scope)
    -- Install an exact board (optionally preset score/moves).
    scope.registerFixtureLoader("board", function(fixture)
        local data = fixture.data or {}
        Board:setGrid(data.grid)
        if data.score then Board.score = data.score end
        if data.moves then Board.moves = data.moves end
        Board:notify()
    end)

    -- Load a save file and apply it.
    scope.registerFixtureLoader("save-file", function(fixture)
        local data = Save.read(fixture.path, fixture.baseDir)
        Save.apply(data)
    end)
end
