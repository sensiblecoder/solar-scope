-- Phase 3 probe: returns structured before/after diagnostics rather than
-- pass/fail. The runner captures the report() payload in the result.
local boards = require("tests.support.known_boards")

return {
    type = "probe",
    name = "inspect swap",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        local Board = require("game.board")
        t:setSeed(777)
        Board:setGrid(boards.col3_swap)

        local before = Board:snapshot()
        Board:trySwap(3, 3, 3, 4)
        local after = Board:snapshot()

        t:report({
            kind = "swap-inspection",
            swap = { "r3.c3", "r3.c4" },
            before = { score = before.score, moves = before.moves },
            after = { score = after.score, moves = after.moves },
            delta = after.score - before.score,
        })
    end,
}
