# Synthesis and timing history

Dated snapshots record the tested design, constraints, resource use, timing results, and limitations. Keep each snapshot and its reports with the commit containing the corresponding RTL. These measurements are not automatically updated when RTL changes.

| Date | Design | Clock | LUTs | Registers | BRAM tiles | DSPs | Setup slack | Hold slack |
|---|---|---|---:|---:|---:|---:|---:|---:|
| [2026-11-19](2026-11-19-orb.md) | ORB core, 640x480 | 100 MHz | 3,777 | 14,343 | 9 | 36 | +0.561 ns | -0.441 ns |

For future runs, add a dated Markdown snapshot, preserve the reports in a matching subfolder, and append a row here.
