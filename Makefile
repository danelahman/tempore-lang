default: format
	dune build

format:
	dune build @fmt --auto-promote

check-format:
	dune build @fmt

release:
	dune build --profile release

test: default
	dune test

clean:
	dune clean

deps: tempore-deps opentrons-deps

tempore-deps:
	opam install --deps-only --with-dev-setup .

# The Opentrons simulator, opentrons_simulate of the Python package opentrons
# 10.0.0, in the virtual environment _opentrons, created with the first of the
# interpreters below of version 3.10 or later. Skipped with a notice if there
# is none. clean-opentrons removes it, together with the protocols written by
# --emit-opentrons to _opentrons/protocols.
OPENTRONS_VENV = _opentrons
OPENTRONS_PYTHONS = python3.13 python3.12 python3.11 python3.10 python3

opentrons-deps:
	@if [ -x $(OPENTRONS_VENV)/bin/opentrons_simulate ]; then \
	  echo "The Opentrons simulator is installed in $(OPENTRONS_VENV)."; \
	  exit 0; \
	fi; \
	for python in $(OPENTRONS_PYTHONS); do \
	  if command -v $$python > /dev/null 2>&1 && \
	     $$python -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then \
	    echo "Installing the Opentrons simulator in $(OPENTRONS_VENV) with $$python."; \
	    $$python -m venv $(OPENTRONS_VENV) && \
	    $(OPENTRONS_VENV)/bin/pip install --quiet --disable-pip-version-check opentrons==10.0.0 && \
	    mkdir -p $(OPENTRONS_VENV)/config; \
	    exit $$?; \
	  fi; \
	done; \
	echo "Python 3.10 or later was not found; the Opentrons simulator is not installed."

clean-opentrons:
	rm -rf $(OPENTRONS_VENV)

vscode-extension:
	cd editors/vscode && \
	  rm -f vscode-tempore-*.vsix && \
	  npx --yes @vscode/vsce package && \
	  code --install-extension vscode-tempore-*.vsix --force

.PHONY: default format check-format release test clean deps tempore-deps \
  opentrons-deps clean-opentrons vscode-extension
