-- SolarScope coroutine runner.
-- Runs a test module as a coroutine on Solar2D's enterFrame loop so tests can
-- await across frames. Includes a wall-clock watchdog so a test that loops
-- without yielding (or never completes) fails cleanly instead of hanging the
-- simulator.
--
-- Phase-4 seam: onEnterFrame is the single place that "advances one step per
-- frame". A future virtual clock hooks here.

local Context = require("solar_scope.core.context")
local Reporter = require("solar_scope.core.reporter")
local Errors = require("solar_scope.core.errors")

local Runner = {
    active = nil,     -- the running coroutine
    context = nil,    -- current Context
    config = {},
    moduleName = nil,
    startTime = 0,
    finished = false,
    entered = false,  -- beforeRun fired and afterRun is still owed
}

local function reloadModule(name)
    package.loaded[name] = nil
    return require(name)
end

function Runner.setConfig(config)
    Runner.config = config or {}
end

-- Optional config hooks around every run: beforeRun() as a run starts,
-- afterRun() once it finalizes or is stopped. The game uses them to
-- switch on test-only settings for the run and put them back after, so
-- a simulator left running after a test plays by its normal rules. A
-- hook that throws is reported and skipped; it never fails the run.
local function callHook(name)
    local fn = Runner.config[name]
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn)
    if not ok then print("SolarScope: " .. name .. " failed: " .. tostring(err)) end
end

local function enter()
    if Runner.entered then return end
    Runner.entered = true
    callHook("beforeRun")
end

local function leave()
    if not Runner.entered then return end
    Runner.entered = false
    callHook("afterRun")
end

-- Resolve the callable test function from whatever the module returned:
--   function(t)                -> the function
--   { run = function(t) end }  -> .run  (also carries name/fixture/seed metadata)
local function resolveTest(def)
    if type(def) == "function" then
        return def, nil
    elseif type(def) == "table" then
        return (def.run or def[1]), def
    end
    return nil, nil
end

function Runner.run(moduleName, meta)
    Runner.stop()
    Runner.moduleName = moduleName
    Runner.finished = false
    Runner.startTime = system.getTimer()
    Errors.reset()
    enter()

    local ok, def = pcall(reloadModule, moduleName)
    local ctx = Context.new(Runner.config)
    ctx.name = moduleName
    ctx.seq = meta and meta.seq
    Runner.context = ctx

    if not ok then
        ctx:fail("Failed to load test '" .. moduleName .. "': " .. tostring(def))
        Runner.finalize()
        return
    end

    local testFn, meta = resolveTest(def)
    if meta and meta.name then
        ctx.name = meta.name
    end
    ctx.meta = meta

    if type(testFn) ~= "function" then
        ctx:fail("Test module '" .. moduleName .. "' did not return a function or {run=...}")
        Runner.finalize()
        return
    end

    Runner.active = coroutine.create(function()
        testFn(ctx)
        ctx:pass()
    end)

    -- Instruction-count watchdog: the wall-clock check in onEnterFrame runs
    -- *before* resume, so it cannot interrupt a test stuck in a non-yielding
    -- loop (that resume never returns). This debug hook fires from inside the
    -- coroutine after N VM instructions without yielding, turning an infinite
    -- loop into a clean failure. Legit code yields long before this.
    local budget = Runner.config.instructionBudget or 20000000
    debug.sethook(Runner.active, function()
        error("Test ran " .. budget .. " instructions without yielding (instruction watchdog)", 2)
    end, "", budget)
end

function Runner.finalize()
    if Runner.finished then
        return
    end
    Runner.finished = true

    local ctx = Runner.context
    if ctx and ctx.status == "running" then
        ctx:pass()
    end

    -- Capture a screenshot on failure before tearing down.
    if ctx and ctx.status == "fail" then
        pcall(function() ctx:screenshot("failure") end)
    end

    local result = ctx and ctx:result() or { status = "fail", message = "no test context" }

    if ctx then
        pcall(function() ctx:cleanup() end)
    end

    Reporter.write(result)
    Runner.active = nil
    leave()
end

function Runner.onEnterFrame()
    if not Runner.active or Runner.finished then
        return
    end

    local ctx = Runner.context

    -- Watchdog: global wall-clock backstop.
    local watchdog = Runner.config.watchdog or 30000
    if system.getTimer() - Runner.startTime > watchdog then
        ctx:fail("Test exceeded watchdog limit of " .. watchdog .. "ms")
        Runner.finalize()
        return
    end

    if coroutine.status(Runner.active) == "dead" then
        Runner.finalize()
        return
    end

    local ok, err = coroutine.resume(Runner.active)
    if not ok then
        ctx:fail(err)
        Runner.finalize()
        return
    end

    if coroutine.status(Runner.active) == "dead" then
        Runner.finalize()
    end
end

function Runner.stop()
    if Runner.context and not Runner.finished then
        pcall(function() Runner.context:cleanup() end)
    end
    Runner.active = nil
    Runner.context = nil
    Runner.finished = false
    leave()
end

Runtime:addEventListener("enterFrame", Runner.onEnterFrame)

return Runner
