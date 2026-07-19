-- Phase 3: record an interaction, write/reload a .sscope bundle, replay it to
-- reproduce the same end state, and translate the log into Lua.
local boards = require("tests.support.known_boards")
local translate = require("tools.translate")
local Recorder = require("solar_scope.core.recorder")

return {
    name = "record, bundle, replay, translate",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        local Board = require("game.board")

        -- Record a drag from a known, seeded state.
        t:setSeed(777)
        Board:setGrid(boards.col3_swap)
        t:startRecording({ seed = 777 })
        t:findById("tile.r3.c3"):dragTo(t:findById("tile.r3.c4"))
        local log = t:stopRecording()
        local recordedScore = Board:snapshot().score

        t:expect(#log.actions, "recorded actions"):toEqual(1)
        t:expect(log.actions[1].source.id, "recorded source id"):toEqual("tile.r3.c3")

        -- Write + reload the bundle (compact round-trip).
        t:writeBundle("demo", log)
        local reloaded, manifest = t:loadBundle("demo")
        t:expect(manifest.seed, "manifest seed"):toEqual(777)
        t:expect(reloaded.actions[1].target.id, "reloaded target id"):toEqual("tile.r3.c4")

        -- Replay reproduces the same end state.
        t:setSeed(777)
        Board:setGrid(boards.col3_swap)
        t:replay(reloaded)
        t:expect(Board:snapshot().score, "replayed score"):toEqual(recordedScore)

        -- Translate the compact log into Lua.
        local lua = translate.translate(Recorder.toCompact(reloaded), { name = "demo regression" })
        local hasDrag = lua:find('t:findById("tile.r3.c3"):dragTo(t:findById("tile.r3.c4"))', 1, true) ~= nil
        t:expect(hasDrag, "translation contains dragTo"):toBeTrue()

        -- Trace snapshot artifact.
        t:trace("demo")

        t:expectNoErrors()
    end,
}
