#!/usr/bin/env -S bash -euo pipefail

set -euo pipefail
shopt -s autocd
shopt -s globstar
shopt -s extglob
shopt -s nullglob

help() {
  cat << EOF
Usage: ssh3-server.sh [-h|--help]

Environment Variables:

  - SSH3_HOST: Hostname for the SSH3 server. Default: localhost

  - SSH3_PORT: Port number for the SSH3 server. Default: 8222

  - SSH3_URL_PATH_PREFIX: URL path prefix for SSH3 sessions. Default: /api/ssh3/session/<timestamp>/user/<uid>/<username>/.hiddenpath

  - SSH3_URL_PATH: A password-like hidden URL path suffix for SSH3 sessions. Default: /<random-password>

  - SSH3_URL_HIDDENPATH_CHARSET: Character set for generating the hidden URL path. Default: [:alnum:].~_-

  - SSH3_URL_HIDDENPATH_SIZE: Size of the hidden URL path. Default: 20

  - SILENT: If set, suppresses verbose output of ssh3-server. Default: Not set

  - SSH3_LISTEN_FILE: Path to the file containing the SSH3 server details. Default: ~/.local/state/ssh3_listen_<host>_<port>

  - SSH3_CERT: Path to the SSH3 SSL certificate. Default: ~/.ssh/ssh3-ssl-certificate.pem

  - SSH3_CERT_KEY: Path to the SSH3 SSL private key. Default: ~/.ssh/ssh3-ssl-private.key

  - SSH3_GEN_SELFSIGNED: If set, generates a self-signed certificate. Default: Not set

  - SSH3_GEN_PUBLICERT: If set, generates public certificates based on SSH3_GEN_PUBLICERT_HOSTS. Default: Not set

  - SSH3_GEN_PUBLICERT_HOSTS: Space-separated list of hosts for which public certificates should be generated. Default: SSH3_HOST

  - SSH3_GENCERT_TIMEOUT: Timeout duration for generating certificates. Default: 5s

EOF
}

# Check for help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] ; then
  help
  exit 0
fi

# Function to be executed on script exit
cleanup() {
  >&2 echo
  >&2 echo
  rm -fv "${SSH3_LISTEN_FILE:-}"
  >&2 echo
  >&2 echo ssh3 server exit code ${_ret:-0}
  exit ${_ret:-0}
}

# Registering the cleanup function to run on script exit
trap cleanup EXIT

mkdir -vp ~/.ssh ~/.local/state

cd ~/.ssh

[ -z "${SILENT:-}" ] \
  && VERBOSE="-v" \
  || VERBOSE=""

SSH3_HOST="${SSH3_HOST:-localhost}"
SSH3_PORT="${SSH3_PORT:-8222}"

SSH3_URL_PATH_PREFIX="${SSH3_URL_PATH_PREFIX:-/api/ssh3/session/$(date +%s)}/user/$(id -u)/$(id -nu)/.hiddenpath"

SSH3_URL_HIDDENPATH_CHARSET="${SSH3_URL_HIDDENPATH_CHARSET:-[:alnum:].~_-}"

SSH3_URL_HIDDENPATH_SIZE="${SSH3_URL_HIDDENPATH_SIZE:-20}"

SSH3_URL_PATH="${SSH3_URL_PATH:-/$((tr -dc "${SSH3_URL_HIDDENPATH_CHARSET}" < /dev/urandom || true ) | head -c "${SSH3_URL_HIDDENPATH_SIZE}")}"

SSH3_URL_PATH_PREFIX=$(sed -sure 's~/+~/~g;s~/$~~' <<< "/${SSH3_URL_PATH_PREFIX}/")

SSH3_URL_PATH=$(sed -sure 's~/+~/~g;s~/$~~' <<< "/${SSH3_URL_PATH}/")

SSH3_URL_FULLPATH="${SSH3_URL_PATH_PREFIX}${SSH3_URL_PATH}"

SSH3_LISTEN_FILE="${SSH3_LISTEN_FILE:-${HOME}/.local/state/ssh3_listen_${SSH3_HOST}_${SSH3_PORT}}"

SSH3_CERT="${SSH3_CERT:-${HOME}/.ssh/ssh3-ssl-certificate.pem}"
SSH3_CERT_KEY="${SSH3_CERT_KEY:-${HOME}/.ssh/ssh3-ssl-private.key}"

unset _k _c

if [[ -n "${SSH3_GEN_SELFSIGNED:-}" ]] \
|| [[ -n "${SSH3_GEN_PUBLICERT:-}" ]] \
|| ! [[ -f "${SSH3_CERT}" ]] \
|| ! [[ -f "${SSH3_CERT_KEY}" ]] \
; then
  mv -f "${SSH3_CERT_KEY}" "${SSH3_CERT_KEY}_$(date +%s).bak" &> /dev/null || true
  mv -f "${SSH3_CERT}" "${SSH3_CERT}_$(date +%s).bak" &> /dev/null || true
  TIMEOUT_OPTS="-v --preserve-status -s TERM ${SSH3_GENCERT_TIMEOUT:-5s}"
  if [[ -n "${SSH3_GEN_SELFSIGNED:-}" ]] \
  || [[ -z "${SSH3_GEN_PUBLICERT:-}" ]] \
  ; then
    timeout ${TIMEOUT_OPTS} ssh3-server -generate-selfsigned-cert -key "${SSH3_CERT_KEY}" -cert "${SSH3_CERT}" &> /dev/null || true
  else
    for _i in ${SSH3_GEN_PUBLICERT_HOSTS:-${SSH3_HOST}} ; do
      _k=$(sed -sure 's/(\.key)?$/-'"${_i}"'\1/i' <<< "${SSH3_CERT_KEY}")
      _c=$(sed -sure 's/(\.cert)?$/-'"${_i}"'\1/i' <<< "${SSH3_CERT}")
      timeout ${TIMEOUT_OPTS} ssh3-server -generate-public-cert "${_i}" -key "${_k}" -cert "${_c}" &> /dev/null || true
    done
  fi
fi

[ -n "${_k:-}" ] && SSH3_CERT_KEY="${_k:-}"
[ -n "${_c:-}" ] && SSH3_CERT="${_c:-}"

# export ssh3-server details for non-interactive commands
mkdir -vp "$(dirname "${SSH3_LISTEN_FILE}")"
echo "${SSH3_HOST}" > "${SSH3_LISTEN_FILE}"
echo "${SSH3_PORT}" >> "${SSH3_LISTEN_FILE}"
echo "${SSH3_HOST}:${SSH3_PORT}" >> "${SSH3_LISTEN_FILE}"
echo "${SSH3_HOST}:${SSH3_PORT}${SSH3_URL_PATH_PREFIX}" >> "${SSH3_LISTEN_FILE}"
echo "${SSH3_URL_PATH_PREFIX}" >> "${SSH3_LISTEN_FILE}"
echo "${SSH3_CERT}" >> "${SSH3_LISTEN_FILE}"
echo "${SSH3_CERT_KEY}" >> "${SSH3_LISTEN_FILE}"

>&2 ssh3-server \
  ${VERBOSE:-} \
  -key "${SSH3_CERT_KEY:-}" \
  -cert "${SSH3_CERT:-}" \
  -url-path "${SSH3_URL_FULLPATH:-}" \
  -bind "${SSH3_HOST:-}:${SSH3_PORT:-}" \
|| _ret=$?

exit  ${_ret:-0}

