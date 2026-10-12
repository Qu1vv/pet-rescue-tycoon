local Events = {}
local listeners = {}
-- Registers a server-only gameplay observer and returns its disconnection function.
function Events.Connect(callback)
 listeners[callback] = true
 return function() listeners[callback] = nil end
end
-- Publishes committed actions only; observers must not yield or change the original transaction.
function Events.Emit(player, action, amount, detail)
 for callback in listeners do
  local ok, err = pcall(callback, player, action, amount or 1, detail)
  if not ok then warn("Gameplay observer failed: " .. tostring(err)) end
 end
end
return Events
