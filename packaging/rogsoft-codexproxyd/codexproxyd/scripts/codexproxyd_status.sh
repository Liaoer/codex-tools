#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh >/dev/null 2>&1
eval $(dbus export codexproxyd)

CONTAINER_NAME="codexproxyd"
PORT="8787"
DEFAULT_MODEL="gpt-5.4"
DEFAULT_EFFORT="high"
DEFAULT_AUDIT_LOG_LEVEL="basic"
DISK_PATH="${codexproxyd_disk_path_selected}"
DOCKROOT_BIN="${DISK_PATH}/DockRootBin/DockRoot"
DOCKROOT_DATA_DIR="${DISK_PATH}/DockRootData/${CONTAINER_NAME}"
DATA_DIR="${DISK_PATH}/codex-proxyd-data"
LOG_PATH="${DOCKROOT_DATA_DIR}/ruri.log"
ACCESS_LOG_PATH="${DATA_DIR}/logs/access.jsonl"
DEBUG_LOG_PATH="${DATA_DIR}/logs/debug.jsonl"
ERROR_LOG_PATH="${DATA_DIR}/logs/error.jsonl"
ACCOUNTS_FILE="${DATA_DIR}/accounts.json"
API_KEY_FILE="${DATA_DIR}/api-proxy.key"
DOCKROOT_VERSION=""

json_escape() {
	echo -n "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g; :a;N;$!ba;s/\n/\\n/g'
}

extract_api_key_from_accounts() {
	if [ ! -f "${ACCOUNTS_FILE}" ]; then
		return 0
	fi
	grep -o '"apiProxyApiKey"[[:space:]]*:[[:space:]]*"[^"]*"' "${ACCOUNTS_FILE}" 2>/dev/null | head -n1 | sed 's/.*"apiProxyApiKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

DOCKROOT_INSTALLED=0
CONTAINER_EXISTS=0
RUNNING=0
PID=""
API_KEY=""
API_KEY_PRESENT=0
ACCOUNTS_PRESENT=0
LAST_ERROR="${codexproxyd_last_error}"
LAST_IMPORT_AT="${codexproxyd_last_import_at}"
IMAGE_REF="${codexproxyd_image_ref}"
DEFAULT_MODEL_VALUE="${codexproxyd_default_model}"
DEFAULT_EFFORT_VALUE="${codexproxyd_default_effort}"
AUDIT_LOG_LEVEL_VALUE="${codexproxyd_audit_log_level}"
LAN_IP="$(nvram get lan_ipaddr 2>/dev/null)"
LOCAL_BASE_URL="http://127.0.0.1:${PORT}/v1"
LAN_BASE_URL=""
AUDIT_LOG_PATH="${ACCESS_LOG_PATH}"

[ -n "${DEFAULT_MODEL_VALUE}" ] || DEFAULT_MODEL_VALUE="${DEFAULT_MODEL}"
[ -n "${DEFAULT_EFFORT_VALUE}" ] || DEFAULT_EFFORT_VALUE="${DEFAULT_EFFORT}"
[ -n "${AUDIT_LOG_LEVEL_VALUE}" ] || AUDIT_LOG_LEVEL_VALUE="${DEFAULT_AUDIT_LOG_LEVEL}"
DEFAULT_EFFORT_VALUE="$(printf "%s" "${DEFAULT_EFFORT_VALUE}" | tr 'A-Z' 'a-z')"
AUDIT_LOG_LEVEL_VALUE="$(printf "%s" "${AUDIT_LOG_LEVEL_VALUE}" | tr 'A-Z' 'a-z')"

case "${AUDIT_LOG_LEVEL_VALUE}" in
	off|basic|debug)
		;;
	*)
		AUDIT_LOG_LEVEL_VALUE="${DEFAULT_AUDIT_LOG_LEVEL}"
		;;
esac

[ -s "${ACCOUNTS_FILE}" ] && ACCOUNTS_PRESENT=1
[ -n "${LAN_IP}" ] && LAN_BASE_URL="http://${LAN_IP}:${PORT}/v1"

if [ -f "${DOCKROOT_BIN}" ]; then
	chmod 755 "${DOCKROOT_BIN}" >/dev/null 2>&1
	DOCKROOT_INSTALLED=1
	DOCKROOT_VERSION="$(${DOCKROOT_BIN} -v 2>&1)"
fi

if [ -d "${DOCKROOT_DATA_DIR}" ] || [ -f "${DOCKROOT_DATA_DIR}/ruri.conf" ]; then
	CONTAINER_EXISTS=1
fi

if [ -s "${API_KEY_FILE}" ]; then
	API_KEY="$(cat "${API_KEY_FILE}" 2>/dev/null | tr -d '\r\n')"
else
	API_KEY="$(extract_api_key_from_accounts | tr -d '\r\n')"
fi

[ -n "${API_KEY}" ] && API_KEY_PRESENT=1

if [ "${AUDIT_LOG_LEVEL_VALUE}" = "debug" ] && [ -f "${DEBUG_LOG_PATH}" ]; then
	AUDIT_LOG_PATH="${DEBUG_LOG_PATH}"
fi

if pidof codex-tools-proxyd >/dev/null 2>&1; then
	PID="$(pidof codex-tools-proxyd 2>/dev/null | awk '{print $1}')"
	RUNNING=1
	DOCKROOT_INSTALLED=1
elif [ -f "${DOCKROOT_BIN}" ]; then
	PS_OUTPUT="$(${DOCKROOT_BIN} ps ${CONTAINER_NAME} 2>/dev/null)"
	if [ "$?" = "0" ] && [ -n "${PS_OUTPUT}" ]; then
		RUNNING=1
		DOCKROOT_INSTALLED=1
	fi
fi

RESP="{\\\"dockrootInstalled\\\":${DOCKROOT_INSTALLED},\\\"dockrootVersion\\\":\\\"$(json_escape "${DOCKROOT_VERSION}")\\\",\\\"dockrootBin\\\":\\\"$(json_escape "${DOCKROOT_BIN}")\\\",\\\"containerExists\\\":${CONTAINER_EXISTS},\\\"running\\\":${RUNNING},\\\"pid\\\":\\\"$(json_escape "${PID}")\\\",\\\"port\\\":${PORT},\\\"imageRef\\\":\\\"$(json_escape "${IMAGE_REF}")\\\",\\\"defaultModel\\\":\\\"$(json_escape "${DEFAULT_MODEL_VALUE}")\\\",\\\"defaultEffort\\\":\\\"$(json_escape "${DEFAULT_EFFORT_VALUE}")\\\",\\\"auditLogLevel\\\":\\\"$(json_escape "${AUDIT_LOG_LEVEL_VALUE}")\\\",\\\"dataDir\\\":\\\"$(json_escape "${DATA_DIR}")\\\",\\\"accountsPresent\\\":${ACCOUNTS_PRESENT},\\\"apiKeyPresent\\\":${API_KEY_PRESENT},\\\"apiKey\\\":\\\"$(json_escape "${API_KEY}")\\\",\\\"localBaseUrl\\\":\\\"$(json_escape "${LOCAL_BASE_URL}")\\\",\\\"lanBaseUrl\\\":\\\"$(json_escape "${LAN_BASE_URL}")\\\",\\\"logPath\\\":\\\"$(json_escape "${LOG_PATH}")\\\",\\\"auditLogPath\\\":\\\"$(json_escape "${AUDIT_LOG_PATH}")\\\",\\\"errorLogPath\\\":\\\"$(json_escape "${ERROR_LOG_PATH}")\\\",\\\"lastError\\\":\\\"$(json_escape "${LAST_ERROR}")\\\",\\\"lastImportAt\\\":\\\"$(json_escape "${LAST_IMPORT_AT}")\\\"}"

http_response "${RESP}"
