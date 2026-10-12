"""Reject legacy or accidental map-sized floor parts before a place reaches Studio."""

from pathlib import Path
import json
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "default.project.json"
PREVIEW = ROOT / "world" / "ShelterPreview.rbxmx"
PLACE = ROOT / "Pet Rescue Shelter Tycoon.rbxlx"


def property_node(item: ET.Element, tag: str, name: str) -> ET.Element | None:
    """Returns one typed property node from a Roblox XML item."""
    properties = item.find("Properties")
    if properties is None:
        return None
    for node in properties.findall(tag):
        if node.get("name") == name:
            return node
    return None


def item_name(item: ET.Element) -> str:
    """Reads an item's Roblox Name property without relying on XML ordering."""
    node = property_node(item, "string", "Name")
    return node.text if node is not None and node.text else ""


def vector(item: ET.Element, property_name: str) -> tuple[float, float, float] | None:
    """Reads a Vector3 property as numeric coordinates."""
    node = property_node(item, "Vector3", property_name)
    if node is None:
        node = property_node(item, "Vector3", property_name.lower())
    if node is None:
        return None
    return tuple(float(node.find(axis).text) for axis in ("X", "Y", "Z"))


def color(item: ET.Element) -> tuple[float, float, float] | None:
    """Reads a Color3 property as normalized RGB values."""
    node = property_node(item, "Color3", "Color")
    if node is not None:
        return tuple(float(node.find(axis).text) for axis in ("R", "G", "B"))
    packed = property_node(item, "Color3uint8", "Color3uint8")
    if packed is None or packed.text is None:
        return None
    value = int(packed.text)
    return ((value >> 16 & 255) / 255, (value >> 8 & 255) / 255, (value & 255) / 255)


def audit_xml(path: Path, require_ground: bool) -> None:
    """Rejects legacy baseplates and any unexpected map-sized horizontal square."""
    root = ET.parse(path).getroot()
    items = list(root.iter("Item"))
    names = [item_name(item) for item in items]
    if "Baseplate" in names:
        raise AssertionError(f"{path.name} still contains the legacy gray Baseplate")

    grounds = [item for item in items if item_name(item) == "Ground"]
    if require_ground and len(grounds) != 1:
        raise AssertionError(f"{path.name} must contain exactly one generated Ground")

    for item in items:
        size = vector(item, "Size")
        if size and size[0] >= 400 and size[2] >= 400 and item_name(item) != "Ground":
            raise AssertionError(f"{path.name} contains unexpected map-sized floor {item_name(item)!r}")

    if grounds:
        size = vector(grounds[0], "Size")
        tint = color(grounds[0])
        if size != (768.0, 2.0, 768.0):
            raise AssertionError(f"Generated Ground has unexpected size {size}")
        if tint is None or tint[1] <= tint[0] or tint[1] <= tint[2]:
            raise AssertionError(f"Generated Ground is not visibly green: {tint}")


def main() -> None:
    """Audits the Rojo tree, edit preview, and latest built place."""
    project = json.loads(PROJECT.read_text(encoding="utf-8-sig"))
    workspace = project["tree"]["Workspace"]
    if "Baseplate" in workspace:
        raise AssertionError("default.project.json still maps the legacy gray Baseplate")
    audit_xml(PREVIEW, True)
    if not PLACE.is_file():
        raise AssertionError("Built place is missing; run the Rojo build before the world audit")
    audit_xml(PLACE, True)
    print("PASS: no legacy or accidental map-sized gray floor")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise


