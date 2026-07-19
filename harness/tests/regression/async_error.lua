-- RED test (expected to FAIL): schedules an error in a timer callback (outside
-- SolarScope's synchronous dispatch) to validate the Runtime "unhandledError"
-- listener path feeding expectNoErrors().
return {
    name = "async error capture (intentionally failing)",
    run = function(t)
        timer.performWithDelay(30, function()
            error("async boom from timer")
        end)
        t:waitFrames(20) -- ~330ms, well past the 30ms delay
        t:expectNoErrors()
    end,
}
