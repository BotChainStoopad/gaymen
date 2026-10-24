"""Tiny NBT writer used to emit vanilla structure templates (.nbt, gzipped)."""
import gzip
import struct

TAG_END, TAG_BYTE, TAG_INT, TAG_DOUBLE, TAG_STRING, TAG_LIST, TAG_COMPOUND = 0, 1, 3, 6, 8, 9, 10


class Int(int):
    pass


class Byte(int):
    pass


class Double(float):
    pass


class List(list):
    """List with an explicit element tag id (needed for empty lists)."""

    def __init__(self, elem_tag, items=()):
        super().__init__(items)
        self.elem_tag = elem_tag


def _tag_id(v):
    if isinstance(v, Byte):
        return TAG_BYTE
    if isinstance(v, bool):
        return TAG_BYTE
    if isinstance(v, (Int, int)):
        return TAG_INT
    if isinstance(v, (Double, float)):
        return TAG_DOUBLE
    if isinstance(v, str):
        return TAG_STRING
    if isinstance(v, list):
        return TAG_LIST
    if isinstance(v, dict):
        return TAG_COMPOUND
    raise TypeError(type(v))


def _str(s):
    b = s.encode("utf-8")
    return struct.pack(">H", len(b)) + b


def _payload(v):
    t = _tag_id(v)
    if t == TAG_BYTE:
        return struct.pack(">b", int(v))
    if t == TAG_INT:
        return struct.pack(">i", int(v))
    if t == TAG_DOUBLE:
        return struct.pack(">d", float(v))
    if t == TAG_STRING:
        return _str(v)
    if t == TAG_LIST:
        elem = v.elem_tag if isinstance(v, List) else (_tag_id(v[0]) if v else TAG_END)
        out = struct.pack(">bi", elem, len(v))
        for item in v:
            out += _payload(item)
        return out
    out = b""
    for k, item in v.items():
        out += struct.pack(">b", _tag_id(item)) + _str(k) + _payload(item)
    return out + struct.pack(">b", TAG_END)


def write(path, root):
    data = struct.pack(">b", TAG_COMPOUND) + _str("") + _payload(root)
    with gzip.open(path, "wb") as f:
        f.write(data)


class Template:
    """Collects blocks/entities and serialises them as a structure template."""

    def __init__(self, data_version=3955):
        self.blocks = {}
        self.block_nbt = {}
        self.entities = []
        self.data_version = data_version

    def set(self, x, y, z, name, props=None, nbt=None):
        self.blocks[(x, y, z)] = (name, tuple(sorted((props or {}).items())))
        if nbt is not None:
            self.block_nbt[(x, y, z)] = nbt

    def get(self, x, y, z):
        return self.blocks.get((x, y, z))

    def add_entity(self, x, y, z, nbt):
        self.entities.append((x, y, z, nbt))

    def save(self, path):
        xs = [p[0] for p in self.blocks]
        ys = [p[1] for p in self.blocks]
        zs = [p[2] for p in self.blocks]
        mx, my, mz = min(xs), min(ys), min(zs)
        palette, index, blocks = [], {}, []
        for pos in sorted(self.blocks, key=lambda p: (p[1], p[2], p[0])):
            state = self.blocks[pos]
            if state not in index:
                index[state] = len(palette)
                entry = {"Name": state[0]}
                if state[1]:
                    entry["Properties"] = dict(state[1])
                palette.append(entry)
            b = {"pos": List(TAG_INT, [Int(pos[0] - mx), Int(pos[1] - my), Int(pos[2] - mz)]),
                 "state": Int(index[state])}
            if pos in self.block_nbt:
                b["nbt"] = self.block_nbt[pos]
            blocks.append(b)
        ents = List(TAG_COMPOUND)
        for x, y, z, nbt in self.entities:
            ents.append({
                "pos": List(TAG_DOUBLE, [Double(x - mx), Double(y - my), Double(z - mz)]),
                "blockPos": List(TAG_INT, [Int(int(x // 1) - mx), Int(int(y // 1) - my), Int(int(z // 1) - mz)]),
                "nbt": nbt,
            })
        size = [max(xs) - mx + 1, max(ys) - my + 1, max(zs) - mz + 1]
        write(path, {
            "DataVersion": Int(self.data_version),
            "size": List(TAG_INT, [Int(s) for s in size]),
            "palette": List(TAG_COMPOUND, palette),
            "blocks": List(TAG_COMPOUND, blocks),
            "entities": ents,
        })
        return size
