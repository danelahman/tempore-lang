# A stub of opentrons.protocol_api: a protocol context that prints each command
# a protocol gives, one per line, with labware and wells named by their deck
# slot.


class Well:
    def __init__(self, labware, name):
        self.labware = labware
        self.name = name

    def top(self):
        return Location(self, "top")

    def __repr__(self):
        return "%s of %s" % (self.name, self.labware.location)


class Location:
    def __init__(self, well, position):
        self.well = well
        self.position = position

    def __repr__(self):
        return "%s of %r" % (self.position, self.well)


class Labware:
    def __init__(self, load_name, location):
        self.load_name = load_name
        self.location = location

    def __getitem__(self, name):
        return Well(self, name)

    def __repr__(self):
        return "%s in %s" % (self.load_name, self.location)


class Instrument:
    """A pipette or a module: each method call is printed."""

    def __init__(self, context, name):
        self._context = context
        self._name = name

    def load_labware(self, load_name):
        return self._context._load(Labware(load_name, self._name), self._name + ".load_labware", load_name)

    def __getattr__(self, method):
        def command(*args, **kwargs):
            self._context._record(self._name + "." + method, *args, **kwargs)

        return command

    def __repr__(self):
        return self._name


class ProtocolContext:
    def __init__(self, simulating=True):
        self._simulating = simulating

    def _record(self, name, *args, **kwargs):
        arguments = [repr(a) for a in args] + ["%s=%r" % kv for kv in sorted(kwargs.items())]
        print("%s(%s)" % (name, ", ".join(arguments)))

    def _load(self, value, name, *args, **kwargs):
        self._record(name, *args, **kwargs)
        return value

    def is_simulating(self):
        return self._simulating

    def load_labware(self, load_name, location, **kwargs):
        return self._load(Labware(load_name, location), "load_labware", load_name, location, **kwargs)

    def load_trash_bin(self, location):
        return self._load(Labware("trash_bin", location), "load_trash_bin", location)

    def load_instrument(self, instrument_name, mount, **kwargs):
        return self._load(Instrument(self, "pipette"), "load_instrument", instrument_name, mount, **kwargs)

    def load_module(self, module_name, location):
        return self._load(Instrument(self, module_name), "load_module", module_name, location)

    def move_labware(self, labware, new_location, **kwargs):
        self._record("move_labware", labware, new_location, **kwargs)

    def delay(self, seconds=0, minutes=0, msg=None):
        self._record("delay", seconds=seconds)

    def comment(self, msg):
        print("comment: %s" % msg)

    def pause(self, msg=None):
        self._record("pause", msg)
