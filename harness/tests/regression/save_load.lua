-- Save loading: loadSave restores score/moves/seed/grid from a bundled save.
return {
    name = "load sample save",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        t:loadSave("repros/sample.save")

        t:expectState("score"):toEqual(12)
        t:expectState("moves"):toEqual(2)
        t:expectNoErrors()
    end,
}
