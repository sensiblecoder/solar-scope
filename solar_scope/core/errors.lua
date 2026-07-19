-- SolarScope runtime-error capture.
--
-- Two sources feed one buffer:
--   1. Runtime "unhandledError" — async errors from timers/transitions/frame
--      listeners that would otherwise pop the simulator error dialog.
--   2. Errors.record(...) — errors caught while SolarScope synthetically
--      dispatches input (see context dispatchChain), so a broken tap/touch
--      handler is captured instead of crashing the test coroutine.
--
-- `expectNoErrors()` inspects this buffer. The runner resets it per test.

local Errors = {
    collected = {},
    installed = false,
}

function Errors.record(message, traceback)
    Errors.collected[#Errors.collected + 1] = {
        message = tostring(message),
        traceback = traceback,
    }
end

function Errors.install()
    if Errors.installed then
        return
    end
    Errors.installed = true
    Runtime:addEventListener("unhandledError", function(event)
        Errors.record(event.errorMessage or "unknown error", event.stackTrace)
        return true -- handled: keep the simulator running headlessly
    end)
end

function Errors.reset()
    Errors.collected = {}
end

return Errors
