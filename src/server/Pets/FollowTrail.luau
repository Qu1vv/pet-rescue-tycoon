-- A bounded path of grounded positions. Advancing by path distance prevents
-- shortcuts through corners and backwards movement when old samples are pruned.
local FollowTrail = {}
FollowTrail.__index = FollowTrail

-- Creates a bounded trail starting at the pet's current position.
function FollowTrail.new(first)
	return setmetatable({ Points = { first }, Length = 0, Progress = 0 }, FollowTrail)
end

-- Records sufficiently separated positions and prunes old samples while preserving travelled distance.
function FollowTrail:Add(point)
	local points = self.Points
	local distance = (point - points[#points]).Magnitude
	if distance < 0.5 then return end
	table.insert(points, point)
	self.Length += distance
	if #points > 100 then
		local removed = (points[2] - points[1]).Magnitude
		table.remove(points, 1)
		self.Length -= removed
		self.Progress = math.max(0, self.Progress - removed)
	end
end

-- Moves along the recorded path at the requested speed, or recovers to a safe point behind the leader.
function FollowTrail:Advance(behind, speed, dt, recover)
	local target = math.max(0, self.Length - behind)
	self.Progress = if recover then target else math.min(target, self.Progress + speed * dt)
	local points = self.Points
	while #points > 1 do
		local length = (points[2] - points[1]).Magnitude
		if self.Progress < length then
			return points[1] + (points[2] - points[1]) * (self.Progress / length)
		end
		table.remove(points, 1)
		self.Progress -= length
		self.Length = math.max(0, self.Length - length)
	end
	return points[1]
end

return FollowTrail
