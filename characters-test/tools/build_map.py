#!/usr/bin/env python3
# Writes testplace.project.json (the "Characters Test" arena + code) and default.project.json (code only).
# Run from characters-test/: python3 tools/build_map.py, then
# rojo build testplace.project.json -o build/CharactersTest.rbxl
import json
import math
import re


def cf(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return {"CFrame": {"position": [round(x, 2), round(y, 2), round(z, 2)],
                       "orientation": [[round(c, 4), 0, round(s, 4)], [0, 1, 0], [round(-s, 4), 0, round(c, 4)]]}}


def part(size, pos, color, material, yaw=0.0, cls="Part", **extra):
    props = {"Anchored": True, "Size": size, "Color": color, "Material": material, "CFrame": cf(*pos, yaw)}
    props.update(extra)
    return {"$className": cls, "$properties": props}


STONE = [0.36, 0.34, 0.33]
DARK_STONE = [0.24, 0.22, 0.22]
TORII_RED = [0.72, 0.12, 0.1]
TORII_BLACK = [0.1, 0.09, 0.09]

workspace = {
    "$className": "Workspace",
    "Arena": part([420, 4, 420], [0, -2, 0], STONE, "Slate"),
    "Ring": part([0.2, 150, 150], [0, 0.05, 0], DARK_STONE, "Slate", Shape="Cylinder", CanCollide=False,
                 CFrame={"CFrame": {"position": [0, 0.05, 0],
                                    "orientation": [[0, -1, 0], [1, 0, 0], [0, 0, 1]]}}),
    "SpawnLocation": part([12, 1, 12], [0, 0.5, 40], [0.3, 0.75, 0.42], "SmoothPlastic",
                          cls="SpawnLocation", Neutral=True, Duration=0),
}

# Stone pillars around the edge of the arena.
pillars = {"$className": "Model"}
for i in range(10):
    angle = i / 10 * math.tau
    height = 28 + (i % 3) * 10
    pillars[f"Pillar{i}"] = part([9, height, 9], [math.cos(angle) * 150, height / 2, math.sin(angle) * 150],
                                 DARK_STONE, "Rock", yaw=angle)
workspace["Pillars"] = pillars

# Two red torii gates, a nod to Wano.
for name, z in (("ToriiNorth", -170), ("ToriiSouth", 170)):
    gate = {"$className": "Model"}
    for side in (-1, 1):
        gate[f"Post{'L' if side < 0 else 'R'}"] = part([3, 34, 3], [side * 16, 17, z], TORII_RED, "SmoothPlastic")
    gate["Kasagi"] = part([46, 3, 5], [0, 35.5, z], TORII_BLACK, "SmoothPlastic")
    gate["Nuki"] = part([38, 2, 3], [0, 28, z], TORII_RED, "SmoothPlastic")
    workspace[name] = gate

code = {
    "ReplicatedStorage": {"$className": "ReplicatedStorage", "Shared": {"$path": "src/shared"}},
    "ServerScriptService": {"$className": "ServerScriptService", "Server": {"$path": "src/server"}},
    "StarterPlayer": {"$className": "StarterPlayer", "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts", "Client": {"$path": "src/client"}}},
}
lighting = {
    "$className": "Lighting",
    "$properties": {"ClockTime": 17.8, "Brightness": 2.4},
    "Atmosphere": {"$className": "Atmosphere", "$properties": {
        "Density": 0.3, "Offset": 0.1, "Haze": 1.6, "Glare": 0.6,
        "Color": [0.9, 0.62, 0.5], "Decay": [0.55, 0.32, 0.3]}},
    "Sky": {"$className": "Sky", "$properties": {"CelestialBodiesShown": True, "StarCount": 3000}},
}
place = {"name": "CharactersTest", "tree": {"$className": "DataModel", "Workspace": workspace, "Lighting": lighting,
         "Players": {"$className": "Players", "$properties": {"RespawnTime": 3}}, **code}}


def write(path, data):
    text = json.dumps(data, indent=2)
    for _ in range(2):  # short number arrays and the 3x3 orientation on one line
        text = re.sub(r"\[\s*((?:-?[\d.]+|\[[^\[\]]*\])(?:\s*,\s*(?:-?[\d.]+|\[[^\[\]]*\]))*)\s*\]",
                      lambda m: "[" + re.sub(r"\s+", " ", m.group(1)).replace("[ ", "[").replace(" ]", "]") + "]",
                      text)
    open(path, "w").write(text + "\n")


write("testplace.project.json", place)
write("default.project.json", {"name": "CharactersTest", "tree": {"$className": "DataModel", **code}})
