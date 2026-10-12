# Engagement and production-readiness milestone

This milestone extends existing shelter, pet, reward, adoption and persistence systems.
It does not depend on final pet models.

## Player-facing additions

- First-session NEXT markers point to claim, purchase, habitats, home, food controls
  and a sheltered pet. GOALS includes a two-step Skip Tutorial action.
- Pets receive one server-selected personality. Owners may assign a filtered custom
  name and favorite pets to block adoption.
- Pet, Brush, Play and Practice Walk grant small XP rewards with independent,
  server-clock, per-pet cooldowns. Care upgrades multiply those rewards.
- Each purchased shelter receives a rotating adopter request for a species, rarity
  or minimum level. Matches add 35 percent; ordinary adoption remains available.
- Shelter rebuilds visibly show the combined tier, branch levels and current adopter
  request. Higher pantry tiers display the second nozzle.
- Settings provide reduced motion, higher contrast and larger text locally. Roblox
  buttons remain selectable for keyboard/gamepad navigation.
- Daily goals can now include care and shelter upgrades.

## Security and persistence

PetAction still carries an action name, stable pet ID and one bounded detail value.
The server verifies profile readiness, ownership, proximity, pet state, favorite
protection, cooldowns and configured action IDs. Clients cannot submit XP, payout,
request bonuses, personalities or timestamps.

Profile schema 4 stores custom name, personality, favorite state and all care
deadlines. Versions 1 through 3 migrate with Gentle personality, no favorite and
ready care actions. Save retries use configurable count/delay values and expose only
a simple Saving/Saved/Retrying display state.

Adopter requests are session state. Their reward is calculated again on the server
when adoption begins. A completed matching adoption rotates the request only after
the NPC successfully exits.

## Balance controls

- src/shared/Pets/PetCare.luau: care XP and cooldowns, personality list.
- src/shared/Pets/AdoptionRequests.luau: duration, preference pools and match bonus.
- src/shared/Config/GameConfig.luau: upgrade benefits, saving, naming and economy.
- src/shared/Config/Rewards.luau: daily objectives and payouts.

Run python tools/simulate_balance.py after balance changes. It regenerates
docs/BALANCE_REPORT.md from central configuration values.

## Studio checks

1. Run tests/studio-engagement.luau in a fresh solo server Command Bar.
2. Open a sheltered pet and test Feed, Pet, Brush, Play and Practice Walk.
3. Repeat one care action; it must award no XP until its displayed cooldown expires.
4. Favorite the pet and confirm adoption is blocked; unfavorite and confirm it works.
5. Rename the pet, reset, then use a private persistence test to verify it survives.
6. Match and miss the adopter request; verify only the matching offer includes 35%.
7. Test NEXT markers, tutorial skipping, every settings toggle, phone landscape,
   phone portrait and gamepad focus.
8. Buy all upgrade branches and inspect the physical tier/request boards.
9. In multiplayer, verify another player cannot care for, rename, favorite or adopt
   pets they do not own.
