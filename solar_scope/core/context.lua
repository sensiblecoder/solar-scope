-- SolarScope test context — the `t` object handed to every test.
-- Composes: lifecycle, frame waiting, input simulation (hit-tested + bubbling
-- dispatch), lazy locators, immediate + retrying assertions, state reads, scene
-- helpers, screenshots, and structured results.

local DisplayTree = require("solar_scope.core.display_tree")
local Assertions = require("solar_scope.core.assertions")
local Element = require("solar_scope.core.locators")
local Errors = require("solar_scope.core.errors")
local Registry = require("solar_scope.core.registry")
local Fixtures = require("solar_scope.fixtures")
local Rng = require("solar_scope.core.rng")
local Recorder = require("solar_scope.core.recorder")
local Replay = require("solar_scope.core.replay")
local Trace = require("solar_scope.core.trace")
local lfs = require("lfs")

local Context = {}
Context.__index = Context

local TOUCH_ID = "solar_scope"

function Context.new(config)
    local self = setmetatable({}, Context)
    self.config = config or {}
    self.status = "running" -- running | pass | fail
    self.message = nil
    self.name = nil
    self.assertions = {}
    self.errors = {}
    self.logs = {}
    self.reportData = nil -- probe payload (Phase 3)
    self.artifacts = {}
    self.cleanups = {}
    self.seq = nil        -- command-channel sequence that triggered this run
    self.startTime = system.getTimer()
    return self
end

-- ---- lifecycle -----------------------------------------------------------

function Context:pass()
    if self.status == "running" then
        self.status = "pass"
    end
end

function Context:fail(message)
    if self.status == "running" then
        self.status = "fail"
        self.message = tostring(message)
    end
end

function Context:log(message)
    self.logs[#self.logs + 1] = tostring(message)
    print("[solar_scope] " .. tostring(message))
end

function Context:registerCleanup(fn)
    if type(fn) == "function" then
        self.cleanups[#self.cleanups + 1] = fn
    end
end

function Context:cleanup()
    for i = #self.cleanups, 1, -1 do
        pcall(self.cleanups[i])
    end
    self.cleanups = {}
end

-- ---- frame-based waiting -------------------------------------------------

function Context:waitFrames(count)
    for _ = 1, (count or 1) do
        coroutine.yield("next_frame")
    end
end

function Context:waitUntil(predicate, options)
    options = options or {}
    local timeout = options.timeout or self.config.timeout or 5000
    local description = options.description or "condition"
    local deadline = system.getTimer() + timeout
    while not predicate() do
        if system.getTimer() >= deadline then
            error("Timed out after " .. timeout .. "ms waiting for " .. description, 0)
        end
        coroutine.yield("next_frame")
    end
end

-- ---- input simulation ----------------------------------------------------
-- Dispatch an event to a hit object, then bubble up its ancestor chain (stopping
-- below the stage) so a listener on either the object or a parent group fires.
-- Each dispatch is pcall-guarded: a throwing handler is captured as a runtime
-- error rather than crashing the test coroutine.

local function dispatchChain(hitObj, event)
    local stage = display.getCurrentStage()
    event.target = hitObj
    local node = hitObj
    while node and node ~= stage do
        local ok, err = pcall(node.dispatchEvent, node, event)
        if not ok then
            Errors.record(err)
        end
        node = node.parent
    end
end

local function centerOf(obj)
    local b = obj.contentBounds
    if b then
        return (b.xMin + b.xMax) / 2, (b.yMin + b.yMax) / 2
    end
    return obj.x, obj.y
end

-- Self-healing target descriptor for the recorder.
local function targetInfo(obj)
    local x, y = centerOf(obj)
    return {
        id = obj.testId,
        role = obj.testRole,
        name = obj.testName,
        fallback = { x = x, y = y },
    }
end

-- Emit a full tap: a touch began/ended pair AND a discrete tap event, so the
-- object reacts whether it listens for "touch" or "tap".
function Context:_emitTap(hitObj, x, y)
    dispatchChain(hitObj, { name = "touch", phase = "began", x = x, y = y, xStart = x, yStart = y, id = TOUCH_ID })
    dispatchChain(hitObj, { name = "touch", phase = "ended", x = x, y = y, xStart = x, yStart = y, id = TOUCH_ID })
    dispatchChain(hitObj, { name = "tap", x = x, y = y, numTaps = 1 })
end

function Context:_dispatchTapObject(obj)
    local x, y = centerOf(obj)
    Recorder.add({ action = "tap", target = targetInfo(obj) })
    self:_emitTap(obj, x, y)
end

-- Tier-0 coordinate tap: hit-test the display tree for the real target.
function Context:tap(x, y)
    local obj = DisplayTree.hitTest(x, y)
    Recorder.add({ action = "tap", target = {
        id = obj and obj.testId, role = obj and obj.testRole, name = obj and obj.testName,
        fallback = { x = x, y = y },
    } })
    if obj then
        self:_emitTap(obj, x, y)
    else
        display.getCurrentStage():dispatchEvent({ name = "tap", x = x, y = y, numTaps = 1 })
    end
    return self
end

-- Drive a drag by dispatching began/moved/ended to a specific source object.
-- All phases go to the same object (mirrors Solar2D touch focus).
function Context:_dragFrom(sourceObj, x1, y1, x2, y2, frames)
    frames = frames or 10
    dispatchChain(sourceObj, { name = "touch", phase = "began", x = x1, y = y1, xStart = x1, yStart = y1, id = TOUCH_ID })
    for f = 1, frames do
        local p = f / frames
        local x = x1 + (x2 - x1) * p
        local y = y1 + (y2 - y1) * p
        dispatchChain(sourceObj, { name = "touch", phase = "moved", x = x, y = y, xStart = x1, yStart = y1, id = TOUCH_ID })
        self:waitFrames(1)
    end
    dispatchChain(sourceObj, { name = "touch", phase = "ended", x = x2, y = y2, xStart = x1, yStart = y1, id = TOUCH_ID })
    return self
end

-- Tier-0 coordinate drag: hit-test the start point for the grabbed object.
function Context:drag(x1, y1, x2, y2, frames)
    local sourceObj = DisplayTree.hitTest(x1, y1) or display.getCurrentStage()
    Recorder.add({ action = "drag",
        source = { id = sourceObj.testId, fallback = { x = x1, y = y1 } },
        target = { fallback = { x = x2, y = y2 } } })
    return self:_dragFrom(sourceObj, x1, y1, x2, y2, frames)
end

-- Object drag (from a locator): dispatch directly to the resolved source object
-- so an overlapping label on top can't steal the hit.
function Context:_dragObjects(a, b, frames)
    local ax, ay = centerOf(a)
    local bx, by = centerOf(b)
    Recorder.add({ action = "drag", source = targetInfo(a), target = targetInfo(b) })
    self:_dragFrom(a, ax, ay, bx, by, frames)
end

-- ---- locators ------------------------------------------------------------

function Context:findById(id)
    return Element.new(self, function()
        -- Registry first (durable, O(1)); fall back to a tree scan for objects
        -- tagged only by testId field.
        local obj = Registry.get(id)
        if obj then
            return obj
        end
        return DisplayTree.findFirst(function(o) return o.testId == id end)
    end, "findById('" .. tostring(id) .. "')")
end

function Context:findByText(text)
    return Element.new(self, function()
        return DisplayTree.findFirst(function(o)
            return o.text == text or o.testName == text or o.label == text
        end)
    end, "findByText('" .. tostring(text) .. "')")
end

function Context:findByRole(role, name)
    return Element.new(self, function()
        return DisplayTree.findFirst(function(o)
            if o.testRole ~= role then
                return false
            end
            return name == nil or o.testName == name or o.text == name
        end)
    end, "findByRole('" .. tostring(role) .. "'" .. (name and (", '" .. name .. "'") or "") .. ")")
end

-- ---- assertions & state --------------------------------------------------

function Context:expect(value, label)
    return Assertions.Assertion.new(self, value, label)
end

function Context:expectState(path)
    return Assertions.Eventually.new(self, function() return self:getState(path) end,
        "state '" .. tostring(path) .. "'")
end

function Context:eventually(read, opts)
    opts = opts or {}
    return Assertions.Eventually.new(self, read, opts.label or "value")
end

-- Resolve a dotted path through the configured state reader.
function Context:getState(path)
    local stateFn = self.config.state
    if type(stateFn) ~= "function" then
        error("expectState/getState requires configure{ state = function() ... end }", 0)
    end
    local node = stateFn()
    if path == nil then
        return node
    end
    for key in string.gmatch(tostring(path), "[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[key]
    end
    return node
end

-- ---- determinism & fixtures ---------------------------------------------

function Context:setSeed(n)
    Rng.seed(n)
    return self
end

-- Load a named fixture module (default dir "tests.fixtures") and apply it via
-- its registered loader.
function Context:loadFixture(name, opts)
    opts = opts or {}
    local dir = opts.module or self.config.fixturesModule or "tests.fixtures"
    local fixture = require(dir .. "." .. name)
    return Fixtures.load(fixture)
end

-- Load a save via the game's registered "save-file" loader.
function Context:loadSave(path, opts)
    opts = opts or {}
    return Fixtures.load({ loader = "save-file", path = path, baseDir = opts.baseDir })
end

-- Invoke a named game control (registered via configure{ controls = {...} }).
function Context:control(name, ...)
    Recorder.add({ action = "control", name = name })
    local controls = self.config.controls
    local fn = controls and controls[name]
    if type(fn) ~= "function" then
        error("no control registered: " .. tostring(name), 0)
    end
    return fn(...)
end

-- ---- recording, replay, traces -------------------------------------------

function Context:startRecording(opts)
    opts = opts or {}
    if opts.seed == nil then
        opts.seed = Rng.getSeed()
    end
    Recorder.start(opts)
    return self
end

function Context:stopRecording()
    return Recorder.stop()
end

function Context:replay(log)
    Replay.play(self, log)
    return self
end

function Context:writeBundle(name, log, opts)
    return Replay.writeBundle(name, log, opts)
end

function Context:loadBundle(name)
    return Replay.readBundle(name)
end

function Context:trace(name, opts)
    if name then
        local path = Trace.write(self, name, opts)
        self.artifacts[#self.artifacts + 1] = { type = "trace", name = name, path = path }
        return path
    end
    return Trace.capture(self, opts)
end

function Context:expectNoErrors()
    local errs = Errors.collected
    if #errs > 0 then
        for _, e in ipairs(errs) do
            self.errors[#self.errors + 1] = e
        end
        error("expectNoErrors: " .. #errs .. " runtime error(s); first: " .. tostring(errs[1].message), 0)
    end
    return self
end

-- ---- scenes --------------------------------------------------------------

function Context:currentScene()
    local adapter = self.config.sceneAdapter
    if adapter and adapter.getCurrentScene then
        return adapter.getCurrentScene()
    end
    return nil
end

function Context:waitForScene(name, opts)
    opts = opts or {}
    self:waitUntil(function() return self:currentScene() == name end, {
        timeout = opts.timeout,
        description = "scene '" .. tostring(name) .. "'",
    })
    return self
end

-- ---- artifacts -----------------------------------------------------------

function Context:screenshot(name)
    name = name or ("shot_" .. (#self.artifacts + 1))
    local rel = "solar_scope/screenshots/" .. name .. ".png"
    local ok, err = pcall(function()
        local docs = system.pathForFile("", system.DocumentsDirectory)
        lfs.mkdir(docs .. "/solar_scope")
        lfs.mkdir(docs .. "/solar_scope/screenshots")
        local capture = display.captureScreen(false)
        display.save(capture, { filename = rel, baseDir = system.DocumentsDirectory })
        capture:removeSelf()
    end)
    self.artifacts[#self.artifacts + 1] = {
        type = "screenshot", name = name, path = rel,
        ok = ok, error = (not ok) and tostring(err) or nil,
    }
    return self
end

function Context:report(payload)
    self.reportData = payload
    return self
end

-- ---- result serialization ------------------------------------------------

function Context:result()
    return {
        status = self.status,
        name = self.name,
        message = self.message,
        seq = self.seq,
        durationMs = system.getTimer() - self.startTime,
        assertions = self.assertions,
        errors = self.errors,
        logs = self.logs,
        report = self.reportData,
        artifacts = self.artifacts,
    }
end

return Context
