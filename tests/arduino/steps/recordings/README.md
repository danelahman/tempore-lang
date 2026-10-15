# Recordings of the step counter

Five recordings of `examples/arduino/steps` on an M5Stack CoreS3 Lite, made
on 2026-10-15 under the build flag `STEPS_RECORD` and read out by
`scripts/steps-recording.py`, each from its calibration on; reduced to the
columns `t_ms`, `ax`, `ay` and `az` (g) of the readings, the events left out.

| File | Motion | Steps |
| --- | --- | --- |
| `steps-1.csv` | the calibration, then lying still | 0 |
| `steps-2.csv` | walking with the device in the hand | about 32 |
| `steps-3.csv` | moving the device up and down in the hand | 0 |
| `steps-4.csv` | walking with the device in a pocket, with a standstill | about 49 |
| `steps-5.csv` | handling the device, then lying still | 0 |

`tests/arduino/steps.t` replays them through the host simulation
(`STEPS_REPLAY`).
