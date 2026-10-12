#!/bin/sh
# Compiles the Opentrons examples to protocols and runs each with the
# Opentrons simulator, opentrons_simulate, of the opentrons package 10.0.0,
# installed in a Python virtual environment, by 'tempore --simulate'. Not
# part of 'make test': it needs the network if the environment does not exist.
#
# Usage: scripts/opentrons-simulate.sh [VENV_DIR]
#
# VENV_DIR, or else $OPENTRONS_VENV, or else _opentrons (the environment of
# 'make opentrons-deps'), is the virtual environment, created with $PYTHON
# (default python3.12) if it does not hold the simulator. The simulator keeps
# its configuration in VENV_DIR/config unless $OT_API_CONFIG_DIR is set.
# The protocols and the logs of the simulator are written to VENV_DIR/runs.
# Run from the root of the repository, after 'make'.

set -eu

venv=${1:-${OPENTRONS_VENV:-_opentrons}}
python=${PYTHON:-python3.12}

if [ ! -x "$venv/bin/opentrons_simulate" ]; then
  "$python" -m venv "$venv"
  "$venv/bin/pip" install --quiet --disable-pip-version-check opentrons==10.0.0
fi

OT_API_CONFIG_DIR=${OT_API_CONFIG_DIR:-$venv/config}
export OT_API_CONFIG_DIR
mkdir -p "$OT_API_CONFIG_DIR" "$venv/runs"

status=0
# Each example: its name, its grades, its time unit.
for example in \
  "elisa time-interval minutes" \
  "washes regex-timed-interval-symbolic minutes" \
  "contamination time-upper-bound-levels minutes" \
  "reagents time-interval minutes" \
  "staggered time-interval minutes" \
  "beads time-interval minutes" \
  "stopread time-interval minutes"
do
  set -- $example
  name=$1
  log="$venv/runs/$name.log"
  if ./tempore --grades "$2" --emit-opentrons "$venv/runs/$name.py" \
       --bind "examples/opentrons/${name}_bindings.py" --time-unit "$3" \
       --simulate --simulator "$venv/bin/opentrons_simulate" \
       "examples/opentrons/$name.tpe" > "$log" 2>&1; then
    echo "$name: accepted by the simulator, $(grep -c 'Tempore timeline' "$log") timeline comments"
  else
    echo "$name: rejected by the simulator; see $log"
    status=1
  fi
done
exit $status
