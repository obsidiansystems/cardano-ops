#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p keys
mkdir -p keys/byron

ln -sf globals-alonzo-os.nix globals.nix

(
cd keys
cp -vf ../os/genesis/genesis.json .
cp -vf ../os/genesis/genesis.alonzo.json .
)
(
cd keys/byron
cp -vf ../../os/genesis/byron/genesis.json .
)

nix-shell --run "./scripts/create-genesis-and-keys.sh"
nix-shell --run "./scripts/create-libvirtd.sh"
