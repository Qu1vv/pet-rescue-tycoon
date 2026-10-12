"""Execute real Luau world builders with a geometry adapter, then export edit-mode Roblox XML."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MODULES = {"Config":"shared/Config/GameConfig", "Biomes":"shared/Config/Biomes",
 "Upgrades":"shared/Config/ShelterUpgrades", "WorldBuilder":"server/World/WorldBuilder",
 "PlotBuilder":"server/World/PlotBuilder", "BiomeBuilder":"server/World/BiomeBuilder",
 "LegacyWorldCleanup":"server/World/LegacyWorldCleanup", "BuildUtil":"server/Common/BuildUtil",
 "PetHousing":"shared/Pets/PetHousing"}
chunks = ["local sources={}"]
for name, path in MODULES.items():
    source = (ROOT / "src" / (path + ".luau")).read_text(encoding="utf-8-sig")
    assert "]====]" not in source
    chunks.append(f'sources["{name}"]=[====[{source}]====]')
chunks.append((ROOT / "tools/world_export.luau").read_text(encoding="utf-8"))
with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".luau", delete=False, dir=ROOT/"tools") as f:
    f.write("\n".join(chunks)); generated = Path(f.name)
try:
    luau = sys.argv[1] if len(sys.argv) > 1 else shutil.which("luau")
    if not luau:
        raise SystemExit("Luau was not found. Pass the luau executable path as the first argument.")
    result = subprocess.run([luau, str(generated)], capture_output=True, text=True, encoding="utf-8", check=True)
    data = json.loads(result.stdout)
finally:
    generated.unlink()

enums = {"SurfaceType":{"Smooth":0}, "PartType":{"Ball":0,"Block":1,"Cylinder":2},
 "Material":{"SmoothPlastic":272,"Grass":1280,"Wood":512}, "Font":{"GothamBold":19},
 "NormalId":{"Front":5,"Top":1}, "SurfaceGuiSizingMode":{"PixelsPerStud":0}}
def value(parent, name, v):
    """Encode the Roblox property types used by the shared geometry builders."""
    if isinstance(v,bool): ET.SubElement(parent,"bool",name=name).text=str(v).lower()
    elif isinstance(v,str): ET.SubElement(parent,"string",name=name).text=v
    elif isinstance(v,(int,float)): ET.SubElement(parent,"float",name=name).text=str(v)
    elif isinstance(v,dict):
        kind=v.get("Kind")
        if kind=="Enum": ET.SubElement(parent,"token",name=name).text=str(enums.get(v["Category"],{}).get(v["Name"],0))
        elif kind=="Ref": ET.SubElement(parent,"Ref",name=name).text="RBX"+str(v["Id"])
        elif kind in ("Vector3","Color3","UDim2"):
            node=ET.SubElement(parent,kind,name=name)
            for k in {"Vector3":["X","Y","Z"],"Color3":["R","G","B"],"UDim2":["XS","XO","YS","YO"]}[kind]: ET.SubElement(node,k).text=str(v[k])
        elif kind=="CFrame":
            node=ET.SubElement(parent,"CoordinateFrame",name=name)
            for k in ["X","Y","Z"]: ET.SubElement(node,k).text=str(v["Position"][k])
            for i,n in enumerate(v["R"]): ET.SubElement(node,f"R{i//3}{i%3}").text=str(n)
def item(parent, obj):
    """Write preview-only geometry, disabling all decorative spawn locations."""
    node=ET.SubElement(parent,"Item",{"class":obj["ClassName"],"referent":"RBX"+str(obj["Id"])})
    props=ET.SubElement(node,"Properties")
    for name,v in obj.items():
        if name in {"ClassName","Children","Attributes","Kind","Id"}: continue
        value(props,name,False if obj["ClassName"]=="SpawnLocation" and name=="Enabled" else v)
    for child in obj.get("Children",[]): item(node,child)
    return node
xml=ET.Element("roblox",version="4")
ET.SubElement(xml,"External").text="null"
ET.SubElement(xml,"External").text="nil"
item(xml,data)
output=ROOT/"world"/"ShelterPreview.rbxmx"
output.parent.mkdir(exist_ok=True)
ET.indent(xml)
ET.ElementTree(xml).write(output,encoding="utf-8",xml_declaration=True)
print(f"Exported {len(list(xml.iter('Item')))} preview instances to {output}")

