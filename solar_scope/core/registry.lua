-- SolarScope semantic registry (Tier 2). Maps a stable id to a display object
-- with weak values, so destroyed objects don't leak and don't keep resolving.
-- findById checks here first, then falls back to a display-tree scan for objects
-- tagged only by field (testId) without going through the registry.

local Registry = {
    objects = setmetatable({}, { __mode = "v" }),
    metadata = {},
}

function Registry.register(id, object, meta)
    assert(type(id) == "string", "registry id must be a string")
    Registry.objects[id] = object
    Registry.metadata[id] = meta or {}
    object.testId = id
    return object
end

function Registry.unregister(id)
    Registry.objects[id] = nil
    Registry.metadata[id] = nil
end

function Registry.get(id)
    return Registry.objects[id], Registry.metadata[id]
end

return Registry
