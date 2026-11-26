"""Receive ORB UDP packets and emit JSON lines; no external dependencies."""
import argparse
import json
import socket
import struct


def decode_packet(data):
    if len(data) < 16:
        raise ValueError("Short packet")
    magic, kind, flags, count, frame, index = struct.unpack("!4sBBHII", data[:16])
    if magic != b"ORB1" or kind not in (0, 1):
        raise ValueError("Unknown protocol")
    result = dict(type="descriptor" if kind == 0 else "frame_end",
                  frame=frame, index=index, flags=flags)
    if kind == 0:
        if count != 1 or len(data) != 52:
            raise ValueError("Invalid descriptor length/count")
        record = int.from_bytes(data[16:], "big")
        if record >> 283:
            raise ValueError("Nonzero record padding")
        descriptor = record & ((1 << 256) - 1)
        angle = (record >> 256) & 63
        pos = (record >> 262) & ((1 << 19) - 1)
        result.update(octave=(record >> 281) & 3, x=pos >> 9, y=pos & 511,
                      angle=angle, angle_degrees=(angle + .5) * 5.625,
                      descriptor=f"{descriptor:064x}")
    elif count != 0 or len(data) != 16:
        raise ValueError("Invalid frame-end length/count")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="192.168.1.100")
    parser.add_argument("--fpga", default="192.168.1.128")
    parser.add_argument("--port", type=int, default=5000)
    args = parser.parse_args()
    seen = {}
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024 * 1024)
        sock.bind((args.bind, args.port))
        while True:
            data, peer = sock.recvfrom(2048)
            if peer[0] != args.fpga:
                continue
            try:
                item = decode_packet(data)
            except ValueError as error:
                print(json.dumps(dict(error=str(error))), flush=True)
                continue
            indices = seen.setdefault(item["frame"], set())
            if item["type"] == "descriptor":
                item["duplicate"] = item["index"] in indices
                indices.add(item["index"])
            else:
                item["received"] = len(indices)
                item["complete_at_marker"] = len(indices) == item["index"] and all(
                    0 <= index < item["index"] for index in indices)
            while len(seen) > 8:
                del seen[next(iter(seen))]
            print(json.dumps(item), flush=True)


if __name__ == "__main__":
    main()
