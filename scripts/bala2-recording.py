#!/usr/bin/env python3
"""Summarises the recordings of the BALA2 examples.

Reads the recordings printed by examples/arduino/bala2/bindings.cpp under
the build flag BALANCE_RECORD, from a CSV file written by the make target
arduino-bala2-capture or from a serial log, and prints for each recording
its duration, the range and mean of the tilt, the travel of the wheels, the
first time at which the tilt exceeds the cutoff, and the correlation of the
reference tilt with the speed of the wheels. The speed loop opposes a motion
when the correlation is negative: as the wheels roll forwards, their counts
increasing, the reference tilt leans the robot backwards.

Uses the Python standard library only; run as

    python3 -I scripts/bala2-recording.py _arduino/recordings/bala2-TIME.csv
"""

import math
import sys

# The tilt beyond which the step stops the motors, in degrees, and the
# distance per count of the encoders, in metres: a wheel of radius 0.033 m
# and 420 counts per revolution.
CUTOFF = 70.0
METRES_PER_COUNT = 2 * math.pi * 0.033 / 420


def recordings(lines):
    """The recordings of the lines: of each sequence number, the last copy
    read in full, as its header and its rows of floats."""
    found, order, header, rows = {}, [], None, []
    for line in lines:
        line = line.strip()
        if line.startswith("# Recording "):
            header, rows = line, []
        elif header is None or line.startswith("["):
            continue
        elif line.startswith("# End of recording "):
            number = header.split()[2].rstrip(",")
            if line.split()[4] == number:
                if number not in found:
                    order.append(number)
                found[number] = (header, rows)
            header = None
        elif line and line[0] in "-0123456789":
            rows.append([float(x) for x in line.split(",")])
    return [found[n] for n in order]


def correlation(xs, ys):
    """The Pearson correlation coefficient of xs and ys, or None if either
    is constant."""
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sxx = sum((x - mx) ** 2 for x in xs)
    syy = sum((y - my) ** 2 for y in ys)
    return None if sxx == 0 or syy == 0 else sxy / math.sqrt(sxx * syy)


def summary(header, rows):
    """The lines of the summary of a recording."""
    lines = [header]
    if not rows:
        return lines + ["  no samples"]
    time, tilt, speed, reference = ([r[i] for r in rows] for i in (0, 1, 3, 4))
    left, right = ([r[i] for r in rows] for i in (7, 8))
    travel = [((l - left[0]) + (r - right[0])) / 2 for l, r in zip(left, right)]
    fall = next((t for t, x in zip(time, tilt) if abs(x) > CUTOFF), None)
    lines += [
        "  duration %.1f s, %d samples" % (time[-1] / 1000, len(rows)),
        "  tilt: mean %.2f, min %.2f, max %.2f degrees"
        % (sum(tilt) / len(tilt), min(tilt), max(tilt)),
        "  reference tilt: mean %.2f, min %.2f, max %.2f degrees"
        % (sum(reference) / len(reference), min(reference), max(reference)),
        "  speed: mean %.0f counts/s" % (sum(speed) / len(speed)),
        "  travel: final %.0f counts (%.3f m), largest %.0f counts"
        % (travel[-1], travel[-1] * METRES_PER_COUNT,
           max(travel, key=abs)),
        "  counts: left %+d, right %+d"
        % (left[-1] - left[0], right[-1] - right[0]),
        "  tilt beyond the cutoff of %.0f degrees: %s"
        % (CUTOFF, "never" if fall is None else "from %.2f s" % (fall / 1000)),
    ]
    c = correlation(speed, reference)
    if c is None:
        lines.append("  correlation of speed and reference tilt: undefined")
    else:
        lines.append(
            "  correlation of speed and reference tilt: %.2f (%s)"
            % (c, "the speed loop opposes the motion" if c < 0
               else "the speed loop does not oppose the motion"))
    return lines


def main(arguments):
    if len(arguments) != 1:
        sys.exit("usage: bala2-recording.py FILE")
    with open(arguments[0], encoding="utf-8", errors="replace") as f:
        found = recordings(f)
    if not found:
        sys.exit("No complete recording in " + arguments[0])
    for header, rows in found:
        print("\n".join(summary(header, rows)))


if __name__ == "__main__":
    main(sys.argv[1:])
