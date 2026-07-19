-- SolarScope command channel — enables hot-reload / rerun without relaunching
-- the simulator. An external driver (the solar2d MCP) writes a small JSON
-- command file into the project dir; the running app polls it and dispatches.
--
-- Command file: <ResourceDirectory>/.solar_scope/command.json
--   { "seq": <monotonic number>, "action": "run"|"rerun"|"stop", "module": "tests..." }
--
-- Only commands with seq greater than the last handled seq act, so a launch
-- picks up a pending command exactly once and later reruns fire on each bump.

local Runner = require("solar_scope.core.runner")
local json = require("json")

local Commands = {
    enabled = false,
    path = nil,
    lastSeq = 0,
    pollMs = 250,
    timerHandle = nil,
}

local function defaultPath()
    local dir = system.pathForFile("", system.ResourceDirectory)
    return dir .. "/.solar_scope/command.json"
end

local function readCommand()
    local f = io.open(Commands.path, "r")
    if not f then
        return nil
    end
    local body = f:read("*a")
    f:close()
    if not body or body == "" then
        return nil
    end
    local ok, cmd = pcall(json.decode, body)
    if not ok then
        return nil
    end
    return cmd
end

function Commands.dispatch(cmd)
    local action = cmd.action or "run"
    if action == "run" and cmd.module then
        Runner.run(cmd.module, { seq = cmd.seq })
        return true
    elseif action == "rerun" and Runner.moduleName then
        Runner.run(Runner.moduleName, { seq = cmd.seq })
        return true
    elseif action == "stop" then
        Runner.stop()
        return true
    end
    return false
end

-- Check for a newer command; dispatch it. Returns true if it dispatched.
function Commands.poll()
    if not Commands.enabled then
        return false
    end
    local cmd = readCommand()
    if not cmd or type(cmd.seq) ~= "number" or cmd.seq <= Commands.lastSeq then
        return false
    end
    Commands.lastSeq = cmd.seq
    return Commands.dispatch(cmd)
end

-- Begin polling. The immediate poll lets a launch pick up a pending command;
-- its return value tells bootstrap whether to skip the normal autorun.
function Commands.start(opts)
    opts = opts or {}
    Commands.path = opts.path or defaultPath()
    Commands.pollMs = opts.pollMs or 250
    Commands.enabled = true
    local dispatchedOnBoot = Commands.poll()
    Commands.timerHandle = timer.performWithDelay(Commands.pollMs, function()
        Commands.poll()
    end, 0)
    return dispatchedOnBoot
end

function Commands.stop()
    if Commands.timerHandle then
        timer.cancel(Commands.timerHandle)
        Commands.timerHandle = nil
    end
    Commands.enabled = false
end

return Commands
