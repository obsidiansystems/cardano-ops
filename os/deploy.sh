#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p keys
mkdir -p keys/byron

ln -sf globals-alonzo-os.nix globals.nix

(
cd keys
ln -sf ../os/genesis/genesis.json .
ln -sf ../os/genesis/genesis.alonzo.json .
)
(
cd keys/byron
ln -sf ../../os/genesis/byron/genesis.json .
)

./scripts/create-genesis-and-keys.sh
./scripts/create-libvirtd.sh
