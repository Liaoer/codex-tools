#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh >/dev/null 2>&1
eval $(dbus export codexproxyd)

DISK_PATH="${codexproxyd_disk_path_selected}"
DATA_DIR_OVERRIDE="${codexproxyd_data_dir_value}"
LOG_KIND="$2"
[ -n "${LOG_KIND}" ] || LOG_KIND="${codexproxyd_log_kind}"
AUDIT_LOG_LEVEL="${codexproxyd_audit_log_level}"
RUNTIME_LOG_PATH="${DISK_PATH}/DockRootData/codexproxyd/ruri.log"
DATA_DIR=""
ACCESS_LOG_PATH=""
DEBUG_LOG_PATH=""
ERROR_LOG_PATH=""
ACTION_LOG_PATH="/tmp/upload/codexproxyd_log.txt"
LOG_PATH="${RUNTIME_LOG_PATH}"
MISSING_MESSAGE=""

json_escape_text() {
	printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g; :a;N;$!ba;s/\n/\\n/g'
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
	extracted_path="$(extract_runtime_data_dir_from_file "${DISK_PATH}/DockRootData/codexproxyd/config.json")"
	if [ -z "${extracted_path}" ]; then
		extracted_path="$(extract_runtime_data_dir_from_file "${DISK_PATH}/DockRootData/codexproxyd/ruri.conf")"
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

[ -n "${LOG_KIND}" ] || LOG_KIND="runtime"
[ -n "${AUDIT_LOG_LEVEL}" ] || AUDIT_LOG_LEVEL="basic"
AUDIT_LOG_LEVEL="$(printf "%s" "${AUDIT_LOG_LEVEL}" | tr 'A-Z' 'a-z')"
resolved_data_dir="$(resolve_runtime_data_dir "${DISK_PATH}/codex-proxyd-data")"
DATA_DIR="${resolved_data_dir:-${DISK_PATH}/codex-proxyd-data}"
ACCESS_LOG_PATH="${DATA_DIR}/logs/access.jsonl"
DEBUG_LOG_PATH="${DATA_DIR}/logs/debug.jsonl"
ERROR_LOG_PATH="${DATA_DIR}/logs/error.jsonl"

case "${LOG_KIND}" in
	audit)
		if [ "${AUDIT_LOG_LEVEL}" = "debug" ] && [ -f "${DEBUG_LOG_PATH}" ]; then
			LOG_PATH="${DEBUG_LOG_PATH}"
		else
			LOG_PATH="${ACCESS_LOG_PATH}"
		fi
		if [ "${AUDIT_LOG_LEVEL}" = "off" ]; then
			MISSING_MESSAGE="请求审计日志已关闭。将日志级别切换到 basic 或 debug 后，再发起一次 API 请求即可看到记录。"
		else
			MISSING_MESSAGE="暂无请求审计记录。先发起一次 /v1/models、/v1/chat/completions 或 /v1/responses 请求后再刷新。"
		fi
		;;
	error)
		LOG_PATH="${ERROR_LOG_PATH}"
		MISSING_MESSAGE="暂无错误日志。"
		;;
	action)
		LOG_PATH="${ACTION_LOG_PATH}"
		MISSING_MESSAGE="正在等待操作日志输出。"
		;;
	*)
		LOG_PATH="${RUNTIME_LOG_PATH}"
		MISSING_MESSAGE="暂无运行日志，请确认容器已经启动。"
		;;
esac

if [ -f "${LOG_PATH}" ]; then
	LOG_TEXT="$(tail -n 80 "${LOG_PATH}" 2>/dev/null)"
else
	LOG_TEXT="${MISSING_MESSAGE}"
fi

http_response "$(json_escape_text "${LOG_TEXT}")"
