# M4 implementation and verification

## What changed

- Claim restoration no longer shadows its callback with a boolean. Profile loading
  explicitly initializes the player's currency first. A player standing on a pad
  while loading is eligible when loading completes.
- Shift holds sprint; gamepad L3 and mobile RUN toggle it. The server selects speed.
- Original plush pet geometry replaces the older shapes. Labels display name,
  level and grey/green/blue/purple/yellow rarity, with pink retained for Mythic.
- Eighteen available pets occupy Meadow (dogs), Orchard (cats), and Pondside
  (small pets). Twelve definitions provide twenty-two discoverable variants.
- Index search supports names, species, variants, rarity and habitat; discoveries
  survive adoption. Visual progression adds growth, bows and a champion crown.
- Beds, Pantry, Storage and Care each have two purchases. Save schema 2 migrates
  existing schema 1 profiles while preserving pet identities, cash and discoveries.

## Research and design decisions

Adopt Me's November 2024 update describes active care activities and needs displayed
above pets. Our inference: nearby readable feedback helps connect actions to an
individual pet. This project uses active feeding, nameplates and visible progression;
it does not import their assets or claim access to their implementation.
[Official release notes](https://www.playadopt.me/news/pet-needs-revamp).

Pet Simulator 99's first update documents collection acquisition hints and additional
upgrade choices. Our inference: show players where to find missing pets and give
cash several meaningful uses. This project uses habitat hints and four shelter
upgrade branches, keeping rescue/care as its theme.
[Official update](https://www.biggames.io/post/pet-simulator-99-update-1).

## Balance defaults

| Branch | First purchase | Second purchase |
| --- | --- | --- |
| Beds | 100 cash: 6 beds | 240 cash: 8 beds |
| Pantry | 65 cash: one drop every 3s | 160 cash: every 1.75s |
| Storage | 55 cash: 100 stored / 60 pending | 140 cash: 175 stored / 100 pending |
| Care | 90 cash: 25 XP per meal | 220 cash: 30 XP per meal |

Base feeding remains 20 XP, one food, per-pet 180-second cooldown. Walk/run speeds
are 16/26; pet follow speed is 32. Tune `shared/Config/GameConfig.luau`.
Rarity weights are normalized among tiers eligible in each habitat; they are not
global percentages across the three equally populated habitats.

## Studio verification still required

1. Build/open the latest place, restart Play, and wait for profile loading.
2. In fresh solo Play with `StudioPersistence=false`, run `tests/studio-m4.luau`
   in the **server** Command Bar. It uses pad polling and tests all upgrade tiers.
3. In another fresh Play run `tests/studio-economy.luau` for food, feeding,
   progression, discovery retention and NPC adoption.
4. Physically walk across claim/purchase pads; inspect actual pet art, rarity labels,
   index search, sprint controls, and six simultaneous rescue leashes. Test mobile.
5. With two clients, attempt another player's pads, feeding and adoption; verify
   neither ownership nor cash changes. Rejoin a private published test to verify
   real save/restore, without enabling Studio access to production data.
6. Run six clients for 15 minutes, repeating rescue/feed/adopt/upgrades. Watch Output,
   instance counts and frame rate. Verify no lingering NPCs, leashes or food visuals.

Standalone tests cover migration, bounded geometry, habitat eligibility, upgrade
stats, rollback and profile/claim initialization. The geometry preview uses the
actual part descriptors but a separate renderer; it does not prove Roblox rendering,
multiplayer behavior or mobile performance. Those gates remain pending while Studio
is in use by the developer.

## Completion evidence and remaining gates

| Requirement | Evidence now | Still required |
| --- | --- | --- |
| Restore walk-on shelter building | Actual-service regression covers profile-first join, claim callback, purchase and loading-on-pad edge | Run the pad polling test in Studio and physically walk the route |
| Better pet art | Original geometry preview reviewed; all 22 variants at four stages validate | Inspect Roblox lighting, silhouettes, animation and mobile frame rate |
| Overhead rarity colors | RarityStyles and nameplate controller implemented | Check readability, late replication and stage changes in two clients |
| Running | Actual server/client tests cover configured speed, spam, chat focus and release | Keyboard, controller, mobile and six leashed followers in Studio |
| Expanded spawning/index | Habitat rolls and registry verified; search/hints implemented | Actual spawn count, discovery UI and rejoin behavior |
| Model progression | Every configured stage has geometry and registry mapping | Actual art swap preserves prompt, root and identity during play |
| Deeper upgrades | All branches, rollback, stats and legacy save migration tested | All walk-on purchases, rebuilt conveyor visuals and private save/reload |
| Research | Official sources and applied design decisions recorded above | No research blocker |

Integration review also fixed machine-visual caches after kennel replacement and
Shift release while chat is focused. These changes do not remove the runtime gates.
