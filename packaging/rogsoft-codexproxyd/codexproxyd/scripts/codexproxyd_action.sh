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
BOOT_ACTION="${ACTION:-$1}"
ACTION_NAME="${codexproxyd_action}"
DISK_PATH="${codexproxyd_disk_path_selected}"
IMAGE_REF="${codexproxyd_image_ref}"
DEFAULT_MODEL_VALUE="${codexproxyd_default_model}"
DEFAULT_EFFORT_VALUE="${codexproxyd_default_effort}"
AUDIT_LOG_LEVEL_VALUE="${codexproxyd_audit_log_level}"
DOCKROOT_BIN="${DISK_PATH}/DockRootBin/DockRoot"
DATA_DIR="${DISK_PATH}/codex-proxyd-data"
DOCKROOT_DATA_DIR="${DISK_PATH}/DockRootData/${CONTAINER_NAME}"
ACCOUNTS_FILE="${DATA_DIR}/accounts.json"
API_KEY_FILE="${DATA_DIR}/api-proxy.key"
PROXY_SETTINGS_FILE="${DATA_DIR}/proxy-settings.json"
TMP_PAYLOAD="/tmp/${CONTAINER_NAME}_payload.json"
TMP_ACCOUNTS="/tmp/${CONTAINER_NAME}_accounts.json"

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

write_log_header() {
	mkdir -p /tmp/upload
	echo "codexproxyd action: ${ACTION_NAME:-${BOOT_ACTION}}" > "${LOG_FILE}"
}

fail_action() {
	local message="$1"
	echo_date "${message}" >> "${LOG_FILE}"
	set_last_error "${message}"
	return 1
}

ensure_disk_path() {
	if [ -z "${DISK_PATH}" ] || [ ! -d "${DISK_PATH}" ]; then
		fail_action "Disk path is empty or unavailable."
		return 1
	fi
	return 0
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
}

normalize_default_model() {
	local value="$1"
	[ -n "${value}" ] || value="${DEFAULT_MODEL}"
	printf "%s" "${value}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

normalize_default_effort() {
	local value normalized
	value="$1"
	normalized=$(printf "%s" "${value}" | tr 'A-Z' 'a-z' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
	case "${normalized}" in
		minimal|low|medium|high)
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

json_escape() {
	printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
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
	if [ ! -s "${ACCOUNTS_FILE}" ]; then
		fail_action "accounts.json is missing from ${DATA_DIR}."
		return 1
	fi
	return 0
}

decode_payload() {
	if [ -z "${codexproxyd_payload_b64}" ]; then
		fail_action "Import payload is empty."
		return 1
	fi

	if printf "%s" "${codexproxyd_payload_b64}" | base64 -d > "${TMP_PAYLOAD}" 2>/dev/null; then
		return 0
	fi

	if command -v openssl >/dev/null 2>&1 && printf "%s" "${codexproxyd_payload_b64}" | openssl base64 -d -A > "${TMP_PAYLOAD}" 2>/dev/null; then
		return 0
	fi

	fail_action "Failed to decode import payload."
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
	chmod 600 "${ACCOUNTS_FILE}" >/dev/null 2>&1
	set_last_import_at
	clear_last_error
	echo_date "Saved accounts.json into ${ACCOUNTS_FILE}" >> "${LOG_FILE}"
	return 0
}

pull_image() {
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	ensure_image_ref || return 1
	ensure_data_dir
	write_proxy_settings

	echo_date "Pulling image: ${IMAGE_REF}" >> "${LOG_FILE}"
	"${DOCKROOT_BIN}" pull "${IMAGE_REF}" "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || {
		fail_action "DockRoot pull failed."
		return 1
	}

	clear_last_error
	echo_date "Image pull finished." >> "${LOG_FILE}"
	return 0
}

start_container() {
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	ensure_image_ref || return 1
	ensure_data_dir
	write_proxy_settings
	ensure_accounts_file || return 1

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

	clear_last_error
	echo_date "Container started." >> "${LOG_FILE}"
	return 0
}

stop_container() {
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	echo_date "Stopping container ${CONTAINER_NAME}." >> "${LOG_FILE}"
	"${DOCKROOT_BIN}" stop "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || true
	clear_last_error
	echo_date "Stop command finished." >> "${LOG_FILE}"
	return 0
}

remove_container() {
	ensure_disk_path || return 1
	ensure_dockroot || return 1
	echo_date "Removing container ${CONTAINER_NAME}." >> "${LOG_FILE}"
	"${DOCKROOT_BIN}" stop "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || true
	"${DOCKROOT_BIN}" rm "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || true
	clear_last_error
	echo_date "Container remove finished. Data dir was preserved." >> "${LOG_FILE}"
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

	if pidof codex-tools-proxyd >/dev/null 2>&1; then
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
	dbus set codexproxyd_enable="${codexproxyd_enable}"
	dbus set codexproxyd_disk_path_selected="${codexproxyd_disk_path_selected}"
	dbus set codexproxyd_image_ref="${codexproxyd_image_ref}"
	dbus set codexproxyd_default_model="$(normalize_default_model "${codexproxyd_default_model}")"
	dbus set codexproxyd_default_effort="$(normalize_default_effort "${codexproxyd_default_effort}")"
	dbus set codexproxyd_audit_log_level="$(normalize_audit_log_level "${codexproxyd_audit_log_level}")"
	DEFAULT_MODEL_VALUE="$(normalize_default_model "${codexproxyd_default_model}")"
	DEFAULT_EFFORT_VALUE="$(normalize_default_effort "${codexproxyd_default_effort}")"
	AUDIT_LOG_LEVEL_VALUE="$(normalize_audit_log_level "${codexproxyd_audit_log_level}")"
	ensure_disk_path || return 1
	ensure_data_dir
	write_proxy_settings
	clear_last_error
	echo_date "Settings saved." >> "${LOG_FILE}"
	return 0
}

import_accounts_payload() {
	ensure_disk_path || return 1
	decode_payload || return 1
	validate_accounts_payload || return 1
	save_accounts_payload || return 1
	echo_date "Accounts import finished. Running proxyd will pick up the new store on later requests." >> "${LOG_FILE}"
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

write_log_header

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
	remove_container)
		remove_container
		;;
	regenerate_key)
		regenerate_key
		;;
	import_accounts|import_auth)
		import_accounts_payload
		;;
	*)
		fail_action "Unknown action: ${ACTION_NAME}"
		;;
esac

ACTION_RESULT=$?
finish_log
http_response "$1"
exit ${ACTION_RESULT}
