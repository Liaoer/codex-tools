#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh >/dev/null 2>&1
eval $(dbus export codexproxyd)

CONTAINER_NAME="codexproxyd"
PORT="8787"
DEFAULT_MODEL="gpt-5-4"
DEFAULT_EFFORT="high"
DEFAULT_AUDIT_LOG_LEVEL="basic"
ACTION_PID_FILE="/tmp/codexproxyd_action.pid"
ACTION_LOG_PATH="/tmp/upload/codexproxyd_log.txt"
ACTION_STATE_FILE="/tmp/codexproxyd_action.state"
DISK_PATH="${codexproxyd_disk_path_selected}"
DATA_DIR_OVERRIDE="${codexproxyd_data_dir_value}"
LAST_PULLED_IMAGE_REF="${codexproxyd_last_pulled_image_ref}"
LAST_PULL_AT="${codexproxyd_last_pull_at}"
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
PROXY_SETTINGS_FILE=""
DOCKROOT_VERSION=""
DATA_DIR_RESOLVED_FROM="default"
USAGE_EXPORT_URL="http://127.0.0.1:${PORT}/__codex_tools/accounts/usage"
TMP_LIVE_USAGE_SUMMARY="/tmp/${CONTAINER_NAME}_live_usage_summary.json"
HTTP_CLIENT=""

json_escape() {
	printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g; :a;N;$!ba;s/\n/\\n/g'
}

json_escape_for_api_result() {
	json_escape "$(json_escape "$1")"
}

read_proxy_settings_field() {
	local field_name="$1"
	[ -s "${PROXY_SETTINGS_FILE}" ] || return 0
	sed -n "s/^.*\"${field_name}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*$/\\1/p" "${PROXY_SETTINGS_FILE}" 2>/dev/null | head -n1
}

coalesce_saved_proxy_setting() {
	local current_value="$1"
	local field_name="$2"
	local saved_value=""
	current_value="$(printf "%s" "${current_value}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
	if [ -n "${current_value}" ]; then
		printf "%s" "${current_value}"
		return 0
	fi
	saved_value="$(read_proxy_settings_field "${field_name}")"
	printf "%s" "${saved_value}"
}

refresh_runtime_paths() {
	local default_data_dir resolved_runtime_data resolved_source resolved_data_dir
	DOCKROOT_BIN="${DISK_PATH}/DockRootBin/DockRoot"
	DOCKROOT_DATA_DIR="${DISK_PATH}/DockRootData/${CONTAINER_NAME}"
	default_data_dir="${DISK_PATH}/codex-proxyd-data"
	resolved_runtime_data="$(resolve_runtime_data_dir "${default_data_dir}")"
	resolved_source="${resolved_runtime_data%%|*}"
	resolved_data_dir="${resolved_runtime_data#*|}"
	if [ "${resolved_data_dir}" = "${resolved_runtime_data}" ]; then
		resolved_source="default"
	fi
	DATA_DIR_RESOLVED_FROM="${resolved_source}"
	DATA_DIR="${resolved_data_dir:-${default_data_dir}}"
	LOG_PATH="${DOCKROOT_DATA_DIR}/ruri.log"
	ACCESS_LOG_PATH="${DATA_DIR}/logs/access.jsonl"
	DEBUG_LOG_PATH="${DATA_DIR}/logs/debug.jsonl"
	ERROR_LOG_PATH="${DATA_DIR}/logs/error.jsonl"
	ACCOUNTS_FILE="${DATA_DIR}/accounts.json"
	API_KEY_FILE="${DATA_DIR}/api-proxy.key"
	USAGE_SUMMARY_FILE="${DATA_DIR}/accounts-usage-summary.json"
	PROXY_SETTINGS_FILE="${DATA_DIR}/proxy-settings.json"
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

has_data_dir_evidence() {
	local candidate="$1"
	case "$(data_dir_score "${candidate}")" in
		""|*[!0-9]*|0)
			return 1
			;;
		*)
			return 0
			;;
	esac
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
		printf "runtime_config|%s" "${extracted_path}"
		return 0
	fi
	if [ -n "${DATA_DIR_OVERRIDE}" ] && has_data_dir_evidence "${DATA_DIR_OVERRIDE}"; then
		printf "saved_value|%s" "${DATA_DIR_OVERRIDE}"
		return 0
	fi
	fallback_path="$(find_existing_data_dir)"
	if [ -n "${fallback_path}" ]; then
		printf "scan|%s" "${fallback_path}"
		return 0
	fi
	printf "default|%s" "${default_data_dir}"
}

persist_resolved_data_dir() {
	case "${DATA_DIR_RESOLVED_FROM}" in
		runtime_config|scan)
			dbus set codexproxyd_data_dir_value="${DATA_DIR}"
			;;
		saved_value|default)
			if has_data_dir_evidence "${DATA_DIR}"; then
				dbus set codexproxyd_data_dir_value="${DATA_DIR}"
			fi
			;;
	esac
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
	persist_resolved_data_dir
}

read_action_state_field() {
	local field_name="$1"
	if [ ! -s "${ACTION_STATE_FILE}" ]; then
		return 0
	fi
	sed -n "s/^.*\"${field_name}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*$/\\1/p" "${ACTION_STATE_FILE}" 2>/dev/null | head -n1
}

is_action_pid_running() {
	local action_pid="$1"
	case "${action_pid}" in
		""|*[!0-9]*)
			return 1
			;;
	esac
	kill -0 "${action_pid}" 2>/dev/null
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

extract_accounts_usage_timestamp() {
	local source_file="$1"
	[ -s "${source_file}" ] || {
		printf "0"
		return 0
	}
	awk '
		BEGIN { max = 0 }
		{
			while (match($0, /"(updatedAt|fetchedAt)"[[:space:]]*:[[:space:]]*[0-9]+/)) {
				value = substr($0, RSTART, RLENGTH)
				gsub(/[^0-9]/, "", value)
				if ((value + 0) > max) {
					max = value + 0
				}
				$0 = substr($0, RSTART + RLENGTH)
			}
		}
		END { printf "%d", max + 0 }
	' "${source_file}" 2>/dev/null
}

is_empty_accounts_usage_json() {
	local compact
	compact="$(printf "%s" "$1" | tr -d '\r\n\t ')"
	[ -z "${compact}" ] || [ "${compact}" = "[]" ]
}

count_accounts_usage_rows() {
	printf "%s" "$1" | awk '
		{
			while (match($0, /"email"[[:space:]]*:/)) {
				count++
				$0 = substr($0, RSTART + RLENGTH)
			}
		}
		END { printf "%d", count + 0 }
	'
}

ensure_http_client() {
	if command -v curl >/dev/null 2>&1; then
		HTTP_CLIENT="curl"
		return 0
	fi
	if command -v wget >/dev/null 2>&1; then
		HTTP_CLIENT="wget"
		return 0
	fi
	if command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1; then
		HTTP_CLIENT="busybox_wget"
		return 0
	fi
	if command -v nc >/dev/null 2>&1; then
		HTTP_CLIENT="nc"
		return 0
	fi
	if command -v busybox >/dev/null 2>&1 && busybox nc --help >/dev/null 2>&1; then
		HTTP_CLIENT="busybox_nc"
		return 0
	fi
	return 1
}

extract_http_body_to_file() {
	local response_file="$1"
	local output_path="$2"
	awk 'BEGIN{body=0} body{print} /^\r?$/{body=1}' "${response_file}" | sed '1{/^\r\?$/d;}' > "${output_path}"
}

run_http_get_to_file() {
	local url="$1"
	local output_path="$2"
	local request_path response_path status_code
	if [ "${HTTP_CLIENT}" = "curl" ]; then
		curl -sS -o "${output_path}" -w "%{http_code}" --max-time 30 "${url}" 2>/dev/null
		return $?
	fi
	if [ "${HTTP_CLIENT}" = "wget" ]; then
		wget -q -O "${output_path}" --timeout=30 "${url}" >/dev/null 2>&1
		if [ "$?" = "0" ]; then
			printf "200"
			return 0
		fi
		return 1
	fi
	if [ "${HTTP_CLIENT}" = "busybox_wget" ]; then
		busybox wget -q -O "${output_path}" --timeout=30 "${url}" >/dev/null 2>&1
		if [ "$?" = "0" ]; then
			printf "200"
			return 0
		fi
		return 1
	fi
	request_path="$(printf "%s" "${url}" | sed -n 's#^http://127\.0\.0\.1:[0-9]\+\(/.*\)$#\1#p')"
	[ -n "${request_path}" ] || request_path="/"
	response_path="${output_path}.http"
	rm -f "${response_path}"
	if [ "${HTTP_CLIENT}" = "nc" ]; then
		printf "GET %s HTTP/1.1\r\nHost: 127.0.0.1:%s\r\nConnection: close\r\n\r\n" "${request_path}" "${PORT}" | nc -w 30 127.0.0.1 "${PORT}" > "${response_path}" 2>/dev/null || return 1
	elif [ "${HTTP_CLIENT}" = "busybox_nc" ]; then
		printf "GET %s HTTP/1.1\r\nHost: 127.0.0.1:%s\r\nConnection: close\r\n\r\n" "${request_path}" "${PORT}" | busybox nc -w 30 127.0.0.1 "${PORT}" > "${response_path}" 2>/dev/null || return 1
	else
		return 1
	fi
	status_code="$(sed -n '1s#^HTTP/[0-9.]* \([0-9][0-9][0-9]\).*$#\1#p' "${response_path}" | head -n1)"
	extract_http_body_to_file "${response_path}" "${output_path}"
	rm -f "${response_path}"
	printf "%s" "${status_code:-000}"
	return 0
	return 1
}

load_live_accounts_usage_json() {
	local http_code usage_json
	ensure_http_client || return 1
	[ "${RUNNING}" = "1" ] || return 1
	rm -f "${TMP_LIVE_USAGE_SUMMARY}"
	http_code="$(run_http_get_to_file "${USAGE_EXPORT_URL}" "${TMP_LIVE_USAGE_SUMMARY}")" || {
		rm -f "${TMP_LIVE_USAGE_SUMMARY}"
		return 1
	}
	if [ "${http_code}" != "200" ]; then
		rm -f "${TMP_LIVE_USAGE_SUMMARY}"
		return 1
	fi
	usage_json="$(cat "${TMP_LIVE_USAGE_SUMMARY}" 2>/dev/null)"
	normalize_accounts_usage_json "${usage_json}"
}

file_mtime_epoch() {
	local path="$1"
	[ -f "${path}" ] || {
		printf "0"
		return 0
	}
	if stat -c %Y "${path}" >/dev/null 2>&1; then
		stat -c %Y "${path}" 2>/dev/null
		return 0
	fi
	if stat -f %m "${path}" >/dev/null 2>&1; then
		stat -f %m "${path}" 2>/dev/null
		return 0
	fi
	if date -r "${path}" +%s >/dev/null 2>&1; then
		date -r "${path}" +%s 2>/dev/null
		return 0
	fi
	printf "0"
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
	local usage_json live_usage_json live_timestamp
	usage_json=""
	live_usage_json="$(load_live_accounts_usage_json)"
	if ! is_empty_accounts_usage_json "${live_usage_json}"; then
		ACCOUNTS_USAGE_SOURCE="live_endpoint"
		printf "%s" "${live_usage_json}" > "${TMP_LIVE_USAGE_SUMMARY}"
		live_timestamp="$(extract_accounts_usage_timestamp "${TMP_LIVE_USAGE_SUMMARY}")"
		rm -f "${TMP_LIVE_USAGE_SUMMARY}"
		case "${live_timestamp}" in
			""|*[!0-9]*)
				live_timestamp=0
				;;
		esac
		USAGE_SUMMARY_UPDATED_AT="${live_timestamp}"
		printf "%s" "${live_usage_json}"
		return 0
	fi
	if [ -s "${USAGE_SUMMARY_FILE}" ]; then
		usage_json="$(cat "${USAGE_SUMMARY_FILE}" 2>/dev/null)"
	fi

	if ! is_empty_accounts_usage_json "${usage_json}"; then
		ACCOUNTS_USAGE_SOURCE="usage_summary"
		USAGE_SUMMARY_UPDATED_AT="$(file_mtime_epoch "${USAGE_SUMMARY_FILE}")"
		normalize_accounts_usage_json "${usage_json}"
		return 0
	fi

	if [ -s "${ACCOUNTS_FILE}" ]; then
		ACCOUNTS_USAGE_SOURCE="accounts_file"
		usage_json="$(load_accounts_usage_from_accounts_file)"
		normalize_accounts_usage_json "${usage_json}"
		return 0
	fi

	ACCOUNTS_USAGE_SOURCE="none"
	USAGE_SUMMARY_UPDATED_AT="0"
	printf "[]"
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
IMAGE_REF=""
DEFAULT_MODEL_VALUE=""
DEFAULT_EFFORT_VALUE=""
AUDIT_LOG_LEVEL_VALUE=""
LAN_IP="$(nvram get lan_ipaddr 2>/dev/null)"
LOCAL_BASE_URL="http://127.0.0.1:${PORT}/v1"
LAN_BASE_URL=""
AUDIT_LOG_PATH="${ACCESS_LOG_PATH}"
ACTION_RUNNING=0
ACTION_PID=""
ACTION_REQUEST_ID=""
ACTION_NAME=""
ACTION_STATUS=""
ACTION_PHASE=""
ACTION_MESSAGE=""
ACTION_UPDATED_AT=""
ACTION_LAST_LINE=""
IMAGE_STATUS="missing"
IMAGE_STATUS_TEXT="未拉取"
PROXYD_PID_LIST=""
PROXYD_PID_COUNT=0
PROCESS_CONFLICT=0
PROCESS_CONFLICT_TEXT=""
ACCOUNTS_USAGE_SOURCE="none"
ACCOUNTS_COUNT=0
USAGE_SUMMARY_UPDATED_AT=0
RECOVERY_STATE="unknown"
RECOVERY_HINT=""

select_runtime_disk_path

IMAGE_REF="$(coalesce_saved_proxy_setting "${codexproxyd_image_ref}" "imageRef")"
DEFAULT_MODEL_VALUE="$(coalesce_saved_proxy_setting "${codexproxyd_default_model}" "defaultModel")"
DEFAULT_EFFORT_VALUE="$(coalesce_saved_proxy_setting "${codexproxyd_default_effort}" "defaultEffort")"
AUDIT_LOG_LEVEL_VALUE="$(coalesce_saved_proxy_setting "${codexproxyd_audit_log_level}" "auditLogLevel")"

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

AUDIT_LOG_PATH="${ACCESS_LOG_PATH}"

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

ACTION_REQUEST_ID="$(read_action_state_field "requestId")"
ACTION_NAME="$(read_action_state_field "name")"
ACTION_STATUS="$(read_action_state_field "status")"
ACTION_PID="$(read_action_state_field "pid")"
ACTION_MESSAGE="$(read_action_state_field "message")"
ACTION_PHASE="$(read_action_state_field "phase")"
ACTION_UPDATED_AT="$(read_action_state_field "updatedAt")"
ACTION_LAST_LINE="$(last_action_log_line)"

if [ -z "${ACTION_MESSAGE}" ]; then
	ACTION_MESSAGE="${ACTION_LAST_LINE}"
fi

case "${ACTION_STATUS}" in
	running)
		if is_action_pid_running "${ACTION_PID}"; then
			ACTION_RUNNING=1
			if [ -z "${ACTION_PHASE}" ] || [ "${ACTION_PHASE}" = "accepted" ]; then
				:
			else
				ACTION_PHASE="running"
			fi
		else
			ACTION_RUNNING=0
			ACTION_STATUS="error"
			ACTION_PHASE="failed"
			if [ -z "${ACTION_MESSAGE}" ]; then
				ACTION_MESSAGE="Action process exited before reporting a final state."
			fi
		fi
		;;
	success)
		[ -n "${ACTION_PHASE}" ] || ACTION_PHASE="completed"
		;;
	error)
		[ -n "${ACTION_PHASE}" ] || ACTION_PHASE="failed"
		;;
esac

if [ "${ACTION_NAME}" = "pull_image" ] && [ "${ACTION_STATUS}" = "running" ]; then
	IMAGE_STATUS="pulling"
	IMAGE_STATUS_TEXT="拉取中"
elif [ "${RUNNING}" = "1" ] || [ "${BUNDLE_READY}" = "1" ]; then
	IMAGE_STATUS="ready"
	IMAGE_STATUS_TEXT="已拉取"
elif [ -n "${IMAGE_REF}" ] && [ -n "${LAST_PULLED_IMAGE_REF}" ] && [ "${IMAGE_REF}" != "${LAST_PULLED_IMAGE_REF}" ]; then
	IMAGE_STATUS="stale"
	IMAGE_STATUS_TEXT="镜像地址已变更，需重新拉取"
elif [ "${ACTION_NAME}" = "pull_image" ] && [ "${ACTION_STATUS}" = "error" ]; then
	IMAGE_STATUS="error"
	if [ -n "${ACTION_MESSAGE}" ]; then
		IMAGE_STATUS_TEXT="拉取失败: ${ACTION_MESSAGE}"
	else
		IMAGE_STATUS_TEXT="拉取失败"
	fi
else
	IMAGE_STATUS="missing"
	IMAGE_STATUS_TEXT="未拉取"
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

if [ "${RUNNING}" = "1" ]; then
	RECOVERY_STATE="running"
	RECOVERY_HINT="服务正在运行，数据目录已挂载。"
elif [ "${ACTION_NAME}" = "pull_image" ] && [ "${ACTION_STATUS}" = "running" ]; then
	RECOVERY_STATE="recovering"
	RECOVERY_HINT="正在拉取镜像，完成后可直接启动。"
elif [ "${ACCOUNTS_PRESENT}" = "1" ] && [ "${BUNDLE_READY}" != "1" ]; then
	RECOVERY_STATE="needs_image_pull"
	RECOVERY_HINT="账号数据已保留，只需重新拉取镜像并启动。"
elif [ "${ACCOUNTS_PRESENT}" = "1" ] && [ "${BUNDLE_READY}" = "1" ]; then
	RECOVERY_STATE="ready_to_start"
	RECOVERY_HINT="账号数据和镜像已保留，可直接启动容器。"
elif [ "${ACCOUNTS_PRESENT}" != "1" ] && [ "${BUNDLE_READY}" = "1" ]; then
	RECOVERY_STATE="needs_accounts_import"
	RECOVERY_HINT="镜像已拉取，但还未检测到 accounts.json，请先导入账号。"
else
	RECOVERY_STATE="needs_full_setup"
	RECOVERY_HINT="未检测到镜像 bundle 和账号数据，需要先拉取镜像并导入账号。"
fi

ACCOUNTS_USAGE_JSON="$(load_accounts_usage_json)"
ACCOUNTS_USAGE_ESCAPED="$(json_escape_for_api_result "${ACCOUNTS_USAGE_JSON}")"
ACCOUNTS_COUNT="$(count_accounts_usage_rows "${ACCOUNTS_USAGE_JSON}")"

RESP="{\\\"dockrootInstalled\\\":${DOCKROOT_INSTALLED},\\\"dockrootVersion\\\":\\\"$(json_escape "${DOCKROOT_VERSION}")\\\",\\\"dockrootBin\\\":\\\"$(json_escape "${DOCKROOT_BIN}")\\\",\\\"containerExists\\\":${CONTAINER_EXISTS},\\\"bundleReady\\\":${BUNDLE_READY},\\\"running\\\":${RUNNING},\\\"pid\\\":\\\"$(json_escape "${PID}")\\\",\\\"proxydPidCount\\\":${PROXYD_PID_COUNT},\\\"processConflict\\\":${PROCESS_CONFLICT},\\\"processConflictText\\\":\\\"$(json_escape_for_api_result "${PROCESS_CONFLICT_TEXT}")\\\",\\\"port\\\":${PORT},\\\"imageRef\\\":\\\"$(json_escape "${IMAGE_REF}")\\\",\\\"imageStatus\\\":\\\"$(json_escape "${IMAGE_STATUS}")\\\",\\\"imageStatusText\\\":\\\"$(json_escape_for_api_result "${IMAGE_STATUS_TEXT}")\\\",\\\"recoveryState\\\":\\\"$(json_escape "${RECOVERY_STATE}")\\\",\\\"recoveryHint\\\":\\\"$(json_escape_for_api_result "${RECOVERY_HINT}")\\\",\\\"lastPulledImageRef\\\":\\\"$(json_escape "${LAST_PULLED_IMAGE_REF}")\\\",\\\"lastPullAt\\\":\\\"$(json_escape "${LAST_PULL_AT}")\\\",\\\"defaultModel\\\":\\\"$(json_escape "${DEFAULT_MODEL_VALUE}")\\\",\\\"defaultEffort\\\":\\\"$(json_escape "${DEFAULT_EFFORT_VALUE}")\\\",\\\"auditLogLevel\\\":\\\"$(json_escape "${AUDIT_LOG_LEVEL_VALUE}")\\\",\\\"dataDir\\\":\\\"$(json_escape "${DATA_DIR}")\\\",\\\"dataDirResolvedFrom\\\":\\\"$(json_escape "${DATA_DIR_RESOLVED_FROM}")\\\",\\\"accountsPresent\\\":${ACCOUNTS_PRESENT},\\\"accountsUsage\\\":\\\"${ACCOUNTS_USAGE_ESCAPED}\\\",\\\"accountsCount\\\":${ACCOUNTS_COUNT},\\\"accountsSource\\\":\\\"$(json_escape "${ACCOUNTS_USAGE_SOURCE}")\\\",\\\"usageSummaryUpdatedAt\\\":${USAGE_SUMMARY_UPDATED_AT},\\\"apiKeyPresent\\\":${API_KEY_PRESENT},\\\"apiKey\\\":\\\"$(json_escape "${API_KEY}")\\\",\\\"localBaseUrl\\\":\\\"$(json_escape "${LOCAL_BASE_URL}")\\\",\\\"lanBaseUrl\\\":\\\"$(json_escape "${LAN_BASE_URL}")\\\",\\\"logPath\\\":\\\"$(json_escape "${LOG_PATH}")\\\",\\\"auditLogPath\\\":\\\"$(json_escape "${AUDIT_LOG_PATH}")\\\",\\\"errorLogPath\\\":\\\"$(json_escape "${ERROR_LOG_PATH}")\\\",\\\"lastError\\\":\\\"$(json_escape_for_api_result "${LAST_ERROR}")\\\",\\\"lastImportAt\\\":\\\"$(json_escape "${LAST_IMPORT_AT}")\\\",\\\"actionRunning\\\":${ACTION_RUNNING},\\\"actionPid\\\":\\\"$(json_escape "${ACTION_PID}")\\\",\\\"actionRequestId\\\":\\\"$(json_escape "${ACTION_REQUEST_ID}")\\\",\\\"actionName\\\":\\\"$(json_escape "${ACTION_NAME}")\\\",\\\"actionStatus\\\":\\\"$(json_escape "${ACTION_STATUS}")\\\",\\\"actionPhase\\\":\\\"$(json_escape "${ACTION_PHASE}")\\\",\\\"actionMessage\\\":\\\"$(json_escape_for_api_result "${ACTION_MESSAGE}")\\\",\\\"actionUpdatedAt\\\":\\\"$(json_escape "${ACTION_UPDATED_AT}")\\\",\\\"actionLastLine\\\":\\\"$(json_escape_for_api_result "${ACTION_LAST_LINE}")\\\"}"

http_response "${RESP}"
