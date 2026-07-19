-- Determinism: the same seed + same swap yields the same board and score.
-- Drives the model directly (not the UI) since we're validating the RNG seam.
local boards = require("tests.support.known_boards")

local function checksum(snap)
    local s = 0
    for r = 1, snap.rows do
        for c = 1, snap.cols do
            s = (s * 31 + snap.grid[r][c]) % 2147483647
        end
    end
    return s
end

return {
    name = "deterministic refill from seed",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        local Board = require("game.board")

        t:setSeed(777)
        Board:setGrid(boards.col3_swap)
        Board:trySwap(3, 3, 3, 4)
        local a = Board:snapshot()

        t:setSeed(777)
        Board:setGrid(boards.col3_swap)
        Board:trySwap(3, 3, 3, 4)
        local b = Board:snapshot()

        t:expect(b.score, "score (run 2)"):toEqual(a.score)
        t:expect(checksum(b), "board checksum (run 2)"):toEqual(checksum(a))
        t:expectNoErrors()
    end,
}
