# Milestone 2 acceptance procedure

Historical checklist: Milestone 3 replaces free release with paid adoption and adds
an expansion to six beds. Use [the Milestone 3 procedure](MILESTONE3_TESTING.md) for
current remote names, rewards, capacities and economy behavior.

## Verification boundaries

Standalone `tests/session.spec.luau` checks the actual session ledger and trail
algorithm: exclusive claims, six plots, capacity including reservations, ownership
checks, duplicate operations, cleanup/reuse, 1,000 six-player churn cycles, corner
following, speed bounds, gap distance, recovery, bounded history, and forward progress.

`tests/studio-smoke.luau` is a repeatable **real Roblox engine** service test. Paste it
into the server Command Bar in a fresh solo session. It tests world counts, free claim,
payment rejection, intentional construction/pickup failures and rollback, duplicate
purchases, distance validation, reserved capacity, delivery, release, cancellation,
and replenishment. Two intentional rollback warnings are expected. It uses server
teleports and therefore does not verify ordinary walking or visual behavior.

Studio UI, multiplayer, replication, 15-minute performance, mobile/gamepad, and
published-place configuration must be tested separately using the steps below.

## 1. Build and mapping preservation

```powershell
rojo build -o "Pet Rescue Shelter Tycoon.rbxlx"
luau tests/session.spec.luau
```

If the optional Luau CLI is not on PATH, use its absolute path. It is a development
test tool, not a dependency of the game. Open the generated place in Studio.

Verify `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and
`StarterPlayer.StarterPlayerScripts.Client`. Server/client controller ModuleScripts
must be children of their entrypoint scripts. `default.project.json` should match
SHA256 `739CEF9475B6832D2E4917322827C93F7DF29EE4BB48EAF272711D4620963FAF`.

## 2. Fresh solo play

1. Start Play; inspect `Workspace.ShelterWorld` in the server Explorer.
2. Confirm six fenced plots and a central park with 12 dogs/cats. Inspect all six
   paths: no trees/benches block an entrance. The world is 768×768 and plot lawns
   are 112×112; the player starts in the center.
3. Confirm there is no visible spawn star. Generated SpawnLocations are invisible.
   The repository's mapped place contains no separate template SpawnLocation. If
   testing an older Studio place, inspect any additional standalone SpawnLocation
   before removing its identified decoration; do not delete unrelated authored objects.
4. Confirm 100 ShelterCash, 0/3 pets, the claim objective, and the session-reset notice.
5. Walk onto an entrance plate. Claim is free, owner name appears, HOME appears, and
   respawning returns you inside that plot. Another entrance cannot change ownership.
6. Walk onto the gold pad: cash becomes 75, one kennel appears, and the gold pad hides.
   Stand still and then walk off/on again: cash must remain 75.

## 3. Collection and delivery

1. Before building a kennel in a fresh session, attempt to rescue a pet. Expect the
   build/claim feedback and no leash or reserved slot.
2. With a kennel built, approach a central pet. Press E (or tap the standard prompt).
   Confirm one leash from hand to collar and `ReservedCount = 1` on your plot.
3. Attempt a second pickup: rejected. Walk turns and through the fence entrance.
   The pet should follow approximately four studs behind without dragging the avatar.
4. Jump and stop; the pet should remain grounded and follow the sampled route. Walk
   briskly around a path corner: it should not repeatedly walk backwards.
5. In the server Command Bar, move only the character into its intake:

   ```luau
   local p = game.Players:GetPlayers()[1]
   local s = require(game.ServerScriptService.Server.Shelter.ShelterService)
   p.Character:PivotTo(s.GetPlot(p).Intake.CFrame)
   ```

   Observe the next movement updates: delivery must wait for the pet to reach the
   intake too. A pet may recover to its recent grounded trail if >32 studs behind.
6. In ordinary walking, enter your own kennel with the pet behind you. Confirm the
   leash disappears, one pet occupies a bed, `PetCount = 1`, `ReservedCount = 0`, and
   cash stays 75. Walking through someone else's intake must not deliver it.
7. Collect three pets. Verify separate beds, a 3/3 HUD, and rejection of a fourth.

## 4. Release and client tampering

1. Approach a pet sheltered in your plot; activate its Release prompt. Verify its
   name in the confirmation. Choose Keep pet: count and model remain unchanged.
2. Confirm Release: that pet disappears and one bed becomes available.
3. Confirm once, then quickly repeat a request using the same ID: no second release
   or counter decrement is allowed.
4. From a client Command Bar, send another owner's sheltered pet ID:

   ```luau
   game.ReplicatedStorage.ShelterRemotes.ReleaseRequest:FireServer("OTHER_PET_ID")
   ```

   Replace the placeholder with a server-observed ID from the other plot. Verify no
   ownership/count/model change. Also try a table or a 1,000-character string; there
   must be no server exception or state change.
5. Locally alter the displayed cash, plot attributes, or prompt distance. Verify the
   server cash/ownership remains intact and pickup/release requires real proximity.
6. Set the owner's cash to 24 on the server before purchase and step onto the pad.
   Verify no construction or charge. Restore 100, leave the pad and re-enter; standing
   still after the rejection must not auto-purchase.

## 5. Six players and race cases

1. In Studio server/client test mode, start six players. Everyone should spawn in
   the central plaza with 100 cash and no plot. Claim all six independently.
2. In a fresh session, move two players onto the same entrance at approximately the
   same time. Exactly one wins; the other can claim another plot. No cash is charged.
3. Have a non-owner walk on another plot's purchase pad. Neither player's cash or
   kennel changes. Owner purchase affects only that owner's balance.
4. Have two equipped players press E on the same central pet. Exactly one acquires
   it and reserves a slot. The losing player's following ID stays empty.
5. Lead six pets simultaneously. Every client should see the correct owner/leash,
   and sheltered pets must stay in their own plots.
6. Add a seventh client if Studio supports it. With all six plots claimed, show
   "All shelters occupied"; never assign a second owner to a plot.
7. Join late after other players have rescued pets. Verify accurate current counts,
   ownership, pet state, and HUD without requiring another state change.

## 6. Lifecycle and cleanup

1. Reset while leading a pet: following model/leash disappear and reservation frees.
   Already sheltered pets and cash persist. There is one HUD after respawn.
2. Disconnect a player leading a pet. Verify their leash/attachment disappears and
   only their plot resets. No reserved bed or cooldown entry remains for them.
3. Disconnect a player with three sheltered pets. Verify all three disappear, their
   kennel clears, and the entrance is claimable again.
4. Reclaim that plot using another player. Confirm a fresh 25-cash purchase, empty
   capacity, and the new owner's respawn; never retain the previous owner's pets.
5. Stop/restart Play: all balances return to 100, all plots are free, and 12 new pets
   populate the center.

## 7. Performance and devices

Run a six-client session for 15 minutes. Repeatedly rescue, deliver, release, reset,
and disconnect/rejoin. In server Explorer watch `AvailablePetCount` (refills to 12
after five seconds), `TotalPetCount` (never >36), and plot counters (never >3 including
reservations). Monitor Developer Console/MicroProfiler for sustained growth in
instances, memory, or script time; verify no accumulating attachments or recurring
Output warnings. Check follow motion from both the owner and an observing client.

Use the device emulator for a small phone viewport in portrait and landscape. Check
HUD text, the session notice, HOME marker, touch rescue, and both release buttons.
If a controller is available, verify the standard prompt and dialog button navigation.

## 8. Publishing gate

The game is not currently published. On first publication, configure that place's
Maximum Players to **6** and save. Verify `game.Players.MaxPlayers` in a published
server and test six players there. Do not report this setting as complete based on
six local plots or a successful Rojo build.
