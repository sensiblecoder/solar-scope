-- Minimal match-3 color board (the harness game model).
-- Fixed grid of cells; a "tile" is just a cell's current color index (1..COLORS).
-- Swapping exchanges colors between two adjacent cells; a swap that forms a run
-- of 3+ resolves (clear -> gravity -> refill, cascading), otherwise it reverts.
--
-- Deterministic: refills draw from a seeded RNG local to the board. Phase 2
-- routes this through the shared solar_scope RNG abstraction + t:setSeed.

-- Randomness flows through the shared SolarScope RNG so a seed reproduces a run.
local Rng = require("solar_scope.core.rng")

local Board = {
    ROWS = 6,
    COLS = 6,
    COLORS = 4,
    DEFAULT_SEED = 1337,
    grid = {},
    score = 0,
    moves = 0,
    onChange = nil, -- view hook: function() end
}

function Board:randColor()
    return Rng.randomInt(1, self.COLORS)
end

local function idx(self, r, c)
    return (r - 1) * self.COLS + c
end

-- Return a set (linear-index -> true) of cells belonging to a run of 3+.
local function findMatches(self)
    local m = {}
    local grid = self.grid
    -- horizontal
    for r = 1, self.ROWS do
        local c = 1
        while c <= self.COLS do
            local color = grid[r][c]
            local c2 = c
            while c2 + 1 <= self.COLS and grid[r][c2 + 1] == color do
                c2 = c2 + 1
            end
            if color ~= 0 and (c2 - c + 1) >= 3 then
                for cc = c, c2 do m[idx(self, r, cc)] = true end
            end
            c = c2 + 1
        end
    end
    -- vertical
    for c = 1, self.COLS do
        local r = 1
        while r <= self.ROWS do
            local color = grid[r][c]
            local r2 = r
            while r2 + 1 <= self.ROWS and grid[r2 + 1][c] == color do
                r2 = r2 + 1
            end
            if color ~= 0 and (r2 - r + 1) >= 3 then
                for rr = r, r2 do m[idx(self, rr, c)] = true end
            end
            r = r2 + 1
        end
    end
    return m
end

-- Clear matches, apply gravity, refill; repeat for cascades. Returns cells cleared.
local function resolve(self)
    local cleared = 0
    local guard = 0
    while true do
        local m = findMatches(self)
        if not next(m) then
            break
        end
        for i in pairs(m) do
            local r = math.floor((i - 1) / self.COLS) + 1
            local c = (i - 1) % self.COLS + 1
            self.grid[r][c] = 0
            cleared = cleared + 1
        end
        -- gravity + refill per column
        for c = 1, self.COLS do
            local write = self.ROWS
            for r = self.ROWS, 1, -1 do
                if self.grid[r][c] ~= 0 then
                    self.grid[write][c] = self.grid[r][c]
                    if write ~= r then
                        self.grid[r][c] = 0
                    end
                    write = write - 1
                end
            end
            for r = write, 1, -1 do
                self.grid[r][c] = self:randColor()
            end
        end
        guard = guard + 1
        if guard > 50 then
            break
        end
    end
    return cleared
end

function Board:notify()
    if self.onChange then
        self.onChange()
    end
end

function Board:adjacent(r1, c1, r2, c2)
    return math.abs(r1 - r2) + math.abs(c1 - c2) == 1
end

-- Fill a fresh board from the seed, scrubbing any initial matches (no scoring).
function Board:reset(seed)
    Rng.seed(seed or self.DEFAULT_SEED)
    self.grid = {}
    for r = 1, self.ROWS do
        self.grid[r] = {}
        for c = 1, self.COLS do
            self.grid[r][c] = self:randColor()
        end
    end
    local guard = 0
    while true do
        local m = findMatches(self)
        if not next(m) then
            break
        end
        for i in pairs(m) do
            local r = math.floor((i - 1) / self.COLS) + 1
            local c = (i - 1) % self.COLS + 1
            self.grid[r][c] = self:randColor()
        end
        guard = guard + 1
        if guard > 200 then
            break
        end
    end
    self.score = 0
    self.moves = 0
    self:notify()
end

-- Test hook: install an exact grid (deep copy), reset score/moves. No resolve,
-- so tests get precisely the board they specify.
function Board:setGrid(grid)
    self.grid = {}
    for r = 1, self.ROWS do
        self.grid[r] = {}
        for c = 1, self.COLS do
            self.grid[r][c] = grid[r][c]
        end
    end
    self.score = 0
    self.moves = 0
    self:notify()
end

-- Attempt to swap two adjacent cells. Returns true if it produced a match
-- (and resolved), false if not adjacent or no match (reverted).
function Board:trySwap(r1, c1, r2, c2)
    if not self:adjacent(r1, c1, r2, c2) then
        return false
    end
    self.grid[r1][c1], self.grid[r2][c2] = self.grid[r2][c2], self.grid[r1][c1]
    if not next(findMatches(self)) then
        self.grid[r1][c1], self.grid[r2][c2] = self.grid[r2][c2], self.grid[r1][c1]
        self:notify()
        return false
    end
    local cleared = resolve(self)
    self.score = self.score + cleared
    self.moves = self.moves + 1
    self:notify()
    return true
end

function Board:snapshot()
    local g = {}
    for r = 1, self.ROWS do
        g[r] = {}
        for c = 1, self.COLS do
            g[r][c] = self.grid[r] and self.grid[r][c] or 0
        end
    end
    return { score = self.score, moves = self.moves, rows = self.ROWS, cols = self.COLS, grid = g }
end

return Board
