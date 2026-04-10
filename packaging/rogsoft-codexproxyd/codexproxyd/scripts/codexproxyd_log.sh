#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh >/dev/null 2>&1
eval $(dbus export codexproxyd)

DISK_PATH="${codexproxyd_disk_path_selected}"
LOG_KIND="${codexproxyd_log_kind}"
AUDIT_LOG_LEVEL="${codexproxyd_audit_log_level}"
RUNTIME_LOG_PATH="${DISK_PATH}/DockRootData/codexproxyd/ruri.log"
ACCESS_LOG_PATH="${DISK_PATH}/codex-proxyd-data/logs/access.jsonl"
DEBUG_LOG_PATH="${DISK_PATH}/codex-proxyd-data/logs/debug.jsonl"
ERROR_LOG_PATH="${DISK_PATH}/codex-proxyd-data/logs/error.jsonl"
LOG_PATH="${RUNTIME_LOG_PATH}"
MISSING_MESSAGE=""

[ -n "${LOG_KIND}" ] || LOG_KIND="runtime"
[ -n "${AUDIT_LOG_LEVEL}" ] || AUDIT_LOG_LEVEL="basic"
AUDIT_LOG_LEVEL="$(printf "%s" "${AUDIT_LOG_LEVEL}" | tr 'A-Z' 'a-z')"

case "${LOG_KIND}" in
	audit)
		if [ "${AUDIT_LOG_LEVEL}" = "debug" ] && [ -f "${DEBUG_LOG_PATH}" ]; then
			LOG_PATH="${DEBUG_LOG_PATH}"
		else
			LOG_PATH="${ACCESS_LOG_PATH}"
		fi
		MISSING_MESSAGE="Audit log not found: ${LOG_PATH}"
		;;
	error)
		LOG_PATH="${ERROR_LOG_PATH}"
		MISSING_MESSAGE="Error log not found: ${LOG_PATH}"
		;;
	*)
		LOG_PATH="${RUNTIME_LOG_PATH}"
		MISSING_MESSAGE="Runtime log not found: ${LOG_PATH}"
		;;
esac

if [ -f "${LOG_PATH}" ]; then
	LOG_TEXT="$(tail -n 120 "${LOG_PATH}" 2>/dev/null)"
else
	LOG_TEXT="${MISSING_MESSAGE}"
fi

http_response "${LOG_TEXT}"
