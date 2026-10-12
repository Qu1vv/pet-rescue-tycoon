# Exploration, progression and UI milestone — testing

## Automated checks

Run the complete local gate from the repository root:

    python tools/release_check.py

The gate compiles all Luau, discovers every standalone spec, runs the actual-service
harness and pet-asset audit, regenerates balance and world-preview artifacts, and
builds the place with pinned Rojo. The detailed receipt is in
docs/RELEASE_CHECK_REPORT.md.

The pure suites cover capacity, food, XP, model stages, weighted catalog, biome
eligibility, rewards, profile migration, concurrency races, malformed client/save
inputs, upgrade references, content IDs, and asset mappings. Studio is still required
for Roblox engine behavior, multiplayer replication, devices, and DataStores.

Latest automated result: **84 Luau files compiled, 11 standalone suites passed,
3,396+ explicit assertions passed, 25 actual-service regressions passed**, plus
130,000 rarity/biome rolls, 10,000 food steps, 1,000 six-player churn cycles,
asset/content audits, preview regeneration, and a successful Rojo 7.7.0 place build.

## Studio acceptance order

Use a fresh local session with `StudioPersistence=false`. The developer should run
these after the full source tree has synced.

1. **Edit mode:** confirm `Workspace.ShelterPreview` shows the plaza, six shelters,
   paths, Dog Park, Whisperwood Forest, and Cat Orchard before pressing Play. Confirm
   there is no visible default spawn star.
2. **Exploration/rewards:** start solo Play, wait for the HUD, and paste all of
   [studio-exploration.luau](../tests/studio-exploration.luau) into the **server**
   Command Bar. Expect its single PASS line. It checks preview replacement, all
   habitats, their exact populations/species, pet spacing, invisible spawn markers,
   server event progress, configured payout, and duplicate-claim rejection.
3. **Economy loop:** restart and run [studio-economy.luau](../tests/studio-economy.luau)
   in the server Command Bar. It claims/builds, tests manual generation and bin
   limits, delivers two pets, feeds independently, forces a visual stage, and checks
   the adopter/leash/capacity payout flow.
4. **Regression:** restart and run [studio-smoke.luau](../tests/studio-smoke.luau).
   Two deliberate rollback warnings are expected. Purchases, build failures, rescue
   rollback, capacity, replenishment, and cleanup must pass.
5. **Multiplayer:** start 2–6 clients and run
   [studio-multiplayer.luau](../tests/studio-multiplayer.luau) on the server. It
   verifies isolated plots and rejects cross-owner feed, adoption, bin, and generator
   actions. It also verifies player-isolated quest progress and one-time reward payout.
   Then manually claim all six plots; a seventh test client must receive no plot.
6. **M8 assets and presentation:** run [studio-m8.luau](../tests/studio-m8.luau)
   on the server, then complete [the M8 manual checklist](M8_STUDIO_CHECKLIST.md).
7. **Engagement and identity:** run
   [studio-engagement.luau](../tests/studio-engagement.luau) on the server. Then
   test tutorial markers/skip, pet care/name/favorite controls, adopter requests,
   accessibility settings and visible shelter tiers manually.

## Manual experience checks

### Exploration and pets

- Walk each signed trail from the plaza. The biome banner should show **Dog Park**,
  **Whisperwood Forest**, or **Cat Orchard** once on entry.
- Dog Park spawns only dogs; Forest spawns rabbits/hamsters/guinea pigs; Orchard
  spawns only cats. Pets must use separated clearings and wait to respawn if a player
  is standing on the slot.
- Rescue with keyboard, touch, and gamepad. The pet should accelerate and turn
  smoothly, keep useful spacing through the shelter entrance, and catch up faster
  when behind. Repositioning should occur only after remaining extremely far away.
- Compare dogs, cats, rabbits, hamsters, and guinea pigs. Their idle/walk/run motion
  should be recognizable but lightweight. Verify nearby pets animate and distant
  pets do not consume visible client update work.
- Rare pets use subtle rarity nameplate/card colors and trigger discovery feedback.
  No scripts, animations, marketplace IDs, or unrelated art styles should exist in
  any placeholder pet.

### UI, Index, goals and guidance

- On phone portrait/landscape, desktop, and gamepad, confirm the default HUD shows
  cash, pets/capacity, food, one clear objective, and the session-reset notice without
  blocking movement or prompts.
- Open **PET INDEX**. Test ALL, DOGS, and RABBITS filters plus search. Cards should
  show a 3D preview/name/species/rarity when discovered and a locked silhouette when
  unknown. Scroll through all 24 entries.
- Open **GOALS**. Confirm three rotating dailies and collection rewards at 5/10/20
  discoveries. Finish one objective, claim it, and verify a second click cannot pay.
- Confirm NEXT markers follow the guided step. Skip Tutorial must require two
  presses, hide only guidance, and award no cash.
- Toggle reduced motion, high contrast and larger text. Reopen every menu and verify
  keyboard/gamepad selection plus phone portrait/landscape layout.
  Change only the local displayed progress and verify the server still rejects it.
- Follow the first-session objectives: visit Dog Park, rescue, deliver, generate,
  collect, feed, then visit Forest. Rejoining should preserve the current guide step.
- Check button hover/press/pop tweens and feedback for rescue, biome entry, discovery,
  feed XP, level up, quest complete, reward, adoption, and food collection. Feedback
  should remain readable without rapid duplicate spam.
- SOUND ON/OFF should locally mute/unmute. The game remains intentionally silent
  until approved SoundIds are added to `Config/Audio.luau`.

### Food, feeding, adoption and security

- The Paw Pantry must show recognizable bounded treat pieces moving from dropper to
  bin. Manual Generate gives immediate feedback but cannot exceed one accepted press
  every 0.75 seconds. No more than eight visible pieces per plot may accumulate.
- Food reaches pending bin storage first. Collection transfers only available room
  into stored food; excess remains pending when storage is full.
- Feeding spends one stored food and grants configured XP once per pet per 180
  seconds. It must not spend food during cooldown. Another pet may be fed immediately.
- Force levels 5, 10, and 20 with the server-only `PetService.AddPetXP` helper.
  The visual changes while GUID, owner, rarity, variant, XP, slot, and cooldown remain.
- Confirm adoption: the selected pet locks, an adopter walks in, attaches a Beam
  leash, exits with that pet, then cash is paid and capacity frees. Cancel/reset/delete
  the NPC during travel and verify the pet returns with no payout or leaked leash.
- Test Pet, Brush, Play and Practice Walk. Same-action spam must award nothing;
  another action and another pet remain independently eligible.
- Favorite a pet and confirm adoption is blocked. Rename it and verify the filtered
  name, personality, favorite state and cooldowns restore in a private save test.
- Match and miss the physical adopter request. The server-calculated 35% bonus applies
  only to a match, and the request rotates only after successful departure.
- From a client, fire unknown actions, table IDs, foreign IDs, repeated reward claims,
  and repeated feed/adopt requests. Expect no server error or authoritative mutation.

### Performance and persistence

- Run six clients for 15 minutes. Check that available pets remain capped at 18,
  total pets stay within the configured bound, food visuals stay at eight per plot,
  adopters stay at one per plot, and removed pets/NPCs/leashes/connections clean up.
- Publish a **private test experience** before persistence tests. Use a test DataStore,
  enable Studio API access, and temporarily set `StudioPersistence=true`. Verify
  cash, upgrades, food, pet identity/progression/cooldowns, collection entries,
  dailies, claimed collection rewards, and guided step restore. Dailies should reset
  at the next server UTC period while milestones and guide progress remain.
- Test a foreign session lock, malformed data, future schema, API failure, server
  shutdown, and rejoin. Validation must fail closed without overwriting good data.
  Restore production settings afterwards.

## Main balance files

- `src/shared/Config/GameConfig.luau`: cash, kennel/upgrades, food, feeding, XP,
  adoption, movement, save timing, and global limits.
- `src/shared/Config/Biomes.luau`: habitat coordinates, routes, spawn clearings,
  allowed species, per-biome rarity weights, active caps, respawn and ambience keys.
- `src/shared/Pets/MovementProfiles.luau`: acceleration, turning, spacing, and
  catch-up/recovery by species.
- `src/shared/Pets/AnimationProfiles.luau`: centralized rig-animation IDs and
  procedural fallback motion by species and state.
- `src/shared/Pets/PetAssets.luau`: approved local model-stage paths, review
  metadata, scale/orientation, dependencies, and contract profile IDs.
- `src/shared/Pets/PetCatalog.luau`: species/variants, rarity, weights, habitats,
  adoption values, stage thresholds and future event tags.
- `src/shared/Config/Rewards.luau`: daily rotation, targets/payouts, collection
  milestone rewards, reset period, and guided objective sequence.
- `src/shared/Config/Audio.luau`: master/category volumes, voice cap, cooldowns,
  and empty approved-asset slots.

The current values are MVP tuning and require real player/device testing. The actual
published experience must set Maximum Players to 6; six generated plots alone do not
change the Roblox place limit.

