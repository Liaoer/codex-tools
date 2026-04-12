#!/bin/sh
source /koolshare/scripts/base.sh >/dev/null 2>&1
alias echo_date='echo [$(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")]'

DIR=$(cd "$(dirname "$0")"; pwd)
module=${DIR##*/}
TITLE="codexproxyd"
DESCR="DockRoot control panel for codex-tools-proxyd"

cleanup_tmp() {
	rm -rf /tmp/${module}* >/dev/null 2>&1
}

exit_install() {
	local state=$1
	if [ "${state}" != "0" ]; then
		echo_date "Current firmware is not compatible with the codexproxyd rogsoft package."
		cleanup_tmp
		exit 1
	fi

	cleanup_tmp
	exit 0
}

platform_test() {
	local linux_ver arch
	linux_ver=$(uname -r | awk -F'.' '{print $1$2}')
	arch=$(uname -m)
	if [ -d "/koolshare" ] && [ -f "/usr/bin/skipd" ] && [ "${linux_ver}" -ge "41" ] && [ "${arch}" = "aarch64" -o "${arch}" = "arm64" ]; then
		echo_date "Detected a compatible rogsoft arm64 platform. Installing ${TITLE}."
	else
		exit_install 1
	fi
}

install_now() {
	local plver current_enable current_disk_path current_data_dir current_image_ref current_default_model current_default_effort current_audit_log_level current_last_error current_last_import_at
	plver=$(cat "${DIR}/version")
	current_enable=$(dbus get ${module}_enable)
	current_disk_path=$(dbus get ${module}_disk_path_selected)
	current_data_dir=$(dbus get ${module}_data_dir_value)
	current_image_ref=$(dbus get ${module}_image_ref)
	current_default_model=$(dbus get ${module}_default_model)
	current_default_effort=$(dbus get ${module}_default_effort)
	current_audit_log_level=$(dbus get ${module}_audit_log_level)
	current_last_error=$(dbus get ${module}_last_error)
	current_last_import_at=$(dbus get ${module}_last_import_at)

	mkdir -p /koolshare/webs /koolshare/res /koolshare/scripts /koolshare/init.d
	cp -f "/tmp/${module}/webs/Module_${module}.asp" /koolshare/webs/
	cp -f "/tmp/${module}/res/icon-${module}.png" /koolshare/res/
	cp -f /tmp/${module}/scripts/* /koolshare/scripts/
	cp -f "/tmp/${module}/uninstall.sh" "/koolshare/scripts/uninstall_${module}.sh"
	chmod 755 /koolshare/scripts/${module}_*.sh
	chmod 755 "/koolshare/scripts/uninstall_${module}.sh"
	ln -sf "/koolshare/scripts/${module}_action.sh" "/koolshare/init.d/S96${module}.sh"

	[ -z "${current_enable}" ] && current_enable="0"
	[ -z "${current_default_model}" ] && current_default_model="gpt-5.4"
	[ -z "${current_default_effort}" ] && current_default_effort="high"
	[ -z "${current_audit_log_level}" ] && current_audit_log_level="basic"
	dbus set ${module}_enable="${current_enable}"
	dbus set ${module}_disk_path_selected="${current_disk_path}"
	dbus set ${module}_data_dir_value="${current_data_dir}"
	dbus set ${module}_image_ref="${current_image_ref}"
	dbus set ${module}_default_model="${current_default_model}"
	dbus set ${module}_default_effort="${current_default_effort}"
	dbus set ${module}_audit_log_level="${current_audit_log_level}"
	dbus set ${module}_title="${TITLE}"
	dbus set ${module}_last_error="${current_last_error}"
	dbus set ${module}_last_import_at="${current_last_import_at}"
	dbus set ${module}_version="${plver}"
	dbus set softcenter_module_${module}_version="${plver}"
	dbus set softcenter_module_${module}_install="1"
	dbus set softcenter_module_${module}_name="${module}"
	dbus set softcenter_module_${module}_title="${TITLE}"
	dbus set softcenter_module_${module}_description="${DESCR}"

	echo_date "${TITLE} installed successfully."
	exit_install 0
}

platform_test
install_now
