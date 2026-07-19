-- SolarScope self-healing interaction recorder.
-- Captures the interactions SolarScope performs as semantic targets (id/role/
-- name) WITH coordinate fallbacks, so a recording survives layout changes and
-- can be replayed or translated into a readable Lua test. No-ops when disabled.
--
-- In-memory events are "rich" (semantic + fallback). toCompact() produces the
-- tiny array-of-arrays disk form; fromCompact() expands it back for replay.

local Recorder = {
    enabled = false,
    events = {},
    startTime = 0,
    meta = {},
}

function Recorder.start(opts)
    opts = opts or {}
    Recorder.enabled = true
    Recorder.events = {}
    Recorder.startTime = system.getTimer()
    Recorder.meta = {
        seed = opts.seed,
        gameVersion = opts.gameVersion,
        save = opts.save,
    }
    return Recorder
end

function Recorder.add(event)
    if not Recorder.enabled then
        return
    end
    event.t = math.floor(system.getTimer() - Recorder.startTime)
    Recorder.events[#Recorder.events + 1] = event
end

function Recorder.stop()
    Recorder.enabled = false
    return Recorder.log()
end

function Recorder.log()
    return {
        version = 1,
        seed = Recorder.meta.seed,
        gameVersion = Recorder.meta.gameVersion,
        save = Recorder.meta.save,
        actions = Recorder.events,
    }
end

-- Rich log -> compact disk form.
function Recorder.toCompact(log)
    local out = {}
    for _, e in ipairs(log.actions) do
        if e.action == "tap" then
            local tgt = e.target or {}
            local f = tgt.fallback or {}
            out[#out + 1] = { "tap", e.t or 0, tgt.id or "", f.x or 0, f.y or 0 }
        elseif e.action == "drag" then
            local s, tg = e.source or {}, e.target or {}
            local sf, tf = s.fallback or {}, tg.fallback or {}
            out[#out + 1] = { "drag", e.t or 0, s.id or "", tg.id or "", sf.x or 0, sf.y or 0, tf.x or 0, tf.y or 0 }
        elseif e.action == "control" then
            out[#out + 1] = { "control", e.t or 0, e.name or "" }
        end
    end
    return {
        version = log.version or 1,
        seed = log.seed,
        gameVersion = log.gameVersion,
        save = log.save,
        actions = out,
    }
end

local function orNil(s)
    if s == nil or s == "" then return nil end
    return s
end

-- Compact disk form -> rich log for replay.
function Recorder.fromCompact(compact)
    local actions = {}
    for _, a in ipairs(compact.actions or {}) do
        local kind = a[1]
        if kind == "tap" then
            actions[#actions + 1] = {
                action = "tap", t = a[2],
                target = { id = orNil(a[3]), fallback = { x = a[4], y = a[5] } },
            }
        elseif kind == "drag" then
            actions[#actions + 1] = {
                action = "drag", t = a[2],
                source = { id = orNil(a[3]), fallback = { x = a[5], y = a[6] } },
                target = { id = orNil(a[4]), fallback = { x = a[7], y = a[8] } },
            }
        elseif kind == "control" then
            actions[#actions + 1] = { action = "control", t = a[2], name = a[3] }
        end
    end
    return {
        version = compact.version or 1,
        seed = compact.seed,
        gameVersion = compact.gameVersion,
        save = compact.save,
        actions = actions,
    }
end

return Recorder
