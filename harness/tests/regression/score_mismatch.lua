-- RED test (expected to FAIL): asserts a score that never occurs, to validate
-- retry-timeout messaging and screenshot-on-failure.
local boards = require("tests.support.known_boards")

return {
    name = "score mismatch (intentionally failing)",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        require("game.board"):setGrid(boards.col3_swap)

        t:findById("tile.r3.c3")
            :dragTo(t:findById("tile.r3.c4"))

        t:expectState("score"):toEqual(9999, 1500)
    end,
}
