"""Compile UDP integration, elaborate board, and test descriptor packetization."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VIVADO = Path(os.environ.get("VIVADO_BIN", "C:/Xilinx/Vivado/2024.1/bin"))


def run(tool, args, work):
    command = subprocess.list2cmdline([str(VIVADO / (tool + ".bat")), *map(str, args)])
    result = subprocess.run(command, shell=True, cwd=work, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="orb_udp_") as work:
        vendor = ROOT / "third_party/verilog-ethernet"
        sources = sorted((ROOT / "rtl").rglob("*.sv"))
        sources += sorted((ROOT / "rtl/network").glob("*.v"))
        sources += sorted((vendor / "rtl").glob("*.v"))
        sources += sorted((vendor / "lib/axis/rtl").glob("*.v"))
        run("xvlog", ["--sv", *sources, ROOT / "tb/descriptor_udp_packetizer_tb.sv", VIVADO.parent / "data/verilog/src/glbl.v"], work)
        run("xelab", ["orb_udp_board_top", "glbl", "-L", "xpm", "-L", "unisims_ver", "-s", "udp_board"], work)
        print("PASS: full UDP board elaboration", flush=True)
        run("xelab", ["descriptor_udp_packetizer_tb", "-s", "packetizer"], work)
        log = run("xsim", ["packetizer", "-runall"], work)
        if "PASS: UDP packet" not in log or "Fatal:" in log:
            raise RuntimeError(log)
        print(next(line for line in log.splitlines() if "PASS:" in line))
