import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import tempfile
import time

NAME = re.compile(r'(full|proof)-([0-9]{10})-([0-9]+)\.cms')
DAY = 86400
BJT = dt.timezone(dt.timedelta(hours=8))


def period(timestamp):
    """The backup day begins at 03:15 in Shanghai."""
    return (dt.datetime.fromtimestamp(timestamp, BJT) - dt.timedelta(hours=3, minutes=15)).date()


def sync_dir(directory):
    fd = os.open(directory, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_json(path, value, mode=0o600):
    path = pathlib.Path(path)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.write-', delete=False) as file:
        pending = pathlib.Path(file.name)
        try:
            os.fchmod(file.fileno(), mode)
            file.write(json.dumps(value, sort_keys=True).encode() + b'\n')
            file.flush()
            os.fsync(file.fileno())
            os.replace(pending, path)
            sync_dir(path.parent)
        finally:
            pending.unlink(missing_ok=True)


def read_json(path, default=None):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default


def checksum(path):
    digest = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def prune(directory, keep, full_days, proof_days, now=None):
    now = time.time() if now is None else now
    removed = 0
    for item in directory.iterdir():
        match = NAME.fullmatch(item.name)
        if not match or not item.is_file() or item.is_symlink() or item.name in keep:
            continue
        days = full_days if match[1] == 'full' else proof_days
        if now - int(match[2]) >= days * DAY:
            item.unlink()
            removed += 1
    if removed:
        sync_dir(directory)
    return removed
