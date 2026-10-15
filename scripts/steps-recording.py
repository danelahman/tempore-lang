#!/usr/bin/env python3
"""Reads and erases the recordings of the step counter.

Talks to examples/arduino/steps/bindings.cpp built under the build flag
STEPS_RECORD over its serial port, by the commands "dump" and "erase":

    steps-recording.py capture --port PORT [--wait SECONDS] PREFIX
    steps-recording.py erase --port PORT [--wait SECONDS]
    steps-recording.py split LOG PREFIX

capture sends "dump" and writes the lines read to PREFIX.log and each
complete recording N to PREFIX-N.csv, with the columns t_ms, ax, ay, az, gx,
gy, gz and event; erase sends "erase" and waits for its confirmation; split
extracts the recordings of a log written by capture or by the host
simulation. A recording is complete if its line "# End of recording N, R
rows" follows its line "# Recording N", its line of columns and R rows of 8
fields. The lines of the dump that begin with "@" may follow text of the log
written at the same time, which is ignored.

The port is opened in raw mode, its modem control lines left as opening it
sets them. A command is sent again every 3 seconds until the device answers,
and the port is opened again if it disappears, as while the board restarts,
so that a reset of the board by the opening of the port does not matter.
The device has SECONDS (default 30) to answer, and then 10 seconds between
the lines of a dump and 120 seconds for an erase.

Uses the Python standard library only.
"""

import argparse
import os
import select
import sys
import termios
import time

COLUMNS = "t_ms,ax,ay,az,gx,gy,gz,event"


def open_port(port, deadline):
    """The port opened for reading and writing in raw mode at 115200 baud,
    retried while it is missing until the deadline; None after it."""
    while True:
        try:
            fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        except FileNotFoundError:
            if time.monotonic() >= deadline:
                return None
            time.sleep(0.1)
            continue
        try:
            attributes = termios.tcgetattr(fd)
            iflag, oflag, cflag, lflag = 0, 0, attributes[2], 0
            cflag = (cflag & ~(termios.CSIZE | termios.PARENB | termios.CSTOPB
                               | termios.HUPCL)) | termios.CS8 | termios.CREAD \
                | termios.CLOCAL
            speed = termios.B115200
            cc = attributes[6]
            cc[termios.VMIN] = 0
            cc[termios.VTIME] = 0
            termios.tcsetattr(fd, termios.TCSANOW,
                              [iflag, oflag, cflag, lflag, speed, speed, cc])
        except termios.error:
            pass
        return fd


def lines(port, command, answer, until, wait, silence):
    """The lines read from the port after sending the command, until a line
    contains until. The command is sent again every 3 seconds until a line
    contains answer; if the port disappears, as while the board restarts, it
    is opened again and the command sent anew. Raises TimeoutError if no
    answer comes within wait seconds, or no line within silence seconds of
    the answer."""
    deadline = time.monotonic() + wait
    answered = False
    fd = None
    buffer = b""
    sent = 0.0
    last = time.monotonic()
    try:
        while True:
            now = time.monotonic()
            if not answered and now >= deadline:
                raise TimeoutError("no answer to %r within %d s" % (command, wait))
            if answered and now - last > silence:
                raise TimeoutError("no line for %d s" % silence)
            if fd is None:
                fd = open_port(port, deadline)
                if fd is None:
                    continue
                sent, buffer = 0.0, b""
            if not answered and now - sent >= 3:
                try:
                    os.write(fd, command.encode() + b"\n")
                except OSError:
                    os.close(fd)
                    fd = None
                    continue
                sent = now
            ready, _, _ = select.select([fd], [], [], 0.2)
            if not ready:
                continue
            try:
                data = os.read(fd, 65536)
            except OSError:
                data = b""
            if not data:
                os.close(fd)
                fd = None
                if answered:
                    answered = False
                    deadline = time.monotonic() + wait
                time.sleep(0.1)
                continue
            buffer += data
            while b"\n" in buffer:
                raw, buffer = buffer.split(b"\n", 1)
                line = raw.decode("utf-8", "replace").replace("\r", "")
                last = time.monotonic()
                if answer in line:
                    answered = True
                yield line
                if answered and until in line:
                    return
    finally:
        if fd is not None:
            os.close(fd)


def recordings(lines):
    """The complete recordings of the lines, as (number, header, rows), the
    last copy of each number, in the order of their numbers."""
    found = {}
    number, header, rows, columns = None, None, [], False
    for line in lines:
        if "# Recording " in line:
            header = line[line.index("# Recording "):]
            number = header.split()[2].rstrip(",")
            rows, columns = [], False
        elif number is None:
            continue
        elif "# End of recording " in line:
            words = line[line.index("# End of recording "):].split()
            if (words[4].rstrip(",") == number and columns
                    and int(words[5]) == len(rows)):
                found[int(number)] = (header, rows)
            number = None
        elif "@" in line:
            row = line[line.rindex("@") + 1:]
            if not columns:
                columns = row == COLUMNS
                if not columns:
                    number = None
            elif len(row.split(",")) == 8:
                rows.append(row)
            else:
                number = None
    return [(n,) + found[n] for n in sorted(found)]


def write_csvs(found, prefix):
    for number, header, rows in found:
        path = "%s-%d.csv" % (prefix, number)
        with open(path, "w", encoding="utf-8") as f:
            f.write(COLUMNS + "\n")
            f.write("\n".join(rows) + ("\n" if rows else ""))
        print("Wrote %s: %s, %d rows" % (path, header[2:], len(rows)))


def main():
    parser = argparse.ArgumentParser(description="The recordings of the step counter.")
    sub = parser.add_subparsers(dest="action", required=True)
    capture = sub.add_parser("capture")
    capture.add_argument("--port", required=True)
    capture.add_argument("--wait", type=int, default=30)
    capture.add_argument("prefix")
    erase = sub.add_parser("erase")
    erase.add_argument("--port", required=True)
    erase.add_argument("--wait", type=int, default=30)
    split = sub.add_parser("split")
    split.add_argument("log")
    split.add_argument("prefix")
    arguments = parser.parse_args()

    if arguments.action == "split":
        with open(arguments.log, encoding="utf-8", errors="replace") as f:
            found = recordings(line.rstrip("\r\n") for line in f)
    elif arguments.action == "capture":
        read = []
        try:
            with open(arguments.prefix + ".log", "w", encoding="utf-8") as log:
                for line in lines(arguments.port, "dump", "# Recordings:",
                                  "# End of the recordings", arguments.wait,
                                  10):
                    read.append(line)
                    log.write(line + "\n")
        except TimeoutError as e:
            print("Error: %s; the lines read are in %s.log" % (e, arguments.prefix),
                  file=sys.stderr)
        found = recordings(read)
        arguments.log = arguments.prefix + ".log"
    else:
        try:
            for line in lines(arguments.port, "erase", "# Erasing",
                              "# Recordings erased", arguments.wait, 120):
                print(line)
        except TimeoutError as e:
            sys.exit("Error: %s" % e)
        return
    if not found:
        sys.exit("No complete recording in " + arguments.log)
    write_csvs(found, arguments.prefix)


if __name__ == "__main__":
    main()
