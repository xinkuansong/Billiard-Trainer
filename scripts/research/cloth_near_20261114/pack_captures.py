"""Retain native GPU captures as verified archives, including internal links."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import tarfile


def digest(stream):
    h = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b''):
        h.update(block)
    return h.hexdigest()


def pack(work, evidence, from_evidence=False, names=('baseline', 'lamp-mask', 'squared')):
    destination = work / 'captures'
    destination.mkdir(exist_ok=True)
    reports = []
    for name in names:
        trace = (evidence if from_evidence else destination) / (name + '.gputrace')
        assert trace.is_dir() and not trace.is_symlink()
        records = {}
        for path in sorted(trace.rglob('*')):
            key = str(path.relative_to(trace))
            if path.is_symlink():
                assert path.resolve(strict=True).is_relative_to(trace.resolve()), path
                records[key] = {'link': os.readlink(path)}
            elif path.is_file():
                with path.open('rb') as stream:
                    records[key] = {'sha256': digest(stream)}
        if from_evidence:
            moved = destination / trace.name
            assert not moved.exists()
            trace.rename(moved)
            trace = moved
        archive = evidence / (name + '.gputrace.tar.gz')
        with tarfile.open(archive, 'w:gz', dereference=False) as tar:
            tar.add(trace, arcname=trace.name)
        with tarfile.open(archive, 'r:gz') as tar:
            checked = set()
            for member in tar:
                key = str(Path(member.name).relative_to(trace.name))
                if member.isdir():
                    continue
                expected = records[key]
                if member.issym():
                    assert expected == {'link': member.linkname}
                else:
                    assert member.isfile() or member.islnk()
                    with tar.extractfile(member) as stream:
                        assert digest(stream) == expected['sha256'], key
                checked.add(key)
            assert checked == set(records)
        with archive.open('rb') as stream:
            archive_sha = digest(stream)
        reports.append({'variant': name, 'archive': archive.name, 'sha256': archive_sha,
                        'bytes': archive.stat().st_size, 'entries': records,
                        'temporaryRawTrace': str(trace), 'verified': True})
    (evidence / 'capture-archives.json').write_text(json.dumps(reports, indent=2) + '\n')
    print([(r['variant'], r['bytes'], r['verified']) for r in reports])


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--work', required=True, type=Path)
    p.add_argument('--evidence', required=True, type=Path)
    p.add_argument('--from-evidence', action='store_true')
    a = p.parse_args()
    pack(a.work, a.evidence, a.from_evidence)
