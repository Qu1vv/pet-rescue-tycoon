# Milestone 3: economy and progression

## Defaults and tuning

All timing/formula inputs are in `src/shared/Config/GameConfig.luau`; definitions are in
`PetCatalog.luau`. Shared copies serve display only; server services own actual state.

| Setting | Initial value |
| --- | --- |
| Starter capacity / expansion | 3 / 6 beds; expansion costs 100 cash |
| Food generator | Included with kennel; 1 food every 5 seconds |
| Conveyor travel / food cap | 3 seconds / 30 stored food |
| Pet feeding | Every 30 seconds after delivery; consumes 1 food and grants 10 XP |
| XP to next level | `20 + (level - 1) * 10`; leftover XP carries forward |
| Level cap | 20; XP resets to 0 at cap |
| Adoption offer | `floor(baseValue * rarityMultiplier * (1 + (level - 1) * 0.25))` |
| Starting dogs/cats | Common, base value 25; all existing coats retained |
| Visual stages | Level 1: teal collar; level 5: blue; level 10: gold |

All current pets remain Common. Other rarity multipliers are supported by definitions,
not special world events. A pet's unique GUID is distinct from its catalog DefinitionId.

Food moves as client-only anchored visuals. The server schedules each arrival and
credits storage only when travel completes. Touching, moving, deleting, or spawning a
visual food part cannot change food. A full store pauses production; pending deliveries
reserve room to avoid overflow. Server stalls do not create a catch-up burst.

Meals happen only while sheltered. Missing food has no penalty. If food is scarce,
least recently fed pets get priority. Following/available pets do not eat or earn XP.
No offline progression or saving is implemented.

## Existing systems extended

- `ShelterState` has per-plot capacity. `ShelterService.GetPetCapacity(player)` returns
  `currentPetCount` (including reservations), `maxPetCapacity`, `hasAvailablePetSlot`.
  Reserving/committing/freeing still uses the original ledger. Upgrading one shelter
  preserves existing pets and food; owner departure resets it to three beds.
- `PetProgression` centralizes `AddPetXP`, `GetPetLevel`, `GetXPRequired`, adoption
  valuation, and model stage lookup. `PetService.AddPetXP` is a server-only entrypoint;
  the pet record, not client attributes, is authoritative.
- `PetBuilder.RefreshVisual` prepares replacement art before replacing it. The outer
  model, root/prompt, GUID, XP, level, owner, rarity, and slot survive. Current stages
  reuse original art with collar changes. Catalog stage ModelKeys can point to reviewed
  local templates later without changing progression code.
- The old free-release UI becomes **View pet → Adopt out → Confirm adoption**.
  This is a minimal adopter interaction; there is no NPC pathfinding or request AI.
  A base-level pet can always be adopted, so a full shelter never requires an upgrade
  or waiting for XP to recover capacity.
- The three existing remote roles remain: `Feedback`, renamed `PetDetails`, and
  renamed `AdoptRequest`. Only AdoptRequest accepts client input: a string pet GUID.
  Ownership, sheltered state, living character, proximity and rate limit are rechecked;
  cash is calculated from the private pet record. Extra client reward arguments are ignored.
- A purple walk-on expansion pad reuses `PadService` and the purchase/rollback style.
  It rebuilds the kennel with a second row while the first three bed positions stay fixed.

## Automated/local checks

```powershell
luau tests/session.spec.luau
luau tests/economy.spec.luau
rojo build -o "Pet Rescue Shelter Tycoon.rbxlx"
```

Use the official standalone Luau executable by absolute path if not on PATH. There
are no new runtime dependencies. The original Rojo mappings are unchanged.

In a fresh solo Studio Play session, paste all of `tests/studio-economy.luau` into the
**server** Command Bar after the character spawns. It runs for about 65 seconds and
checks real feeding, a deliberately unavailable meal, visual stage changes, adoption,
repeat/malformed requests, and upgrade rollback. One intentional rollback warning
is expected. It temporarily replaces Food.TryConsume during the starvation test;
if you interrupt the script, restart Play. It does not edit saved source.

`tests/studio-smoke.luau` also remains available for rescue/regression testing; its
former release action now adopts out and expects the corresponding cash reward.

## Manual acceptance checklist

1. Stop/start Play after Rojo sync. Claim a plot, buy its kennel for 25, and verify
   75 cash. The food machine should drop a piece after ~5 seconds; stored food should
   rise only after the three-second trip. Wait until storage reaches 30; it must stop
   growing. No-food waiting never harms pets.
2. Rescue three pets normally. Follow/enter/deliver still works. Check 3/3 capacity,
   full-shelter feedback, and no fourth pickup. Counts include a pet currently on leash.
3. After delivery, verify each pet gains 10 XP at each successful 30-second meal and
   the food count falls by one. A level-1 pet reaches level 2 after two meals. View its
   live level, XP, rarity, and adoption value in the existing styled dialog.
4. Click Adopt out, then Keep pet: no changes. Reopen and confirm adoption: pet leaves,
   count decreases once, and cash increases by the displayed current server offer.
   The offer can grow if a feeding occurs while the dialog is open; the server uses
   the current value. Rescue a replacement immediately.
5. Earn enough cash through adoption, walk onto the purple 100-cash pad, and verify
   six beds, one charge, unchanged food, and intact existing pets. Rescue four or more
   pets. Re-enter the pad: no extra charge. Insufficient cash must not buy an upgrade.
6. In a two-client session, attempt another player's adoption from the client Command
   Bar with that pet's GUID:
   `game.ReplicatedStorage.ShelterRemotes.AdoptRequest:FireServer("PET_GUID", 999999)`.
   Expect no reward or removal. Repeat with your own following pet, an out-of-range
   sheltered pet, an already adopted ID, a table, nil, or a long string. None should
   cause duplicate money, negative counts, or server errors. Local edits to XP/food/
   rarity/value attributes must not alter server rewards or feeding.
7. Reset your character: sheltered pets, food, XP and upgrades persist in the session.
   Disconnect: only your plot resets. A new owner starts with no food, no pets, three
   beds and no stale delivery from the old owner. Rejoin: 100 cash and no saved progress.
8. Test six upgraded shelters for 15 minutes. Available pets refill to 12; the derived
   total cap is 54. Check stable instances/listeners, no recurring warnings, and clear
   food/XP/capacity/adoption UI on a small mobile viewport and with gamepad navigation.

Standalone checks cannot validate Studio rendering, replication or physics. Run the
Studio checklist before treating this milestone as gameplay-verified. The unpublished
place still needs Maximum Players = 6 when first published.
