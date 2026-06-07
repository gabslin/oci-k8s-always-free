#!/usr/bin/env bash

retry_command() {
  local attempts="${RETRY_ATTEMPTS:-12}"
  local sleep_seconds="${RETRY_SLEEP_SECONDS:-10}"
  local attempt=1

  while true; do
    if "$@"; then
      return 0
    fi

    if [[ "${attempt}" -ge "${attempts}" ]]; then
      echo "Comando falhou apos ${attempts} tentativas: $*" >&2
      return 1
    fi

    echo "Comando falhou, tentando novamente em ${sleep_seconds}s: $*" >&2
    sleep "${sleep_seconds}"
    attempt=$((attempt + 1))
  done
}

dnf_retry() {
  retry_command dnf "$@"
}

rpm_import_retry() {
  retry_command rpm --import "$@"
}
