"""Compare recorded hardware descriptors with software keypoint candidates."""
import json
from pathlib import Path
import cv2
import numpy as np
from fast_check import opencv_fast

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/tests/2026-11-24-tum"
DATA = ROOT / "orb_test_output/tum_images"


def main():
    results = json.loads((REPORT / "results.json").read_text())
    comparisons = []
    for frame, threshold in enumerate([20, 40]):
        canvas = np.full((96 + 4*532, 1280, 3), 25, np.uint8)
        cv2.putText(canvas, f"Hardware vs software baseline | FAST threshold {threshold}",
                    (18, 30), cv2.FONT_HERSHEY_SIMPLEX, .8, (255, 255, 255), 1, cv2.LINE_AA)
        cv2.putText(canvas, "Green: hardware descriptor / shared point. Orange: software-only candidate.",
                    (18, 57), cv2.FONT_HERSHEY_SIMPLEX, .57, (210, 210, 210), 1, cv2.LINE_AA)
        cv2.putText(canvas, "Same 21-pixel border. Software has no engine-busy limit. Native 640x480 images.",
                    (18, 80), cv2.FONT_HERSHEY_SIMPLEX, .57, (210, 210, 210), 1, cv2.LINE_AA)
        for row, result in enumerate(results):
            name = result["sequence"]
            color = cv2.imread(str(DATA / f"{name}.png"))
            gray = cv2.cvtColor(color, cv2.COLOR_BGR2GRAY)
            baseline = {p: s for p, s in opencv_fast(gray, threshold).items()
                        if 21 <= p[0] < 619 and 21 <= p[1] < 459}
            records = [line.split() for line in (REPORT / f"{name}-rtl_descriptors.txt").read_text().splitlines()]
            # Fixed descriptor latency preserves raster order. A single wrap separates the two passes.
            wraps = [i for i in range(1, len(records))
                     if (int(records[i][2]), int(records[i][1])) <
                        (int(records[i-1][2]), int(records[i-1][1]))]
            assert len(wraps) == 1, (name, wraps)
            hardware_records = records[:wraps[0]] if frame == 0 else records[wraps[0]:]
            hardware = {(int(r[1]), int(r[2])): int(r[3]) for r in hardware_records}
            assert len(hardware) == len(hardware_records)
            assert all(baseline.get(p) == score for p, score in hardware.items())
            missing = baseline.keys() - hardware.keys()
            left, right = color.copy(), color.copy()
            for x, y in hardware:
                cv2.circle(left, (x, y), 2, (0, 255, 0), 1, cv2.LINE_AA)
            for x, y in baseline:
                cv2.circle(right, (x, y), 2, (0, 165, 255) if (x, y) in missing else (0, 255, 0), 1, cv2.LINE_AA)
            for img in [left, right]:
                cv2.rectangle(img, (21, 21), (618, 458), (0, 220, 220), 1)
            top = 96 + row*532
            label = name.replace("freiburg1_", "fr1/")
            for x, text in [(12, f"{label} | HARDWARE: {len(hardware)} descriptors"),
                            (652, f"SOFTWARE: {len(baseline)} candidates ({len(missing)} extra)")]:
                cv2.putText(canvas, text, (x, top+30), cv2.FONT_HERSHEY_SIMPLEX, .59,
                            (255, 255, 255), 1, cv2.LINE_AA)
            canvas[top+48:top+528, :640] = left
            canvas[top+48:top+528, 640:] = right
            comparisons.append(dict(sequence=name, threshold=threshold, hardware=len(hardware),
                                    software=len(baseline), software_only=len(missing)))
        cv2.imwrite(str(REPORT / f"hardware-vs-software-t{threshold}.png"), canvas)
    (REPORT / "comparison-counts.json").write_text(json.dumps(comparisons, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(comparisons, indent=2))


if __name__ == "__main__":
    main()
