-- SolarScope display-tree inspection + hit-testing.
-- Standalone (no dependency on context) so it can be reused freely.

local DisplayTree = {}

local function isVisibleNode(obj)
    return obj.isVisible ~= false and (obj.alpha == nil or obj.alpha > 0)
end
DisplayTree.isVisible = isVisibleNode

-- Predicate for HIT-TESTING traversal — distinct from isVisibleNode.
-- Solar2D hit-tests by isVisible only: an alpha == 0 object (or group)
-- is fully transparent yet still receives touches, and Composer routinely
-- parents a live scene under a transient alpha == 0 container. Gating hits
-- on alpha (as isVisibleNode does, which is right for "is it painted?")
-- would wrongly drop that whole subtree, so hit-testing uses this instead.
local function isHittable(obj)
    return obj.isVisible ~= false
end

-- Depth-first pre-order walk collecting objects matching predicate(obj).
local function walk(group, predicate, out)
    local n = group.numChildren or 0
    for i = 1, n do
        local child = group[i]
        if predicate(child) then
            out[#out + 1] = child
        end
        if child.numChildren then
            walk(child, predicate, out)
        end
    end
    return out
end

function DisplayTree.find(predicate, root)
    root = root or display.getCurrentStage()
    return walk(root, predicate, {})
end

function DisplayTree.findFirst(predicate, root)
    return DisplayTree.find(predicate, root)[1]
end

-- Topmost *visible leaf* whose contentBounds contain (x, y).
-- Children are iterated back-to-front (higher index = drawn later = on top),
-- and groups are recursed before falling back to leaf bounds, so we return the
-- object a real touch would land on. Groups are never returned directly — the
-- caller bubbles the event up to whichever ancestor holds the listener.
local function hitTest(group, x, y)
    for i = (group.numChildren or 0), 1, -1 do
        local child = group[i]
        if isHittable(child) then
            if child.numChildren then
                local hit = hitTest(child, x, y)
                if hit then
                    return hit
                end
            else
                local b = child.contentBounds
                if b and x >= b.xMin and x <= b.xMax and y >= b.yMin and y <= b.yMax then
                    return child
                end
            end
        end
    end
    return nil
end

function DisplayTree.hitTest(x, y, root)
    return hitTest(root or display.getCurrentStage(), x, y)
end

-- Every visible leaf whose contentBounds contain (x, y), ordered
-- front-to-back (topmost first) — the "hit stack" a real Solar2D touch
-- cascades through: the frontmost object gets first shot, and if it
-- doesn't consume the event it falls through to the object beneath.
-- Used by tap dispatch so a listener on an object BEHIND the topmost
-- (e.g. a button whose touch handler sits on its background rect while
-- a label is drawn on top) still fires, matching real input.
local function hitStack(group, x, y, out)
    for i = (group.numChildren or 0), 1, -1 do
        local child = group[i]
        if isHittable(child) then
            if child.numChildren then
                hitStack(child, x, y, out)
            else
                local b = child.contentBounds
                if b and x >= b.xMin and x <= b.xMax and y >= b.yMin and y <= b.yMax then
                    out[#out + 1] = child
                end
            end
        end
    end
    return out
end

function DisplayTree.hitStack(x, y, root)
    return hitStack(root or display.getCurrentStage(), x, y, {})
end

-- Structured node for reporting / self-healing recording (Phase 3 enriches).
function DisplayTree.inspect(obj)
    local b = obj.contentBounds
    return {
        id = obj.testId,
        role = obj.testRole,
        name = obj.testName or obj.text or obj.label,
        text = obj.text,
        visible = isVisibleNode(obj),
        alpha = obj.alpha,
        x = obj.x,
        y = obj.y,
        bounds = b and { xMin = b.xMin, yMin = b.yMin, xMax = b.xMax, yMax = b.yMax } or nil,
    }
end

return DisplayTree
