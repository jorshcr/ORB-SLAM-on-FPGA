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
| [2026-11-24, 3/3/2 BRIEF](2026-11-24-board-332.md) | 3 ORBs, 8 BRIEFs; synthesis counts, placement failed | 100 MHz target | 55,329 | 87,387 | 33.5 | 180 | unavailable | unavailable |
| [2026-11-24, two levels](2026-11-24-board-two-level.md) | 2 ORBs, 6 BRIEFs + scaler; routed | 100 MHz | 39,556 | 64,298 | 27 | 124 | +0.003 ns | +0.007 ns |
| [2026-11-24, two BRIEFs per level](2026-11-24-board-two-level-two-brief.md) | 2 ORBs, 4 BRIEFs + scaler; routed | 100 MHz | 29,224 | 46,358 | 27 | 108 | +0.019 ns | +0.051 ns |
| [2026-11-25, frame controller](2026-11-25-frame-controller.md) | 2 ORBs, 4 BRIEFs; single-frame capture/drain + Q8 angle | 100 MHz | 29,017 | 46,311 | 27 | 104 | +0.138 ns | +0.021 ns |
| [2026-11-25, OpenCV pattern](2026-11-25-opencv-pattern.md) | UDP, 3 ORBs, 2/2/1 BRIEFs, standard pair table | 100 MHz | 41,461 | 63,066 | 37 | 150 | +0.011 ns | +0.017 ns |

For future runs, add a dated Markdown snapshot, preserve the reports in a matching subfolder, and append a row here.

Resource-only experiments: [2026-11-24 BRIEF DSP mapping](2026-11-24-brief-dsp.md) compares isolated baseline/DSP implementations and estimates the resulting ORB usage. No routed timing result is implied.
