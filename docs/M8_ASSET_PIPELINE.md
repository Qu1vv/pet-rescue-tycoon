# M8 pet asset contract and replacement workflow

## Required model contract

Every active pet resolves through `PetModelContract` and `PetAssets` before it is
built. The server normalizer enforces:

- one direct `Root` BasePart used as `PrimaryPart`;
- local **-Z** as forward, with any reviewed yaw correction stored in the registry;
- ground offset, scale, descendant/bounds budgets, and species profile IDs;
- direct `Root.LeashAttachment` and `Root.PromptAttachment` positions;
- non-colliding, non-touching, non-querying visual parts;
- anchored procedural models, or an explicitly reviewed `Motor6D` rig mode;
- no scripts, remotes, bindables, ObjectValues, prompts, sounds, particles, UI,
  forces, or unapproved constraints inside the imported model.

The logical pet record owns identity, XP, level, rarity, variant, owner, slot, and
cooldowns. A stage/model swap replaces presentation only. Saved profiles contain
stable definition/variant IDs rather than model paths, so approved art can change
without a data migration.

## Repeatable replacement steps

1. Import the model into an isolated inspection place, never directly into the game.
2. Inspect every descendant and remove scripts, remotes, bindables, ObjectValues,
   UI, sounds, particles, forces, unrelated constraints, and hidden content.
3. Verify creator permission, license, mesh/texture ownership, triangle count,
   materials, rig, animations, and the complete dependency list.
4. Face the animal toward local **-Z**. Put its feet at the intended ground plane.
5. Add a direct `Root` BasePart and make it the PrimaryPart. The normalizer can add
   one for testing, but an approved production model should author it deliberately.
6. Add or verify `Root.LeashAttachment`; place it at the collar/chest. Add
   `Root.PromptAttachment` above the body. Registry offsets remain the final authority.
7. Disable collisions/touch/query. Use a `Motor6D`/bone rig only when every visual
   part is connected and the registry explicitly declares `RigMode="Motor6D"`.
8. Export as XML `.rbxmx` beneath
   `src/server/Pets/PetModels/<DefinitionId>/<Stage>.rbxmx`. Binary `.rbxm` files are
   rejected because the static audit cannot inspect them.
9. Run `python tools/audit_pet_assets.py`. Resolve every blocking finding and manually
   review every printed mesh, texture, and animation dependency.
10. Set the model attribute `Reviewed=true`. In `PetAssets.luau`, add one entry to
    the local `approved` override table for that logical stage with
    `Status="Reviewed"`, source, creator, permission, review date, scale/yaw/offsets,
    rig mode, and dependency-review flags.
11. Confirm the catalog stage uses that logical key. Movement and animation profile
    IDs belong on the definition/asset configuration, not gameplay scripts.
12. Build and test spawn position, facing, ground height, idle/walk/run/eat/happy,
    leash alignment, acceleration, stopping, stuck recovery, and adoption exit.
13. Force a model-stage change and confirm identity, XP, rarity, variant, ownership,
    prompt, leash, and cooldown survive.
14. Test save/rejoin and the Pet Index preview/locked/discovered states before approval.

## Registry status

`GeneratedPlaceholder` means the current original procedural plush geometry is used.
`Reviewed` means a local model passed inspection and is eligible for cloning. No
runtime Marketplace loading exists. Missing, rejected, oversized, or unreviewed files
fall back to the safe generated model and emit a server warning.

## Current asset checklist

No third-party models are approved. The working catalog uses one consistent generated
plush style for Golden Retriever, Labrador, Husky, Corgi, Shiba Inu, German Shepherd,
House Cat, Siamese, Persian, Bunny, Woodland Rabbit, Hamster, and Guinea Pig across
four configured stages. These are production-safe placeholders, not final commissioned art.

Still needed from one cohesive lightweight art pack:

- **Dogs:** puppy/young/adult/champion models for the six current breeds.
- **Cats:** a compatible base rig/material set for House Cat, Siamese, and Persian.
- **Rabbits:** upright and lop-compatible rabbit rigs for Bunny and Woodland Rabbit.
- **Small pets:** readable Hamster and Guinea Pig rigs at their smaller world scale.
- **Animations:** Idle, Walk, Run, Eat, Happy, and Adoption for each compatible rig family.
- **Audio:** UI hover/click/menu/reward, rescue/feed/level/discovery/adoption, food
  drop/collect/upgrade, and subtle Dog Park/Forest/Orchard ambience.
- **UI:** optional owned icon set for cash, food, pets, goals, collection, locked,
  feed, and adoption. Current text/cards remain functional without it.

Do not invent asset IDs or combine unrelated styles to fill this list.
