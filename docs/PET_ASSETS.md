# Pet asset pipeline and catalog

## Shipped catalog

All assets are original procedural geometry, with rounded heads, large eyes,
collars, breed/ear silhouettes and coat patches. These are replaceable placeholders,
not finished breed sculpts. No Marketplace models, asset IDs, meshes, textures,
animations or third-party scripts were imported for this milestone.

| Definition | Variants and rarity |
| --- | --- |
| Golden Retriever | Golden, Cream — Common |
| Labrador | Chocolate — Common; Black — Uncommon |
| Husky | Gray — Rare; White — Epic |
| Corgi | Fawn — Uncommon |
| Shiba Inu | Sesame — Legendary |
| House Cat | Orange, Black — Common; Tuxedo — Uncommon; Calico — Rare |
| Siamese | Seal Point — Epic |
| Bunny | White — Rare; Cream Lop — Mythic |
| Woodland Rabbit | Chestnut — Common; Silver — Uncommon |
| German Shepherd | Sable — Rare |
| Persian | Pearl — Epic; Silver — Legendary |
| Hamster | Honey — Common; Panda — Uncommon |
| Guinea Pig | Ginger — Uncommon; Tricolor — Rare |

Thirteen definitions, twenty-four discoverable variants. Rarity weights are rolled first,
then eligible variants within the selected tier use definition × variant weights.
Habitat species rules and rarity weights are applied before selection. Spawn zones and
future event tags are data fields, without a rare-event system.

Each definition currently maps levels 1/5/10/20 to Puppy/Young/Adult/Champion keys.
Names are technical stage keys, including for cats and rabbits. Placeholder tiers
change size (0.82/0.95/1.08/1.15), collar, bows and champion crown; they do not require new gameplay
records. Per-species thresholds and keys live in `PetCatalog.ModelProgression`.

## Replace a model without changing gameplay

Use the current repeatable contract and fourteen-step workflow in
[M8_ASSET_PIPELINE.md](M8_ASSET_PIPELINE.md). The summary below is retained for quick reference.

Example registry key: `GoldenRetriever.Puppy` maps to
`ServerScriptService.Server.Pets.PetModels.GoldenRetriever.Puppy`.

1. Obtain a permitted model in an isolated Studio inspection place. Prefer a single
   cohesive commissioned/approved model-only pack. Record source URL, creator,
   license/permission, reviewer and date. Do not invent or guess asset IDs.
2. Inspect **all descendants before putting the file under the server mapping**.
   Remove every Script/LocalScript/ModuleScript, remote, prompt, sound, emitter,
   hidden object and unnecessary physics constraint. A script already placed in
   ServerScriptService could run before clone sanitization; the loader is not a
   security review substitute.
3. Check style and silhouette together with the other pets. Inspect triangle count,
   mesh/texture dependencies and permissions, rig hierarchy, bones, animation
   compatibility, collision geometry and descendant count. Aim initially for
   approximately 2–5k triangles, few materials and few moving parts per pet; measure
   the configured maximum population plus six adopters on a low-end mobile device before accepting the budget.
4. Use a ground-level direct-child `Root` BasePart as `PrimaryPart`; face local
   **-Z**, feet at **Y=0**. The normalizer owns `Root.LeashAttachment` and
   `Root.PromptAttachment` using registry offsets. Keep bounds near 4×5×5 studs
   (the default diagonal limit is 12). Procedural parts are anchored and non-colliding.
   A fully connected rig may opt into reviewed `RigMode="Motor6D"`.
5. Set the model attribute `Reviewed=true` after inspection. Save the model locally
   as `src/server/Pets/PetModels/GoldenRetriever/Puppy.rbxmx`. Its existing folder mapping
   becomes `PetModels.GoldenRetriever.Puppy`; do not edit `default.project.json`.
6. In `src/shared/Pets/PetAssets.luau`, mark that registry entry `Status="Reviewed"`, keep
   its path segments, and record verified provenance in `Source` plus this document.
   Current entries are `GeneratedPlaceholder`, so only original geometry is used.
7. Repeat for stage files or point several stage keys at the same reviewed model.
   Change stage `Scale` to 1 for pre-sized art. Variant colors/patterns belong in
   catalog data. A variant may provide its own `ModelProgression`, or a
   `ModelOverrides = { ["HouseCat.Puppy"] = "Tuxedo.Puppy" }` table. Register each
   override key in `PetAssets`; its model can carry variant-specific textures.
8. Rebuild and test spawning, six simultaneous rescue leashes, delivery, feeding,
   stage changes, NPC adoption, save/reload and all mobile distances. A stage swap
   must retain the outer pet Model, live Root/prompt, GUID, owner, rarity, variant,
   XP and feeding deadline. It changes art only.

The static audit and runtime loader reject executable/networked/unrelated descendants;
they do not silently bless them by stripping them. Normalization applies root,
attachment, orientation, scale, bounds, collision and rig policy. Missing or
incompatible reviewed templates fall back to original geometry. Runtime asset
downloading is never used.

## Manual sourcing shortlist

Direct Marketplace model-content inspection is unavailable in this environment.
No new listing has been approved or imported. Source these together in one style:

1. Puppy/young/adult Golden Retriever, Labrador, Husky, Corgi and Shiba Inu.
2. One adaptable cat rig with orange, black, tuxedo, calico and Siamese materials.
3. One rabbit with upright and lop ears.
4. Later additions: German Shepherd, Pug, Beagle, Persian, hamster and guinea pig.

Candidate evaluation record (complete before importing):

| Source/creator/license | Style/quality | Triangles/parts/materials | Rig/animation | Scripts/extra descendants | Mesh/texture permissions | Mobile stress result | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Not sourced yet | Match the catalog | Measure | Inspect | Must be model-only | Verify | Test 48 pets | Unapproved |

References: [Roblox assets](https://create.roblox.com/docs/projects/assets),
[third-party asset security](https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities).
