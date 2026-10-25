# The development container of Tempore: OCaml 5.5 with the opam packages of
# tempore.opam and the development tools, a C++17 compiler for the Arduino
# tests and host simulations, Node.js for the tests of the web interface, and
# Python 3 with venv for the Opentrons tests and for 'make arduino-deps' and
# 'make opentrons-deps'. Ubuntu with GCC, as the continuous integration.

FROM ubuntu:24.04

ARG OCAML_VERSION=5.5.0
ARG OPAM_VERSION=2.6.1
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bubblewrap build-essential ca-certificates curl g++ git less libgmp-dev \
      m4 make nodejs npm patch pkg-config python3 python3-pip python3-venv \
      rsync sudo unzip zip \
 && rm -rf /var/lib/apt/lists/*

# opam from its release binaries, the distribution's being older than the
# option --with-dev-setup of tempore-deps.
RUN case "$(uname -m)" in \
      aarch64|arm64) arch=arm64 ;; \
      x86_64|amd64) arch=x86_64 ;; \
      *) echo "unsupported architecture $(uname -m)" >&2; exit 1 ;; \
    esac \
 && curl -fsSL -o /usr/local/bin/opam \
      "https://github.com/ocaml/opam/releases/download/$OPAM_VERSION/opam-$OPAM_VERSION-$arch-linux" \
 && chmod 0755 /usr/local/bin/opam

# The image's default user 'ubuntu' holds UID 1000; it is replaced by the
# development user, with password-free sudo.
RUN userdel -r ubuntu 2>/dev/null || true \
 && groupadd --gid "$USER_GID" "$USERNAME" \
 && useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME" \
 && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
 && chmod 0440 "/etc/sudoers.d/$USERNAME"

USER $USERNAME
WORKDIR /home/$USERNAME

ENV OPAMROOT=/home/$USERNAME/.opam \
    OPAMYES=1 \
    OPAMCONFIRMLEVEL=unsafe-yes

RUN opam init --bare --disable-sandboxing --no-setup \
 && opam switch create "$OCAML_VERSION" "ocaml-base-compiler.$OCAML_VERSION" \
 && opam clean -a -c -s --logs

# The environment of the switch, as 'opam env' sets it, for every process of
# the container, the editor's language server included.
ENV OPAM_SWITCH_PREFIX=$OPAMROOT/$OCAML_VERSION \
    CAML_LD_LIBRARY_PATH=$OPAMROOT/$OCAML_VERSION/lib/stublibs:$OPAMROOT/$OCAML_VERSION/lib/ocaml/stublibs:$OPAMROOT/$OCAML_VERSION/lib/ocaml \
    OCAML_TOPLEVEL_PATH=$OPAMROOT/$OCAML_VERSION/lib/toplevel \
    MANPATH=:$OPAMROOT/$OCAML_VERSION/man \
    PATH=$OPAMROOT/$OCAML_VERSION/bin:$PATH

# The dependencies of tempore.opam, with the development setup (ocamlformat),
# and the language server and toplevel for the editor. Only the opam file is
# copied, so that this layer is rebuilt only when the dependencies change.
COPY --chown=$USERNAME:$USERNAME tempore.opam /tmp/tempore/tempore.opam
RUN opam install --deps-only --with-dev-setup /tmp/tempore \
 && opam install ocaml-lsp-server utop \
 && opam clean -a -c -s --logs \
 && rm -rf /tmp/tempore

RUN echo 'eval "$(opam env)"' >> /home/$USERNAME/.bashrc
