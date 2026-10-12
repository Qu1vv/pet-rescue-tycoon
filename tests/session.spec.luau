-- Run from the repository root: luau tests/session.spec.luau
local State = require("../src/server/Shelter/ShelterState")
local Trail = require("../src/server/Pets/FollowTrail")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local state = State.new(6, 3)
check(state:Claim("Alice", 1), "First claim succeeds")
local ok, reason = state:Claim("Bob", 1)
check(not ok and reason == "PlotTaken", "Same plot cannot have two owners")
ok, reason = state:Claim("Alice", 2)
check(not ok and reason == "AlreadyOwnPlot", "Owner cannot claim a second plot")
for id = 2, 6 do check(state:Claim("Player" .. id, id), "Six independent owners") end
ok = state:Claim("Seventh", 7)
check(not ok, "Seventh plot does not exist")
check(state:Reserve("Visitor", "x") == nil, "Unclaimed player cannot reserve")
local first = state:Reserve("Alice", "pet-a")
check(first == 1, "First rescue reserves first slot")
check(state:Reserve("Player2", "pet-a") == nil, "Pet cannot be reserved by two owners")
check(not state:Commit("Player2", "pet-a"), "Other player cannot deliver reserved pet")
check(not state:Free("Player2", "pet-a"), "Other player cannot release reserved pet")
check(state:Reserve("Alice", "pet-b") == 2, "Second slot")
check(state:Reserve("Alice", "pet-c") == 3, "Third slot")
local slot, full = state:Reserve("Alice", "pet-d")
check(slot == nil and full == "ShelterFull", "Reservations count against capacity")
check(state:Commit("Alice", "pet-a"), "Delivery commits once")
check(not state:Commit("Alice", "pet-a"), "Duplicate delivery rejected")
local delivered, reserved = state:Counts(1)
check(delivered == 1 and reserved == 2, "Replicated counts distinguish delivered and following")
check(state:Free("Alice", "pet-b"), "Death/failed pickup frees reservation")
check(state:Reserve("Alice", "pet-d") == 2, "Freed slot reused without collision")
check(state:Free("Alice", "pet-a"), "Sheltered pet can be released")
check(not state:Free("Alice", "pet-a"), "Repeated release is harmless")
check(state:Reserve("Alice", "pet-e") == 1, "Released bed reused")
check(state:Reserve("Player2", "pet-other") == 1, "Another plot has separate slots")
check(state:ReleasePlot("Alice") == 1, "Departure frees plot")
check(state.Pets["pet-e"] == nil and state.Pets["pet-d"] == nil and state.Pets["pet-c"] == nil, "Departure frees all reservations")
check(state.Pets["pet-other"] ~= nil, "Departure leaves other shelter intact")
check(state:ReleasePlot("Alice") == nil, "Repeated cleanup is idempotent")
check(state:Claim("Replacement", 1), "Vacated plot can be reclaimed")
check(state:Reserve("Replacement", "fresh") == 1, "Reclaimed plot is empty")

-- Deterministic churn catches leaked slots/owners over many rescue sessions.
for iteration = 1, 1000 do
	local session = State.new(6, 3)
	for owner = 1, 6 do
		assert(session:Claim(owner, owner))
		for index = 1, 3 do
			local id = owner .. ":" .. index
			assert(session:Reserve(owner, id) == index)
			assert(session:Commit(owner, id))
		end
	end
	for owner = 1, 6 do session:ReleasePlot(owner) end
	assert(next(session.Pets) == nil and next(session.Owners) == nil, "Churn leaked session state")
end
check(true, "1000 six-player collection/cleanup cycles")

-- Minimal vector arithmetic for engine-independent path tests.
local Vec = {}
local function v(x, y, z) return setmetatable({ X = x, Y = y or 0, Z = z or 0 }, Vec) end
Vec.__sub = function(a, b) return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vec.__add = function(a, b) return v(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vec.__mul = function(a, n) return v(a.X * n, a.Y * n, a.Z * n) end
Vec.__index = function(a, key)
	if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
	return nil
end
local function near(a, b) return (a - b).Magnitude < 0.0001 end
local path = Trail.new(v(0))
check(near(path:Advance(4, 24, 0.1, false), v(0)), "Stationary owner leaves pet still")
path:Add(v(10))
check(near(path:Advance(4, 2, 1, false), v(2)), "Follow movement respects speed")
check(near(path:Advance(4, 100, 1, false), v(6)), "Pet stops four studs behind")
path:Add(v(10, 0, 10))
check(near(path:Advance(4, 4, 1, false), v(10)), "Pet reaches corner before turning")
check(near(path:Advance(4, 2, 1, false), v(10, 0, 2)), "Pet follows second segment")
check(near(path:Advance(4, 100, 1, false), v(10, 0, 6)), "Trail pruning preserves lag distance")
path:Add(v(10, 0, 100))
check(near(path:Advance(4, 1, 0.01, true), v(10, 0, 96)), "Recovery lands on recent trail")
path:Add(v(10, 0, 100.1))
check(#path.Points <= 2, "Tiny movement does not grow history")
local long = Trail.new(v(0))
for index = 1, 10000 do long:Add(v(index)) end
check(#long.Points <= 100, "History bounded even while stalled")
check(near(long:Advance(4, 24, 0.05, true), v(9996)), "Bounded history recovery uses recent path")
local walking = Trail.new(v(0))
local previous = v(0)
for index = 1, 2000 do
	walking:Add(v(index * 0.8))
	local position = walking:Advance(4, 24, 0.05, false)
	assert(position.X >= previous.X, "Following moved backwards after pruning")
	assert(position.X <= index * 0.8, "Pet overtook player")
	previous = position
end
check(near(previous, v(1596)), "Continuous walking retains four-stud gap")
print("PASS: " .. checks .. " session and trail checks, including 1000 six-player churn cycles")
