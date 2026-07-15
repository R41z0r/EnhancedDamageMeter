#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-"${ROOT_DIR}/build/EnhancedDamageMeter"}"
TEMPLATE_DIR="${ROOT_DIR}"

resolve_source_dir() {
	if [ "${2:-}" != "" ]; then
		printf '%s\n' "$2"
		return
	fi
	if [ "${ENHANCEQOL_SOURCE_DIR:-}" != "" ]; then
		printf '%s\n' "${ENHANCEQOL_SOURCE_DIR}"
		return
	fi

	local candidates=(
		"${ROOT_DIR}/source"
		"${ROOT_DIR}/source/EnhanceQoL"
		"${ROOT_DIR}/../EnhanceQoL"
		"${ROOT_DIR}/../EnhanceQoL/EnhanceQoL"
		"${ROOT_DIR}/../WoWAddons/Raizor"
		"${ROOT_DIR}/../WoWAddons/Raizor/EnhanceQoL"
		"/Volumes/T7 Shield/Git/WoWAddons/Raizor"
		"${ROOT_DIR}/../Raizor/EnhanceQoL"
	)

	local candidate
	for candidate in "${candidates[@]}"; do
		if [ -f "${candidate}/EnhanceQoLDamageMeter/DamageMeter.lua" ] || [ -f "${candidate}/Submodules/DamageMeter.lua" ]; then
			printf '%s\n' "${candidate}"
			return
		fi
	done

	printf '%s\n' "${ROOT_DIR}/source"
}

SOURCE_DIR="$(resolve_source_dir "$@")"

if [ -f "${SOURCE_DIR}/EnhanceQoLDamageMeter/DamageMeter.lua" ]; then
	CORE_SOURCE_DIR="${SOURCE_DIR}/EnhanceQoL"
	DAMAGE_METER_SOURCE_DIR="${SOURCE_DIR}/EnhanceQoLDamageMeter"
	DAMAGE_METER_FILE="${DAMAGE_METER_SOURCE_DIR}/DamageMeter.lua"
elif [ -f "${SOURCE_DIR}/../EnhanceQoLDamageMeter/DamageMeter.lua" ]; then
	CORE_SOURCE_DIR="${SOURCE_DIR}"
	DAMAGE_METER_SOURCE_DIR="${SOURCE_DIR}/../EnhanceQoLDamageMeter"
	DAMAGE_METER_FILE="${DAMAGE_METER_SOURCE_DIR}/DamageMeter.lua"
elif [ -f "${SOURCE_DIR}/Submodules/DamageMeter.lua" ]; then
	CORE_SOURCE_DIR="${SOURCE_DIR}"
	DAMAGE_METER_SOURCE_DIR="${SOURCE_DIR}/Submodules"
	DAMAGE_METER_FILE="${DAMAGE_METER_SOURCE_DIR}/DamageMeter.lua"
else
	echo "EnhanceQoL source directory not found: ${SOURCE_DIR}" >&2
	echo "Pass the source root explicitly: bash scripts/build.sh <out-dir> /path/to/Raizor" >&2
	exit 1
fi

copy_dir() {
	local source="$1"
	local destination="$2"
	mkdir -p "$(dirname "${destination}")"
	/usr/bin/rsync -a --delete --exclude '.DS_Store' "${source}/" "${destination}/"
}

if [ ! -d "${CORE_SOURCE_DIR}/Locales" ]; then
	echo "EnhanceQoL core source directory not found: ${CORE_SOURCE_DIR}" >&2
	exit 1
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/libs" "${OUT_DIR}/Locales" "${OUT_DIR}/Core"

cp "${TEMPLATE_DIR}/EnhancedDamageMeter.toc" "${OUT_DIR}/EnhancedDamageMeter.toc"
cp "${TEMPLATE_DIR}/Core.lua" "${OUT_DIR}/Core.lua"
cp "${TEMPLATE_DIR}/Functions.lua" "${OUT_DIR}/Functions.lua"
cp "${TEMPLATE_DIR}/Settings.lua" "${OUT_DIR}/Settings.lua"
cp "${DAMAGE_METER_FILE}" "${OUT_DIR}/DamageMeter.lua"
cp "${CORE_SOURCE_DIR}/Core/EditModeLib.lua" "${OUT_DIR}/Core/EditModeLib.lua"
cp "${CORE_SOURCE_DIR}/Core/EditMode.lua" "${OUT_DIR}/Core/EditMode.lua"
copy_dir "${TEMPLATE_DIR}/Icons" "${OUT_DIR}/Icons"

perl -0pi -e 's/_G\.EnhanceQoLDB/_G.EnhancedDamageMeterDB/g; s/category = "EnhanceQoL"/category = "Enhanced Damage Meter"/g' "${OUT_DIR}/Core/EditMode.lua"
perl -0pi -e 's/local parentAddonName = "EnhanceQoL"/local parentAddonName = "EnhancedDamageMeter"/' "${OUT_DIR}/DamageMeter.lua"

for locale in "${CORE_SOURCE_DIR}"/Locales/*.lua; do
	name="$(basename "${locale}")"
	cp "${locale}" "${OUT_DIR}/Locales/${name}"
	perl -0pi -e 's/NewLocale\("EnhanceQoL"/NewLocale("EnhancedDamageMeter"/g' "${OUT_DIR}/Locales/${name}"
done

copy_dir "${CORE_SOURCE_DIR}/libs/LibStub" "${OUT_DIR}/libs/LibStub"
copy_dir "${CORE_SOURCE_DIR}/libs/CallbackHandler-1.0" "${OUT_DIR}/libs/CallbackHandler-1.0"
copy_dir "${CORE_SOURCE_DIR}/libs/AceLocale-3.0" "${OUT_DIR}/libs/AceLocale-3.0"
copy_dir "${CORE_SOURCE_DIR}/libs/LibDeflate" "${OUT_DIR}/libs/LibDeflate"
copy_dir "${CORE_SOURCE_DIR}/libs/AceSerializer-3.0" "${OUT_DIR}/libs/AceSerializer-3.0"
copy_dir "${CORE_SOURCE_DIR}/libs/LibSharedMedia-3.0" "${OUT_DIR}/libs/LibSharedMedia-3.0"
copy_dir "${CORE_SOURCE_DIR}/libs/EnhanceQoLEditMode" "${OUT_DIR}/libs/EnhanceQoLEditMode"

printf 'Built Enhanced Damage Meter at %s\n' "${OUT_DIR}"
