"""Run four native-resolution TUM frames through the full ORB RTL (two thresholds each)."""
import hashlib
import json
import re
from pathlib import Path
import cv2
import numpy as np
from fast_check import ROOT, RTL, TB, vivado, opencv_fast, numpy_fast, diff

REPO = ROOT.parent
DATA = REPO / "orb_test_output/tum_images"
OUT = REPO / "orb_test_output/tum_2026-11-24"


def save_hex(path, values):
    path.write_text("".join(f"{int(v):02x}\n" for v in values.flat), encoding="ascii")


def references(gray):
    weights = np.array([1, 6, 15, 20, 15, 6, 1], dtype=np.float64)
    blur = (cv2.sepFilter2D(gray.astype(np.float64), -1, weights, weights) / 4096).astype(np.uint8)
    axis = np.arange(-18, 19, dtype=np.float64)
    ones = np.ones(37, dtype=np.float64)
    mx = np.rint(cv2.sepFilter2D(blur.astype(np.float64), -1, axis, ones)).astype(np.int64)
    my = np.rint(cv2.sepFilter2D(blur.astype(np.float64), -1, ones, axis)).astype(np.int64)
    ax, ay = np.abs(mx), np.abs(my)
    quadrant = np.where(my < 0, np.where(mx < 0, 2, 3), np.where(mx < 0, 1, 0))
    sector = np.zeros_like(gray)
    for k in range(15):
        tangent = int(np.floor(np.tan((k+1)*np.pi/32)*256+.5))
        sector[(ay != 0) & (ax*tangent <= ay*256)] = k + 1
    # Check the vectorized reference against direct integer dot products.
    for y, x in [(21, 21), (100, 100), (240, 320), (458, 618)]:
        patch = gray[y-3:y+4, x-3:x+4].astype(np.int64)
        assert blur[y, x] == np.sum(patch * np.outer(weights, weights)) // 4096
        patch = blur[y-18:y+19, x-18:x+19].astype(np.int64)
        assert mx[y, x] == np.sum(patch * axis[None, :])
        assert my[y, x] == np.sum(patch * axis[:, None])
    return blur, ((quadrant << 4) | sector).astype(np.uint8)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((DATA / "manifest.json").read_text())
    results = []
    for index, source in enumerate(manifest):
        name = source["sequence"]
        work = OUT / name
        work.mkdir(exist_ok=True)
        color = cv2.imread(str(DATA / f"{name}.png"), cv2.IMREAD_COLOR)
        gray = cv2.cvtColor(color, cv2.COLOR_BGR2GRAY)
        assert gray.shape == (480, 640)
        blur, angle = references(gray)
        save_hex(work / "image.hex", gray)
        save_hex(work / "blur.hex", blur)
        save_hex(work / "angle.hex", angle)
        gaps = index % 2
        print(f"RUN {name}: 640x480, thresholds 20/40, gaps={gaps}", flush=True)
        vivado("xvlog", ["--sv", TB, *RTL], str(work))
        args = ["fast_detector_tb", "-L", "xpm", "-s", "dataset_test"]
        for key, value in dict(W=640, H=480, THRESH0=20, THRESH1=40, GAPS=gaps,
                               SEED=index+1, BLUR_REF="blur.hex", ANGLE_REF="angle.hex").items():
            args += ["--generic_top", f"{key}={value}"]
        vivado("xelab", args, str(work))
        log = vivado("xsim", ["dataset_test", "-runall"], str(work))
        (work / "simulation.txt").write_text(log, encoding="utf-8")
        if "TB PASS" not in log or "Fatal:" in log:
            raise RuntimeError(log[-5000:])
        frames = [{}, {}]
        for line in (work / "rtl_keypoints.txt").read_text().splitlines():
            frame, x, y, score = map(int, line.split())
            frames[frame][x, y] = score
        for frame, threshold in enumerate([20, 40]):
            cv_ref, np_ref = opencv_fast(gray, threshold), numpy_fast(gray, threshold)
            assert diff("numpy/OpenCV", np_ref, cv_ref)
            assert diff("RTL/reference", frames[frame], cv_ref)
        match = re.search(r"BRIEF COUNTS: admitted=(\d+) dispatched=(\d+) completed=(\d+) dropped=(\d+)", log)
        assert match
        admitted, dispatched, completed, dropped = map(int, match.groups())
        records = [line.split() for line in (work / "rtl_descriptors.txt").read_text().splitlines()]
        assert len(records) == completed and completed > 0
        engines = [sum(int(r[0]) == e for r in records) for e in range(3)]
        row = dict(**source, width=640, height=480, thresholds=[20, 40], gaps=bool(gaps),
                   fast_counts=[len(f) for f in frames], admitted=admitted, descriptors=completed,
                   dropped=dropped, per_engine=engines, orientations=2*(640-42)*(480-42), passed=True,
                   grayscale_sha256=hashlib.sha256(gray.tobytes()).hexdigest())
        results.append(row)
        (OUT / "results.json").write_text(json.dumps(results, indent=2)+"\n", encoding="utf-8")
        overlay = color.copy()
        for r in records:
            cv2.circle(overlay, (int(r[1]), int(r[2])), 2, (0, 255, 0), 1)
        cv2.rectangle(overlay, (21, 21), (618, 458), (0, 200, 255), 1)
        cv2.imwrite(str(work / "descriptors.png"), overlay)
        print(f"PASS {name}: FAST={row['fast_counts']}, descriptors={completed}, dropped={dropped}, engines={engines}", flush=True)
    print("PASS: all four TUM image cases", flush=True)


if __name__ == "__main__":
    main()
