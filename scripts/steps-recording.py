#!/usr/bin/env python3
"""Reads and erases the recordings of the step counter.

Talks to examples/arduino/steps/bindings.cpp built under the build flag
STEPS_RECORD over its serial port, by the commands "dump", "dump N" and
"erase":

    steps-recording.py capture --port PORT [--wait SECONDS] PREFIX
    steps-recording.py erase --port PORT [--wait SECONDS]
    steps-recording.py split LOG PREFIX

capture sends "dump", then "dump N" for each recording N up to the last
that did not arrive complete, at most three times each, and writes the lines
read to PREFIX.log and each complete recording N to PREFIX-N.csv, with the
columns t_ms, ax, ay, az, gx, gy, gz and event; erase sends "erase" and
waits for its confirmation; split extracts the recordings of a log written
by capture or by the host simulation.

Each line of the dump ends with "*" and the CRC-16/CCITT-FALSE of the
characters before it, in four hexadecimal digits; a line whose checksum
does not match is damaged. A recording is complete if its line "# End of
recording N, R rows" follows its line "# Recording N", its line of columns
and R rows of 8 fields, all undamaged. The lines of the dump that begin with
"@" or "#" may follow text of the log written at the same time, which is
ignored.

The port is opened in raw mode, its modem control lines left as opening it
sets them, and kept open from one command to the next. A command is sent
again every 3 seconds until the first line of its answer arrives, and not
after it; the port is opened again if it disappears before the answer, as
while the board restarts, so that a reset of the board by the opening of
the port does not matter. The device has SECONDS (default 30) to answer,
and then 10 seconds between the lines of a dump and 120 seconds for an
erase; an answer cut short is re-requested by the recordings it lacks.

Uses the Python standard library only.
"""

import argparse
import os
import re
import select
import sys
import termios
import time

COLUMNS = "t_ms,ax,ay,az,gx,gy,gz,event"
ATTEMPTS = 3


def crc16(data):
    """The CRC-16/CCITT-FALSE of the bytes: the polynomial 0x1021, the
    initial value 0xffff, bit by bit."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc


def payload(line):
    """The line of the dump that the line ends with, without its checksum,
    or None if the line holds none or it is damaged: the shortest suffix
    from a "@" or "#" whose checksum matches."""
    star = line.rfind("*")
    if star < 0 or len(line) != star + 5:
        return None
    try:
        expected = int(line[star + 1:], 16)
    except ValueError:
        return None
    for i in range(star - 1, -1, -1):
        if line[i] in "@#" and crc16(line[i:star].encode()) == expected:
            return line[i:star]
    return None


def of_dump(line):
    """Whether the line is meant as a line of the dump."""
    return "@" in line or "# Record" in line or "# End of" in line


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


class Port:
    """A serial port kept open across commands, opened again when it
    disappears."""

    def __init__(self, path):
        self.path = path
        self.fd = None

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def lines(self, command, answer, until, wait, silence):
        """The lines read after sending the command, until a line contains
        until. The command is sent again every 3 seconds until a line
        contains answer, and not after it; if the port disappears before the
        answer, it is opened again and the command sent anew. Raises
        TimeoutError if no answer comes within wait seconds, or no line
        within silence seconds of the answer, and ConnectionError if the
        port disappears after the answer."""
        deadline = time.monotonic() + wait
        answered = False
        buffer = b""
        sent = 0.0
        last = time.monotonic()
        while True:
            now = time.monotonic()
            if not answered and now >= deadline:
                raise TimeoutError("no answer to %r within %d s" % (command, wait))
            if answered and now - last > silence:
                raise TimeoutError("no line for %d s" % silence)
            if self.fd is None:
                self.fd = open_port(self.path, deadline)
                if self.fd is None:
                    continue
                sent, buffer = 0.0, b""
            if not answered and now - sent >= 3:
                try:
                    os.write(self.fd, command.encode() + b"\n")
                except OSError:
                    self.close()
                    continue
                sent = now
            ready, _, _ = select.select([self.fd], [], [], 0.2)
            if not ready:
                continue
            try:
                data = os.read(self.fd, 65536)
            except OSError:
                data = b""
            if not data:
                self.close()
                if answered:
                    raise ConnectionError("the port closed during the answer")
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


def recordings(lines):
    """The complete recordings of the lines, as a map from their numbers to
    (header, rows), the last copy of each number, and the number of the last
    recording announced by a dump, or 0."""
    found = {}
    last = 0
    number, header, rows, columns = None, None, [], False
    for line in lines:
        text = payload(line)
        if text is None:
            if of_dump(line):
                number = None
            continue
        if text.startswith("# Recordings: "):
            announced = re.search(r"the last recording (\d+)", text)
            if announced:
                last = max(last, int(announced.group(1)))
            number = None
        elif text.startswith("# Recording "):
            header = text
            number = text.split()[2].rstrip(",")
            rows, columns = [], False
        elif number is None:
            continue
        elif text.startswith("# End of recording "):
            words = text.split()
            if (words[4].rstrip(",") == number and columns
                    and int(words[5]) == len(rows)):
                found[int(number)] = (header, rows)
            number = None
        elif text.startswith("@"):
            row = text[1:]
            if not columns:
                columns = row == COLUMNS
                if not columns:
                    number = None
            elif len(row.split(",")) == 8:
                rows.append(row)
            else:
                number = None
    return found, last


def write_csvs(found, prefix):
    for number in sorted(found):
        header, rows = found[number]
        path = "%s-%d.csv" % (prefix, number)
        with open(path, "w", encoding="utf-8") as f:
            f.write(COLUMNS + "\n")
            f.write("\n".join(rows) + ("\n" if rows else ""))
        print("Wrote %s: %s, %d rows" % (path, header[2:], len(rows)))


def request(port, command, wait, log, read):
    """The lines of the answer to a command of the dump, added to read and
    written to the log; those read before an error, which is reported."""
    try:
        for line in port.lines(command, "# Recordings:",
                               "# End of the recordings", wait, 10):
            read.append(line)
            log.write(line + "\n")
    except (TimeoutError, ConnectionError) as e:
        print("Error: %r: %s" % (command, e), file=sys.stderr)


def capture(arguments):
    """The complete recordings of a dump, those damaged or missing requested
    again one by one."""
    port = Port(arguments.port)
    read = []
    try:
        with open(arguments.prefix + ".log", "w", encoding="utf-8") as log:
            request(port, "dump", arguments.wait, log, read)
            found, last = recordings(read)
            for _ in range(ATTEMPTS):
                missing = [n for n in range(1, last + 1) if n not in found]
                if not missing:
                    break
                for n in missing:
                    print("Requesting the recording %d again" % n,
                          file=sys.stderr)
                    answer = []
                    request(port, "dump %d" % n, arguments.wait, log, answer)
                    read.extend(answer)
                    more, _ = recordings(answer)
                    found.update(more)
    finally:
        port.close()
    missing = [n for n in range(1, last + 1) if n not in found]
    if missing:
        print("Error: incomplete recordings %s" % missing, file=sys.stderr)
    return found


def main():
    parser = argparse.ArgumentParser(description="The recordings of the step counter.")
    sub = parser.add_subparsers(dest="action", required=True)
    capture_parser = sub.add_parser("capture")
    capture_parser.add_argument("--port", required=True)
    capture_parser.add_argument("--wait", type=int, default=30)
    capture_parser.add_argument("prefix")
    erase = sub.add_parser("erase")
    erase.add_argument("--port", required=True)
    erase.add_argument("--wait", type=int, default=30)
    split = sub.add_parser("split")
    split.add_argument("log")
    split.add_argument("prefix")
    arguments = parser.parse_args()

    if arguments.action == "split":
        with open(arguments.log, encoding="utf-8", errors="replace") as f:
            found, _ = recordings(line.rstrip("\r\n") for line in f)
    elif arguments.action == "capture":
        found = capture(arguments)
        arguments.log = arguments.prefix + ".log"
    else:
        port = Port(arguments.port)
        try:
            for line in port.lines("erase", "# Erasing", "# Recordings erased",
                                   arguments.wait, 120):
                text = payload(line)
                print(text if text is not None else line)
        except (TimeoutError, ConnectionError) as e:
            sys.exit("Error: %s" % e)
        finally:
            port.close()
        return
    if not found:
        sys.exit("No complete recording in " + arguments.log)
    write_csvs(found, arguments.prefix)


if __name__ == "__main__":
    main()
