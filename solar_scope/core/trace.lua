-- SolarScope trace artifacts. Captures a structured snapshot (display tree,
-- state, logs, errors, seed) to disk for post-hoc investigation.

local DisplayTree = require("solar_scope.core.display_tree")
local Errors = require("solar_scope.core.errors")
local Rng = require("solar_scope.core.rng")
local json = require("json")
local lfs = require("lfs")

local Trace = {}

-- Depth-limited display-tree dump (bounded so huge scenes stay reasonable).
local function dumpTree(group, depth, out)
    local n = group.numChildren or 0
    for i = 1, n do
        local child = group[i]
        local node = DisplayTree.inspect(child)
        out[#out + 1] = node
        if child.numChildren and depth > 0 then
            node.children = {}
            dumpTree(child, depth - 1, node.children)
        end
    end
    return out
end

function Trace.capture(context, opts)
    opts = opts or {}
    local ok, state = pcall(function()
        return context.config.state and context.config.state() or nil
    end)
    return {
        seed = Rng.getSeed(),
        platform = system.getInfo("platformName"),
        scene = context.currentScene and context:currentScene() or nil,
        state = ok and state or nil,
        errors = Errors.collected,
        logs = context.logs,
        displayTree = dumpTree(display.getCurrentStage(), opts.depth or 6, {}),
    }
end

function Trace.write(context, name, opts)
    local docs = system.pathForFile("", system.DocumentsDirectory)
    lfs.mkdir(docs .. "/solar_scope")
    lfs.mkdir(docs .. "/solar_scope/traces")
    local path = docs .. "/solar_scope/traces/" .. name .. ".json"
    local f = assert(io.open(path, "w"))
    f:write(json.encode(Trace.capture(context, opts)))
    f:close()
    return path
end

return Trace
