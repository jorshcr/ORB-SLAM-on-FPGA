"""One saved TUM frame through camera, three ORBs and the RMII transmitter."""
import json
import zlib
from pathlib import Path
import cv2
from udp_check import ROOT, VIVADO, run

work = ROOT.parent / "orb_test_output/frame_udp_2026-11-25"
work.mkdir(parents=True, exist_ok=True)
source = ROOT.parent / "orb_test_output/tum_images/freiburg1_desk.png"
gray = cv2.cvtColor(cv2.imread(str(source)), cv2.COLOR_BGR2GRAY)
(work / "image.hex").write_text("".join(f"{v:02x}\n" for v in gray.flat))
vendor = ROOT / "third_party/verilog-ethernet"
sources = sorted((ROOT / "rtl").rglob("*.sv"))
sources += sorted((ROOT / "rtl/network").glob("*.v"))
sources += sorted((vendor / "rtl").glob("*.v"))
sources += sorted((vendor / "lib/axis/rtl").glob("*.v"))
for tool, args in [
    ("xvlog", ["--sv", *sources, ROOT / "tb/frame_udp_tb.sv", VIVADO.parent / "data/verilog/src/glbl.v"]),
    ("xelab", ["frame_udp_tb", "glbl", "-L", "xpm", "-L", "unisims_ver", "-s", "frame_udp"]),
    ("xsim", ["frame_udp", "-runall"]),
]:
    print(f"Running {tool}", flush=True)
    log = run(tool, args, work)
    (work / f"{tool}.txt").write_text(log)
    if "Fatal:" in log or (tool == "xsim" and "PASS: frame" not in log):
        raise RuntimeError(log[-6000:])

payloads = [bytes.fromhex(s) for s in (work / "udp_payloads.hex").read_text().splitlines()]
received = []
for line in (work / "ethernet_frames.hex").read_text().splitlines():
    raw = bytes.fromhex(line)
    assert raw[:8] == b"\x55"*7 + b"\xd5", "Ethernet preamble"
    frame = raw[8:]
    assert int.from_bytes(frame[-4:], "little") == zlib.crc32(frame[:-4]), "Ethernet FCS"
    assert frame[12:14] == b"\x08\x00", "IPv4 EtherType"
    ip = frame[14:]
    ihl = (ip[0] & 15)*4
    words = [int.from_bytes(ip[i:i+2],"big") for i in range(0,ihl,2)]
    checksum = sum(words)
    while checksum >> 16:
        checksum = (checksum & 65535) + (checksum >> 16)
    assert checksum == 65535 and ip[9] == 17, "IPv4 header/checksum"
    udp = ip[ihl:]
    assert int.from_bytes(udp[2:4],"big") == 5000
    length = int.from_bytes(udp[4:6],"big")
    received.append(udp[8:length])
assert received == payloads, "RMII packets differ from accepted UDP payloads"
assert received[-1][4] == 1 and all(p[4] == 0 for p in received[:-1])
summary = dict(image=str(source), width=640, height=480, orb_levels=3,
               brief_engines=[2,2,1], descriptors=len(received)-1,
               ethernet_packets=len(received), fcs_and_ip_checksums=True,
               exact_payload_match=True, simulation_overrides=[
                   "Broadcast destination bypasses ARP peer", "Shortened PHY startup wait"],
               rtl_result=next(s for s in log.splitlines() if "PASS: frame" in s))
(work / "summary.json").write_text(json.dumps(summary,indent=2)+"\n")
print(json.dumps(summary,indent=2))
