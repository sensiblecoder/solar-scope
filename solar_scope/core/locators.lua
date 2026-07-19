-- SolarScope lazy element handles.
--
-- A locator (findById/findByText/findByRole) returns an Element that holds a
-- resolver closure, not a display object. Resolution happens at ACTION time
-- (:tap/:dragTo/:expect) and briefly auto-waits, so a test written against an
-- object that registers a frame or two late is not flaky. This mirrors
-- Playwright's auto-waiting locators.

local Element = {}
Element.__index = Element

function Element.new(context, resolver, description)
    return setmetatable({
        context = context,
        _resolver = resolver,
        description = description or "element",
    }, Element)
end

function Element.isElement(v)
    return getmetatable(v) == Element
end

-- Resolve now, or keep yielding frames until it appears or the timeout passes.
function Element:resolve(timeout)
    timeout = timeout or self.context.config.locatorTimeout or 2000
    local obj = self._resolver()
    if obj then
        return obj
    end
    local deadline = system.getTimer() + timeout
    while system.getTimer() < deadline do
        coroutine.yield("next_frame")
        obj = self._resolver()
        if obj then
            return obj
        end
    end
    return nil
end

function Element:_require()
    local obj = self:resolve()
    if not obj then
        error("Could not resolve " .. self.description .. " within timeout", 0)
    end
    return obj
end

function Element:object()
    return self:_require()
end

function Element:center()
    local obj = self:_require()
    local b = obj.contentBounds
    if b then
        return (b.xMin + b.xMax) / 2, (b.yMin + b.yMax) / 2
    end
    return obj.x, obj.y
end

function Element:tap()
    self.context:_dispatchTapObject(self:_require())
    return self
end

function Element:dragTo(target, frames)
    local a = self:_require()
    local b = Element.isElement(target) and target:_require() or target
    self.context:_dragObjects(a, b, frames)
    return self
end

-- Assert against the (optionally still-nil) resolved object.
function Element:expect(label)
    return self.context:expect(self:resolve(), label or self.description)
end

return Element
