-- RED test (expected to FAIL): taps the BOOM button whose handler raises, then
-- asserts no errors — validating that dispatch-time errors are captured and
-- surfaced by expectNoErrors().
return {
    name = "error detection (intentionally failing)",
    run = function(t)
        t:findByText("Start Game"):tap()
        t:waitForScene("scenes.game")

        t:findById("debug.boom"):tap()
        t:waitFrames(2)

        t:expectNoErrors() -- should fail: the boom handler exploded
    end,
}
