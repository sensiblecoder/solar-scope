-- SolarScope display-tree inspection + hit-testing.
-- Standalone (no dependency on context) so it can be reused freely.

local DisplayTree = {}

local function isVisibleNode(obj)
    return obj.isVisible ~= false and (obj.alpha == nil or obj.alpha > 0)
end
DisplayTree.isVisible = isVisibleNode

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
        if isVisibleNode(child) then
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
