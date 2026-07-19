-- Phase 3: a named control is recorded and replays to the same result.
local boards = require("tests.support.known_boards")

return {
    name = "control record & replay",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        local Board = require("game.board")

        t:setSeed(777)
        Board:setGrid(boards.col3_swap)
        t:startRecording({ seed = 777 })
        t:control("swap_demo")
        local log = t:stopRecording()
        local recorded = Board:snapshot().score

        t:expect(log.actions[1].action, "action kind"):toEqual("control")
        t:expect(log.actions[1].name, "control name"):toEqual("swap_demo")

        t:setSeed(777)
        Board:setGrid(boards.col3_swap)
        t:replay(log)
        t:expect(Board:snapshot().score, "replayed score"):toEqual(recorded)
        t:expectNoErrors()
    end,
}
