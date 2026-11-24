#!/usr/bin/env python3
"""Run window and FAST regressions with Vivado XSim, NumPy, and OpenCV.
Usage: python orb_hardware/scripts/fast_check.py [--quick]
Override the Vivado bin directory using VIVADO_BIN.
"""

import os
import subprocess
import sys
import tempfile

import cv2
import numpy as np

from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "rtl"
SIM = ROOT / "tb"
VIVADO = Path(os.environ.get("VIVADO_BIN", "C:/Xilinx/Vivado/2024.1/bin"))
RTL = sorted(str(p) for p in SRC.rglob("*.sv"))
TB = str(SIM / "fast_detector_tb.sv")

def vivado(tool, args, work):
    command = " ".join(chr(34) + str(arg) + chr(34) for arg in [VIVADO / (tool + ".bat"), *args])
    result = subprocess.run(command, shell=True, cwd=work,
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

CIRCLE = [(0, -3), (1, -3), (2, -2), (3, -1), (3, 0), (3, 1), (2, 2), (1, 3),
          (0, 3), (-1, 3), (-2, 2), (-3, 1), (-3, 0), (-3, -1), (-2, -2), (-1, -3)]


# ---------------------------------------------------------------- references

def opencv_fast(img, t):
    det = cv2.FastFeatureDetector_create(
        threshold=t, nonmaxSuppression=True,
        type=cv2.FAST_FEATURE_DETECTOR_TYPE_9_16)
    h, w = img.shape
    out = {}
    for kp in det.detect(img, None):
        x, y = int(round(kp.pt[0])), int(round(kp.pt[1]))
        if x <= w - 5 and y <= h - 5:
            out[(x, y)] = int(round(kp.response)) + 1
    return out


def numpy_fast(img, t):
    """Brute force: S = max over arcs and polarities of the min difference."""
    h, w = img.shape
    a = img.astype(np.int32)
    c = a[3:h - 3, 3:w - 3]
    ring = np.stack([a[3 + dy:h - 3 + dy, 3 + dx:w - 3 + dx] for dx, dy in CIRCLE])
    best = np.zeros_like(c)
    for sign in (1, -1):
        d = sign * (ring - c)
        for start in range(16):
            arc = d[[(start + i) % 16 for i in range(9)]].min(axis=0)
            best = np.maximum(best, arc)
    score = np.zeros((h, w), np.int32)
    score[3:h - 3, 3:w - 3] = np.where(best > t, best, 0)

    out = {}
    ys, xs = np.nonzero(score)
    for y, x in zip(ys, xs):
        s = score[y, x]
        nb = score[y - 1:y + 2, x - 1:x + 2].copy()
        nb[1, 1] = -1
        if (s > nb).all() and x <= w - 5 and y <= h - 5:
            out[(int(x), int(y))] = int(s)
    return out


# ---------------------------------------------------------------- images

def test_image(w, h):
    """The png_to_hex.py pattern, scaled to w x h."""
    y, x = np.mgrid[0:h, 0:w]
    a = (x * 255 // max(w - 1, 1) * 0.4 + y * 255 // max(h - 1, 1) * 0.3).astype(np.uint8)
    sy, sx = h / 480, w / 640
    def box(y0, y1, x0, x1, v):
        a[int(y0 * sy):int(y1 * sy), int(x0 * sx):int(x1 * sx)] = v
    box(80, 200, 100, 260, 240)
    box(300, 420, 380, 500, 15)
    box(120, 160, 420, 560, 200)
    box(260, 290, 60, 340, 30)
    for i in range(6):
        for j in range(6):
            if (i + j) % 2 == 0:
                box(360 + i * 16, 376 + i * 16, 80 + j * 16, 96 + j * 16, 255)
    return a


def scene_image(w, h, seed):
    """Smooth background, random rectangles and blobs, sensor-like noise."""
    rng = np.random.default_rng(seed)
    a = cv2.GaussianBlur(rng.uniform(0, 255, (h, w)).astype(np.float32), (0, 0), 12)
    a = cv2.normalize(a, None, 40, 200, cv2.NORM_MINMAX)
    for _ in range(40):
        x0, y0 = rng.integers(0, w), rng.integers(0, h)
        cv2.rectangle(a, (int(x0), int(y0)),
                      (int(x0 + rng.integers(5, 80)), int(y0 + rng.integers(5, 80))),
                      float(rng.integers(0, 256)), -1)
    for _ in range(30):
        cv2.circle(a, (int(rng.integers(0, w)), int(rng.integers(0, h))),
                   int(rng.integers(3, 30)), float(rng.integers(0, 256)), -1)
    a += rng.normal(0, 4, (h, w))
    return np.clip(a, 0, 255).astype(np.uint8)


def noise_image(w, h, seed):
    return np.random.default_rng(seed).integers(0, 256, (h, w), dtype=np.uint8)


# ---------------------------------------------------------------- runner

def run_rtl(img, t0, t1, gaps, seed, work):
    h, w = img.shape
    hexf = os.path.join(work, "image.hex")
    kpf = os.path.join(work, "rtl_keypoints.txt")
    with open(hexf, "w") as f:
        f.write("\n".join(f"{v:02x}" for v in img.flatten()) + "\n")
    vivado("xvlog", ["--sv", TB, *RTL], work)
    args = ["fast_detector_tb", "-L", "xpm", "-s", "fast_test"]
    for key, value in dict(W=w, H=h, THRESH0=t0, THRESH1=t1, GAPS=gaps, SEED=seed).items():
        args += ["--generic_top", f"{key}={value}"]
    vivado("xelab", args, work)
    log = vivado("xsim", ["fast_test", "-runall"], work)
    tb_ok = "TB PASS" in log
    frames = [{}, {}]
    for line in open(kpf):
        fr, x, y, s = map(int, line.split())
        frames[fr][(x, y)] = s
    return tb_ok, log.strip().splitlines(), frames


def diff(name, got, ref):
    missing = sorted(set(ref) - set(got))
    extra = sorted(set(got) - set(ref))
    bad = sorted(p for p in set(got) & set(ref) if got[p] != ref[p])
    if not (missing or extra or bad):
        return True
    print(f"    {name}: {len(missing)} missing, {len(extra)} extra, {len(bad)} wrong score")
    for label, pts in (("missing", missing), ("extra", extra), ("score", bad)):
        for p in pts[:5]:
            print(f"      {label} {p}: rtl={got.get(p)} ref={ref.get(p)}")
    return False


def main():
    quick = "--quick" in sys.argv
    configs = [
        # name,              image,                        t0, t1, gaps
        ("noise 64x48",      noise_image(64, 48, 1),        5, 30, 1),
        ("noise 100x50",     noise_image(100, 50, 2),       1, 60, 0),
        ("scene 160x120",    scene_image(160, 120, 3),     10, 25, 1),
    ]
    if not quick:
        configs += [
            ("test pattern 640x480", test_image(640, 480), 20, 40, 0),
            ("scene 640x480",        scene_image(640, 480, 4), 12, 30, 1),
        ]

    all_ok = True
    with tempfile.TemporaryDirectory() as work:
        vivado("xvlog", ["--sv", str(SIM / "line_window_tb.sv"), *RTL], work)
        vivado("xelab", ["line_window_tb", "-s", "window_test"], work)
        log = vivado("xsim", ["window_test", "-runall"], work)
        if "PASS: line_window" not in log or "FAIL:" in log:
            raise RuntimeError(log)
        print(next(line for line in log.splitlines() if "PASS: line_window" in line))
    with tempfile.TemporaryDirectory() as work:
        for i, (name, img, t0, t1, gaps) in enumerate(configs):
            print(f"{name}  t={t0}/{t1}  gaps={gaps}")
            tb_ok, log, frames = run_rtl(img, t0, t1, gaps, i + 1, work)
            ok = tb_ok
            if not tb_ok:
                print("    testbench:", *log[-6:], sep="\n      ")
            for fr, t in enumerate((t0, t1)):
                cv_ref, np_ref = opencv_fast(img, t), numpy_fast(img, t)
                if not diff(f"frame {fr}: numpy vs OpenCV", np_ref, cv_ref):
                    print("    REFERENCE DISAGREEMENT -- fix the model first")
                    ok = False
                    continue
                ok &= diff(f"frame {fr}: RTL vs OpenCV", frames[fr], cv_ref)
                print(f"    frame {fr}: {len(cv_ref)} keypoints, RTL found {len(frames[fr])}")
            print("    PASS" if ok else "    FAIL")
            all_ok &= ok

    print("\nALL CONFIGS PASSED" if all_ok else "\nSOME CONFIGS FAILED")
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
