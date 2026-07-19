-- SolarScope reporter — writes a structured result to disk and prints a
-- sentinel line the MCP driver can grep for.
--
-- Transport (decided): JSON to DocumentsDirectory/solar_scope/result.latest.json
-- plus a timestamped copy. The console sentinel carries the absolute path so the
-- host can read the file without guessing the sandbox location.

local json = require("json")
local lfs = require("lfs")

local Reporter = {}

local SUBDIR = "solar_scope"
local SENTINEL = "###SOLAR_SCOPE_RESULT###"

local function ensureDir()
    local docs = system.pathForFile("", system.DocumentsDirectory)
    local path = docs .. "/" .. SUBDIR
    lfs.mkdir(path) -- no-op if it already exists
    return path
end

local function writeFile(path, body)
    local f, err = io.open(path, "w")
    if not f then
        print("[solar_scope] reporter could not open " .. path .. ": " .. tostring(err))
        return false
    end
    f:write(body)
    f:close()
    return true
end

function Reporter.write(result)
    local dir = ensureDir()
    local body = json.encode(result)

    local latest = dir .. "/result.latest.json"
    writeFile(latest, body)

    -- Timestamped copy for history / bundle association.
    local stamp = tostring(os.time())
    writeFile(dir .. "/result." .. stamp .. ".json", body)

    -- Single machine-readable line for the log tail.
    local summary = json.encode({
        status = result.status,
        name = result.name,
        message = result.message,
        durationMs = result.durationMs,
        file = "result.latest.json",
        path = latest,
    })
    print(SENTINEL .. " " .. summary)

    return latest
end

Reporter.SENTINEL = SENTINEL

return Reporter
