#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-"${ROOT_DIR}/build/EnhancedDamageMeter"}"
SOURCE_DIR="${2:-"${ENHANCEQOL_SOURCE_DIR:-"${ROOT_DIR}/source/EnhanceQoL"}"}"
TEMPLATE_DIR="${ROOT_DIR}"

copy_dir() {
	local source="$1"
	local destination="$2"
	mkdir -p "$(dirname "${destination}")"
	/usr/bin/rsync -a --delete --exclude '.DS_Store' "${source}/" "${destination}/"
}

if [ ! -d "${SOURCE_DIR}" ]; then
	echo "EnhanceQoL source directory not found: ${SOURCE_DIR}" >&2
	exit 1
fi

LIBEQOL_DIR="${TEMPLATE_DIR}/libs/LibEQOL"
if [ ! -d "${LIBEQOL_DIR}" ]; then
	LIBEQOL_DIR="${SOURCE_DIR}/libs/LibEQOL"
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/libs" "${OUT_DIR}/Locales" "${OUT_DIR}/Core"

cp "${TEMPLATE_DIR}/EnhancedDamageMeter.toc" "${OUT_DIR}/EnhancedDamageMeter.toc"
cp "${TEMPLATE_DIR}/Core.lua" "${OUT_DIR}/Core.lua"
cp "${TEMPLATE_DIR}/Functions.lua" "${OUT_DIR}/Functions.lua"
cp "${TEMPLATE_DIR}/Settings.lua" "${OUT_DIR}/Settings.lua"
cp "${SOURCE_DIR}/Submodules/DamageMeter.lua" "${OUT_DIR}/DamageMeter.lua"
cp "${SOURCE_DIR}/Core/EditModeLib.lua" "${OUT_DIR}/Core/EditModeLib.lua"
cp "${SOURCE_DIR}/Core/EditMode.lua" "${OUT_DIR}/Core/EditMode.lua"
copy_dir "${TEMPLATE_DIR}/Icons" "${OUT_DIR}/Icons"

perl -0pi -e 's/_G\.EnhanceQoLDB/_G.EnhancedDamageMeterDB/g; s/category = "EnhanceQoL"/category = "Enhanced Damage Meter"/g' "${OUT_DIR}/Core/EditMode.lua"

for locale in "${SOURCE_DIR}"/Locales/*.lua; do
	name="$(basename "${locale}")"
	cp "${locale}" "${OUT_DIR}/Locales/${name}"
	perl -0pi -e 's/NewLocale\("EnhanceQoL"/NewLocale("EnhancedDamageMeter"/g' "${OUT_DIR}/Locales/${name}"
done

copy_dir "${SOURCE_DIR}/libs/LibStub" "${OUT_DIR}/libs/LibStub"
copy_dir "${SOURCE_DIR}/libs/CallbackHandler-1.0" "${OUT_DIR}/libs/CallbackHandler-1.0"
copy_dir "${SOURCE_DIR}/libs/AceLocale-3.0" "${OUT_DIR}/libs/AceLocale-3.0"
copy_dir "${SOURCE_DIR}/libs/LibDeflate" "${OUT_DIR}/libs/LibDeflate"
copy_dir "${SOURCE_DIR}/libs/AceSerializer-3.0" "${OUT_DIR}/libs/AceSerializer-3.0"
copy_dir "${SOURCE_DIR}/libs/LibSharedMedia-3.0" "${OUT_DIR}/libs/LibSharedMedia-3.0"
copy_dir "${LIBEQOL_DIR}" "${OUT_DIR}/libs/LibEQOL"

find "${OUT_DIR}/libs/LibEQOL" -type f \( -name '*.lua' -o -name '*.xml' \) -print0 |
	xargs -0 perl -0pi -e 's/LibEQOL(?:\@project-abbreviated-hash\@|[A-Za-z0-9]+)?_(SettingsListSectionHintTemplate|MultiDropdownTemplate|ScrollDropdownTemplate|InputControlTemplate|ColorOverridesPanel|ColorOverridesPanelNoHead|SoundDropdownTemplate|SortableListTemplate)/LibEQOL_EnhancedDamageMeter_$1/g'

printf 'Built Enhanced Damage Meter at %s\n' "${OUT_DIR}"
