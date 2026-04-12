#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh >/dev/null 2>&1
alias echo_date='echo [$(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")]'
eval $(dbus export codexproxyd)

CONTAINER_NAME="codexproxyd"
PORT="8787"
DEFAULT_MODEL="gpt-5.4"
DEFAULT_EFFORT="high"
DEFAULT_AUDIT_LOG_LEVEL="basic"
LOG_FILE="/tmp/upload/codexproxyd_log.txt"
ACTION_PID_FILE="/tmp/codexproxyd_action.pid"
ACTION_STATE_FILE="/tmp/codexproxyd_action.state"
BOOT_ACTION="${ACTION:-$1}"
ACTION_NAME="${codexproxyd_action:-${2:-$1}}"
coalesce_setting_value() {
	local preferred="$1"
	local fallback="$2"
	preferred="$(printf "%s" "${preferred}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
	if [ -n "${preferred}" ]; then
		printf "%s" "${preferred}"
		return 0
	fi
	printf "%s" "${fallback}"
}
DISK_PATH="$(coalesce_setting_value "${codexproxyd_disk_path_selected}" "$(dbus get codexproxyd_disk_path_selected)")"
IMAGE_REF="$(coalesce_setting_value "${codexproxyd_image_ref}" "$(dbus get codexproxyd_image_ref)")"
DEFAULT_MODEL_VALUE="$(coalesce_setting_value "${codexproxyd_default_model}" "$(dbus get codexproxyd_default_model)")"
DEFAULT_EFFORT_VALUE="$(coalesce_setting_value "${codexproxyd_default_effort}" "$(dbus get codexproxyd_default_effort)")"
AUDIT_LOG_LEVEL_VALUE="$(coalesce_setting_value "${codexproxyd_audit_log_level}" "$(dbus get codexproxyd_audit_log_level)")"
CUSTOM_API_KEY_VALUE="${codexproxyd_api_key_value}"
DATA_DIR_OVERRIDE="$(coalesce_setting_value "${codexproxyd_data_dir_value}" "$(dbus get codexproxyd_data_dir_value)")"
DOCKROOT_BIN=""
DATA_DIR=""
DOCKROOT_DATA_DIR=""
ACCOUNTS_FILE=""
API_KEY_FILE=""
PROXY_SETTINGS_FILE=""
USAGE_SUMMARY_FILE=""
USAGE_REFRESH_URL="http://127.0.0.1:${PORT}/__codex_tools/accounts/usage/refresh"
TMP_PAYLOAD="/tmp/${CONTAINER_NAME}_payload.json"
TMP_ACCOUNTS="/tmp/${CONTAINER_NAME}_accounts.json"
TMP_USAGE_SUMMARY="/tmp/${CONTAINER_NAME}_usage_summary.json"
TMP_IMPORTED_USAGE_SUMMARY="/tmp/${CONTAINER_NAME}_imported_usage_summary.json"
REQUEST_ID="${codexproxyd_request_id}"
HTTP_CLIENT=""

set_last_error() {
	dbus set codexproxyd_last_error="$1"
}

clear_last_error() {
	dbus set codexproxyd_last_error=""
}

set_last_import_at() {
	dbus set codexproxyd_last_import_at="$(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")"
}

finish_log() {
	echo "XU6J03M6" >> "${LOG_FILE}"
}

write_action_state() {
	local status="$1"
	local message="$2"
	local pid_value="$3"
	mkdir -p /tmp
	cat > "${ACTION_STATE_FILE}" <<-EOF
	{
	  "name": "$(json_escape "${ACTION_NAME}")",
	  "status": "$(json_escape "${status}")",
	  "pid": "$(json_escape "${pid_value}")",
	  "message": "$(json_escape "${message}")",
	  "updatedAt": "$(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")"
	}
	EOF
	chmod 600 "${ACTION_STATE_FILE}" >/dev/null 2>&1
}

write_log_header() {
	mkdir -p /tmp/upload
	echo "codexproxyd action: ${ACTION_NAME:-${BOOT_ACTION}}" > "${LOG_FILE}"
}

last_log_line() {
	tail -n 1 "${LOG_FILE}" 2>/dev/null | tr -d '\r\n'
}

last_meaningful_log_line() {
	awk '
		$0 != "XU6J03M6" && length($0) > 0 { line = $0 }
		END {
			if (length(line) > 0) {
				gsub(/\r/, "", line)
				printf "%s", line
			}
		}
	' "${LOG_FILE}" 2>/dev/null
}

success_response_value() {
	if [ -n "${REQUEST_ID}" ]; then
		printf "%s" "${REQUEST_ID}"
		return 0
	fi
	printf "%s" "$1"
}

refresh_runtime_paths() {
	local default_data_dir resolved_data_dir
	DOCKROOT_BIN="${DISK_PATH}/DockRootBin/DockRoot"
	DOCKROOT_DATA_DIR="${DISK_PATH}/DockRootData/${CONTAINER_NAME}"
	default_data_dir="${DISK_PATH}/codex-proxyd-data"
	resolved_data_dir="$(resolve_runtime_data_dir "${default_data_dir}")"
	DATA_DIR="${resolved_data_dir:-${default_data_dir}}"
	ACCOUNTS_FILE="${DATA_DIR}/accounts.json"
	API_KEY_FILE="${DATA_DIR}/api-proxy.key"
	PROXY_SETTINGS_FILE="${DATA_DIR}/proxy-settings.json"
	USAGE_SUMMARY_FILE="${DATA_DIR}/accounts-usage-summary.json"
}

fail_action() {
	local message="$1"
	echo_date "${message}" >> "${LOG_FILE}"
	set_last_error "${message}"
	return 1
}

read_proxyd_pid_list() {
	pidof codex-tools-proxyd 2>/dev/null | tr ' ' '\n' | awk 'NF { print $0 }'
}

get_proxyd_pid_count() {
	read_proxyd_pid_list | awk 'NF { count++ } END { printf "%d", count + 0 }'
}

is_action_running() {
	local action_pid
	[ -f "${ACTION_PID_FILE}" ] || return 1
	action_pid="$(cat "${ACTION_PID_FILE}" 2>/dev/null | tr -d '\r\n')"
	case "${action_pid}" in
		""|*[!0-9]*)
			rm -f "${ACTION_PID_FILE}"
			return 1
			;;
	esac
	if kill -0 "${action_pid}" 2>/dev/null; then
		return 0
	fi
	rm -f "${ACTION_PID_FILE}"
	return 1
}

wait_for_action_slot() {
	if is_action_running; then
		fail_action "Another action is still running. Wait for it to finish first."
		return 1
	fi
	return 0
}

data_dir_score() {
	local candidate="$1" score=0
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

find_existing_disk_path() {
	local candidate found_path="" found_count=0
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

find_accounts_disk_path() {
	local candidate found_path="" found_count=0
	for candidate in /tmp/mnt/*; do
		[ -d "${candidate}" ] || continue
		case "${candidate}" in
			/tmp/mnt/defaults)
				continue
				;;
		esac
		if [ -s "${candidate}/codex-proxyd-data/accounts.json" ] || [ -s "${candidate}/codex-proxyd-data/accounts-usage-summary.json" ]; then
			found_path="${candidate}"
			found_count=$((found_count + 1))
		fi
	done
	if [ "${found_count}" = "1" ]; then
		printf "%s" "${found_path}"
	fi
}

recover_disk_path_from_accounts_file() {
	local recovered_path
	recovered_path="$(find_accounts_disk_path)"
	if [ -n "${recovered_path}" ] && [ -d "${recovered_path}" ]; then
		DISK_PATH="${recovered_path}"
		codexproxyd_disk_path_selected="${DISK_PATH}"
		dbus set codexproxyd_disk_path_selected="${DISK_PATH}"
		refresh_runtime_paths
		echo_date "Recovered disk path from existing accounts.json: ${DISK_PATH}" >> "${LOG_FILE}"
		return 0
	fi
	return 1
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

ensure_disk_path() {
	local recovered_path
	if [ -n "${DISK_PATH}" ] && [ -d "${DISK_PATH}" ]; then
		codexproxyd_disk_path_selected="${DISK_PATH}"
		dbus set codexproxyd_disk_path_selected="${DISK_PATH}"
		refresh_runtime_paths
		dbus set codexproxyd_data_dir_value="${DATA_DIR}"
		return 0
	fi
	recovered_path="$(find_existing_disk_path)"
	if [ -z "${recovered_path}" ]; then
		recover_disk_path_from_accounts_file >/dev/null 2>&1 || true
		if [ -n "${DISK_PATH}" ] && [ -d "${DISK_PATH}" ]; then
			refresh_runtime_paths
			dbus set codexproxyd_data_dir_value="${DATA_DIR}"
			return 0
		fi
		recovered_path="$(find_existing_disk_path)"
	fi
	if [ -n "${recovered_path}" ] && [ -d "${recovered_path}" ]; then
		DISK_PATH="${recovered_path}"
		codexproxyd_disk_path_selected="${DISK_PATH}"
		dbus set codexproxyd_disk_path_selected="${DISK_PATH}"
		refresh_runtime_paths
		dbus set codexproxyd_data_dir_value="${DATA_DIR}"
		echo_date "Recovered disk path automatically: ${DISK_PATH}" >> "${LOG_FILE}"
		return 0
	fi
	fail_action "Disk path is empty or unavailable."
	return 1
}

ensure_dockroot() {
	local version_output
	if [ ! -f "${DOCKROOT_BIN}" ]; then
		fail_action "DockRoot binary was not found at ${DOCKROOT_BIN}."
		return 1
	fi
	chmod 755 "${DOCKROOT_BIN}" >/dev/null 2>&1
	version_output="$(${DOCKROOT_BIN} -v 2>&1)"
	echo_date "DockRoot version probe: ${version_output}" >> "${LOG_FILE}"
	if ! echo "${version_output}" | grep -iq "version"; then
		echo_date "DockRoot version probe did not return the standard version string, continuing because the binary exists." >> "${LOG_FILE}"
	fi
	return 0
}

ensure_image_ref() {
	if [ -z "${IMAGE_REF}" ]; then
		fail_action "Image reference is empty. Save settings first."
		return 1
	fi
	return 0
}

ensure_data_dir() {
	mkdir -p "${DATA_DIR}"
	chmod 700 "${DATA_DIR}" >/dev/null 2>&1
	dbus set codexproxyd_data_dir_value="${DATA_DIR}"
}

normalize_default_model() {
	printf "%s" "${DEFAULT_MODEL}"
}

normalize_default_effort() {
	local value normalized
	value="$1"
	normalized=$(printf "%s" "${value}" | tr 'A-Z' 'a-z' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
	case "${normalized}" in
		low|medium|high|xhigh)
			printf "%s" "${normalized}"
			;;
		*)
			printf "%s" "${DEFAULT_EFFORT}"
			;;
	esac
}

normalize_audit_log_level() {
	local value normalized
	value="$1"
	normalized=$(printf "%s" "${value}" | tr 'A-Z' 'a-z' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
	case "${normalized}" in
		off|basic|debug)
			printf "%s" "${normalized}"
			;;
		*)
			printf "%s" "${DEFAULT_AUDIT_LOG_LEVEL}"
			;;
	esac
}

normalize_api_key_value() {
	printf "%s" "$1" | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

normalize_dockroot_image_ref() {
	local value repository
	value="$(printf "%s" "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
	case "${value}" in
		ttl.sh/*:latest|ttl.sh/*@*)
			printf "%s" "${value}"
			;;
		ttl.sh/*:*)
			repository="${value%:*}"
			printf "%s:latest" "${repository}"
			;;
		*)
			printf "%s" "${value}"
			;;
	esac
}

json_escape() {
	printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_api_key_file() {
	local value
	value="$(normalize_api_key_value "$1")"
	[ -n "${value}" ] || return 0
	ensure_data_dir
	printf "%s" "${value}" > "${API_KEY_FILE}"
	chmod 600 "${API_KEY_FILE}" >/dev/null 2>&1
	echo_date "Saved custom API key into ${API_KEY_FILE}" >> "${LOG_FILE}"
}

write_proxy_settings() {
	local normalized_model normalized_effort normalized_audit_log_level
	ensure_data_dir
	normalized_model=$(normalize_default_model "${DEFAULT_MODEL_VALUE}")
	normalized_effort=$(normalize_default_effort "${DEFAULT_EFFORT_VALUE}")
	normalized_audit_log_level=$(normalize_audit_log_level "${AUDIT_LOG_LEVEL_VALUE}")
	cat > "${PROXY_SETTINGS_FILE}" <<-EOF
	{
	  "defaultModel": "$(json_escape "${normalized_model}")",
	  "defaultEffort": "$(json_escape "${normalized_effort}")",
	  "auditLogLevel": "$(json_escape "${normalized_audit_log_level}")"
	}
	EOF
	chmod 600 "${PROXY_SETTINGS_FILE}" >/dev/null 2>&1
	echo_date "Updated proxy settings at ${PROXY_SETTINGS_FILE}" >> "${LOG_FILE}"
}

ensure_accounts_file() {
	local recovered_data_dir=""
	if [ ! -s "${ACCOUNTS_FILE}" ]; then
		recovered_data_dir="$(find_existing_data_dir)"
		if [ -n "${recovered_data_dir}" ] && [ "${recovered_data_dir}" != "${DATA_DIR}" ]; then
			DATA_DIR_OVERRIDE="${recovered_data_dir}"
			dbus set codexproxyd_data_dir_value="${recovered_data_dir}"
			refresh_runtime_paths
			echo_date "Recovered data dir from existing account data: ${DATA_DIR}" >> "${LOG_FILE}"
		else
			recover_disk_path_from_accounts_file >/dev/null 2>&1 || true
		fi
	fi
	if [ ! -s "${ACCOUNTS_FILE}" ]; then
		fail_action "accounts.json is missing from ${DATA_DIR}."
		return 1
	fi
	return 0
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
	fail_action "Neither curl nor wget is available on this system."
	return 1
}

run_http_post_to_file() {
	local url="$1"
	local output_path="$2"
	if [ "${HTTP_CLIENT}" = "curl" ]; then
		curl -sS -X POST -o "${output_path}" -w "%{http_code}" --max-time 180 "${url}" 2>> "${LOG_FILE}"
		return $?
	fi
	if [ "${HTTP_CLIENT}" = "wget" ]; then
		wget -q -O "${output_path}" --timeout=180 --post-data="" "${url}" >> "${LOG_FILE}" 2>&1
		if [ "$?" = "0" ]; then
			printf "200"
			return 0
		fi
		return 1
	fi
	return 1
}

is_runtime_running() {
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

kill_conflicting_proxyd_processes() {
	local pid_list pid
	pid_list="$(read_proxyd_pid_list)"
	[ -n "${pid_list}" ] || return 0
	echo_date "Cleaning conflicting codex-tools-proxyd host processes." >> "${LOG_FILE}"
	for pid in ${pid_list}; do
		case "${pid}" in
			""|*[!0-9]*)
				continue
				;;
		esac
		if kill -0 "${pid}" 2>/dev/null; then
			echo_date "Sending SIGTERM to codex-tools-proxyd pid ${pid}." >> "${LOG_FILE}"
			kill -TERM "${pid}" >> "${LOG_FILE}" 2>&1 || true
		fi
	done
	sleep 1
	pid_list="$(read_proxyd_pid_list)"
	[ -n "${pid_list}" ] || return 0
	for pid in ${pid_list}; do
		case "${pid}" in
			""|*[!0-9]*)
				continue
				;;
		esac
		if kill -0 "${pid}" 2>/dev/null; then
			echo_date "Sending SIGKILL to codex-tools-proxyd pid ${pid}." >> "${LOG_FILE}"
			kill -KILL "${pid}" >> "${LOG_FILE}" 2>&1 || true
		fi
	done
	sleep 1
	return 0
}

assert_single_proxyd_process() {
	local pid_count
	pid_count="$(get_proxyd_pid_count)"
	if [ "${pid_count}" = "1" ]; then
		return 0
	fi
	if [ "${pid_count}" = "0" ]; then
		fail_action "codex-tools-proxyd process was not found after the container action."
		return 1
	fi
	fail_action "codex-tools-proxyd still has multiple host processes."
	return 1
}

assert_runtime_stopped() {
	local pid_count
	if is_runtime_running; then
		fail_action "DockRoot still reports the container as running."
		return 1
	fi
	pid_count="$(get_proxyd_pid_count)"
	if [ "${pid_count}" != "0" ]; then
		fail_action "codex-tools-proxyd host process is still running after stop."
		return 1
	fi
	return 0
}

ensure_runtime_available() {
	if is_runtime_running; then
		return 0
	fi
	fail_action "codex-tools-proxyd is not running. Start the container first."
	return 1
}

save_usage_summary() {
	if [ ! -s "${TMP_USAGE_SUMMARY}" ]; then
		fail_action "Usage refresh returned an empty payload."
		return 1
	fi
	case "$(sed 's/^[[:space:]]*//' "${TMP_USAGE_SUMMARY}" 2>/dev/null)" in
		\[*\])
			;;
		*)
			fail_action "Usage refresh returned an invalid summary payload."
			return 1
			;;
	esac
	cp -f "${TMP_USAGE_SUMMARY}" "${USAGE_SUMMARY_FILE}"
	chmod 600 "${USAGE_SUMMARY_FILE}" >/dev/null 2>&1
	return 0
}

read_chunked_field_value() {
	local field_name="$1"
	local field_value chunk_count chunk_count_var chunk_index=0 chunk_var chunk_value
	eval "field_value=\${${field_name}:-}"
	if [ -n "${field_value}" ]; then
		printf "%s" "${field_value}"
		return 0
	fi
	chunk_count_var="${field_name}_chunks"
	eval "chunk_count=\${${chunk_count_var}:-0}"
	case "${chunk_count}" in
		""|*[!0-9]*)
			chunk_count=0
			;;
	esac
	while [ "${chunk_index}" -lt "${chunk_count}" ]; do
		chunk_var=$(printf "%s_%04d" "${field_name}" "${chunk_index}")
		eval "chunk_value=\${${chunk_var}:-}"
		printf "%s" "${chunk_value}"
		chunk_index=$((chunk_index + 1))
	done
}

decode_payload() {
	local payload_text payload_b64
	payload_text="$(read_chunked_field_value "codexproxyd_payload_text")"
	if [ -n "${payload_text}" ]; then
		printf "%s" "${payload_text}" > "${TMP_PAYLOAD}"
		return 0
	fi
	payload_b64="$(read_chunked_field_value "codexproxyd_payload_b64")"
	if [ -z "${payload_b64}" ]; then
		fail_action "Import payload is empty."
		return 1
	fi

	if printf "%s" "${payload_b64}" | base64 -d > "${TMP_PAYLOAD}" 2>/dev/null; then
		return 0
	fi

	if command -v openssl >/dev/null 2>&1 && printf "%s" "${payload_b64}" | openssl base64 -d -A > "${TMP_PAYLOAD}" 2>/dev/null; then
		return 0
	fi

	fail_action "Failed to decode import payload."
	return 1
}

decode_usage_summary_payload() {
	local usage_summary_text usage_summary_b64
	usage_summary_text="$(read_chunked_field_value "codexproxyd_usage_summary_text")"
	if [ -n "${usage_summary_text}" ]; then
		printf "%s" "${usage_summary_text}" > "${TMP_IMPORTED_USAGE_SUMMARY}"
		return 0
	fi
	usage_summary_b64="$(read_chunked_field_value "codexproxyd_usage_summary_b64")"
	if [ -z "${usage_summary_b64}" ]; then
		rm -f "${TMP_IMPORTED_USAGE_SUMMARY}"
		return 0
	fi

	if printf "%s" "${usage_summary_b64}" | base64 -d > "${TMP_IMPORTED_USAGE_SUMMARY}" 2>/dev/null; then
		return 0
	fi

	if command -v openssl >/dev/null 2>&1 && printf "%s" "${usage_summary_b64}" | openssl base64 -d -A > "${TMP_IMPORTED_USAGE_SUMMARY}" 2>/dev/null; then
		return 0
	fi

	fail_action "Failed to decode imported usage summary."
	return 1
}

validate_accounts_payload() {
	if [ ! -s "${TMP_PAYLOAD}" ]; then
		fail_action "Decoded payload is empty."
		return 1
	fi

	grep -q '"version"[[:space:]]*:' "${TMP_PAYLOAD}" || {
		fail_action "accounts.json payload is missing version."
		return 1
	}
	grep -q '"accounts"[[:space:]]*:' "${TMP_PAYLOAD}" || {
		fail_action "accounts.json payload is missing accounts."
		return 1
	}
	grep -q '"settings"[[:space:]]*:' "${TMP_PAYLOAD}" || {
		fail_action "accounts.json payload is missing settings."
		return 1
	}

	cp -f "${TMP_PAYLOAD}" "${TMP_ACCOUNTS}"
	return 0
}

save_accounts_payload() {
	ensure_data_dir
	if [ -f "${ACCOUNTS_FILE}" ]; then
		cp -f "${ACCOUNTS_FILE}" "${DATA_DIR}/accounts.json.backup"
	fi
	mv -f "${TMP_ACCOUNTS}" "${ACCOUNTS_FILE}"
	if [ -s "${TMP_IMPORTED_USAGE_SUMMARY}" ]; then
		cp -f "${TMP_IMPORTED_USAGE_SUMMARY}" "${USAGE_SUMMARY_FILE}"
		chmod 600 "${USAGE_SUMMARY_FILE}" >/dev/null 2>&1
	else
		rm -f "${USAGE_SUMMARY_FILE}"
	fi
	chmod 600 "${ACCOUNTS_FILE}" >/dev/null 2>&1
	set_last_import_at
	clear_last_error
	echo_date "Saved accounts.json into ${ACCOUNTS_FILE}" >> "${LOG_FILE}"
	return 0
}

pull_image() {
	local PULL_IMAGE_REF
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	ensure_image_ref || return 1
	ensure_data_dir
	write_proxy_settings
	cleanup_container_bundle_for_pull || return 1
	PULL_IMAGE_REF="$(normalize_dockroot_image_ref "${IMAGE_REF}")"
	if [ "${PULL_IMAGE_REF}" != "${IMAGE_REF}" ]; then
		echo_date "Normalized image reference for DockRoot pull: ${IMAGE_REF} -> ${PULL_IMAGE_REF}" >> "${LOG_FILE}"
	fi

	echo_date "Pulling image: ${PULL_IMAGE_REF}" >> "${LOG_FILE}"
	"${DOCKROOT_BIN}" pull "${PULL_IMAGE_REF}" "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
		fail_action "DockRoot pull failed."
		return 1
	}

	clear_last_error
	echo_date "Image pull finished." >> "${LOG_FILE}"
	return 0
}

start_container() {
	local pid_count
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	ensure_image_ref || return 1
	ensure_data_dir
	write_proxy_settings
	ensure_accounts_file || return 1
	if is_runtime_running; then
		assert_single_proxyd_process || return 1
		clear_last_error
		echo_date "Container is already running." >> "${LOG_FILE}"
		return 0
	fi
	pid_count="$(get_proxyd_pid_count)"
	if [ "${pid_count}" != "0" ]; then
		fail_action "Detected existing codex-tools-proxyd host process before start."
		return 1
	fi

	echo_date "Refreshing mount config for ${CONTAINER_NAME}." >> "${LOG_FILE}"
	"${DOCKROOT_BIN}" run -v "${DATA_DIR}:/data" --renew "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
		fail_action "DockRoot run --renew failed."
		return 1
	}

	echo_date "Starting container ${CONTAINER_NAME}." >> "${LOG_FILE}"
	"${DOCKROOT_BIN}" run -d "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
		fail_action "DockRoot run -d failed."
		return 1
	}
	is_runtime_running || {
		fail_action "Container did not enter running state after start."
		return 1
	}
	assert_single_proxyd_process || return 1

	clear_last_error
	echo_date "Container started." >> "${LOG_FILE}"
	return 0
}

stop_container() {
	local pid_count
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	if ! is_runtime_running; then
		pid_count="$(get_proxyd_pid_count)"
		if [ "${pid_count}" != "0" ]; then
			fail_action "Container is not running but codex-tools-proxyd host process still exists."
			return 1
		fi
		clear_last_error
		echo_date "Container is already stopped." >> "${LOG_FILE}"
		return 0
	fi
	echo_date "Stopping container ${CONTAINER_NAME}." >> "${LOG_FILE}"
	"${DOCKROOT_BIN}" stop "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
		fail_action "DockRoot stop failed."
		return 1
	}
	assert_runtime_stopped || return 1
	clear_last_error
	echo_date "Stop command finished." >> "${LOG_FILE}"
	return 0
}

remove_container() {
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	echo_date "Removing container ${CONTAINER_NAME}." >> "${LOG_FILE}"
	if is_runtime_running; then
		stop_container || return 1
	fi
	if [ -d "${DOCKROOT_DATA_DIR}" ] || [ -f "${DOCKROOT_DATA_DIR}/config.json" ] || [ -f "${DOCKROOT_DATA_DIR}/ruri.conf" ]; then
		"${DOCKROOT_BIN}" rm "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
			fail_action "DockRoot rm failed."
			return 1
		}
	fi
	rm -rf "${DOCKROOT_DATA_DIR}"
	assert_runtime_stopped || return 1
	clear_last_error
	echo_date "Container remove finished. Data dir was preserved." >> "${LOG_FILE}"
	return 0
}

cleanup_container_bundle_for_pull() {
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	if [ -d "${DOCKROOT_DATA_DIR}" ] || [ -f "${DOCKROOT_DATA_DIR}/config.json" ] || [ -f "${DOCKROOT_DATA_DIR}/ruri.conf" ] || is_runtime_running; then
		echo_date "Cleaning existing runtime bundle before pull." >> "${LOG_FILE}"
		if is_runtime_running; then
			stop_container || return 1
		fi
		if [ -d "${DOCKROOT_DATA_DIR}" ] || [ -f "${DOCKROOT_DATA_DIR}/config.json" ] || [ -f "${DOCKROOT_DATA_DIR}/ruri.conf" ]; then
			"${DOCKROOT_BIN}" rm "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
				fail_action "DockRoot rm failed during pull cleanup."
				return 1
			}
		fi
		rm -rf "${DOCKROOT_DATA_DIR}"
		assert_runtime_stopped || return 1
	fi
	return 0
}

cleanup_conflict() {
	local pid_count
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	echo_date "Resolving codex-tools-proxyd host process conflict." >> "${LOG_FILE}"
	if is_runtime_running; then
		echo_date "Container appears to be running, stopping it before cleanup." >> "${LOG_FILE}"
		"${DOCKROOT_BIN}" stop "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
			fail_action "DockRoot stop failed during conflict cleanup."
			return 1
		}
	fi
	kill_conflicting_proxyd_processes
	pid_count="$(get_proxyd_pid_count)"
	if [ "${pid_count}" != "0" ]; then
		fail_action "codex-tools-proxyd host process is still running after conflict cleanup."
		return 1
	fi
	if is_runtime_running; then
		fail_action "DockRoot still reports the container as running after conflict cleanup."
		return 1
	fi
	clear_last_error
	echo_date "Conflict cleanup finished." >> "${LOG_FILE}"
	return 0
}

regenerate_key() {
	ensure_disk_path || return 1
	ensure_data_dir
	ensure_accounts_file || return 1

	echo_date "Regenerating api-proxy.key." >> "${LOG_FILE}"
	if grep -q '"apiProxyApiKey"[[:space:]]*:' "${ACCOUNTS_FILE}" 2>/dev/null; then
		sed -i 's/"apiProxyApiKey"[[:space:]]*:[[:space:]]*"[^"]*"/"apiProxyApiKey": ""/g' "${ACCOUNTS_FILE}"
	fi
	rm -f "${API_KEY_FILE}"

	if is_runtime_running; then
		stop_container || return 1
		start_container || return 1
	else
		echo_date "Container is not running. New key will be created on next start." >> "${LOG_FILE}"
	fi

	clear_last_error
	echo_date "Key regeneration flow finished." >> "${LOG_FILE}"
	return 0
}

save_settings() {
	local normalized_api_key existing_api_key key_updated="0"
	local current_disk_path current_image_ref current_default_model current_default_effort current_audit_log_level
	current_disk_path="$(coalesce_setting_value "${codexproxyd_disk_path_selected}" "${DISK_PATH}")"
	current_image_ref="$(coalesce_setting_value "${codexproxyd_image_ref}" "${IMAGE_REF}")"
	current_default_model="$(coalesce_setting_value "${codexproxyd_default_model}" "${DEFAULT_MODEL_VALUE}")"
	current_default_effort="$(coalesce_setting_value "${codexproxyd_default_effort}" "${DEFAULT_EFFORT_VALUE}")"
	current_audit_log_level="$(coalesce_setting_value "${codexproxyd_audit_log_level}" "${AUDIT_LOG_LEVEL_VALUE}")"
	dbus set codexproxyd_enable="${codexproxyd_enable}"
	dbus set codexproxyd_disk_path_selected="${current_disk_path}"
	dbus set codexproxyd_image_ref="${current_image_ref}"
	dbus set codexproxyd_default_model="$(normalize_default_model "${current_default_model}")"
	dbus set codexproxyd_default_effort="$(normalize_default_effort "${current_default_effort}")"
	dbus set codexproxyd_audit_log_level="$(normalize_audit_log_level "${current_audit_log_level}")"
	DISK_PATH="${current_disk_path}"
	IMAGE_REF="${current_image_ref}"
	DEFAULT_MODEL_VALUE="$(normalize_default_model "${current_default_model}")"
	DEFAULT_EFFORT_VALUE="$(normalize_default_effort "${current_default_effort}")"
	AUDIT_LOG_LEVEL_VALUE="$(normalize_audit_log_level "${current_audit_log_level}")"
	ensure_disk_path || return 1
	ensure_data_dir
	write_proxy_settings
	normalized_api_key="$(normalize_api_key_value "${CUSTOM_API_KEY_VALUE}")"
	if [ -n "${normalized_api_key}" ]; then
		existing_api_key="$(normalize_api_key_value "$(cat "${API_KEY_FILE}" 2>/dev/null)")"
		if [ "${existing_api_key}" != "${normalized_api_key}" ]; then
			write_api_key_file "${normalized_api_key}" || return 1
			key_updated="1"
		fi
	fi
	if [ "${key_updated}" = "1" ]; then
		if is_runtime_running; then
			if [ -f "${DOCKROOT_BIN}" ] && [ -n "${IMAGE_REF}" ] && [ -s "${ACCOUNTS_FILE}" ]; then
				echo_date "Restarting container so the updated api-proxy.key takes effect." >> "${LOG_FILE}"
				stop_container || return 1
				start_container || return 1
			else
				echo_date "Custom API key was saved. Restart manually after fixing the current runtime settings." >> "${LOG_FILE}"
			fi
		else
			echo_date "Container is not running. Custom API key will take effect on next start." >> "${LOG_FILE}"
		fi
	fi
	clear_last_error
	echo_date "Settings saved." >> "${LOG_FILE}"
	return 0
}

import_accounts_payload() {
	ensure_disk_path || return 1
	decode_payload || return 1
	decode_usage_summary_payload || return 1
	validate_accounts_payload || return 1
	save_accounts_payload || return 1
	rm -f "${TMP_IMPORTED_USAGE_SUMMARY}"
	echo_date "Accounts import finished. Running proxyd will pick up the new store on later requests." >> "${LOG_FILE}"
	return 0
}

refresh_usage() {
	local http_code
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	ensure_data_dir
	ensure_accounts_file || return 1
	ensure_http_client || return 1
	ensure_runtime_available || return 1

	rm -f "${TMP_USAGE_SUMMARY}"
	echo_date "Refreshing account usage via ${USAGE_REFRESH_URL}" >> "${LOG_FILE}"
	http_code=$(run_http_post_to_file "${USAGE_REFRESH_URL}" "${TMP_USAGE_SUMMARY}") || {
		rm -f "${TMP_USAGE_SUMMARY}"
		fail_action "Account usage refresh request failed."
		return 1
	}

	if [ "${http_code}" != "200" ]; then
		echo_date "Account usage refresh failed with HTTP ${http_code}." >> "${LOG_FILE}"
		if [ -f "${TMP_USAGE_SUMMARY}" ]; then
			echo_date "Refresh response: $(cat "${TMP_USAGE_SUMMARY}" 2>/dev/null)" >> "${LOG_FILE}"
		fi
		rm -f "${TMP_USAGE_SUMMARY}"
		fail_action "Account usage refresh failed with HTTP ${http_code}."
		return 1
	fi

	save_usage_summary || {
		rm -f "${TMP_USAGE_SUMMARY}"
		return 1
	}

	rm -f "${TMP_USAGE_SUMMARY}"
	clear_last_error
	echo_date "Account usage refresh finished." >> "${LOG_FILE}"
	return 0
}

run_action_by_name() {
	case "${ACTION_NAME}" in
		save_settings)
			save_settings
			;;
		pull_image)
			pull_image
			;;
		start)
			start_container
			;;
		stop)
			stop_container
			;;
		restart)
			stop_container && start_container
			;;
		cleanup_conflict)
			cleanup_conflict
			;;
		remove_container)
			remove_container
			;;
		regenerate_key)
			regenerate_key
			;;
		refresh_usage)
			refresh_usage
			;;
		import_accounts|import_auth)
			import_accounts_payload
			;;
		*)
			fail_action "Unknown action: ${ACTION_NAME}"
			;;
	esac
}

start_async_action() {
	local action_pid
	wait_for_action_slot || return 1
	write_log_header
	(
		run_action_by_name
		ACTION_RESULT=$?
		finish_log
		if [ "${ACTION_RESULT}" = "0" ]; then
			write_action_state "success" "$(last_meaningful_log_line)" ""
		else
			write_action_state "error" "$(last_meaningful_log_line)" ""
		fi
		rm -f "${ACTION_PID_FILE}"
		exit ${ACTION_RESULT}
	) &
	action_pid=$!
	echo "${action_pid}" > "${ACTION_PID_FILE}"
	write_action_state "running" "" "${action_pid}"
	echo_date "Action ${ACTION_NAME} is running in background (pid ${action_pid})." >> "${LOG_FILE}"
	return 0
}

handle_boot() {
	if [ "${codexproxyd_enable}" != "1" ]; then
		exit 0
	fi

	write_log_header
	start_container
	finish_log
	exit 0
}

if [ -z "${ACTION_NAME}" ] && [ "${BOOT_ACTION}" = "start" -o "${BOOT_ACTION}" = "restart" ]; then
	handle_boot
fi

case "${ACTION_NAME}" in
	pull_image|start|stop|restart|cleanup_conflict|remove_container|regenerate_key|refresh_usage)
		start_async_action
		ACTION_RESULT=$?
		if [ "${ACTION_RESULT}" = "0" ]; then
			http_response "$(success_response_value "$1")"
		else
			http_response "$(last_meaningful_log_line)"
		fi
		exit ${ACTION_RESULT}
		;;
	*)
		write_log_header
		run_action_by_name
		ACTION_RESULT=$?
		finish_log
		if [ "${ACTION_RESULT}" = "0" ]; then
			http_response "$(success_response_value "$1")"
		else
			http_response "$(last_meaningful_log_line)"
		fi
		exit ${ACTION_RESULT}
		;;
esac
