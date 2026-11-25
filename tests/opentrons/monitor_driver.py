# Runs the program compiled from monitors.tpe, given as the argument, with
# stub binding functions that declare a duration on the virtual clock, and
# prints the outcome of each call under each monitor policy.

import importlib.util
import sys
from fractions import Fraction

spec = importlib.util.spec_from_file_location("monitors", sys.argv[1])
program = importlib.util.module_from_spec(spec)
spec.loader.exec_module(program)
rt = program.tempore_rt
Monitor = program.tempore_Monitor


def operation(name):
    return getattr(program, "tempore_op_" + name)


def taking(seconds):
    def binding(ctx, arg):
        rt.elapse(seconds)
        return arg + 1

    return binding


def attempt(run, **configuration):
    reports = []
    rt.configure(report=reports.append, **configuration)
    try:
        outcome = "returns %s" % program.tempore_execute_run(program.tempore_RUNS[run])
    except program.tempore_BoundViolation as violation:
        outcome = "aborts: %s" % violation
    return outcome, reports


for policy in (Monitor.ABORT, Monitor.WARN):
    print("Policy %s:" % policy.value)
    for run, name in enumerate(("CC", "OO", "CO", "OC")):
        op = operation(name)
        for seconds in (1, 2, 3, 4, 5):
            outcome, reports = attempt(
                run, binding={op: taking(seconds)}, monitor=policy
            )
            print("  %s %s, %d s: %s" % (op, op.bounds, seconds, outcome))
            for report in reports:
                print("    reported: %s" % report)
            if policy is Monitor.WARN:
                assert len(rt.violations) == len(reports)

print("Policy off:")
outcome, reports = attempt(
    0, binding={operation("CC"): taking(5)}, monitor=Monitor.OFF
)
print("  CC, 5 s: %s, %d monitored calls" % (outcome, len(rt.timeline)))

print("Exact durations:")
for seconds in (Fraction(1, 2), (3, 2), Fraction(3, 2) + Fraction(1, 10**9)):
    outcome, reports = attempt(4, binding={operation("Wait"): taking(seconds)})
    duration = program.tempore_format_quantity(program.tempore_exact(seconds))
    print("  Wait, %s s: %s" % (duration, outcome))

print("Time unit of 60 s:")
outcome, reports = attempt(0, binding={operation("CC"): taking(150)}, time_unit=60)
print("  CC, 150 s: %s" % outcome)
outcome, reports = attempt(0, binding={operation("CC"): taking(100)}, time_unit=60)
print("  CC, 100 s: %s" % outcome)

print("Timeline:")
rt.configure(
    binding={
        operation("CC"): taking(3),
        operation("OO"): taking(5),
        operation("CO"): taking(2),
        operation("OC"): taking(4),
    },
    monitor=Monitor.WARN,
    report=lambda message: None,
)
for run in range(5):
    program.tempore_execute_run(program.tempore_RUNS[run])
for event in rt.timeline:
    print("  %s" % event)
print("  clock at the end: %s s" % program.tempore_format_quantity(rt.now()))

print("Delays and the default of Wait, time unit 60 s:")
rt.configure(time_unit=60)
print("  returns %s at %s s, %d monitored calls" % (
    program.tempore_execute_run(program.tempore_RUNS[4]),
    program.tempore_format_quantity(rt.now()),
    len(rt.timeline),
))
