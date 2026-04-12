#!/bin/sh
source /koolshare/scripts/base.sh >/dev/null 2>&1

module=codexproxyd

/koolshare/scripts/${module}_action.sh stop >/dev/null 2>&1

rm -f /koolshare/webs/Module_codexproxyd.asp >/dev/null 2>&1
rm -f /koolshare/res/icon-codexproxyd.png >/dev/null 2>&1
rm -f /koolshare/scripts/codexproxyd_action.sh >/dev/null 2>&1
rm -f /koolshare/scripts/codexproxyd_status.sh >/dev/null 2>&1
rm -f /koolshare/scripts/codexproxyd_log.sh >/dev/null 2>&1
rm -f /koolshare/scripts/uninstall_codexproxyd.sh >/dev/null 2>&1
rm -f /koolshare/init.d/S96codexproxyd.sh >/dev/null 2>&1

dbus remove ${module}_enable
dbus remove ${module}_disk_path_selected
dbus remove ${module}_data_dir_value
dbus remove ${module}_image_ref
dbus remove ${module}_title
dbus remove ${module}_last_error
dbus remove ${module}_last_import_at
dbus remove ${module}_version
dbus remove softcenter_module_${module}_md5
dbus remove softcenter_module_${module}_version
dbus remove softcenter_module_${module}_install
dbus remove softcenter_module_${module}_name
dbus remove softcenter_module_${module}_title
dbus remove softcenter_module_${module}_description

exit 0
