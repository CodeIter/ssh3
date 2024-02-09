#!/usr/bin/env -S bash -euo pipefail

set -euo pipefail
shopt -s autocd
shopt -s globstar
shopt -s extglob
shopt -s nullglob

help() {
  cat << EOF
Usage: quicssh-server.sh [-h|--help]

Environment Variables:

  - QUICSSH_HOST: Hostname for the QUICSSH server. Default: localhost

  - QUICSSH_PORT: Port number for the QUICSSH server. Default: 8222

  - QUICSSH_URL_PATH_PREFIX: URL path prefix for QUICSSH sessions. Default: /api/quicssh/session/<timestamp>/user/<uid>/<username>/.hiddenpath

  - QUICSSH_URL_PATH: A password-like hidden URL path suffix for QUICSSH sessions. Default: /<random-password>

  - QUICSSH_URL_HIDDENPATH_CHARSET: Character set for generating the hidden URL path. Default: [:alnum:].~_-

  - QUICSSH_URL_HIDDENPATH_SIZE: Size of the hidden URL path. Default: 20

  - SILENT: If set, suppresses verbose output of quicssh-server. Default: Not set

  - QUICSSH_LISTEN_FILE: Path to the file containing the QUICSSH server details. Default: ~/.local/state/quicssh_listen_<host>_<port>

  - QUICSSH_CERT: Path to the QUICSSH SSL certificate. Default: ~/.ssh/quicssh-ssl-certificate.pem

  - QUICSSH_CERT_KEY: Path to the QUICSSH SSL private key. Default: ~/.ssh/quicssh-ssl-private.key

  - QUICSSH_GEN_SELFSIGNED: If set, generates a self-signed certificate. Default: Not set

  - QUICSSH_GEN_PUBLICERT: If set, generates public certificates based on QUICSSH_GEN_PUBLICERT_HOSTS. Default: Not set

  - QUICSSH_GEN_PUBLICERT_HOSTS: Space-separated list of hosts for which public certificates should be generated. Default: QUICSSH_HOST

  - QUICSSH_GENCERT_TIMEOUT: Timeout duration for generating certificates. Default: 5s

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
  rm -fv "${QUICSSH_LISTEN_FILE:-}"
  >&2 echo
  >&2 echo quicssh server exit code ${_ret:-0}
  exit ${_ret:-0}
}

# Registering the cleanup function to run on script exit
trap cleanup EXIT

mkdir -vp ~/.ssh ~/.local/state

cd ~/.ssh

[ -z "${SILENT:-}" ] \
  && VERBOSE="-v" \
  || VERBOSE=""

QUICSSH_HOST="${QUICSSH_HOST:-localhost}"
QUICSSH_PORT="${QUICSSH_PORT:-8222}"

QUICSSH_URL_PATH_PREFIX="${QUICSSH_URL_PATH_PREFIX:-/api/quicssh/session/$(date +%s)}/user/$(id -u)/$(id -nu)/.hiddenpath"

QUICSSH_URL_HIDDENPATH_CHARSET="${QUICSSH_URL_HIDDENPATH_CHARSET:-[:alnum:].~_-}"

QUICSSH_URL_HIDDENPATH_SIZE="${QUICSSH_URL_HIDDENPATH_SIZE:-20}"

QUICSSH_URL_PATH="${QUICSSH_URL_PATH:-/$((tr -dc "${QUICSSH_URL_HIDDENPATH_CHARSET}" < /dev/urandom || true ) | head -c "${QUICSSH_URL_HIDDENPATH_SIZE}")}"

QUICSSH_URL_PATH_PREFIX=$(sed -sure 's~/+~/~g;s~/$~~' <<< "/${QUICSSH_URL_PATH_PREFIX}/")

QUICSSH_URL_PATH=$(sed -sure 's~/+~/~g;s~/$~~' <<< "/${QUICSSH_URL_PATH}/")

QUICSSH_URL_FULLPATH="${QUICSSH_URL_PATH_PREFIX}${QUICSSH_URL_PATH}"

QUICSSH_LISTEN_FILE="${QUICSSH_LISTEN_FILE:-${HOME}/.local/state/quicssh_listen_${QUICSSH_HOST}_${QUICSSH_PORT}}"

QUICSSH_CERT="${QUICSSH_CERT:-${HOME}/.ssh/quicssh-ssl-certificate.pem}"
QUICSSH_CERT_KEY="${QUICSSH_CERT_KEY:-${HOME}/.ssh/quicssh-ssl-private.key}"

unset _k _c

if [[ -n "${QUICSSH_GEN_SELFSIGNED:-}" ]] \
|| [[ -n "${QUICSSH_GEN_PUBLICERT:-}" ]] \
|| ! [[ -f "${QUICSSH_CERT}" ]] \
|| ! [[ -f "${QUICSSH_CERT_KEY}" ]] \
; then
  mv -f "${QUICSSH_CERT_KEY}" "${QUICSSH_CERT_KEY}_$(date +%s).bak" &> /dev/null || true
  mv -f "${QUICSSH_CERT}" "${QUICSSH_CERT}_$(date +%s).bak" &> /dev/null || true
  TIMEOUT_OPTS="-v --preserve-status -s TERM ${QUICSSH_GENCERT_TIMEOUT:-5s}"
  if [[ -n "${QUICSSH_GEN_SELFSIGNED:-}" ]] \
  || [[ -z "${QUICSSH_GEN_PUBLICERT:-}" ]] \
  ; then
    timeout ${TIMEOUT_OPTS} quicssh-server -generate-selfsigned-cert -key "${QUICSSH_CERT_KEY}" -cert "${QUICSSH_CERT}" &> /dev/null || true
  else
    for _i in ${QUICSSH_GEN_PUBLICERT_HOSTS:-${QUICSSH_HOST}} ; do
      _k=$(sed -sure 's/(\.key)?$/-'"${_i}"'\1/i' <<< "${QUICSSH_CERT_KEY}")
      _c=$(sed -sure 's/(\.cert)?$/-'"${_i}"'\1/i' <<< "${QUICSSH_CERT}")
      timeout ${TIMEOUT_OPTS} quicssh-server -generate-public-cert "${_i}" -key "${_k}" -cert "${_c}" &> /dev/null || true
    done
  fi
fi

[ -n "${_k:-}" ] && QUICSSH_CERT_KEY="${_k:-}"
[ -n "${_c:-}" ] && QUICSSH_CERT="${_c:-}"

# export quicssh-server details for non-interactive commands
mkdir -vp "$(dirname "${QUICSSH_LISTEN_FILE}")"
echo "${QUICSSH_HOST}" > "${QUICSSH_LISTEN_FILE}"
echo "${QUICSSH_PORT}" >> "${QUICSSH_LISTEN_FILE}"
echo "${QUICSSH_HOST}:${QUICSSH_PORT}" >> "${QUICSSH_LISTEN_FILE}"
echo "${QUICSSH_HOST}:${QUICSSH_PORT}${QUICSSH_URL_PATH_PREFIX}" >> "${QUICSSH_LISTEN_FILE}"
echo "${QUICSSH_URL_PATH_PREFIX}" >> "${QUICSSH_LISTEN_FILE}"
echo "${QUICSSH_CERT}" >> "${QUICSSH_LISTEN_FILE}"
echo "${QUICSSH_CERT_KEY}" >> "${QUICSSH_LISTEN_FILE}"

>&2 quicssh-server \
  ${VERBOSE:-} \
  -key "${QUICSSH_CERT_KEY:-}" \
  -cert "${QUICSSH_CERT:-}" \
  -url-path "${QUICSSH_URL_FULLPATH:-}" \
  -bind "${QUICSSH_HOST:-}:${QUICSSH_PORT:-}" \
|| _ret=$?

exit  ${_ret:-0}

