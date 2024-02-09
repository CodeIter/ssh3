#!/usr/bin/env -S bash -euo pipefail

set -euo pipefail
shopt -s autocd
shopt -s globstar
shopt -s extglob
shopt -s nullglob

# build client
echo building client...
bash -xc "go build -o quicssh cmd/quicssh/main.go"

# build server - require gcc
echo building server...
if [[ "${PREFIX:-}" =~ ^/data/data/com.termux[^/]*/files ]] ; then
  bash -xc "CGO_ENABLED=1 go build -tags disable_password_auth -o quicssh-server cmd/quicssh-server/main.go"
else
  bash -xc "CGO_ENABLED=1 go build -o quicssh-server cmd/quicssh-server/main.go"
fi

mkdir -vp ~/.local/bin
cp -afv ./quicssh ./quicssh-server ./quicssh-*.sh ~/.local/bin

