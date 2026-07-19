-- Regression: a swap that forms no match is a no-op (reverts, no score/moves).
local boards = require("tests.support.known_boards")

return {
    name = "invalid swap is a no-op",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        require("game.board"):setGrid(boards.col3_swap)

        -- (1,1)=1 and (1,2)=3: swapping forms no run.
        t:findById("tile.r1.c1")
            :dragTo(t:findById("tile.r1.c2"))

        t:expectState("moves"):toEqual(0)
        t:expectState("score"):toEqual(0)
        t:expectNoErrors()
    end,
}
