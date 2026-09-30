"""Reuse owner-uploaded font assets at a pinned revision, verified before bundling."""
import argparse
import hashlib
import json
import tempfile
import urllib.request
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'native/Resources/Fonts'
manifest = json.loads((folder / 'fonts.json').read_text(encoding='utf-8'))


def valid(data, expected):
    return (data[:4] == b'OTTO' and len(data) == expected['bytes']
            and hashlib.sha256(data).hexdigest() == expected['sha256'])


def prepare(source=None):
    for name, expected in manifest['files'].items():
        target = folder / name
        if target.is_file() and valid(target.read_bytes(), expected):
            print(f'Verified existing {name}')
            continue
        if source:
            data = (source / name).read_bytes()
        else:
            with urllib.request.urlopen(manifest['baseURL'] + name, timeout=120) as response:
                data = response.read(expected['bytes'] + 1)
        if not valid(data, expected):
            raise ValueError(f'Font integrity check failed: {name}')
        with tempfile.NamedTemporaryFile(dir=folder, suffix='.download', delete=False) as temporary:
            temporary.write(data)
            temporary_path = Path(temporary.name)
        try:
            temporary_path.replace(target)
        finally:
            temporary_path.unlink(missing_ok=True)
        print(f'Prepared verified {name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--from-directory', type=Path)
    prepare(parser.parse_args().from_directory)
