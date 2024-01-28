#!/usr/bin/env -S bash -euo pipefail

set -euo pipefail
shopt -s autocd
shopt -s globstar
shopt -s extglob
shopt -s nullglob

# build client
echo building client...
bash -xc "go build -o ssh3 cmd/ssh3/main.go"

# build server - require gcc
echo building server...
if [[ "${PREFIX:-}" =~ ^/data/data/com.termux[^/]*/files ]] ; then
  bash -xc "CGO_ENABLED=1 go build -tags disable_password_auth -o ssh3-server cmd/ssh3-server/main.go"
else
  bash -xc "CGO_ENABLED=1 go build -o ssh3-server cmd/ssh3-server/main.go"
fi

mkdir -vp ~/.local/bin
cp -afv ./ssh3 ./ssh3-server ./ssh3-*.sh ~/.local/bin

