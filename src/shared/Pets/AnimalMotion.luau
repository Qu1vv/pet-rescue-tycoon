local Motion = {}
-- Computes bounded acceleration/braking along a trail; recovery needs sustained extreme separation.
function Motion.Step(speed, gap, distance, farTime, dt, profile)
 dt = math.clamp(dt, 0, 0.15)
 farTime = if distance > profile.RecoveryDistance then farTime + dt else 0
 local recover = farTime >= profile.RecoveryDelay
 local target = if gap <= profile.StopDistance then 0 else math.min(
  if distance > profile.CatchupDistance then profile.CatchupSpeed else profile.Speed,
  math.sqrt(2 * profile.Deceleration * math.max(0, gap)))
 local rate = if target < speed then profile.Deceleration else profile.Acceleration
 speed += math.clamp(target - speed, -rate * dt, rate * dt)
 if gap <= profile.StopDistance then speed = 0 end
 return speed, if recover then 0 else farTime, recover,
  if speed < 0.1 then "Idle" elseif speed > 20 then "Run" else "Walk"
end
return Motion
