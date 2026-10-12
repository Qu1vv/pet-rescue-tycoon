"""Run actual server modules under a minimal deterministic Roblox API test double.
Uses Luau from PATH, or an explicit executable passed as the first argument.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MODULES = {
    "Config": "src/shared/Config/GameConfig.luau",
    "RewardConfig": "src/shared/Config/Rewards.luau",
    "RewardState": "src/shared/Config/RewardState.luau",
    "Upgrades": "src/shared/Config/ShelterUpgrades.luau",
    "Catalog": "src/shared/Pets/PetCatalog.luau",
    "PetCare": "src/shared/Pets/PetCare.luau",
    "State": "src/server/Shelter/ShelterState.luau",
    "Data": "src/server/Persistence/ProfileData.luau",
    "Shelter": "src/server/Shelter/ShelterService.luau",
    "Profiles": "src/server/Persistence/ProfileService.luau",
    "Pads": "src/server/Shelter/PadService.luau",
    "Movement": "src/server/Players/MovementService.luau",
    "MovementClient": "src/client/Controllers/MovementController.luau",
}
header = ["local sources = {}"]
for name, relative in MODULES.items():
    source = (ROOT / relative).read_text(encoding="utf-8-sig")
    assert "]====]" not in source
    header.append(f'sources["{name}"] = [====[{source}]====]')
header.append((ROOT / "tests/service-regressions.luau").read_text(encoding="utf-8-sig"))
with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".luau", dir=ROOT / "tests", delete=False) as file:
    generated = Path(file.name)
    file.write("\n".join(header))
try:
    luau = sys.argv[1] if len(sys.argv) > 1 else shutil.which("luau")
    if not luau:
        raise SystemExit("Luau was not found. Pass the luau executable path as the first argument.")
    subprocess.run([luau, str(generated)], cwd=ROOT, check=True)
finally:
    generated.unlink()
