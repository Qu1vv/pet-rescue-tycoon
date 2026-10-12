# Unattended development and release gate

This pass adds two asset-independent player tools and a complete pre-Studio release
gate. It deliberately leaves final pet models, environment art, and the full modern
UI polish pass for the next art-focused milestone.

## Player tools

### My Pets

MyPetsController reads the server-authored pet models already replicated in
Workspace.ShelterWorld.Pets. It shows owned pet names, favorite state, level, XP,
rarity, variant, personality, feeding readiness, care readiness, and adopter-request
matches. Filters cover all pets, favorites, feeding-ready pets, and request matches.

Locate creates an eight-second local marker and highlight. It does not teleport,
feed, care for, rename, favorite, or adopt a pet. Those actions still require the
existing nearby world prompt and the validated PetAction server endpoint.

### Shelter dashboard

ShelterDashboardController reads the player's current plot attributes and shows:

- occupied and maximum pet capacity;
- stored and pending food capacity;
- pantry production interval;
- shelter tier;
- current adopter request and refresh time;
- current and next tier for Beds, Pantry, Storage, and Care.

The dashboard is read-only. Upgrade purchases still happen on the server-observed
physical pads, so the client cannot choose a price or tier.

## One-command release gate

Run tools/release_check.py with Python from the repository root.

The command performs these steps and stops at the first failure:

1. compile every Luau source file;
2. discover and run every standalone spec in tests;
3. run the actual service regression harness;
4. audit the pet asset registry and checked-in templates;
5. regenerate the balance report;
6. regenerate the edit-mode world preview;
7. build the place with pinned Rojo 7.7.0;
8. reject legacy or accidental map-sized floor parts;
9. write docs/RELEASE_CHECK_REPORT.md.

Optional local tool paths can be supplied with --luau, --luau-compile, and --rojo.
The gate does not open Studio, access the network, or publish the game.

## Studio checks still required

After this gate passes, verify the two new menus in solo and six-client Studio
sessions. Test small phone and gamepad layouts, roster filtering, locate cleanup,
dashboard live updates, request countdowns, and every existing world interaction.
Published DataStore behavior and the six-player place setting also require a private
published test experience.

