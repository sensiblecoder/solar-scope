-- SolarScope assertions.
--   Assertion  — immediate, one-shot checks on a captured value.
--   Eventually — auto-retrying checks that re-read a value each frame until it
--                satisfies the condition or the timeout elapses (Playwright-style).
-- Failures raise with level 0 so the message is clean (no file:line noise).

local Assertions = {}

local function fail(message)
    error(message, 0)
end

-- ---- immediate -----------------------------------------------------------

local Assertion = {}
Assertion.__index = Assertion

function Assertion.new(context, actual, label)
    return setmetatable({ context = context, actual = actual, label = label or "value" }, Assertion)
end

function Assertion:toEqual(expected)
    if self.actual ~= expected then
        fail(string.format("Expected %s to equal %s, but was %s",
            self.label, tostring(expected), tostring(self.actual)))
    end
    return self
end

function Assertion:notToBeNil()
    if self.actual == nil then
        fail("Expected " .. self.label .. " not to be nil")
    end
    return self
end

function Assertion:toBeNil()
    if self.actual ~= nil then
        fail("Expected " .. self.label .. " to be nil, but was " .. tostring(self.actual))
    end
    return self
end

function Assertion:toBeTrue()
    if self.actual ~= true then
        fail("Expected " .. self.label .. " to be true, but was " .. tostring(self.actual))
    end
    return self
end

function Assertion:toBeGreaterThan(n)
    if type(self.actual) ~= "number" or self.actual <= n then
        fail(string.format("Expected %s (%s) to be greater than %s",
            self.label, tostring(self.actual), tostring(n)))
    end
    return self
end

-- ---- retrying ------------------------------------------------------------

local Eventually = {}
Eventually.__index = Eventually

function Eventually.new(context, read, label)
    return setmetatable({ context = context, read = read, label = label or "value" }, Eventually)
end

-- Poll `predicate` each frame until true or timeout; on timeout report the last
-- observed value for a useful message.
function Eventually:_await(predicate, describe, timeout)
    timeout = timeout or self.context.config.timeout or 5000
    local deadline = system.getTimer() + timeout
    while not predicate() do
        if system.getTimer() >= deadline then
            fail(string.format("Expected %s %s, last value was %s (waited %dms)",
                self.label, describe, tostring(self.read()), timeout))
        end
        coroutine.yield("next_frame")
    end
    return self
end

function Eventually:toEqual(expected, timeout)
    return self:_await(function() return self.read() == expected end,
        "to equal " .. tostring(expected), timeout)
end
Eventually.toEventuallyEqual = Eventually.toEqual

function Eventually:toBeGreaterThan(expected, timeout)
    return self:_await(function()
        local v = self.read()
        return type(v) == "number" and v > expected
    end, "to be greater than " .. tostring(expected), timeout)
end
Eventually.toEventuallyBeGreaterThan = Eventually.toBeGreaterThan

function Eventually:notToBeNil(timeout)
    return self:_await(function() return self.read() ~= nil end, "to be non-nil", timeout)
end

function Eventually:toSatisfy(fn, timeout)
    return self:_await(function() return fn(self.read()) == true end, "to satisfy predicate", timeout)
end

Assertions.Assertion = Assertion
Assertions.Eventually = Eventually
return Assertions
