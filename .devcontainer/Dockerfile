FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        opam \
        build-essential \
        pkg-config \
        libsqlite3-dev \
        libgmp-dev \
        libev-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

USER vscode

RUN opam init --disable-sandboxing --auto-setup \
    && opam switch create connections 5.4.0 \
    && eval $(opam env --switch=connections) \
    && opam update

ENV PATH="/home/vscode/.opam/connections/bin:${PATH}"
ENV OPAM_SWITCH_PREFIX="/home/vscode/.opam/connections"
ENV CAML_LD_LIBRARY_PATH="/home/vscode/.opam/connections/lib/stublibs:/home/vscode/.opam/connections/lib/ocaml/stublibs:/home/vscode/.opam/connections/lib/ocaml"
ENV OCAML_TOPLEVEL_PATH="/home/vscode/.opam/connections/lib/toplevel"
