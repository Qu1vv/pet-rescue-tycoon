"""Fail closed on unsafe checked-in Roblox pet templates before a Rojo build."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "src" / "server" / "Pets" / "PetModels"
FORBIDDEN = {
    "Script", "LocalScript", "ModuleScript", "RemoteEvent", "RemoteFunction",
    "BindableEvent", "BindableFunction", "ObjectValue", "ProximityPrompt",
    "ClickDetector", "Sound", "ParticleEmitter", "Trail", "Beam",
    "BillboardGui", "SurfaceGui", "ScreenGui", "Humanoid",
    "RopeConstraint", "SpringConstraint", "VectorForce", "LinearVelocity",
    "AngularVelocity", "BodyPosition", "BodyVelocity", "BodyGyro",
}
REFERENCE_PROPERTIES = {"MeshId", "TextureID", "TextureId", "AnimationId"}


def property_text(item: ET.Element, name: str) -> str:
    """Return a serialized property value without interpreting Roblox binary metadata."""
    props = item.find("Properties")
    if props is None:
        return ""
    for value in props:
        if value.attrib.get("name") == name:
            return (value.text or "").strip()
    return ""


def audit(path: Path) -> tuple[list[str], list[str]]:
    """Audit one XML model and return blocking findings plus dependency references."""
    findings: list[str] = []
    dependencies: list[str] = []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        return [f"invalid XML: {exc}"], dependencies
    top = root.find("Item")
    if top is None or top.attrib.get("class") != "Model":
        findings.append("top-level Roblox item must be a Model")
    items = list(root.iter("Item"))
    if len(items) > 181:
        findings.append(f"descendant budget exceeded: {len(items) - 1} > 180")
    names: list[str] = []
    for item in items:
        class_name = item.attrib.get("class", "")
        name = property_text(item, "Name") or class_name
        names.append(name)
        if class_name in FORBIDDEN or class_name.endswith("Constraint"):
            findings.append(f"forbidden {class_name}: {name}")
        for prop in REFERENCE_PROPERTIES:
            value = property_text(item, prop)
            if value:
                dependencies.append(f"{name}.{prop}={value}")
                if not re.fullmatch(r"(?:rbxassetid://)?\d+", value):
                    findings.append(f"unexpected {prop} format on {name}")
    if "Root" not in names:
        findings.append("missing direct model Root; normalizer can create one, but approval requires review")
    return findings, dependencies


def main() -> int:
    """Audit every source-controlled XML pet and reject unsupported binary model files."""
    if not ASSET_ROOT.exists():
        print("PASS: no third-party pet templates are checked in")
        return 0
    binary = sorted(ASSET_ROOT.rglob("*.rbxm"))
    files = sorted(ASSET_ROOT.rglob("*.rbxmx"))
    failures: list[str] = [f"{path}: binary .rbxm cannot be statically audited; export as .rbxmx" for path in binary]
    for path in files:
        findings, dependencies = audit(path)
        print(f"AUDIT {path.relative_to(ROOT)}")
        for dependency in dependencies:
            print(f"  REVIEW DEPENDENCY: {dependency}")
        for finding in findings:
            failures.append(f"{path.relative_to(ROOT)}: {finding}")
    if failures:
        print("PET ASSET AUDIT FAILED", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"PASS: {len(files)} checked-in pet templates contain no blocked descendants")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
