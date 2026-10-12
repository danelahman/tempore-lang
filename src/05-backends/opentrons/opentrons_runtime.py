# Runtime of the Python programs compiled from Tempore.
#
# Values are represented as follows:
#   nat -> int, float -> float, string -> str, bool -> bool,
#   tuples -> tuple (the unit value is ()),
#   constructors -> Con(tag, arg), the tag the rank of the label in the
#     order of labels of the compiler and arg None for a constant constructor,
#   functions -> Python functions from a value to a computation,
#   handlers -> Handler(ret, clauses),
#   continuations -> Continuation(segments), called as functions.
#
# Computations are effect trees, run by the abstract machine `execute`:
# Ret(v), Bind(c, k), App(f, v), Perform(op, v, k), Handle(c, h),
# Delay(duration, c), and Resume(k, v) and Reinstate(frames, segments, v),
# which the machine builds. The machine is iterative: the evaluation context is
# kept on persistent stacks of cons cells, so that neither long sequences nor
# deep recursion consume Python stack, and a captured continuation may be
# dropped or resumed any number of times.
#
# Durations are exact rationals, in units of the program, converted to seconds
# by the runtime's time unit. The runtime `rt` holds the configuration of a
# run: the binding functions of operations, the clock, the time unit and the
# policy of the monitors of running-time bounds.

import math
import sys
import time
from fractions import Fraction
from functools import partial


class TemporeRuntimeError(Exception):
    """A run-time error of a Tempore program."""


class Stuck(Exception):
    """A computation that has no reduction: a match no case of which matches
    its subject."""


class UnhandledOperation(Exception):
    """A call of an operation that no handler, binding function or default
    implementation handles."""

    def __init__(self, op, arg):
        Exception.__init__(self, op)
        self.op = op
        self.arg = arg


class BoundViolation(Exception):
    """A call of a binding function whose running time is outside the
    running-time bounds of its operation."""

    def __init__(self, op, elapsed, bounds):
        Exception.__init__(self, violation_message(op, elapsed, bounds))
        self.op = op
        self.elapsed = elapsed
        self.bounds = bounds


# Computations.


class Ret:
    __slots__ = ("value",)

    def __init__(self, value):
        self.value = value


class Bind:
    __slots__ = ("comp", "cont")

    def __init__(self, comp, cont):
        self.comp = comp
        self.cont = cont


class App:
    __slots__ = ("fun", "arg")

    def __init__(self, fun, arg):
        self.fun = fun
        self.arg = arg


class Perform:
    __slots__ = ("op", "arg", "cont")

    def __init__(self, op, arg, cont):
        self.op = op
        self.arg = arg
        self.cont = cont


class Handle:
    __slots__ = ("comp", "handler")

    def __init__(self, comp, handler):
        self.comp = comp
        self.handler = handler


class Delay:
    __slots__ = ("duration", "comp")

    def __init__(self, duration, comp):
        self.duration = duration
        self.comp = comp


class Resume:
    __slots__ = ("cont", "value")

    def __init__(self, cont, value):
        self.cont = cont
        self.value = value


class Reinstate:
    __slots__ = ("frames", "segments", "value")

    def __init__(self, frames, segments, value):
        self.frames = frames
        self.segments = segments
        self.value = value


# Values.


class Handler:
    __slots__ = ("ret", "clauses")

    def __init__(self, ret, clauses):
        self.ret = ret
        self.clauses = clauses


class Continuation:
    """The continuation of an operation call up to and including the handler
    that handles it: the segments of the context, each a handler and the
    frames inside it up to the next handler inside, the outermost first, as
    nested pairs (segment, rest) ending in None."""

    __slots__ = ("segments",)

    def __init__(self, segments):
        self.segments = segments

    def __call__(self, value):
        return Resume(self, value)


class Con:
    __slots__ = ("tag", "arg")

    def __init__(self, tag, arg):
        self.tag = tag
        self.arg = arg

    @property
    def name(self):
        return LABELS[self.tag]


# The names of the labels, indexed by tag, and the tags of the list
# constructors.
LABELS = ()
NIL = -1
CONS = -1


def declare_labels(names, nil, cons):
    global LABELS, NIL, CONS
    LABELS = tuple(names)
    NIL = nil
    CONS = cons


# Operations: the running-time bounds the program declares.


class Bounds:
    """The running-time bounds [lo, hi] of an operation, in units of the
    program, each end closed or open."""

    __slots__ = ("lo", "lo_closed", "hi", "hi_closed")

    def __init__(self, lo, lo_closed, hi, hi_closed):
        self.lo = lo
        self.lo_closed = lo_closed
        self.hi = hi
        self.hi_closed = hi_closed

    def scaled(self, unit):
        """The bounds with their ends multiplied by `unit`."""
        return Bounds(self.lo * unit, self.lo_closed, self.hi * unit, self.hi_closed)

    def contains(self, x):
        above = self.lo <= x if self.lo_closed else self.lo < x
        below = x <= self.hi if self.hi_closed else x < self.hi
        return above and below

    def __str__(self):
        return "%s%s, %s%s" % (
            "[" if self.lo_closed else "(",
            format_quantity(self.lo),
            format_quantity(self.hi),
            "]" if self.hi_closed else ")",
        )


# The operations of the program that declare running-time bounds, by name.
OPERATIONS = {}


def declare_operations(bounds):
    global OPERATIONS
    OPERATIONS = dict(bounds)


def format_quantity(x):
    """The number `x`: an exact rational as an integer, a finite decimal or a
    fraction n/d, a float as %g prints it with 12 significant digits."""
    if isinstance(x, float):
        return "%.12g" % x
    x = Fraction(x)
    if x.denominator == 1:
        return str(x.numerator)
    d = x.denominator
    while d % 2 == 0:
        d //= 2
    while d % 5 == 0:
        d //= 5
    if d != 1:
        return "%d/%d" % (x.numerator, x.denominator)
    digits = 0
    scaled = x
    while scaled.denominator != 1:
        scaled *= 10
        digits += 1
    sign = "-" if scaled < 0 else ""
    text = str(abs(scaled.numerator)).rjust(digits + 1, "0")
    return sign + text[:-digits] + "." + text[-digits:]


def violation_message(op, elapsed, bounds):
    return "Operation `%s` took %s s, outside its running-time bounds %s s" % (
        op,
        format_quantity(elapsed),
        bounds,
    )


# Clocks, in seconds.


def exact(x):
    """The number `x` as an exact rational: a pair (n, d) as n/d, a float as
    the rational it represents."""
    if isinstance(x, tuple):
        return Fraction(x[0], x[1])
    return Fraction(x)


class VirtualClock:
    """A clock that advances only by the delays of the program and by the
    durations binding functions declare. Its time is an exact rational."""

    def __init__(self):
        self.time = Fraction(0)

    def now(self):
        return self.time

    def advance(self, seconds):
        self.time += exact(seconds)


class RealClock:
    """The monotonic clock of the host, measured from its creation; delays and
    declared durations do not advance it, as the time they take passes."""

    def __init__(self):
        self.origin = time.monotonic()

    def now(self):
        return time.monotonic() - self.origin

    def advance(self, seconds):
        pass


# The runtime: the configuration of runs and the monitors of binding calls.


class Event:
    """A monitored call of a binding function: the clock's time at its start,
    the operation, its running time and the bounds, in seconds."""

    __slots__ = ("start", "op", "elapsed", "bounds")

    def __init__(self, start, op, elapsed, bounds):
        self.start = start
        self.op = op
        self.elapsed = elapsed
        self.bounds = bounds

    def within(self):
        return self.bounds.contains(self.elapsed)

    def __str__(self):
        text = "At %s s: operation `%s` took %s s, %s its running-time bounds %s s"
        return text % (
            format_quantity(self.start),
            self.op,
            format_quantity(self.elapsed),
            "within" if self.within() else "outside",
            self.bounds,
        )


MONITOR_POLICIES = ("abort", "warn", "off")


def _warn_to_stderr(message):
    sys.stderr.write("Warning: %s\n" % message)


class Runtime:
    """The configuration of the runs of a program.

    binding: the binding functions, a mapping from operation names to
      functions f(ctx, arg) returning the result of the operation;
    ctx: the context passed to the binding functions;
    clock: the clock, VirtualClock() unless given;
    time_unit: the length of one unit of duration of the program in seconds;
    monitor: what a call of a binding function outside the running-time bounds
      of its operation does: "abort" raises BoundViolation, "warn" records
      it and reports it by `report`, "off" neither checks nor records calls;
    on_delay: a function called with the length in seconds of each delay,
      which waits that long, or None;
    report: the function that reports a warning, given its message.

    The timeline lists the monitored calls in order, and violations those
    outside their bounds that did not abort."""

    def __init__(self):
        self.configure()

    def configure(
        self,
        binding=None,
        ctx=None,
        clock=None,
        time_unit=1,
        monitor="abort",
        on_delay=None,
        report=_warn_to_stderr,
    ):
        if monitor not in MONITOR_POLICIES:
            raise ValueError("unknown monitor policy " + repr(monitor))
        self.binding = dict(binding or {})
        self.ctx = ctx
        self.clock = VirtualClock() if clock is None else clock
        self.time_unit = exact(time_unit)
        self.monitor = monitor
        self.on_delay = on_delay
        self.report = report
        self.timeline = []
        self.violations = []

    def seconds(self, duration):
        """The length in seconds of the duration `duration` of the program."""
        return exact(duration) * self.time_unit

    def now(self):
        return self.clock.now()

    def delay(self, duration):
        """Delays for `duration` units of the program."""
        seconds = self.seconds(duration)
        if self.on_delay is not None:
            self.on_delay(float(seconds))
        self.clock.advance(seconds)

    def elapse(self, seconds):
        """Declares that `seconds` seconds pass, as a binding function does for
        the nominal duration of the action it performs."""
        self.clock.advance(seconds)

    def call(self, op, function, arg):
        """The result of the binding function `function` of the operation
        `op` on `arg`, monitored if `op` declares running-time bounds."""
        bounds = OPERATIONS.get(op)
        if bounds is None or self.monitor == "off":
            return function(self.ctx, arg)
        start = self.clock.now()
        value = function(self.ctx, arg)
        elapsed = self.clock.now() - start
        event = Event(start, op, elapsed, bounds.scaled(self.time_unit))
        self.timeline.append(event)
        if not event.within():
            if self.monitor == "abort":
                raise BoundViolation(op, event.elapsed, event.bounds)
            self.violations.append(event)
            self.report(violation_message(op, event.elapsed, event.bounds))
        return value


rt = Runtime()


# The abstract machine.


def execute(comp, defaults=None):
    """The value the computation `comp` returns, its unhandled operations
    performed by their binding functions in `rt` or else their default
    implementations in `defaults`, a mapping from operation names to
    functions from the argument to a computation.

    The state is the current computation and its evaluation context, split at
    the handlers into segments: `frames`, the frames inside the innermost
    handler, each a continuation, as nested pairs (frame, rest) ending in
    None, and `segments`, the handlers from the innermost, each with the
    frames outside it up to the next handler, as nested pairs
    ((handler, frames), rest) ending in None.

    Handlers are deep: an operation call is handled by the innermost handler
    that has a case for it, given the argument and the continuation up to and
    including that handler, whose frames outside it continue the case. An
    operation call no handler handles is unhandled: it calls the operation's
    binding function and continues with its result, or else runs the default
    implementation outside every handler and then continues, or else raises
    UnhandledOperation. A delay delays by `rt.delay`."""
    if defaults is None:
        defaults = {}
    frames = None
    segments = None
    while True:
        cls = comp.__class__
        if cls is App:
            comp = comp.fun(comp.arg)
        elif cls is Bind:
            frames = (comp.cont, frames)
            comp = comp.comp
        elif cls is Ret:
            if frames is not None:
                frame, frames = frames
                comp = frame(comp.value)
            elif segments is not None:
                (handler, frames), segments = segments
                comp = handler.ret(comp.value)
            else:
                return comp.value
        elif cls is Perform:
            op = comp.op
            inside = (comp.cont, frames)
            captured = None
            rest = segments
            clause = None
            while rest is not None:
                (handler, outside), rest = rest
                captured = ((handler, inside), captured)
                clause = handler.clauses.get(op)
                if clause is not None:
                    break
                inside = outside
            if clause is not None:
                frames = outside
                segments = rest
                comp = clause((comp.arg, Continuation(captured)))
            elif op in rt.binding:
                value = rt.call(op, rt.binding[op], comp.arg)
                frames = (comp.cont, frames)
                comp = Ret(value)
            elif op in defaults:
                frames = (partial(Reinstate, (comp.cont, frames), segments), None)
                segments = None
                comp = defaults[op](comp.arg)
            else:
                raise UnhandledOperation(op, comp.arg)
        elif cls is Resume:
            outside = frames
            captured = comp.cont.segments
            while captured is not None:
                (handler, inside), captured = captured
                segments = ((handler, outside), segments)
                outside = inside
            frames = outside
            comp = Ret(comp.value)
        elif cls is Reinstate:
            frames = comp.frames
            segments = comp.segments
            comp = Ret(comp.value)
        elif cls is Handle:
            segments = ((comp.handler, frames), segments)
            frames = None
            comp = comp.comp
        elif cls is Delay:
            rt.delay(comp.duration)
            comp = comp.comp
        else:
            raise TypeError("not a computation: " + repr(comp))


def match_failure():
    raise Stuck()


# Comparison: the structural order of values, constants compared as OCaml
# compares them (floats by Float.compare, strings by bytes).


def _float_compare(x, y):
    if x < y:
        return -1
    if x > y:
        return 1
    if x == y:
        return 0
    x_nan = x != x
    y_nan = y != y
    if x_nan and y_nan:
        return 0
    return -1 if x_nan else 1


def _sign(c):
    return (c > 0) - (c < 0)


def compare(a, b):
    """-1, 0 or 1 as a is less than, equal to or greater than b. Tuples are
    ordered lexicographically, constructors by tag and then by argument."""
    pending = [(a, b)]
    while pending:
        x, y = pending.pop()
        if x is y:
            continue
        cls = x.__class__
        if cls is bool or cls is int or cls is str:
            if x != y:
                return -1 if x < y else 1
        elif cls is float:
            c = _float_compare(x, y)
            if c != 0:
                return c
        elif cls is tuple:
            if len(x) != len(y):
                n = min(len(x), len(y))
                pending.append((len(x), len(y)))
            else:
                n = len(x)
            for i in range(n - 1, -1, -1):
                pending.append((x[i], y[i]))
        elif cls is Con:
            if x.tag != y.tag:
                return -1 if x.tag < y.tag else 1
            if x.arg is None or y.arg is None:
                c = (x.arg is not None) - (y.arg is not None)
                if c != 0:
                    return c
            else:
                pending.append((x.arg, y.arg))
        else:
            raise TemporeRuntimeError("Incomparable expression " + to_string(x))
    return 0


def _comparison(test):
    return lambda v: Ret(test(compare(v[0], v[1])))


prim_compare_eq = _comparison(lambda c: c == 0)
prim_compare_lt = _comparison(lambda c: c < 0)
prim_compare_gt = _comparison(lambda c: c > 0)
prim_compare_le = _comparison(lambda c: c <= 0)
prim_compare_ge = _comparison(lambda c: c >= 0)
prim_compare_ne = _comparison(lambda c: c != 0)


def float_eq(x, y):
    return _float_compare(x, y) == 0


# Arithmetic on natural numbers, subtraction truncated at zero.


def prim_nat_add(v):
    return Ret(v[0] + v[1])


def prim_nat_mul(v):
    return Ret(v[0] * v[1])


def prim_nat_sub(v):
    return Ret(max(0, v[0] - v[1]))


def prim_nat_div(v):
    if v[1] == 0:
        raise TemporeRuntimeError("Division by zero")
    return Ret(v[0] // v[1])


def prim_nat_mod(v):
    if v[1] == 0:
        raise TemporeRuntimeError("Modulo by zero")
    return Ret(v[0] % v[1])


# Arithmetic on floats, with the IEEE 754 results of C where Python raises.


def prim_float_add(v):
    return Ret(v[0] + v[1])


def prim_float_mul(v):
    return Ret(v[0] * v[1])


def prim_float_sub(v):
    return Ret(v[0] - v[1])


def _float_div(x, y):
    if y != 0.0:
        return x / y
    if x != x or x == 0.0:
        return math.nan
    return math.copysign(math.inf, x) * math.copysign(1.0, y)


def prim_float_div(v):
    return Ret(_float_div(v[0], v[1]))


def _is_odd_integer(y):
    return math.isfinite(y) and y == math.floor(y) and math.fmod(y, 2.0) != 0.0


def _float_pow(x, y):
    try:
        return math.pow(x, y)
    except OverflowError:
        return -math.inf if x < 0.0 and _is_odd_integer(y) else math.inf
    except ValueError:
        if x == 0.0:
            negative = math.copysign(1.0, x) < 0.0 and _is_odd_integer(y)
            return -math.inf if negative else math.inf
        return math.nan


def prim_float_pow(v):
    return Ret(_float_pow(v[0], v[1]))


def prim_float_neg(v):
    return Ret(-v)


def prim_to_string(v):
    return Ret(to_string(v))


# The pretty-printing engine of OCaml's Format module (Oppen, Prettyprinting,
# 1980), restricted to text, break hints and boxes, with Format's default
# margin 78 and maximal indentation 68. Widths count Unicode scalar values.

_HBOX, _VBOX, _HVBOX, _HOVBOX, _BOX, _FITS = range(6)
_PP_INFINITY = 1000000010
_TEXT, _BREAK, _BEGIN, _END = range(4)


class _Token:
    __slots__ = ("size", "kind", "data", "length")

    def __init__(self, size, kind, data, length):
        self.size = size
        self.kind = kind
        self.data = data
        self.length = length


class _Formatter:
    def __init__(self, margin=78, min_space_left=10):
        self.margin = margin
        self.max_indent = margin - min_space_left
        self.out = []
        self.queue = []
        self.head = 0
        self.format_stack = []
        self.space_left = margin
        self.current_indent = 0
        self.is_new_line = True
        self.left_total = 1
        self.right_total = 1
        self.depth = 0
        self._reset_scan_stack()
        self.open_box(0, _HOVBOX)

    def _reset_scan_stack(self):
        self.scan_stack = [(-1, _Token(-1, _TEXT, "", 0))]

    # Output.

    def _break_new_line(self, offset, width):
        self.out.append("\n")
        self.is_new_line = True
        indent = min(self.max_indent, self.margin - width + offset)
        self.current_indent = indent
        self.space_left = self.margin - indent
        self.out.append(" " * indent)

    def _break_same_line(self, width):
        self.space_left -= width
        self.out.append(" " * width)

    def _force_break_line(self):
        if not self.format_stack:
            self.out.append("\n")
            return
        box_type, width = self.format_stack[-1]
        if width > self.space_left and box_type not in (_FITS, _HBOX):
            self._break_new_line(0, width)

    def _format_token(self, size, token):
        kind = token.kind
        if kind == _TEXT:
            self.space_left -= size
            self.out.append(token.data)
            self.is_new_line = False
        elif kind == _BEGIN:
            offset, box_type = token.data
            if self.margin - self.space_left > self.max_indent:
                self._force_break_line()
            width = self.space_left - offset
            if box_type != _VBOX and size <= self.space_left:
                box_type = _FITS
            self.format_stack.append((box_type, width))
        elif kind == _END:
            if self.format_stack:
                self.format_stack.pop()
        else:
            fits, offset = token.data
            if not self.format_stack:
                return
            box_type, width = self.format_stack[-1]
            if box_type == _HOVBOX:
                if size > self.space_left:
                    self._break_new_line(offset, width)
                else:
                    self._break_same_line(fits)
            elif box_type == _BOX:
                if self.is_new_line:
                    self._break_same_line(fits)
                elif size > self.space_left:
                    self._break_new_line(offset, width)
                elif self.current_indent > self.margin - width + offset:
                    self._break_new_line(offset, width)
                else:
                    self._break_same_line(fits)
            elif box_type in (_HVBOX, _VBOX):
                self._break_new_line(offset, width)
            else:
                self._break_same_line(fits)

    def _advance_left(self):
        queue = self.queue
        while self.head < len(queue):
            token = queue[self.head]
            pending = self.right_total - self.left_total
            if token.size < 0 and pending < self.space_left:
                return
            self.head += 1
            size = token.size if token.size >= 0 else _PP_INFINITY
            self._format_token(size, token)
            self.left_total += token.length
        del queue[:]
        self.head = 0

    # The scanning stack: the sizes of boxes and break hints.

    def _enqueue(self, token):
        self.right_total += token.length
        self.queue.append(token)

    def _set_size(self, break_hint):
        left_total, token = self.scan_stack[-1]
        if left_total < self.left_total:
            self._reset_scan_stack()
            return
        if token.kind == _BREAK:
            if break_hint:
                token.size = self.right_total + token.size
                self.scan_stack.pop()
        elif token.kind == _BEGIN:
            if not break_hint:
                token.size = self.right_total + token.size
                self.scan_stack.pop()

    def _scan_push(self, break_hint, token):
        if break_hint:
            self.queue.append(token)
            self._set_size(True)
            self.right_total += token.length
        else:
            self._enqueue(token)
        self.scan_stack.append((self.right_total, token))

    # The interface: text, boxes and break hints.

    def text(self, s):
        size = len(s)
        self._enqueue(_Token(size, _TEXT, s, size))
        self._advance_left()

    def open_box(self, indent, box_type):
        self.depth += 1
        token = _Token(-self.right_total, _BEGIN, (indent, box_type), 0)
        self._scan_push(False, token)

    def close_box(self):
        if self.depth > 1:
            self._enqueue(_Token(0, _END, None, 0))
            self._set_size(True)
            self._set_size(False)
            self.depth -= 1

    def cut(self):
        self.brk(0, 0)

    def brk(self, fits, offset):
        token = _Token(-self.right_total, _BREAK, (fits, offset), fits)
        self._scan_push(True, token)

    def flush(self, newline):
        """The text formatted so far, followed by a newline if `newline`."""
        while self.depth > 1:
            self.close_box()
        self.right_total = _PP_INFINITY
        self._advance_left()
        if newline:
            self.out.append("\n")
        return "".join(self.out)


# Printing of values, as the interpreter prints value expressions: the levels
# of precedence of constructor applications parenthesised as there, and
# functions and handlers, whose source is not kept, as <fun> and <handler>.


def _escaped(s):
    parts = ['"']
    for byte in s.encode("utf-8", "surrogateescape"):
        if byte == 0x22:
            parts.append('\\"')
        elif byte == 0x5C:
            parts.append("\\\\")
        elif byte == 0x0A:
            parts.append("\\n")
        elif byte == 0x09:
            parts.append("\\t")
        elif byte == 0x0D:
            parts.append("\\r")
        elif byte == 0x08:
            parts.append("\\b")
        elif 0x20 <= byte <= 0x7E:
            parts.append(chr(byte))
        else:
            parts.append("\\%03d" % byte)
    parts.append('"')
    return "".join(parts)


def float_to_string(x):
    """The float `x` as OCaml's %F prints it."""
    if x != x:
        return "nan"
    if math.isinf(x):
        return "infinity" if x > 0 else "neg_infinity"
    s = "%.12g" % x
    if "." in s or "e" in s or "E" in s:
        return s
    return s + "."


_MAX_LEVEL = sys.maxsize
_PRINT_VALUE, _PRINT_TEXT, _PRINT_OPEN, _PRINT_CLOSE, _PRINT_CUT = range(5)


def _print_value(fmt, value, max_level):
    work = [(_PRINT_VALUE, value, max_level)]
    while work:
        item = work.pop()
        kind = item[0]
        if kind == _PRINT_VALUE:
            _, v, level = item
            cls = v.__class__
            if cls is bool:
                fmt.text("true" if v else "false")
            elif cls is int:
                fmt.text(str(v))
            elif cls is float:
                fmt.text(float_to_string(v))
            elif cls is str:
                fmt.text(_escaped(v))
            elif cls is tuple:
                if not v:
                    fmt.text("()")
                    continue
                items = [(_PRINT_TEXT, "("), (_PRINT_OPEN,)]
                for i, component in enumerate(v):
                    if i > 0:
                        items.append((_PRINT_TEXT, ", "))
                        items.append((_PRINT_CUT,))
                    items.append((_PRINT_VALUE, component, _MAX_LEVEL))
                items.append((_PRINT_CLOSE,))
                items.append((_PRINT_TEXT, ")"))
                work.extend(reversed(items))
            elif cls is Con:
                if v.arg is None:
                    fmt.text("[]" if v.tag == NIL else LABELS[v.tag])
                    continue
                if v.tag == CONS and v.arg.__class__ is tuple and len(v.arg) == 2:
                    items = [
                        (_PRINT_VALUE, v.arg[0], 0),
                        (_PRINT_TEXT, "::"),
                        (_PRINT_VALUE, v.arg[1], 1),
                    ]
                else:
                    items = [
                        (_PRINT_TEXT, LABELS[v.tag] + " "),
                        (_PRINT_VALUE, v.arg, 0),
                    ]
                if level < 1:
                    items = [(_PRINT_TEXT, "(")] + items + [(_PRINT_TEXT, ")")]
                work.extend(reversed(items))
            elif cls is Handler:
                fmt.text("<handler>")
            elif callable(v):
                fmt.text("<fun>")
            else:
                raise TypeError("not a value: " + repr(v))
        elif kind == _PRINT_TEXT:
            fmt.text(item[1])
        elif kind == _PRINT_OPEN:
            fmt.open_box(0, _HOVBOX)
        elif kind == _PRINT_CLOSE:
            fmt.close_box()
        else:
            fmt.cut()


def to_string(value):
    """The value as the primitive to_string prints it."""
    fmt = _Formatter()
    _print_value(fmt, value, _MAX_LEVEL)
    return fmt.flush(False)


def returned(value):
    """The line `return v` the command-line interpreter prints for a run that
    returns the value `v`, with its newline."""
    fmt = _Formatter()
    fmt.text("return ")
    _print_value(fmt, value, 0)
    return fmt.flush(True)


def unhandled(op, arg):
    """The lines the command-line interpreter prints for a run that ends at
    the unhandled call of `op` on `arg`, with the continuation, whose source
    is not kept, as <continuation>."""
    fmt = _Formatter()
    fmt.text("perform %s " % op)
    _print_value(fmt, arg, 0)
    fmt.text(" (<continuation>)")
    return fmt.flush(True)


# The run commands of a program.


class Run:
    """A run command: the function that returns its computation, and the
    default implementations declared above it, by operation name."""

    __slots__ = ("comp", "defaults")

    def __init__(self, comp, defaults):
        self.comp = comp
        self.defaults = defaults


def execute_run(run):
    """The value of the run command `run`, executed by the runtime `rt`."""
    return execute(run.comp(), run.defaults)


def run_plain(runs, **configuration):
    """Executes the run commands `runs` in order with the runtime `rt`
    configured by `configuration`, by default on a virtual clock that delays do
    not wait for, and reports each as the command-line interpreter reports it,
    without the final state of its resources. A run that ends at an unhandled
    operation call is reported as such and the next one follows; a stuck run
    ends the execution; a run-time error or a violation of running-time bounds
    is reported on the standard error and ends the program with exit code 1."""
    rt.configure(**configuration)
    for number, run in enumerate(runs, 1):
        try:
            value = execute_run(run)
        except UnhandledOperation as call:
            sys.stdout.write("=== Run %d (unhandled operation) ===\n" % number)
            sys.stdout.write(unhandled(call.op, call.arg))
            sys.stdout.write("\n")
            continue
        except Stuck:
            return
        except TemporeRuntimeError as error:
            sys.stdout.flush()
            sys.stderr.write("Run-time error: %s\n" % error)
            sys.exit(1)
        except BoundViolation as violation:
            sys.stdout.flush()
            sys.stderr.write("Monitor error: %s\n" % violation)
            sys.exit(1)
        sys.stdout.write("=== Run %d ===\n" % number)
        sys.stdout.write(returned(value))
        sys.stdout.write("\n")
