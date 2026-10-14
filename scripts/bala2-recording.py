#!/usr/bin/env python3
"""Summarises the recordings of the BALA2 examples.

Reads the recordings printed by examples/arduino/bala2/bindings.cpp under
the build flag BALANCE_RECORD, from a CSV file written by the make target
arduino-bala2-capture or from a serial log, and prints for each recording
its duration, the range and mean of the tilt and of the reference tilt, the
mean speed, the travel of the wheels, the difference of the counts of the
left and the right wheel, which measures the heading, with its drift, the
slope of its least-squares line, the fraction of the sampling intervals in
which each wheel is at rest, the first time at which the tilt exceeds the
cutoff, and the Pearson correlation of the speed of the wheels with the
reference tilt.

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
    """The recordings of the lines, as examples/arduino/bala2/recordings.awk
    extracts them: of each sequence number, the last complete copy, as its
    header and its rows of floats. A copy is complete if the line of its
    columns follows its header and is followed by as many rows as the header
    states, each of as many numbers as there are columns, and by its end
    line; text before the "#" of a header or an end line is ignored."""
    found, order, header, rows, columns = {}, [], None, [], 0
    for line in lines:
        line = line.strip()
        if "# Recording " in line:
            header = line[line.index("# Recording "):]
            rows, columns = [], 0
        elif header is None or not line or line.startswith("["):
            continue
        elif "# End of recording " in line:
            words = header.split()
            end = line[line.index("# End of recording "):].split()
            if end[4] == words[2].rstrip(",") and len(rows) == int(words[5]):
                if words[2] not in found:
                    order.append(words[2])
                found[words[2]] = (header, rows)
            header = None
        elif columns == 0:
            columns = len(line.split(","))
        else:
            try:
                row = [float(x) for x in line.split(",")]
            except ValueError:
                row = []
            if len(row) == columns:
                rows.append(row)
            else:
                header = None
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


def slope(xs, ys):
    """The slope of the least-squares line of ys on xs, or None if xs is
    constant."""
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    return None if sxx == 0 else sxy / sxx


def at_rest(counts):
    """The fraction of the sampling intervals in which the counts, or the
    pairs of counts, do not change."""
    steps = list(zip(counts, counts[1:]))
    return sum(a == b for a, b in steps) / len(steps) if steps else 0.0


def summary(header, rows):
    """The lines of the summary of a recording."""
    lines = [header]
    if not rows:
        return lines + ["  no samples"]
    time, tilt, speed, reference = ([r[i] for r in rows] for i in (0, 1, 3, 4))
    left, right = ([r[i] for r in rows] for i in (7, 8))
    travel = [((l - left[0]) + (r - right[0])) / 2 for l, r in zip(left, right)]
    difference = [(l - left[0]) - (r - right[0]) for l, r in zip(left, right)]
    drift = slope(time, difference)
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
        "  difference of the counts, left - right: final %+d, min %+d, "
        "max %+d, drift %s"
        % (difference[-1], min(difference), max(difference),
           "undefined" if drift is None
           else "%+.0f counts/min" % (drift * 60000)),
        "  wheels at rest: left %.0f%%, right %.0f%%, both %.0f%% of the "
        "sampling intervals"
        % (100 * at_rest(left), 100 * at_rest(right),
           100 * at_rest(list(zip(left, right)))),
        "  tilt beyond the cutoff of %.0f degrees: %s"
        % (CUTOFF, "never" if fall is None else "from %.2f s" % (fall / 1000)),
    ]
    c = correlation(speed, reference)
    lines.append(
        "  correlation of the speed and the reference tilt: %s"
        % ("undefined" if c is None else "%.2f" % c))
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
