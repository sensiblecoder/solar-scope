-- Fixture loading: loadFixture installs a known board + preset score/moves,
-- and a subsequent valid swap advances state from there.
return {
    name = "load mid_game fixture and continue",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        t:loadFixture("mid_game")

        t:expectState("score"):toEqual(40)
        t:expectState("moves"):toEqual(5)

        t:findById("tile.r3.c3")
            :dragTo(t:findById("tile.r3.c4"))

        t:expectState("moves"):toEqual(6)
        t:expectState("score"):toBeGreaterThan(40)
        t:expectNoErrors()
    end,
}
