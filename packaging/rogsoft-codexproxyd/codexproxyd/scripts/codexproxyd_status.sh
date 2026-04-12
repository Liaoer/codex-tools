#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh >/dev/null 2>&1
eval $(dbus export codexproxyd)

CONTAINER_NAME="codexproxyd"
PORT="8787"
DEFAULT_MODEL="gpt-5.4"
DEFAULT_EFFORT="high"
DEFAULT_AUDIT_LOG_LEVEL="basic"
ACTION_PID_FILE="/tmp/codexproxyd_action.pid"
ACTION_LOG_PATH="/tmp/upload/codexproxyd_log.txt"
ACTION_STATE_FILE="/tmp/codexproxyd_action.state"
DISK_PATH="${codexproxyd_disk_path_selected}"
DATA_DIR_OVERRIDE="${codexproxyd_data_dir_value}"
DOCKROOT_BIN=""
DOCKROOT_DATA_DIR=""
DATA_DIR=""
LOG_PATH=""
ACCESS_LOG_PATH=""
DEBUG_LOG_PATH=""
ERROR_LOG_PATH=""
ACCOUNTS_FILE=""
API_KEY_FILE=""
USAGE_SUMMARY_FILE=""
USAGE_STATUS_URL="http://127.0.0.1:${PORT}/__codex_tools/accounts/usage"
DOCKROOT_VERSION=""

json_escape() {
	echo -n "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g; :a;N;$!ba;s/\n/\\n/g'
}

json_fragment_normalize() {
	printf "%s" "$1" | sed 's/\r//g; :a;N;$!ba;s/\n//g'
}

refresh_runtime_paths() {
	local default_data_dir resolved_data_dir
	DOCKROOT_BIN="${DISK_PATH}/DockRootBin/DockRoot"
	DOCKROOT_DATA_DIR="${DISK_PATH}/DockRootData/${CONTAINER_NAME}"
	default_data_dir="${DISK_PATH}/codex-proxyd-data"
	resolved_data_dir="$(resolve_runtime_data_dir "${default_data_dir}")"
	DATA_DIR="${resolved_data_dir:-${default_data_dir}}"
	LOG_PATH="${DOCKROOT_DATA_DIR}/ruri.log"
	ACCESS_LOG_PATH="${DATA_DIR}/logs/access.jsonl"
	DEBUG_LOG_PATH="${DATA_DIR}/logs/debug.jsonl"
	ERROR_LOG_PATH="${DATA_DIR}/logs/error.jsonl"
	ACCOUNTS_FILE="${DATA_DIR}/accounts.json"
	API_KEY_FILE="${DATA_DIR}/api-proxy.key"
	USAGE_SUMMARY_FILE="${DATA_DIR}/accounts-usage-summary.json"
}

extract_runtime_data_dir_from_file() {
	local source_file="$1"
	[ -f "${source_file}" ] || return 1
	awk '
		match($0, /\/tmp\/mnt\/[^"[:space:]]+\/codex-proxyd-data/) {
			printf "%s", substr($0, RSTART, RLENGTH)
			exit
		}
	' "${source_file}" 2>/dev/null
}

data_dir_score() {
	local candidate="$1"
	local score=0
	[ -n "${candidate}" ] || {
		printf "0"
		return 0
	}
	[ -d "${candidate}" ] || {
		printf "0"
		return 0
	}
	[ -s "${candidate}/accounts.json" ] && score=$((score + 100))
	[ -s "${candidate}/accounts-usage-summary.json" ] && score=$((score + 80))
	[ -s "${candidate}/proxy-settings.json" ] && score=$((score + 20))
	[ -s "${candidate}/api-proxy.key" ] && score=$((score + 10))
	[ -d "${candidate}/logs" ] && score=$((score + 5))
	[ -d "${candidate}" ] && score=$((score + 1))
	printf "%s" "${score}"
}

find_existing_data_dir() {
	local candidate best_path="" best_score=0 candidate_score=0
	for candidate in /tmp/mnt/*; do
		[ -d "${candidate}" ] || continue
		case "${candidate}" in
			/tmp/mnt/defaults)
				continue
				;;
		esac
		candidate="${candidate}/codex-proxyd-data"
		candidate_score="$(data_dir_score "${candidate}")"
		case "${candidate_score}" in
			""|*[!0-9]*)
				candidate_score=0
				;;
		esac
		if [ "${candidate_score}" -gt "${best_score}" ]; then
			best_path="${candidate}"
			best_score="${candidate_score}"
		fi
	done
	if [ "${best_score}" -gt "0" ]; then
		printf "%s" "${best_path}"
	fi
}

resolve_runtime_data_dir() {
	local default_data_dir="$1"
	local extracted_path="" fallback_path=""
	extracted_path="$(extract_runtime_data_dir_from_file "${DOCKROOT_DATA_DIR}/config.json")"
	if [ -z "${extracted_path}" ]; then
		extracted_path="$(extract_runtime_data_dir_from_file "${DOCKROOT_DATA_DIR}/ruri.conf")"
	fi
	if [ -n "${extracted_path}" ]; then
		printf "%s" "${extracted_path}"
		return 0
	fi
	fallback_path="$(find_existing_data_dir)"
	if [ -n "${fallback_path}" ]; then
		printf "%s" "${fallback_path}"
		return 0
	fi
	if [ -n "${DATA_DIR_OVERRIDE}" ]; then
		printf "%s" "${DATA_DIR_OVERRIDE}"
		return 0
	fi
	printf "%s" "${default_data_dir}"
}

find_preferred_disk_path() {
	local candidate found_path="" found_count=0
	if [ -n "${DISK_PATH}" ] && [ -d "${DISK_PATH}" ] && { [ -f "${DISK_PATH}/DockRootBin/DockRoot" ] || [ -d "${DISK_PATH}/DockRootData/${CONTAINER_NAME}" ] || [ -f "${DISK_PATH}/DockRootData/${CONTAINER_NAME}/ruri.conf" ]; }; then
		printf "%s" "${DISK_PATH}"
		return 0
	fi
	for candidate in /tmp/mnt/*; do
		[ -d "${candidate}" ] || continue
		case "${candidate}" in
			/tmp/mnt/defaults)
				continue
				;;
		esac
		if [ -f "${candidate}/DockRootBin/DockRoot" ] || [ -d "${candidate}/DockRootData/${CONTAINER_NAME}" ] || [ -f "${candidate}/DockRootData/${CONTAINER_NAME}/ruri.conf" ]; then
			found_path="${candidate}"
			found_count=$((found_count + 1))
		fi
	done
	if [ "${found_count}" = "1" ]; then
		printf "%s" "${found_path}"
	fi
}

select_runtime_disk_path() {
	local preferred_path
	preferred_path="$(find_preferred_disk_path)"
	if [ -n "${preferred_path}" ]; then
		DISK_PATH="${preferred_path}"
	fi
	refresh_runtime_paths
	if [ -n "${DATA_DIR}" ]; then
		dbus set codexproxyd_data_dir_value="${DATA_DIR}"
	fi
}

read_action_pid() {
	if [ ! -f "${ACTION_PID_FILE}" ]; then
		return 1
	fi
	tr -d '\r\n' < "${ACTION_PID_FILE}" 2>/dev/null
}

is_action_pid_running() {
	local action_pid
	action_pid="$1"
	case "${action_pid}" in
		""|*[!0-9]*)
			return 1
			;;
	esac
	kill -0 "${action_pid}" 2>/dev/null
}

extract_action_name_from_log() {
	if [ ! -s "${ACTION_LOG_PATH}" ]; then
		return 0
	fi
	sed -n '1s/^codexproxyd action:[[:space:]]*//p' "${ACTION_LOG_PATH}" 2>/dev/null | tr -d '\r\n'
}

last_action_log_line() {
	if [ ! -s "${ACTION_LOG_PATH}" ]; then
		return 0
	fi
	awk '
		$0 != "XU6J03M6" && length($0) > 0 { line = $0 }
		END {
			if (length(line) > 0) {
				gsub(/\r/, "", line)
				printf "%s", line
			}
		}
	' "${ACTION_LOG_PATH}" 2>/dev/null
}

read_action_state_field() {
	local field_name="$1"
	if [ ! -s "${ACTION_STATE_FILE}" ]; then
		return 0
	fi
	sed -n "s/^.*\"${field_name}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*$/\\1/p" "${ACTION_STATE_FILE}" 2>/dev/null | head -n1
}

read_proxyd_pid_list() {
	pidof codex-tools-proxyd 2>/dev/null | tr ' ' '\n' | awk 'NF { print $0 }'
}

count_proxyd_pids() {
	local pid_list="$1"
	if [ -n "${pid_list}" ]; then
		printf "%s\n" "${pid_list}" | awk 'NF { count++ } END { printf "%d", count + 0 }'
		return 0
	fi
	printf "0"
}

first_proxyd_pid() {
	local pid_list="$1"
	printf "%s\n" "${pid_list}" | awk 'NF { print $1; exit }'
}

is_container_running() {
	local ps_output
	if [ ! -f "${DOCKROOT_BIN}" ]; then
		return 1
	fi
	ps_output="$(${DOCKROOT_BIN} ps ${CONTAINER_NAME} 2>/dev/null)"
	if [ "$?" = "0" ] && [ -n "${ps_output}" ]; then
		return 0
	fi
	return 1
}

extract_api_key_from_accounts() {
	if [ ! -f "${ACCOUNTS_FILE}" ]; then
		return 0
	fi
	grep -o '"apiProxyApiKey"[[:space:]]*:[[:space:]]*"[^"]*"' "${ACCOUNTS_FILE}" 2>/dev/null | head -n1 | sed 's/.*"apiProxyApiKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

normalize_accounts_usage_json() {
	local payload trimmed
	payload="$1"
	trimmed=$(printf "%s" "${payload}" | tr -d '\r')
	case "${trimmed}" in
		\[*\])
			printf "%s" "${trimmed}"
			;;
		*)
			printf "[]"
			;;
	esac
}

is_empty_accounts_usage_json() {
	local compact
	compact="$(printf "%s" "$1" | tr -d '\r\n\t ')"
	[ -z "${compact}" ] || [ "${compact}" = "[]" ]
}

load_accounts_usage_from_accounts_file() {
	if [ ! -s "${ACCOUNTS_FILE}" ]; then
		printf "[]"
		return 0
	fi

	awk '
		function escape_json(value, escaped) {
			escaped = value
			gsub(/\\/, "\\\\", escaped)
			gsub(/"/, "\\\"", escaped)
			gsub(/\r/, "", escaped)
			gsub(/\n/, "\\n", escaped)
			return escaped
		}
		function reset_account() {
			account_open = 0
			current_email = ""
			current_plan = ""
			current_error = ""
			current_email_is_set = 0
			current_plan_is_set = 0
			current_error_is_set = 0
		}
		function emit_account(email_json, plan_json, error_json) {
			if (!account_open) {
				return
			}
			if (!first) {
				printf(",")
			}
			first = 0
			email_json = current_email_is_set ? "\"" escape_json(current_email) "\"" : "null"
			plan_json = current_plan_is_set ? "\"" escape_json(current_plan) "\"" : "null"
			error_json = current_error_is_set ? "\"" escape_json(current_error) "\"" : "null"
			printf("{\"email\":%s,\"planType\":%s,\"fiveHourUsedPercent\":null,\"fiveHourResetAt\":null,\"oneWeekUsedPercent\":null,\"oneWeekResetAt\":null,\"usageError\":%s}", email_json, plan_json, error_json)
			reset_account()
		}
		BEGIN {
			first = 1
			in_accounts = 0
			reset_account()
			printf("[")
		}
		/^[[:space:]]*"accounts"[[:space:]]*:[[:space:]]*\[/ {
			in_accounts = 1
			next
		}
		in_accounts && /^[[:space:]]*\][[:space:]]*,?[[:space:]]*$/ {
			emit_account()
			in_accounts = 0
			next
		}
		in_accounts && /^    \{[[:space:]]*$/ {
			emit_account()
			account_open = 1
			next
		}
		in_accounts && account_open && /^      "email"[[:space:]]*:[[:space:]]*null[[:space:]]*,?[[:space:]]*$/ {
			current_email = ""
			current_email_is_set = 0
			next
		}
		in_accounts && account_open && /^      "email"[[:space:]]*:/ {
			line = $0
			sub(/^      "email"[[:space:]]*:[[:space:]]*"/, "", line)
			sub(/"[[:space:]]*,?[[:space:]]*$/, "", line)
			current_email = line
			current_email_is_set = 1
			next
		}
		in_accounts && account_open && /^      "planType"[[:space:]]*:[[:space:]]*null[[:space:]]*,?[[:space:]]*$/ {
			current_plan = ""
			current_plan_is_set = 0
			next
		}
		in_accounts && account_open && /^      "planType"[[:space:]]*:/ {
			line = $0
			sub(/^      "planType"[[:space:]]*:[[:space:]]*"/, "", line)
			sub(/"[[:space:]]*,?[[:space:]]*$/, "", line)
			current_plan = line
			current_plan_is_set = 1
			next
		}
		in_accounts && account_open && /^      "usageError"[[:space:]]*:[[:space:]]*null[[:space:]]*,?[[:space:]]*$/ {
			current_error = ""
			current_error_is_set = 0
			next
		}
		in_accounts && account_open && /^      "usageError"[[:space:]]*:/ {
			line = $0
			sub(/^      "usageError"[[:space:]]*:[[:space:]]*"/, "", line)
			sub(/"[[:space:]]*,?[[:space:]]*$/, "", line)
			current_error = line
			current_error_is_set = 1
			next
		}
		in_accounts && account_open && /^    \}[[:space:]]*,?[[:space:]]*$/ {
			emit_account()
			next
		}
		END {
			emit_account()
			printf("]")
		}
	' "${ACCOUNTS_FILE}" 2>/dev/null
}

load_accounts_usage_json() {
	local usage_json
	usage_json=""

	if [ "${RUNNING}" = "1" ] && command -v curl >/dev/null 2>&1; then
		usage_json="$(curl -fsS --max-time 20 "${USAGE_STATUS_URL}" 2>/dev/null)" || usage_json=""
		if [ -n "${usage_json}" ]; then
			mkdir -p "${DATA_DIR}" >/dev/null 2>&1
			printf "%s" "${usage_json}" > "${USAGE_SUMMARY_FILE}" 2>/dev/null
			chmod 600 "${USAGE_SUMMARY_FILE}" >/dev/null 2>&1
		fi
	fi

	if [ -z "${usage_json}" ] && [ -s "${USAGE_SUMMARY_FILE}" ]; then
		usage_json="$(cat "${USAGE_SUMMARY_FILE}" 2>/dev/null)"
	fi

	if is_empty_accounts_usage_json "${usage_json}"; then
		usage_json="$(load_accounts_usage_from_accounts_file)"
	fi

	normalize_accounts_usage_json "${usage_json}"
}

DOCKROOT_INSTALLED=0
CONTAINER_EXISTS=0
BUNDLE_READY=0
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
ACTION_RUNNING=0
ACTION_PID=""
ACTION_NAME=""
ACTION_LOG_DONE=0
ACTION_LAST_LINE=""
ACTION_STATUS=""
ACTION_MESSAGE=""
IMAGE_STATUS="missing"
IMAGE_STATUS_TEXT="未拉取"
PROXYD_PID_LIST=""
PROXYD_PID_COUNT=0
PROCESS_CONFLICT=0
PROCESS_CONFLICT_TEXT=""

select_runtime_disk_path

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

if [ -f "${DOCKROOT_DATA_DIR}/config.json" ] || [ -d "${DOCKROOT_DATA_DIR}/rootfs" ] || [ -f "${DOCKROOT_DATA_DIR}/ruri.conf" ]; then
	BUNDLE_READY=1
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

ACTION_PID="$(read_action_pid)"
if is_action_pid_running "${ACTION_PID}"; then
	ACTION_RUNNING=1
fi

ACTION_NAME="$(extract_action_name_from_log)"
ACTION_LAST_LINE="$(last_action_log_line)"
if [ -s "${ACTION_LOG_PATH}" ] && grep -q "XU6J03M6" "${ACTION_LOG_PATH}" 2>/dev/null; then
	ACTION_LOG_DONE=1
fi
ACTION_STATUS="$(read_action_state_field "status")"
ACTION_MESSAGE="$(read_action_state_field "message")"
if [ -z "${ACTION_NAME}" ]; then
	ACTION_NAME="$(read_action_state_field "name")"
fi
if [ -z "${ACTION_PID}" ]; then
	ACTION_PID="$(read_action_state_field "pid")"
fi
case "${ACTION_STATUS}" in
	running)
		ACTION_RUNNING=1
		;;
	success|error)
		ACTION_LOG_DONE=1
		;;
esac

if [ "${ACTION_NAME}" = "pull_image" ] && [ "${ACTION_STATUS}" = "running" ]; then
	IMAGE_STATUS="pulling"
	IMAGE_STATUS_TEXT="拉取中"
elif [ "${BUNDLE_READY}" = "1" ]; then
	IMAGE_STATUS="ready"
	IMAGE_STATUS_TEXT="已拉取"
elif [ "${ACTION_NAME}" = "pull_image" ] && [ "${ACTION_STATUS}" = "error" ]; then
	IMAGE_STATUS="error"
	if [ -n "${ACTION_MESSAGE}" ]; then
		IMAGE_STATUS_TEXT="拉取失败: ${ACTION_MESSAGE}"
	else
		IMAGE_STATUS_TEXT="拉取失败"
	fi
fi

PROXYD_PID_LIST="$(read_proxyd_pid_list)"
PROXYD_PID_COUNT="$(count_proxyd_pids "${PROXYD_PID_LIST}")"
if is_container_running; then
	RUNNING=1
	DOCKROOT_INSTALLED=1
	if [ "${PROXYD_PID_COUNT}" = "1" ]; then
		PID="$(first_proxyd_pid "${PROXYD_PID_LIST}")"
	fi
fi

if [ "${PROXYD_PID_COUNT}" -gt "1" ]; then
	PROCESS_CONFLICT=1
	PROCESS_CONFLICT_TEXT="Detected multiple codex-tools-proxyd host processes."
elif [ "${PROXYD_PID_COUNT}" = "1" ] && [ "${RUNNING}" != "1" ]; then
	PROCESS_CONFLICT=1
	PROCESS_CONFLICT_TEXT="Detected a codex-tools-proxyd host process while DockRoot reports the container stopped."
	PID="$(first_proxyd_pid "${PROXYD_PID_LIST}")"
fi

ACCOUNTS_USAGE_JSON="$(load_accounts_usage_json)"
ACCOUNTS_USAGE_ESCAPED="$(json_fragment_normalize "${ACCOUNTS_USAGE_JSON}")"

RESP="{\\\"dockrootInstalled\\\":${DOCKROOT_INSTALLED},\\\"dockrootVersion\\\":\\\"$(json_escape "${DOCKROOT_VERSION}")\\\",\\\"dockrootBin\\\":\\\"$(json_escape "${DOCKROOT_BIN}")\\\",\\\"containerExists\\\":${CONTAINER_EXISTS},\\\"bundleReady\\\":${BUNDLE_READY},\\\"running\\\":${RUNNING},\\\"pid\\\":\\\"$(json_escape "${PID}")\\\",\\\"proxydPidCount\\\":${PROXYD_PID_COUNT},\\\"processConflict\\\":${PROCESS_CONFLICT},\\\"processConflictText\\\":\\\"$(json_escape "${PROCESS_CONFLICT_TEXT}")\\\",\\\"port\\\":${PORT},\\\"imageRef\\\":\\\"$(json_escape "${IMAGE_REF}")\\\",\\\"imageStatus\\\":\\\"$(json_escape "${IMAGE_STATUS}")\\\",\\\"imageStatusText\\\":\\\"$(json_escape "${IMAGE_STATUS_TEXT}")\\\",\\\"defaultModel\\\":\\\"$(json_escape "${DEFAULT_MODEL_VALUE}")\\\",\\\"defaultEffort\\\":\\\"$(json_escape "${DEFAULT_EFFORT_VALUE}")\\\",\\\"auditLogLevel\\\":\\\"$(json_escape "${AUDIT_LOG_LEVEL_VALUE}")\\\",\\\"dataDir\\\":\\\"$(json_escape "${DATA_DIR}")\\\",\\\"accountsPresent\\\":${ACCOUNTS_PRESENT},\\\"accountsUsage\\\":${ACCOUNTS_USAGE_ESCAPED},\\\"apiKeyPresent\\\":${API_KEY_PRESENT},\\\"apiKey\\\":\\\"$(json_escape "${API_KEY}")\\\",\\\"localBaseUrl\\\":\\\"$(json_escape "${LOCAL_BASE_URL}")\\\",\\\"lanBaseUrl\\\":\\\"$(json_escape "${LAN_BASE_URL}")\\\",\\\"logPath\\\":\\\"$(json_escape "${LOG_PATH}")\\\",\\\"auditLogPath\\\":\\\"$(json_escape "${AUDIT_LOG_PATH}")\\\",\\\"errorLogPath\\\":\\\"$(json_escape "${ERROR_LOG_PATH}")\\\",\\\"lastError\\\":\\\"$(json_escape "${LAST_ERROR}")\\\",\\\"lastImportAt\\\":\\\"$(json_escape "${LAST_IMPORT_AT}")\\\",\\\"actionRunning\\\":${ACTION_RUNNING},\\\"actionPid\\\":\\\"$(json_escape "${ACTION_PID}")\\\",\\\"actionName\\\":\\\"$(json_escape "${ACTION_NAME}")\\\",\\\"actionStatus\\\":\\\"$(json_escape "${ACTION_STATUS}")\\\",\\\"actionMessage\\\":\\\"$(json_escape "${ACTION_MESSAGE}")\\\",\\\"actionLogDone\\\":${ACTION_LOG_DONE},\\\"actionLastLine\\\":\\\"$(json_escape "${ACTION_LAST_LINE}")\\\"}"

http_response "${RESP}"
