-- Promoted regression: a matching swap increments moves and score.
local boards = require("tests.support.known_boards")

return {
    name = "match clears: valid swap scores",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        require("game.board"):setGrid(boards.col3_swap)

        t:findById("tile.r3.c3")
            :dragTo(t:findById("tile.r3.c4"))

        t:expectState("moves"):toEqual(1)
        t:expectState("score"):toBeGreaterThan(0)
        t:expectNoErrors()
    end,
}
