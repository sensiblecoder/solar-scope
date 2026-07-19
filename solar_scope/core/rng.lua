-- SolarScope deterministic RNG abstraction.
-- A game routes its randomness through this so a seed reproduces a run. It is
-- intentionally tiny and swappable — the seam Phase 4 extends toward a fully
-- controllable simulation source. Does not touch global math.random.

local Rng = {
    _seed = nil,
    _state = nil,
}

function Rng.seed(n)
    Rng._seed = n
    Rng._state = n % 2147483648
    return Rng
end

function Rng.getSeed()
    return Rng._seed
end

-- Uniform in [0, 1).
function Rng.random()
    if Rng._state == nil then
        Rng.seed(os.time())
    end
    Rng._state = (Rng._state * 1103515245 + 12345) % 2147483648
    return Rng._state / 2147483648
end

-- Integer in [a, b] inclusive.
function Rng.randomInt(a, b)
    return a + math.floor(Rng.random() * (b - a + 1))
end

return Rng
