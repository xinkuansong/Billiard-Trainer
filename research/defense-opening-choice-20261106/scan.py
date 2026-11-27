import concurrent.futures
import gzip
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys

HERE=Path(__file__).resolve().parent
OUT=Path(os.environ.get("DEFENSE_OPENING_OUTPUT", HERE.parents[1]/"output"/HERE.name)).resolve()
work=Path(os.environ["QIUJI_TEST_WORK"])
uid,binary=sys.argv[1:]
def chunk(rows):
    first=rows[0][0]
    archive=OUT/f"pockets-{first:06}.jsonl.gz"
    inp=work/f"{first}.json"
    raw=work/f"{first}.jsonl"
    inp.write_text(json.dumps([dict(id=i,points=json.loads(s)) for i,s in rows]))
    subprocess.run(["xcrun","simctl","spawn",uid,binary,str(inp),str(raw)], check=True)
    data=raw.read_bytes()
    assert [json.loads(s)["id"] for s in data.splitlines()]==[i for i,_ in rows]
    tmp=archive.with_suffix(".tmp")
    tmp.write_bytes(gzip.compress(data,compresslevel=2,mtime=0))
    tmp.replace(archive)
    inp.unlink()
    raw.unlink()
    return len(rows)
def main():
    db=sqlite3.connect(f"file:{OUT}/inputs.sqlite3?mode=ro",uri=True)
    cursor=db.execute("SELECT id,points FROM geom ORDER BY id")
    total=db.execute("SELECT COUNT(*) FROM geom").fetchone()[0]
    done=0
    subprocess.run(["xcrun","simctl","boot",uid],check=True)
    try:
        subprocess.run(["xcrun","simctl","bootstatus",uid,"-b"],check=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            while True:
                batches=[cursor.fetchmany(2048) for _ in range(8)]
                jobs=[pool.submit(chunk,b) for b in batches if b]
                if not jobs: break
                for f in concurrent.futures.as_completed(jobs):
                    done+=f.result()
                    (OUT/"status.json").write_text(json.dumps(dict(completed=done,total=total)))
        assert done==total
    finally:
        db.close()
        subprocess.run(["xcrun","simctl","shutdown",uid],check=True)
if __name__=="__main__": main()
