# M8 Studio verification checklist

Use a fresh session after syncing. Keep `StudioPersistence=false` except in a private
test experience dedicated to saving checks.

## Desktop

- Join, claim a plot, build the kennel, and visit Dog Park, Forest, and Cat Orchard.
- Confirm 18 pets occupy clearings without props/players/other pets overlapping.
- Rescue dog, cat, rabbit, and small-pet examples. Check -Z facing, ground height,
  acceleration, braking, turning, idle/run transitions, catch-up, and rare recovery.
- Check the leash meets the collar/chest without floating or passing through the body.
- Generate/collect food, feed, force a level/stage change, and complete an adoption.
- Verify HUD, Pet Index, goals, discovery reveal, quest completion, collection reward,
  and onboarding objective changes without overlapping full menus.

## Multiplayer (2–6 players)

- Claim separate plots and verify ownership, shelters, pets, food, index, and quests
  remain isolated.
- Attempt another player's feed, adoption, food collection, upgrade, pet ID, and reward
  claim. Confirm no mutation or payout.
- Rescue simultaneously, disconnect while following/adopting, and reuse the freed plot.
- Confirm habitat population remains bounded and one player cannot progress another's goals.

## Mobile and gamepad

- Test portrait and landscape. HUD and bottom buttons must remain on-screen.
- Open and scroll Pet Index and Goals; test filters, search, close, claim, and model cards.
- Open pet details in short landscape view; all three actions must remain readable/tappable.
- Verify E-equivalent prompts, gamepad focus, sprint toggle, and touch prompt actions.

## Persistence (private published test only)

- Save/rejoin with kennel/upgrades, food, pet GUID/definition/variant/rarity/level/XP,
  feeding deadline, discoveries, quest progress, collection claims, and guide step.
- Adopt a discovered pet, rejoin, and confirm the pet is gone while discovery remains.
- Test shutdown, expired/foreign lease, API failure, malformed data, and future schema.
  Good existing data must never be replaced with an empty profile.

## Assets, audio and performance

- Run `python tools/audit_pet_assets.py`; review every dependency listed.
- Test each reviewed stage for orientation, scale, root, attachments, rig animation,
  collisions, prompt position, nameplate height, leash, feeding, and adoption.
- Fill only approved audio slots; confirm category volume, one ambience loop, cue
  rate limits, cleanup, mute/unmute, and no sound pile-up.
- Run six clients for 15 minutes. Watch pet/food/NPC caps, frame time, network traffic,
  instance counts, and Output. Removed pets, tracks, connections, leashes, food, and
  adopters must clean up.

Automated checks still required before release: compile all Luau, run every pure suite,
run actual service regressions, run the static pet audit, regenerate the world preview,
and complete a Rojo build.
