# Runtime of the Python programs compiled from Tempore.
#
# Every global name of the runtime and of the compiled program's own
# definitions begins with `tempore_` or `_tempore_`, so that a binding file
# included in the same module keeps the other names.
#
# Values are represented as follows:
#   nat -> int, float -> float, string -> str, bool -> bool,
#   tuples -> tuple (the unit value is ()),
#   constructors -> tempore_Con(tag, arg), the tag the rank of the label in
#     the order of labels of the compiler and arg None for a constant
#     constructor,
#   functions -> Python functions from a value to a computation,
#   handlers -> tempore_Handler(ret, clauses),
#   continuations -> tempore_Continuation(segments), called as functions.
#
# Computations are effect trees, run by the abstract machine
# `tempore_execute`: tempore_Ret(v), tempore_Bind(c, k), tempore_App(f, v),
# tempore_Perform(op, v, k), tempore_Handle(c, h), tempore_Delay(duration, c),
# and tempore_Resume(k, v) and tempore_Reinstate(frames, segments, v), which
# the machine builds. The machine is iterative: the evaluation context is kept
# on persistent stacks of cons cells, so that neither long sequences nor deep
# recursion consume Python stack, and a captured continuation may be dropped
# or resumed any number of times.
#
# Durations are exact rationals, in units of the program, converted to seconds
# by the runtime's time unit. The runtime `tempore_rt` holds the configuration
# of a run: the binding functions of operations, the clock, the time unit and
# the policy of the monitors of running-time bounds.

import math as tempore_math
import sys as tempore_sys
import time as tempore_time
from fractions import Fraction as tempore_Fraction
from functools import partial as tempore_partial


class tempore_RuntimeError(Exception):
    """A run-time error of a Tempore program."""


class tempore_Stuck(Exception):
    """A computation that has no reduction: a match no case of which matches
    its subject."""


class tempore_UnhandledOperation(Exception):
    """A call of an operation that no handler, binding function or default
    implementation handles."""

    def __init__(self, op, arg):
        Exception.__init__(
            self,
            "Operation `%s` has no handler, binding function or default implementation" % op,
        )
        self.op = op
        self.arg = arg


class tempore_BoundViolation(Exception):
    """A call of a binding function whose running time is outside the
    running-time bounds of its operation."""

    def __init__(self, op, elapsed, bounds):
        Exception.__init__(self, tempore_violation_message(op, elapsed, bounds))
        self.op = op
        self.elapsed = elapsed
        self.bounds = bounds


# Computations.


class tempore_Ret:
    __slots__ = ("value",)

    def __init__(self, value):
        self.value = value


class tempore_Bind:
    __slots__ = ("comp", "cont")

    def __init__(self, comp, cont):
        self.comp = comp
        self.cont = cont


class tempore_App:
    __slots__ = ("fun", "arg")

    def __init__(self, fun, arg):
        self.fun = fun
        self.arg = arg


class tempore_Perform:
    __slots__ = ("op", "arg", "cont")

    def __init__(self, op, arg, cont):
        self.op = op
        self.arg = arg
        self.cont = cont


class tempore_Handle:
    __slots__ = ("comp", "handler")

    def __init__(self, comp, handler):
        self.comp = comp
        self.handler = handler


class tempore_Delay:
    __slots__ = ("duration", "comp")

    def __init__(self, duration, comp):
        self.duration = duration
        self.comp = comp


class tempore_Resume:
    __slots__ = ("cont", "value")

    def __init__(self, cont, value):
        self.cont = cont
        self.value = value


class tempore_Reinstate:
    __slots__ = ("frames", "segments", "value")

    def __init__(self, frames, segments, value):
        self.frames = frames
        self.segments = segments
        self.value = value


# Values.


class tempore_Handler:
    __slots__ = ("ret", "clauses")

    def __init__(self, ret, clauses):
        self.ret = ret
        self.clauses = clauses


class tempore_Continuation:
    """The continuation of an operation call up to and including the handler
    that handles it: the segments of the context, each a handler and the
    frames inside it up to the next handler inside, the outermost first, as
    nested pairs (segment, rest) ending in None."""

    __slots__ = ("segments",)

    def __init__(self, segments):
        self.segments = segments

    def __call__(self, value):
        return tempore_Resume(self, value)


class tempore_Con:
    __slots__ = ("tag", "arg")

    def __init__(self, tag, arg):
        self.tag = tag
        self.arg = arg


# The names of the labels, indexed by tag, and the tags of the list
# constructors.
tempore_LABELS = ()
tempore_NIL = -1
tempore_CONS = -1


def tempore_declare_labels(names, nil, cons):
    global tempore_LABELS, tempore_NIL, tempore_CONS
    tempore_LABELS = tuple(names)
    tempore_NIL = nil
    tempore_CONS = cons


# Operations: the bounds of the running times of the operations of the
# program, those they declare or else those their grades imply.


class tempore_Bounds:
    """The bounds [lo, hi] of the running time of an operation, in units of
    the program, each end closed or open; hi is None for no upper bound."""

    __slots__ = ("lo", "lo_closed", "hi", "hi_closed")

    def __init__(self, lo, lo_closed, hi, hi_closed):
        self.lo = lo
        self.lo_closed = lo_closed
        self.hi = hi
        self.hi_closed = hi_closed

    def scaled(self, unit):
        """The bounds with their ends multiplied by `unit`."""
        hi = None if self.hi is None else self.hi * unit
        return tempore_Bounds(self.lo * unit, self.lo_closed, hi, self.hi_closed)

    def contains(self, x):
        above = self.lo <= x if self.lo_closed else self.lo < x
        if self.hi is None:
            return above
        below = x <= self.hi if self.hi_closed else x < self.hi
        return above and below

    def __str__(self):
        if self.hi is None:
            return "%s%s, \u221e)" % (
                "[" if self.lo_closed else "(",
                tempore_format_quantity(self.lo),
            )
        return "%s%s, %s%s" % (
            "[" if self.lo_closed else "(",
            tempore_format_quantity(self.lo),
            tempore_format_quantity(self.hi),
            "]" if self.hi_closed else ")",
        )


# The operations of the program whose running times are bounded, by name.
tempore_OPERATIONS = {}


def tempore_declare_operations(bounds):
    global tempore_OPERATIONS
    tempore_OPERATIONS = dict(bounds)


def tempore_format_quantity(x):
    """The number `x`: an exact rational as an integer, a finite decimal or a
    fraction n/d, a float as %g prints it with 12 significant digits."""
    if isinstance(x, float):
        return "%.12g" % x
    x = tempore_Fraction(x)
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


def tempore_violation_message(op, elapsed, bounds):
    return "Operation `%s` took %s s, outside its running-time bounds %s s" % (
        op,
        tempore_format_quantity(elapsed),
        bounds,
    )


# Clocks, in seconds.


def tempore_exact(x):
    """The number `x` as an exact rational: a pair (n, d) as n/d, a float as
    the rational it represents."""
    if isinstance(x, tuple):
        return tempore_Fraction(x[0], x[1])
    return tempore_Fraction(x)


class tempore_VirtualClock:
    """A clock that advances only by the delays of the program and by the
    durations binding functions declare. Its time is an exact rational."""

    def __init__(self):
        self.time = tempore_Fraction(0)

    def now(self):
        return self.time

    def advance(self, seconds):
        self.time += tempore_exact(seconds)


class tempore_RealClock:
    """The monotonic clock of the host, measured from its creation; delays and
    declared durations do not advance it, as the time they take passes."""

    def __init__(self):
        self.origin = tempore_time.monotonic()

    def now(self):
        return tempore_time.monotonic() - self.origin

    def advance(self, seconds):
        pass


# The runtime: the configuration of runs and the monitors of binding calls.


class tempore_Event:
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
            tempore_format_quantity(self.start),
            self.op,
            tempore_format_quantity(self.elapsed),
            "within" if self.within() else "outside",
            self.bounds,
        )


class tempore_Wait:
    """A delay outside every default implementation: the clock's time at its
    start and its length, in seconds."""

    __slots__ = ("start", "duration")

    def __init__(self, start, duration):
        self.start = start
        self.duration = duration

    def __str__(self):
        return "At %s s: delay of %s s" % (
            tempore_format_quantity(self.start),
            tempore_format_quantity(self.duration),
        )


tempore_MONITOR_POLICIES = ("abort", "warn", "off")


def _tempore_warn_to_stderr(message):
    tempore_sys.stderr.write("Warning: %s\n" % message)


class tempore_Runtime:
    """The configuration of the runs of a program.

    binding: the binding functions, a mapping from operation names to
      functions f(ctx, arg) returning the result of the operation;
    ctx: the context passed to the binding functions;
    clock: the clock, tempore_VirtualClock() unless given;
    time_unit: the length of one unit of duration of the program in seconds;
    monitor: what a call of a binding function outside the running-time bounds
      of its operation does: "abort" raises tempore_BoundViolation, "warn" records
      it and reports it by `report`, "off" neither checks nor records calls;
    on_delay: a function called with the length in seconds of each delay,
      which waits that long, or None;
    on_event: a function called with each monitored call as it completes,
      before its violation is acted on, or None;
    on_wait: a function called with each delay outside every default
      implementation, as a tempore_Wait, before it waits, or None;
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
        on_event=None,
        on_wait=None,
        report=_tempore_warn_to_stderr,
    ):
        if monitor not in tempore_MONITOR_POLICIES:
            raise ValueError("unknown monitor policy " + repr(monitor))
        self.binding = dict(binding or {})
        self.ctx = ctx
        self.clock = tempore_VirtualClock() if clock is None else clock
        self.time_unit = tempore_exact(time_unit)
        self.monitor = monitor
        self.on_delay = on_delay
        self.on_event = on_event
        self.on_wait = on_wait
        self.report = report
        self.timeline = []
        self.violations = []

    def seconds(self, duration):
        """The length in seconds of the duration `duration` of the program."""
        return tempore_exact(duration) * self.time_unit

    def now(self):
        return self.clock.now()

    def delay(self, duration, nested=False):
        """Delays for `duration` units of the program, inside a default
        implementation if `nested`."""
        seconds = self.seconds(duration)
        if not nested and self.on_wait is not None:
            self.on_wait(tempore_Wait(self.clock.now(), seconds))
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
        bounds = tempore_OPERATIONS.get(op)
        if bounds is None or self.monitor == "off":
            return function(self.ctx, arg)
        start = self.clock.now()
        value = function(self.ctx, arg)
        elapsed = self.clock.now() - start
        event = tempore_Event(start, op, elapsed, bounds.scaled(self.time_unit))
        self.timeline.append(event)
        if self.on_event is not None:
            self.on_event(event)
        if not event.within():
            if self.monitor == "abort":
                raise tempore_BoundViolation(op, event.elapsed, event.bounds)
            self.violations.append(event)
            self.report(tempore_violation_message(op, event.elapsed, event.bounds))
        return value


tempore_rt = tempore_Runtime()


# The abstract machine.


def tempore_execute(comp, defaults=None):
    """The value the computation `comp` returns, its unhandled operations
    performed by their binding functions in `tempore_rt` or else their default
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
    tempore_UnhandledOperation. A delay delays by `tempore_rt.delay`;
    `running` counts the default implementations that have not returned."""
    if defaults is None:
        defaults = {}
    frames = None
    segments = None
    running = 0
    while True:
        cls = comp.__class__
        if cls is tempore_App:
            comp = comp.fun(comp.arg)
        elif cls is tempore_Bind:
            frames = (comp.cont, frames)
            comp = comp.comp
        elif cls is tempore_Ret:
            if frames is not None:
                frame, frames = frames
                comp = frame(comp.value)
            elif segments is not None:
                (handler, frames), segments = segments
                comp = handler.ret(comp.value)
            else:
                return comp.value
        elif cls is tempore_Perform:
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
                comp = clause((comp.arg, tempore_Continuation(captured)))
            elif op in tempore_rt.binding:
                value = tempore_rt.call(op, tempore_rt.binding[op], comp.arg)
                frames = (comp.cont, frames)
                comp = tempore_Ret(value)
            elif op in defaults:
                frames = (tempore_partial(tempore_Reinstate, (comp.cont, frames), segments), None)
                segments = None
                running += 1
                comp = defaults[op](comp.arg)
            else:
                raise tempore_UnhandledOperation(op, comp.arg)
        elif cls is tempore_Resume:
            outside = frames
            captured = comp.cont.segments
            while captured is not None:
                (handler, inside), captured = captured
                segments = ((handler, outside), segments)
                outside = inside
            frames = outside
            comp = tempore_Ret(comp.value)
        elif cls is tempore_Reinstate:
            frames = comp.frames
            segments = comp.segments
            running -= 1
            comp = tempore_Ret(comp.value)
        elif cls is tempore_Handle:
            segments = ((comp.handler, frames), segments)
            frames = None
            comp = comp.comp
        elif cls is tempore_Delay:
            tempore_rt.delay(comp.duration, running > 0)
            comp = comp.comp
        else:
            raise TypeError("not a computation: " + repr(comp))


def tempore_match_failure():
    raise tempore_Stuck("A match has no case for its subject")


# Comparison: the structural order of values, constants compared as OCaml
# compares them (floats by Float.compare, strings by bytes).


def _tempore_float_compare(x, y):
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


def tempore_compare(a, b):
    """-1, 0 or 1 as a is less than, equal to or greater than b. Tuples are
    ordered lexicographically, constructors by tag and then by argument."""
    pending = [(a, b)]
    while pending:
        x, y = pending.pop()
        if x is y:
            continue
        cls = x.__class__
        if cls is bool or cls is int or cls is tempore_Int or cls is str:
            if x != y:
                return -1 if x < y else 1
        elif cls is float:
            c = _tempore_float_compare(x, y)
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
        elif cls is tempore_Con:
            if x.tag != y.tag:
                return -1 if x.tag < y.tag else 1
            if x.arg is None or y.arg is None:
                c = (x.arg is not None) - (y.arg is not None)
                if c != 0:
                    return c
            else:
                pending.append((x.arg, y.arg))
        else:
            raise tempore_RuntimeError("Incomparable expression " + tempore_to_string(x))
    return 0


def _tempore_comparison(test):
    return lambda v: tempore_Ret(test(tempore_compare(v[0], v[1])))


tempore_prim_compare_eq = _tempore_comparison(lambda c: c == 0)
tempore_prim_compare_lt = _tempore_comparison(lambda c: c < 0)
tempore_prim_compare_gt = _tempore_comparison(lambda c: c > 0)
tempore_prim_compare_le = _tempore_comparison(lambda c: c <= 0)
tempore_prim_compare_ge = _tempore_comparison(lambda c: c >= 0)
tempore_prim_compare_ne = _tempore_comparison(lambda c: c != 0)


def tempore_float_eq(x, y):
    return _tempore_float_compare(x, y) == 0


# Arithmetic on natural numbers, subtraction truncated at zero.


def tempore_prim_nat_add(v):
    return tempore_Ret(v[0] + v[1])


def tempore_prim_nat_mul(v):
    return tempore_Ret(v[0] * v[1])


def tempore_prim_nat_sub(v):
    return tempore_Ret(max(0, v[0] - v[1]))


def tempore_prim_nat_div(v):
    if v[1] == 0:
        raise tempore_RuntimeError("Division by zero")
    return tempore_Ret(v[0] // v[1])


def tempore_prim_nat_mod(v):
    if v[1] == 0:
        raise tempore_RuntimeError("Modulo by zero")
    return tempore_Ret(v[0] % v[1])


# Arithmetic on floats, with the IEEE 754 results of C where Python raises.


def tempore_prim_float_add(v):
    return tempore_Ret(v[0] + v[1])


def tempore_prim_float_mul(v):
    return tempore_Ret(v[0] * v[1])


def tempore_prim_float_sub(v):
    return tempore_Ret(v[0] - v[1])


def _tempore_float_div(x, y):
    if y != 0.0:
        return x / y
    if x != x or x == 0.0:
        return tempore_math.nan
    return tempore_math.copysign(tempore_math.inf, x) * tempore_math.copysign(1.0, y)


def tempore_prim_float_div(v):
    return tempore_Ret(_tempore_float_div(v[0], v[1]))


def _tempore_is_odd_integer(y):
    return tempore_math.isfinite(y) and y == tempore_math.floor(y) and tempore_math.fmod(y, 2.0) != 0.0


def _tempore_float_pow(x, y):
    try:
        return tempore_math.pow(x, y)
    except OverflowError:
        return -tempore_math.inf if x < 0.0 and _tempore_is_odd_integer(y) else tempore_math.inf
    except ValueError:
        if x == 0.0:
            negative = tempore_math.copysign(1.0, x) < 0.0 and _tempore_is_odd_integer(y)
            return -tempore_math.inf if negative else tempore_math.inf
        return tempore_math.nan


def tempore_prim_float_pow(v):
    return tempore_Ret(_tempore_float_pow(v[0], v[1]))


def tempore_prim_float_neg(v):
    return tempore_Ret(-v)


def tempore_prim_float_sqrt(v):
    return tempore_Ret(tempore_math.nan if v < 0.0 else tempore_math.sqrt(v))


def tempore_prim_float_atan(v):
    return tempore_Ret(tempore_math.atan(v))


def tempore_prim_float_atan2(v):
    return tempore_Ret(tempore_math.atan2(v[0], v[1]))


# Conversions between natural numbers and floats: a natural number to the
# nearest float, infinity beyond the range of floats; a float to the natural
# number truncated toward zero, zero for a negative float and for NaN, and a
# run-time error for infinity.


def tempore_prim_float_of_nat(v):
    try:
        return tempore_Ret(float(v))
    except OverflowError:
        return tempore_Ret(tempore_math.inf)


def tempore_prim_nat_of_float(v):
    if not v > 0.0:
        return tempore_Ret(0)
    if v == tempore_math.inf:
        raise tempore_RuntimeError("Conversion of infinity to a natural number")
    return tempore_Ret(int(v))


# Arithmetic on integers, unbounded, as values of the subclass tempore_Int of
# int, which the printer marks with the suffix i. Division and modulo truncate
# toward zero, as in C: the remainder has the sign of the dividend.


class tempore_Int(int):
    __slots__ = ()


def tempore_prim_int_add(v):
    return tempore_Ret(tempore_Int(v[0] + v[1]))


def tempore_prim_int_mul(v):
    return tempore_Ret(tempore_Int(v[0] * v[1]))


def tempore_prim_int_sub(v):
    return tempore_Ret(tempore_Int(v[0] - v[1]))


def _tempore_int_quotient(a, b):
    q = abs(a) // abs(b)
    return -q if (a < 0) != (b < 0) else q


def tempore_prim_int_div(v):
    if v[1] == 0:
        raise tempore_RuntimeError("Division by zero")
    return tempore_Ret(tempore_Int(_tempore_int_quotient(v[0], v[1])))


def tempore_prim_int_mod(v):
    if v[1] == 0:
        raise tempore_RuntimeError("Modulo by zero")
    return tempore_Ret(tempore_Int(v[0] - v[1] * _tempore_int_quotient(v[0], v[1])))


def tempore_prim_int_neg(v):
    return tempore_Ret(tempore_Int(-v))


# Conversions of integers: a natural number to the same integer; an integer to
# the same natural number, zero for a negative integer; an integer to the
# nearest float, infinity beyond the range of floats; a float to the integer
# truncated toward zero, zero for NaN, and a run-time error for infinity.


def tempore_prim_int_of_nat(v):
    return tempore_Ret(tempore_Int(v))


def tempore_prim_nat_of_int(v):
    return tempore_Ret(max(0, int(v)))


def tempore_prim_float_of_int(v):
    try:
        return tempore_Ret(float(v))
    except OverflowError:
        return tempore_Ret(tempore_math.inf if v > 0 else -tempore_math.inf)


def tempore_prim_int_of_float(v):
    if v != v:
        return tempore_Ret(tempore_Int(0))
    if v == tempore_math.inf or v == -tempore_math.inf:
        raise tempore_RuntimeError("Conversion of infinity to an integer")
    return tempore_Ret(tempore_Int(int(v)))


def tempore_prim_to_string(v):
    return tempore_Ret(tempore_to_string(v))


# The pretty-printing engine of OCaml's Format module (Oppen, Prettyprinting,
# 1980), restricted to text, break hints and boxes, with Format's default
# margin 78 and maximal indentation 68. Widths count Unicode scalar values.

_tempore_HBOX, _tempore_VBOX, _tempore_HVBOX, _tempore_HOVBOX, _tempore_BOX, _tempore_FITS = range(6)
_tempore_PP_INFINITY = 1000000010
_tempore_TEXT, _tempore_BREAK, _tempore_BEGIN, _tempore_END = range(4)


class _tempore_Token:
    __slots__ = ("size", "kind", "data", "length")

    def __init__(self, size, kind, data, length):
        self.size = size
        self.kind = kind
        self.data = data
        self.length = length


class _tempore_Formatter:
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
        self.open_box(0, _tempore_HOVBOX)

    def _reset_scan_stack(self):
        self.scan_stack = [(-1, _tempore_Token(-1, _tempore_TEXT, "", 0))]

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
        if width > self.space_left and box_type not in (_tempore_FITS, _tempore_HBOX):
            self._break_new_line(0, width)

    def _format_token(self, size, token):
        kind = token.kind
        if kind == _tempore_TEXT:
            self.space_left -= size
            self.out.append(token.data)
            self.is_new_line = False
        elif kind == _tempore_BEGIN:
            offset, box_type = token.data
            if self.margin - self.space_left > self.max_indent:
                self._force_break_line()
            width = self.space_left - offset
            if box_type != _tempore_VBOX and size <= self.space_left:
                box_type = _tempore_FITS
            self.format_stack.append((box_type, width))
        elif kind == _tempore_END:
            if self.format_stack:
                self.format_stack.pop()
        else:
            fits, offset = token.data
            if not self.format_stack:
                return
            box_type, width = self.format_stack[-1]
            if box_type == _tempore_HOVBOX:
                if size > self.space_left:
                    self._break_new_line(offset, width)
                else:
                    self._break_same_line(fits)
            elif box_type == _tempore_BOX:
                if self.is_new_line:
                    self._break_same_line(fits)
                elif size > self.space_left:
                    self._break_new_line(offset, width)
                elif self.current_indent > self.margin - width + offset:
                    self._break_new_line(offset, width)
                else:
                    self._break_same_line(fits)
            elif box_type in (_tempore_HVBOX, _tempore_VBOX):
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
            size = token.size if token.size >= 0 else _tempore_PP_INFINITY
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
        if token.kind == _tempore_BREAK:
            if break_hint:
                token.size = self.right_total + token.size
                self.scan_stack.pop()
        elif token.kind == _tempore_BEGIN:
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
        self._enqueue(_tempore_Token(size, _tempore_TEXT, s, size))
        self._advance_left()

    def open_box(self, indent, box_type):
        self.depth += 1
        token = _tempore_Token(-self.right_total, _tempore_BEGIN, (indent, box_type), 0)
        self._scan_push(False, token)

    def close_box(self):
        if self.depth > 1:
            self._enqueue(_tempore_Token(0, _tempore_END, None, 0))
            self._set_size(True)
            self._set_size(False)
            self.depth -= 1

    def cut(self):
        self.brk(0, 0)

    def brk(self, fits, offset):
        token = _tempore_Token(-self.right_total, _tempore_BREAK, (fits, offset), fits)
        self._scan_push(True, token)

    def flush(self, newline):
        """The text formatted so far, followed by a newline if `newline`."""
        while self.depth > 1:
            self.close_box()
        self.right_total = _tempore_PP_INFINITY
        self._advance_left()
        if newline:
            self.out.append("\n")
        return "".join(self.out)


# Printing of values, as the interpreter prints value expressions: the levels
# of precedence of constructor applications parenthesised as there, and
# functions and handlers, whose source is not kept, as <fun> and <handler>.


def _tempore_escaped(s):
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


def tempore_float_to_string(x):
    """The float `x` as OCaml's %F prints it."""
    if x != x:
        return "nan"
    if tempore_math.isinf(x):
        return "infinity" if x > 0 else "neg_infinity"
    s = "%.12g" % x
    if "." in s or "e" in s or "E" in s:
        return s
    return s + "."


_tempore_MAX_LEVEL = tempore_sys.maxsize
_tempore_PRINT_VALUE, _tempore_PRINT_TEXT, _tempore_PRINT_OPEN, _tempore_PRINT_CLOSE, _tempore_PRINT_CUT = range(5)


def _tempore_print_value(fmt, value, max_level):
    work = [(_tempore_PRINT_VALUE, value, max_level)]
    while work:
        item = work.pop()
        kind = item[0]
        if kind == _tempore_PRINT_VALUE:
            _, v, level = item
            cls = v.__class__
            if cls is bool:
                fmt.text("true" if v else "false")
            elif cls is int:
                fmt.text(str(v))
            elif cls is tempore_Int:
                fmt.text("%di" % v)
            elif cls is float:
                fmt.text(tempore_float_to_string(v))
            elif cls is str:
                fmt.text(_tempore_escaped(v))
            elif cls is tuple:
                if not v:
                    fmt.text("()")
                    continue
                items = [(_tempore_PRINT_TEXT, "("), (_tempore_PRINT_OPEN,)]
                for i, component in enumerate(v):
                    if i > 0:
                        items.append((_tempore_PRINT_TEXT, ", "))
                        items.append((_tempore_PRINT_CUT,))
                    items.append((_tempore_PRINT_VALUE, component, _tempore_MAX_LEVEL))
                items.append((_tempore_PRINT_CLOSE,))
                items.append((_tempore_PRINT_TEXT, ")"))
                work.extend(reversed(items))
            elif cls is tempore_Con:
                if v.arg is None:
                    fmt.text("[]" if v.tag == tempore_NIL else tempore_LABELS[v.tag])
                    continue
                if v.tag == tempore_CONS and v.arg.__class__ is tuple and len(v.arg) == 2:
                    items = [
                        (_tempore_PRINT_VALUE, v.arg[0], 0),
                        (_tempore_PRINT_TEXT, "::"),
                        (_tempore_PRINT_VALUE, v.arg[1], 1),
                    ]
                else:
                    items = [
                        (_tempore_PRINT_TEXT, tempore_LABELS[v.tag] + " "),
                        (_tempore_PRINT_VALUE, v.arg, 0),
                    ]
                if level < 1:
                    items = [(_tempore_PRINT_TEXT, "(")] + items + [(_tempore_PRINT_TEXT, ")")]
                work.extend(reversed(items))
            elif cls is tempore_Handler:
                fmt.text("<handler>")
            elif callable(v):
                fmt.text("<fun>")
            else:
                raise TypeError("not a value: " + repr(v))
        elif kind == _tempore_PRINT_TEXT:
            fmt.text(item[1])
        elif kind == _tempore_PRINT_OPEN:
            fmt.open_box(0, _tempore_HOVBOX)
        elif kind == _tempore_PRINT_CLOSE:
            fmt.close_box()
        else:
            fmt.cut()


def tempore_to_string(value):
    """The value as the primitive to_string prints it."""
    fmt = _tempore_Formatter()
    _tempore_print_value(fmt, value, _tempore_MAX_LEVEL)
    return fmt.flush(False)


def tempore_returned(value):
    """The line `return v` the command-line interpreter prints for a run that
    returns the value `v`, with its newline."""
    fmt = _tempore_Formatter()
    fmt.text("return ")
    _tempore_print_value(fmt, value, 0)
    return fmt.flush(True)


def tempore_unhandled(op, arg):
    """The lines the command-line interpreter prints for a run that ends at
    the unhandled call of `op` on `arg`, with the continuation, whose source
    is not kept, as <continuation>."""
    fmt = _tempore_Formatter()
    fmt.text("perform %s " % op)
    _tempore_print_value(fmt, arg, 0)
    fmt.text(" (<continuation>)")
    return fmt.flush(True)


# The run commands of a program.


class tempore_Run:
    """A run command: the function that returns its computation, and the
    default implementations declared above it, by operation name."""

    __slots__ = ("comp", "defaults")

    def __init__(self, comp, defaults):
        self.comp = comp
        self.defaults = defaults


def tempore_execute_run(run):
    """The value of the run command `run`, executed by the runtime `tempore_rt`."""
    return tempore_execute(run.comp(), run.defaults)


def tempore_run_plain(runs, **configuration):
    """Executes the run commands `runs` in order with the runtime `tempore_rt`
    configured by `configuration`, by default on a virtual clock that delays do
    not wait for, and reports each as the command-line interpreter reports it,
    without the final state of its resources. A run that ends at an unhandled
    operation call is reported as such and the next one follows; a stuck run
    ends the execution; a run-time error or a violation of running-time bounds
    is reported on the standard error and ends the program with exit code 1."""
    tempore_rt.configure(**configuration)
    for number, run in enumerate(runs, 1):
        try:
            value = tempore_execute_run(run)
        except tempore_UnhandledOperation as call:
            tempore_sys.stdout.write("=== Run %d (unhandled operation) ===\n" % number)
            tempore_sys.stdout.write(tempore_unhandled(call.op, call.arg))
            tempore_sys.stdout.write("\n")
            continue
        except tempore_Stuck:
            return
        except tempore_RuntimeError as error:
            tempore_sys.stdout.flush()
            tempore_sys.stderr.write("Run-time error: %s\n" % error)
            tempore_sys.exit(1)
        except tempore_BoundViolation as violation:
            tempore_sys.stdout.flush()
            tempore_sys.stderr.write("Monitor error: %s\n" % violation)
            tempore_sys.exit(1)
        tempore_sys.stdout.write("=== Run %d ===\n" % number)
        tempore_sys.stdout.write(tempore_returned(value))
        tempore_sys.stdout.write("\n")


def tempore_elapse(seconds):
    """Declares that `seconds` seconds pass on the clock of the runtime, as a
    binding function does for the nominal duration of the action it
    performs; on the real clock, which measures the time that passes, it has
    no effect."""
    tempore_rt.elapse(seconds)


def tempore_run_protocol(protocol, runs, setup, binding, time_unit=1, monitor="abort"):
    """Executes the run commands `runs` in order as the Opentrons protocol
    `protocol`, the binding functions `binding`, by operation name, given the
    context `setup(protocol)` returns. In simulation the clock is virtual,
    and on the robot it is the monotonic clock of the host. A delay calls
    `protocol.delay`, and a warning of a monitor `protocol.comment`. Each
    run is announced by a comment, each monitored call is commented as it
    completes, each delay outside every default implementation before it
    waits, and the value of the run is commented at its end; an error of
    a run, a violation of running-time bounds under the policy "abort"
    included, ends the protocol with that error, after the comment of the
    call that violated them."""
    ctx = setup(protocol)
    clock = tempore_VirtualClock() if protocol.is_simulating() else tempore_RealClock()
    tempore_rt.configure(
        binding=binding,
        ctx=ctx,
        clock=clock,
        time_unit=time_unit,
        monitor=monitor,
        on_delay=lambda seconds: protocol.delay(seconds=seconds),
        on_event=lambda event: protocol.comment("Tempore timeline: %s" % event),
        on_wait=lambda wait: protocol.comment("Tempore timeline: %s" % wait),
        report=lambda message: protocol.comment("Tempore warning: " + message),
    )
    for number, run in enumerate(runs, 1):
        protocol.comment("Tempore run %d" % number)
        value = tempore_execute_run(run)
        protocol.comment("Tempore run %d returns %s" % (number, tempore_to_string(value)))
