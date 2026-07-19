-- Phase 1 green E2E: menu -> start -> swap two tiles to make a match -> assert.
local boards = require("tests.support.known_boards")

return function(t)
    t:findByText("Start Game"):tap()
    t:waitForScene("scenes.game")

    -- Install a known board so the swap outcome is deterministic.
    require("game.board"):setGrid(boards.col3_swap)

    t:findById("tile.r3.c3")
        :dragTo(t:findById("tile.r3.c4"))

    t:expectState("moves"):toEqual(1)
    t:expectState("score"):toBeGreaterThan(0)
    t:expectNoErrors()
end
