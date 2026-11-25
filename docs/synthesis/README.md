# Synthesis and timing history

Dated snapshots record the tested design, constraints, resource use, timing results, and limitations. Keep each snapshot and its reports with the commit containing the corresponding RTL. These measurements are not automatically updated when RTL changes.

| Date | Design | Clock | LUTs | Registers | BRAM tiles | DSPs | Setup slack | Hold slack |
|---|---|---|---:|---:|---:|---:|---:|---:|
| [2026-11-19](2026-11-19-orb.md) | ORB core, 640x480 | 100 MHz | 3,777 | 14,343 | 9 | 36 | +0.561 ns | -0.441 ns |
| [2026-11-24](2026-11-24-orb.md) | ORB, 3 BRIEF engines, diagnostic ports internal | 100 MHz | 20,070 | 30,676 | 11 | 36 | -1.028 ns | -0.444 ns |
| [2026-11-24, pipelined](2026-11-24-orb-pipelined.md) | ORB, 3 BRIEF engines, registered pattern lookup | 100 MHz | 20,017 | 30,736 | 11 | 36 | +0.305 ns | -0.502 ns |
| [2026-11-24, single-octave system](2026-11-24-system-single.md) | Camera capture + ORB + descriptor FIFO | 100 MHz | 19,426 | 30,844 | 15.5 | 60 | +0.008 ns | -0.751 ns |
| [2026-11-24, registered inputs](2026-11-24-system-input-registered.md) | Registered camera inputs + split BRIEF lookup | 100 MHz | 19,709 | 32,168 | 15.5 | 60 | +0.106 ns | -0.502 ns |
| [2026-11-24, board + orientation](2026-11-24-board-orientation.md) | Nexys/OV7670 board wrapper + descriptor angle | 100 MHz | 19,777 | 32,164 | 15.5 | 60 | -0.169 ns | +0.023 ns |
| [2026-11-24, board closed](2026-11-24-board-closed.md) | Single octave, post-route optimization | 100 MHz | 19,777 | 32,164 | 15.5 | 60 | +0.055 ns | +0.023 ns |
| [2026-11-24, three levels](2026-11-24-board-three-level.md) | 3 ORBs + 2 scalers; synthesis counts, placement failed | 100 MHz target | 60,349 | 96,399 | 33.5 | 188 | unavailable | unavailable |

For future runs, add a dated Markdown snapshot, preserve the reports in a matching subfolder, and append a row here.

Resource-only experiments: [2026-11-24 BRIEF DSP mapping](2026-11-24-brief-dsp.md) compares isolated baseline/DSP implementations and estimates the resulting ORB usage. No routed timing result is implied.
