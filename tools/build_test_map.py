#!/usr/bin/env python3
# Writes testplace.project.json (rooftop test map + code) and default.project.json (code only).
# Run from the repo root: python3 tools/build_test_map.py, then rojo build testplace.project.json -o build/RooftopChaos.rbxl
import json, re, random

def cf(x, y, z):
    return {"CFrame": {"position": [x, y, z], "orientation": [[1, 0, 0], [0, 1, 0], [0, 0, 1]]}}

def part(size, pos, color, material, cls="Part", **extra):
    props = {"Anchored": True, "Size": size, "Color": color, "Material": material, "CFrame": cf(*pos)}
    props.update(extra)
    return {"$className": cls, "$properties": props}

def hidden(size, pos):
    return {"$className": "Part", "$properties": {"Anchored": True, "CanCollide": False, "CanQuery": False,
            "CanTouch": False, "Transparency": 1, "Size": size, "CFrame": cf(*pos)}}

ROOF_TOP = 100
STREET = -60
concrete, dark, brick = [0.62, 0.62, 0.65], [0.36, 0.36, 0.4], [0.55, 0.33, 0.28]
metal, danger = [0.8, 0.8, 0.82], [1, 0.35, 0.15]

def rooftop(name, cx, cz, w, d, roof_color, body_color):
    """A roof slab whose top is at ROOF_TOP, a building down to the street, and glowing edge strips."""
    items = {
        f"{name}Roof": part([w, 4, d], [cx, ROOF_TOP - 2, cz], roof_color, "Concrete"),
        f"{name}Building": part([w - 4, ROOF_TOP - 4 - STREET, d - 4],
                                [cx, (ROOF_TOP - 4 + STREET) / 2, cz], body_color, "Brick"),
    }
    # Thin glowing lines on the very edge so you can see where the drop is (too low to trip on).
    for side, (sx, sz, px, pz) in {"N": (w, 0.6, cx, cz - d / 2 + 0.3), "S": (w, 0.6, cx, cz + d / 2 - 0.3),
                                   "W": (0.6, d, cx - w / 2 + 0.3, cz), "E": (0.6, d, cx + w / 2 - 0.3, cz)}.items():
        items[f"{name}Edge{side}"] = part([sx, 0.1, sz], [px, ROOF_TOP + 0.05, pz], danger, "Neon", CanCollide=False)
    return items

workspace = {"$className": "Workspace", "$properties": {"FallenPartsDestroyHeight": 0}}
workspace.update(rooftop("Spawn", 0, 0, 60, 60, concrete, brick))
workspace.update(rooftop("Main", 0, -129, 110, 110, dark, [0.45, 0.42, 0.4]))
workspace["SpawnLocation"] = part([10, 1, 10], [0, ROOF_TOP + 0.5, 0], [0.95, 0.55, 0.15], "SmoothPlastic",
                                  cls="SpawnLocation", Neutral=True, Duration=0)
workspace["Bridge"] = part([6, 1, 44], [0, ROOF_TOP - 0.5, -52], [0.6, 0.45, 0.3], "WoodPlanks")

# Cover and obstacles on the main roof: slide around them, or bounce people into them.
props = {
    "AirConditionerA": ([8, 5, 6], [28, ROOF_TOP + 2.5, -108], metal, "Metal"),
    "AirConditionerB": ([6, 5, 8], [-34, ROOF_TOP + 2.5, -150], metal, "Metal"),
    "Stairwell": ([12, 9, 10], [-32, ROOF_TOP + 4.5, -100], concrete, "Concrete"),
    "WaterTank": ([9, 9, 9], [30, ROOF_TOP + 4.5, -160], [0.45, 0.32, 0.22], "Wood"),
    "CrateA": ([4, 4, 4], [8, ROOF_TOP + 2, -150], [0.7, 0.55, 0.35], "Wood"),
    "CrateB": ([4, 4, 4], [12, ROOF_TOP + 2, -147], [0.7, 0.55, 0.35], "Wood"),
}
for name, (size, pos, color, material) in props.items():
    workspace[name] = part(size, pos, color, material)
workspace["WaterTank"]["$properties"]["Shape"] = "Cylinder"
workspace["WaterTank"]["$properties"]["Size"] = [9, 9, 9]

workspace["SafeZones"] = {"$className": "Folder", "SpawnSafeZone": hidden([60, 30, 60], [0, ROOF_TOP + 15, 0])}
workspace["DummySpawns"] = {
    "$className": "Folder",
    "DummySpawnA": hidden([2, 1, 2], [0, ROOF_TOP + 0.5, -115]),
    "DummySpawnB": hidden([2, 1, 2], [-20, ROOF_TOP + 0.5, -140]),
    "DummySpawnC": hidden([2, 1, 2], [24, ROOF_TOP + 0.5, -170]),
}

# Scenery far below: a street and a skyline whose tops stay under the void, so nobody lands on them.
workspace["Street"] = part([1600, 2, 1600], [0, STREET - 1, -60], [0.18, 0.18, 0.2], "Asphalt")
random.seed(7)
skyline = {"$className": "Model"}
colors = [[0.32, 0.36, 0.45], [0.5, 0.42, 0.36], [0.28, 0.3, 0.34], [0.6, 0.55, 0.5], [0.4, 0.25, 0.25]]
placed = 0
while placed < 40:
    x, z = random.uniform(-420, 420), random.uniform(-520, 380)
    if -90 < x < 90 and -220 < z < 60:
        continue  # keep the play area clear
    w, d = random.uniform(30, 70), random.uniform(30, 70)
    top = random.uniform(-20, 18)
    skyline[f"Building{placed}"] = part([round(w), round(top - STREET), round(d)],
                                        [round(x), round((top + STREET) / 2, 1), round(z)],
                                        random.choice(colors), "Concrete", CanCollide=False, CastShadow=False)
    placed += 1
workspace["Skyline"] = skyline

code = {
    "ReplicatedStorage": {"$className": "ReplicatedStorage", "Shared": {"$path": "src/shared"}},
    "ServerScriptService": {"$className": "ServerScriptService", "Server": {"$path": "src/server"}},
    "StarterPlayer": {"$className": "StarterPlayer", "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts", "Client": {"$path": "src/client"}}},
}
lighting = {
    "$className": "Lighting",
    "$properties": {"ClockTime": 17.4, "Brightness": 2.5},
    "Atmosphere": {"$className": "Atmosphere", "$properties": {
        "Density": 0.32, "Offset": 0.15, "Haze": 1.4, "Glare": 0.5,
        "Color": [0.85, 0.72, 0.62], "Decay": [0.55, 0.42, 0.4]}},
}
place = {"name": "RooftopChaos", "tree": {"$className": "DataModel", "Workspace": workspace, "Lighting": lighting,
         "Players": {"$className": "Players", "$properties": {"RespawnTime": 2}}, **code}}

def write(path, data):
    text = json.dumps(data, indent=2)
    for _ in range(2):  # short number arrays and the 3x3 orientation on one line
        text = re.sub(r"\[\s*((?:-?[\d.]+|\[[^\[\]]*\])(?:\s*,\s*(?:-?[\d.]+|\[[^\[\]]*\]))*)\s*\]",
                      lambda m: "[" + re.sub(r"\s+", " ", m.group(1)).replace("[ ", "[").replace(" ]", "]") + "]",
                      text)
    open(path, "w").write(text + "\n")

write("testplace.project.json", place)
write("default.project.json", {"name": "RooftopChaos", "tree": {"$className": "DataModel", **code}})
