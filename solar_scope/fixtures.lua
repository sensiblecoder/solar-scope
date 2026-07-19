-- SolarScope fixture-loader registry. Games register named loaders; the core
-- stays game-agnostic. A fixture is a table { loader = "<name>", ... } and the
-- registered loader applies it (reset + install known state, read a save, etc.).

local Fixtures = {
    loaders = {},
}

function Fixtures.register(name, fn)
    assert(type(name) == "string", "fixture loader name must be a string")
    assert(type(fn) == "function", "fixture loader must be a function")
    Fixtures.loaders[name] = fn
end

function Fixtures.load(fixture)
    local name = fixture and fixture.loader
    local fn = Fixtures.loaders[name]
    if not fn then
        error("Unknown fixture loader: " .. tostring(name), 0)
    end
    return fn(fixture)
end

return Fixtures
