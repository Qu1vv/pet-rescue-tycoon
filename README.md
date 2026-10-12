# Pet Rescue Shelter Tycoon

## Current loop

**Claim → build → explore habitats → rescue → collect food → feed → discover/raise → adopt → expand.**

- Six fenced plots surround the rescue park. Walk onto an entrance to claim free;
  the gold pad buys three beds for 25 of your starting 100 cash.
- Eighteen weighted-rarity pets populate the Dog Park, Whisperwood Forest, and Cat
  Orchard. Dogs, cats, rabbits, hamsters, and guinea pigs use habitat-specific
  species pools, rarity weights, respawn timing, and movement profiles. Rescue with
  E/touch/gamepad, then walk your leashed pet into your shelter. Pickup reserves capacity immediately.
- The Paw Pantry drops visible bone treats onto a moving belt. Its physical
  **Generate food** button gives an extra drop, with a 0.75-second cooldown.
- Food arrives in a **40-food bin**. Interact to transfer it into **50-food storage**.
  Overflow stays in the bin. Food visuals never determine inventory.
- View your sheltered pet and choose **Feed**: one food gives 20 XP, at most once
  per pet every 180 seconds. There is no automatic feeding, starvation, or death.
- Pet, Brush, Play, and Practice Walk provide active care XP on separate per-pet
  cooldowns. Every pet has a personality, an optional filtered name, and favorite
  protection against accidental adoption.
- Original plush-style pets have visual tiers at levels 1/5/10/20 changing size, bows, collar, and crown.
  The same logical pet, identity, XP, owner, rarity and cooldown survive art changes.
- The Pet Index records delivered discoveries, best levels and total rescues. It has
  ALL/DOGS/RABBITS filters, search, locked silhouettes, rarity cards, and model
  previews. Adopting a pet never removes its discovery.
- **Adopt out → Confirm** sends an adopter into the shelter. They leash your pet
  and leave; only then does the server award cash and free the bed. One adoption
  per shelter, with cancellation/timeout recovery.
- A rotating adopter request asks for a species, rarity, or minimum level and adds
  a 35% match bonus. Normal adoption always remains available as the capacity recovery route.
- Four upgrade branches improve beds (3 → 6 → 8), pantry speed, storage, and care XP. Adoption always
  provides a recovery route when full, without requiring an upgrade.
- Hold Shift to run, or toggle RUN on touch/gamepad L3. Rarity-colored pet nameplates
  and searchable index habitat hints help identify and find missing discoveries.
- Three rotating daily goals, permanent collection rewards, and a first-session
  objective chain are driven by committed server gameplay events and save with the profile.
  Local NEXT markers guide new players and the GOALS menu can skip the tutorial.
- A SETTINGS menu provides reduced motion, stronger contrast, larger text, and
  gamepad-selectable controls.
- **MY PETS** provides an owned-pet roster with favorite, rarity, level, XP, care/feed readiness, request-match filters, and a temporary local locate marker.
- **SHELTER** provides a read-only dashboard for capacity, food, production, adopter requests, and every upgrade branch. Purchases remain physical server-validated pad interactions.
- The reusable UI and audio layers provide cards, buttons, progress bars, popups,
  notifications, category volumes, and biome ambience slots. Audio IDs remain empty
  until owned or approved sounds are selected.

See the [current acceptance and balance guide](docs/NEXT_GAMEPLAY_TESTING.md),
[architecture diagram](docs/ARCHITECTURE.md), and
[original pet geometry preview](docs/pet-preview.png). Studio runtime verification
for the latest changes remains for the developer; standalone checks do not replace playtests.

Milestone 9 adds mounted world signs, capacity-linked pet suites, an exclusive
trust encounter before leashing, gentle personality/rarity difficulty, optional
food treats, and persistent happiness with a modest adoption bonus. See the
[M9 Studio checklist](docs/M9_STUDIO_CHECKLIST.md) for runtime verification.

Milestone 8 adds a formal pet-model contract, a reviewed local asset registry,
central animation profiles, import audits, safer live stage swaps, polished habitat
props, responsive pet/index UI, and distinct reward audio hooks. No Marketplace IDs
or third-party models were inserted. Follow the [asset replacement workflow](docs/M8_ASSET_PIPELINE.md)
and the [M8 Studio checklist](docs/M8_STUDIO_CHECKLIST.md) before approving final art.
The [engagement milestone guide](docs/ENGAGEMENT_MILESTONE.md) covers care,
favorites, naming, adopter requests, onboarding, accessibility, schema 4 saving and
the generated [balance report](docs/BALANCE_REPORT.md).

## Build and play

```powershell
rojo build -o "Pet Rescue Shelter Tycoon.rbxlx"
rojo serve
python tools/release_check.py
```

Open the built place in Studio, or sync through the Rojo plugin. The non-scripted
`ShelterPreview` makes the map visible while editing. Stop and restart Play after
source changes; the server removes that preview and generates the authoritative world.

The game is not published yet. When publishing, set the exact place's **Maximum
Players to 6** in Creator Dashboard. Six plots do not enforce the hosting limit.

The original code mappings, lighting, sound settings, greeting module and connection
diagnostic are preserved. The obsolete template Baseplate was intentionally removed so it
cannot cover the generated map. One Workspace preview mapping was added; runtime code
stays under the existing mappings:

- `src/server` → `ServerScriptService.Server` (Script; child modules).
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (LocalScript; child modules).
- `src/shared` → `ReplicatedStorage.Shared`.

## Focused architecture

See [folder layout and system diagram](docs/ARCHITECTURE.md) for module locations,
startup order and the feeding/adoption/save flows. Methods and named helpers have
brief purpose comments beside their implementations.

The existing shelter ledger, capacity reservations, pad detection, purchase/upgrade
transactions, pet following and currency remain in use. PetCare and
AdoptionRequests contain the new pure rules; AdopterRequestService, the onboarding
controller and accessibility controller extend existing runtime flows.

Extended components:

| Component | Responsibility |
| --- | --- |
| `GameConfig`, `PetCatalog`, `PetAssets`, `PetProgression` | Tuning, weighted definitions/variants, reviewed local model paths, XP/stage/payout calculations. |
| `PetModelContract`, `PetModelNormalizer`, `AnimationProfiles` | Stable roots/attachments/orientation, imported-model safety and centralized animation states. |
| `FoodState`, `FoodService`, `PlotBuilder`, `FoodController` | Bounded server production queue, pending bin/storage, physical machine, bounded client-only moving food. |
| `PetService`, `PetBuilder`, `PetController`, `PetCare`, `RescueTrust`, `RescueController` | Server-owned trust, feeding/care, happiness, identity, stage swaps and interaction UI. |
| `PlotBuilder`, `PetHousing`, `BuildUtil` | Physical mounted signs and capacity-linked, species-adaptable pet suites. |
| `CollectionService`, `IndexController` | Persistent discovery independent of current ownership; simple locked/unlocked UI. |
| `AdoptionService`, `AdopterRequestService` | NPC adoption trips, rotating preferences and server-calculated match bonuses. |
| `ProfileData`, `ProfileService` | Schema 5 migration including pet happiness, save retries, UpdateAsync leases, autosave and safe restoration. |
| `ShelterService`, `HUDController` | Existing cash/capacity/upgrades plus restoration hooks and new food/progression feedback. |

Startup: create remotes → shelter/world → food → adopter requests → pets/adopters → rewards → profiles
→ pads/movement/biome detection.
`Feedback`, `PetDetails`, and `PetEncounter` are server-to-client. One bounded PetAction endpoint accepts Calm, Treat, Leash, Feed, Care, Favorite, Rename, or Adopt.
The client sends only an action, stable pet ID, and the care ID or proposed name
when needed. No client amount, XP, timestamp, rarity, reward, request bonus,
position, personality, trust, happiness, or ownership is accepted.
Food uses server prompt handlers, not another remote. All actionable requests
require a loaded profile, ownership, current state, living nearby character and
server cooldown. Adoption marks the pet busy until its single completion.

Capacity APIs remain centralized in `ShelterService.GetPetCapacity`, `ReserveSlot`,
`FreeSlot` and `CommitDelivery`. XP and payout remain in `PetProgression`.
`PetService.TryFeed`, `TryAdopt`, `AddPetXP`, `Export` and `Restore` operate on private
records; replicated attributes only describe them.

## Saving

Published servers save cash, purchased kennel/capacity, stored and pending food,
sheltered pet identities/definitions/variants/rarities/XP/levels, feeding and
care deadlines, filtered names, personalities, happiness, favorites, discovery entries,
daily/milestone reward state, and guided progress every 60 seconds,
on departure and during shutdown.
Claim any free plot after joining to restore your shelter. Unclaimed saved pets are
retained. In-progress adoptions save as owned pets until their completed payout;
unfinished rescues and food still travelling on the belt are not saved.

There was no prior save service. The current schema-5 profile uses UpdateAsync and
180-second session leases. Load failures, foreign locks, unknown schemas and failed
restoration cannot overwrite the existing profile with an empty shelter. Saves are
serialized; losing the lease stops gameplay. DataStore outages can still lose
progress since the last successful save. Abrupt crashes may require waiting for
the old lease to expire before rejoining.

`StudioPersistence = false` by default: local tests are explicitly temporary. For
save tests, publish a **private test experience**, enable Studio API access, use a
separate `DataStoreName`, and temporarily enable `StudioPersistence`. Never test
failure injection against live player data. See [Roblox DataStore guidance](https://create.roblox.com/docs/cloud-services/data-stores/best-practices).

## Checks and next steps

- [Current Studio acceptance tests and balance settings](docs/NEXT_GAMEPLAY_TESTING.md)
- [Pet catalog, asset registry and safe replacement instructions](docs/PET_ASSETS.md)
- [M8 pet art pipeline and missing-asset report](docs/M8_ASSET_PIPELINE.md)
- `luau tests/session.spec.luau tests/economy.spec.luau tests/gameplay.spec.luau`
- `luau tests/asset-contract.spec.luau`
- `python tools/audit_pet_assets.py`
- luau tests/content-validation.spec.luau
- luau tests/security.spec.luau
- python tools/release_check.py — complete compile/test/audit/preview/build gate
- World floor audit rejects the legacy Baseplate and unexpected map-sized surfaces
- [Latest automated release report](docs/RELEASE_CHECK_REPORT.md)
- [Unattended development and release workflow](docs/RELEASE_WORKFLOW.md)
- [Solo Studio service test](tests/studio-economy.luau)
- [Multiplayer service isolation test](tests/studio-multiplayer.luau)
- [Original purchase/rescue rollback test, updated for asynchronous adoption](tests/studio-smoke.luau)

Older milestone documents are historical; the current checklist supersedes their
automatic-feeding, instant-adoption and session-only instructions.

No third-party art or runtime dependencies were imported. Current art is cohesive
procedural placeholder geometry. Before public release: run real Studio/device and
published save tests, review the economy over multiple sessions, source one cohesive
pet art pack, and improve onboarding. Combat, trading, advanced adopter AI, premium
purchases and event systems remain out of scope.


