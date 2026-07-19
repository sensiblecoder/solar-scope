-- SolarScope replay + .sscope bundle IO.
-- Resolves each recorded action's target using the self-healing order
-- (id -> role+name -> text -> coordinates) and performs it against the game.

local Recorder = require("solar_scope.core.recorder")
local json = require("json")
local lfs = require("lfs")

local Replay = {}

local RESOLVE_TIMEOUT = 500

-- Resolve a recorded target (id/role/name) to a live object, else nil.
function Replay.resolve(context, target)
    if not target then
        return nil
    end
    if target.id then
        local obj = context:findById(target.id):resolve(RESOLVE_TIMEOUT)
        if obj then return obj end
    end
    if target.role then
        local obj = context:findByRole(target.role, target.name):resolve(0)
        if obj then return obj end
    end
    if target.name then
        local obj = context:findByText(target.name):resolve(0)
        if obj then return obj end
    end
    return nil
end

-- Play a rich log against the context.
function Replay.play(context, log)
    for _, e in ipairs(log.actions or {}) do
        if e.action == "tap" then
            local obj = Replay.resolve(context, e.target)
            if obj then
                context:_dispatchTapObject(obj)
            else
                local f = e.target.fallback
                context:tap(f.x, f.y)
            end
        elseif e.action == "drag" then
            local a = Replay.resolve(context, e.source)
            local b = Replay.resolve(context, e.target)
            if a and b then
                context:_dragObjects(a, b)
            else
                local sf, tf = e.source.fallback, e.target.fallback
                context:drag(sf.x, sf.y, tf.x, tf.y)
            end
        elseif e.action == "control" then
            context:control(e.name)
        end
    end
    return context
end

-- ---- .sscope bundle ------------------------------------------------------

local function bundlesRoot()
    local docs = system.pathForFile("", system.DocumentsDirectory)
    lfs.mkdir(docs .. "/solar_scope")
    local root = docs .. "/solar_scope/bundles"
    lfs.mkdir(root)
    return root
end

local function writeFile(path, body)
    local f = assert(io.open(path, "w"))
    f:write(body)
    f:close()
end

-- Write a .sscope bundle directory. `log` is a rich log; stored compact.
function Replay.writeBundle(name, log, opts)
    opts = opts or {}
    local dir = bundlesRoot() .. "/" .. name .. ".sscope"
    lfs.mkdir(dir)
    lfs.mkdir(dir .. "/screenshots")
    lfs.mkdir(dir .. "/diagnostics")

    local compact = Recorder.toCompact(log)
    writeFile(dir .. "/interactions.json", json.encode(compact))
    writeFile(dir .. "/manifest.json", json.encode({
        schemaVersion = 1,
        gameVersion = log.gameVersion or opts.gameVersion,
        platform = system.getInfo("platformName"),
        seed = log.seed,
        save = opts.save,
        interactions = "interactions.json",
    }))
    if opts.saveData then
        writeFile(dir .. "/save.dat", opts.saveData)
    end
    return dir
end

-- Read a .sscope bundle back into a rich log (+ manifest).
function Replay.readBundle(name)
    local dir = bundlesRoot() .. "/" .. name .. ".sscope"
    local function readJson(file)
        local f = assert(io.open(dir .. "/" .. file, "r"))
        local body = f:read("*a")
        f:close()
        return json.decode(body)
    end
    local manifest = readJson("manifest.json")
    local compact = readJson("interactions.json")
    local log = Recorder.fromCompact(compact)
    return log, manifest
end

return Replay
