"""Fetch one original RGB PNG per paper-listed TUM sequence without retaining archives."""
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "orb_test_output/tum_images"
SEQUENCES = ["desk", "desk2", "room", "xyz"]


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = []
    for sequence in SEQUENCES:
        name = f"freiburg1_{sequence}"
        meta = DEST / f"{name}.json"
        if meta.exists() and (DEST / f"{name}.png").exists():
            manifest.append(json.loads(meta.read_text()))
            continue
        url = f"https://webshare.cvg.cit.tum.de/g/rgbd/dataset/freiburg1/rgbd_dataset_{name}.tgz"
        print(f"Fetching {name}: first RGB member in archive order", flush=True)
        proc = subprocess.Popen(["curl.exe", "-fLsS", "--connect-timeout", "30", url], stdout=subprocess.PIPE)
        try:
            with tarfile.open(fileobj=proc.stdout, mode="r|gz") as archive:
                for member in archive:
                    if member.isfile() and "/rgb/" in member.name and member.name.endswith(".png"):
                        data = archive.extractfile(member).read()
                        (DEST / f"{name}.png").write_bytes(data)
                        record = dict(sequence=name, archive_url=url, archive_member=member.name,
                                      sha256=hashlib.sha256(data).hexdigest())
                        meta.write_text(json.dumps(record, indent=2)+"\n", encoding="utf-8")
                        manifest.append(record)
                        print(f"Saved {member.name} ({len(data)} bytes)", flush=True)
                        break
                else:
                    raise RuntimeError(f"No RGB frame in {url}")
        finally:
            proc.terminate()
            proc.wait()
            proc.stdout.close()
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
