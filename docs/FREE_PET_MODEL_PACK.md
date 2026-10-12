# Free Starter Pet Pack

The project now includes a local **Free Starter Pet Pack** in
`src/shared/Pets/PetModelPacks.luau`. It covers Golden Retriever, House Cat, Bunny,
Hamster, and Guinea Pig across Puppy, Young, Adult, and Champion stages.

These are the existing original procedural plush models, not downloaded Marketplace
content. They are therefore free to use in this game, have no external mesh or texture
dependencies, and work with the current rescue, leash, adoption, and stage-swap code.

## How to get genuinely free third-party models

In Studio, use Toolbox → Creator Store and search for a model-only pack. Before using
one, inspect every descendant in an isolated place, remove scripts and unrelated
objects, and verify that the creator permits the model and all child meshes/textures.
Roblox notes that Creator Store models can contain malicious scripts, and that asset
privacy determines whether a mesh or texture can load in your experience.

This repository intentionally does not paste a Marketplace asset ID into the game or
load models at runtime. To approve a third-party replacement:

1. Import it into an isolated Studio place and inspect all descendants.
2. Export a clean XML model to `src/server/Pets/PetModels/<Definition>/<Stage>.rbxmx`.
3. Ensure it has a direct `Root` part, faces local `-Z`, stays within the size and
   descendant budgets, and contains no scripts, prompts, sounds, particles, remotes,
   or unreviewed dependencies.
4. Set `Reviewed=true`, add verified provenance to `PetAssets.luau`, then run:
   `python tools/audit_pet_assets.py`
5. Test spawning, feeding, leashing, adoption, stage changes, save/reload, and mobile
   performance before treating it as production art.

The relevant Roblox references are [Creator Store](https://create.roblox.com/docs/production/creator-store),
[Assets and permissions](https://create.roblox.com/docs/projects/assets), and
[third-party asset security](https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities).
