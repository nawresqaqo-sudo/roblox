#!/usr/bin/env python3
# Checks what Luau's type checker can't see, because it all goes through strings: every effect the server
# plays has a client handler, every payload field a handler reads is sent, and Sasuke's sound cues match
# between Shared.Characters.Sasuke.Sounds, the stand-ins in Vfx/Sasuke/Kit and the cues actually played.
# Run from characters-test/: python3 tools/check_effects.py
import re, sys, pathlib
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
problems = []

def table_literal(text, start):
    """Return the {...} literal starting at index `start` (which must be '{')."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == '{': depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0: return text[start:i+1]
    return text[start:]

def top_keys(literal):
    keys, depth = set(), 0
    for m in re.finditer(r'[{}]|(\b[A-Za-z_]\w*)\s*=(?!=)', literal):
        tok = m.group(0)
        if tok == '{': depth += 1
        elif tok == '}': depth -= 1
        elif depth == 1: keys.add(m.group(1))
    return keys

# Effects the server plays, with the payload keys it sends.
sent = {}
for f in (root / 'src/server').rglob('*.luau'):
    text = f.read_text()
    for m in re.finditer(r'Vfx\.play\("([\w.]+)",\s*', text):
        brace = text.index('{', m.end() - 1)
        sent.setdefault(m.group(1), set()).update(top_keys(table_literal(text, brace)))

# Client handlers and the payload fields each one reads.
handlers = {}
vfx = root / 'src/client/Vfx'
def scan(path, prefix):
    text = path.read_text()
    funcs = list(re.finditer(r'^function (\w+)\.(\w+)\(payload', text, re.M))
    for i, m in enumerate(funcs):
        body = text[m.end(): funcs[i+1].start() if i + 1 < len(funcs) else len(text)]
        handlers[f'{prefix}.{m.group(2)}'] = set(re.findall(r'payload\.(\w+)', body))
for f in vfx.glob('*.luau'):
    scan(f, f.stem)
for folder in [p for p in vfx.iterdir() if p.is_dir()]:
    for f in folder.glob('*.luau'):
        if f.stem not in ('init', 'Kit'):
            scan(f, folder.name)

for effect, keys in sorted(sent.items()):
    if effect not in handlers:
        problems.append(f'server plays "{effect}" but no client handler exists')
        continue
    missing = handlers[effect] - keys - {'id'}
    if missing:
        problems.append(f'"{effect}": client reads payload.{sorted(missing)} that the server never sends')
for effect in sorted(handlers):
    if effect.startswith('Sasuke.') and effect not in sent:
        problems.append(f'client handler "{effect}" is never played by the server')

# Sound cues: shared Sounds table vs the client's stand-ins vs every cue used.
shared = (root / 'src/shared/Characters/Sasuke.luau').read_text()
sounds = set(re.findall(r'^\t(\w+) = "",', table_literal(shared, shared.index('{', shared.index('local Sounds'))), re.M))
kit = (root / 'src/client/Vfx/Sasuke/Kit.luau').read_text()
stand_ins = set(re.findall(r'^\t(\w+) = \{ sound', kit, re.M))
used = set()
for f in (vfx / 'Sasuke').glob('*.luau'):
    used.update(re.findall(r'Kit\.(?:sound|loop)\("(\w+)"', f.read_text()))
if sounds != stand_ins:
    problems.append(f'Sounds vs stand-ins differ: {sorted(sounds ^ stand_ins)}')
if used - sounds:
    problems.append(f'cues used but not configured: {sorted(used - sounds)}')
if sounds - used:
    problems.append(f'cues configured but never played: {sorted(sounds - used)}')

print(f'effects played by server: {len(sent)}, client handlers: {len(handlers)}, sound cues: {len(sounds)} ({len(used)} used)')
for p in problems: print('PROBLEM:', p)
sys.exit(1 if problems else 0)
