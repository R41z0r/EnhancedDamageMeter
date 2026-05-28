#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


SECTION_RE = re.compile(r"^##\s+\[?([^\]\s]+)\]?")
HEADING_RE = re.compile(r"^###\s+(.+?)\s*$")
DM_BULLET_RE = re.compile(r"^-\s+(Damage Meter|Enhanced Damage Meter)(?:\s*/\s*([^:]+))?:\s*(.+?)\s*$")


def read_version_section(lines, version):
    start = None
    for index, line in enumerate(lines):
        match = SECTION_RE.match(line)
        if match and match.group(1) == version:
            start = index
            break

    if start is None:
        return []

    end = len(lines)
    for index in range(start + 1, len(lines)):
        if SECTION_RE.match(lines[index]):
            end = index
            break

    return lines[start:end]


def extract_entries(lines):
    grouped = []
    current_heading = None
    current_entries = []

    def flush():
        nonlocal current_heading, current_entries
        if current_entries:
            grouped.append((current_heading, current_entries))
        current_heading = None
        current_entries = []

    for line in lines:
        heading = HEADING_RE.match(line)
        if heading:
            flush()
            current_heading = heading.group(1)
            continue

        bullet = DM_BULLET_RE.match(line)
        if not bullet:
            continue

        area = bullet.group(2)
        text = bullet.group(3)
        if area:
            current_entries.append(f"- {area}: {text}")
        else:
            current_entries.append(f"- {text}")

    flush()
    return grouped


def write_changelog(output_path, version, grouped):
    lines = ["# Enhanced Damage Meter", "", f"## [{version}]", ""]
    if grouped:
        for heading, entries in grouped:
            if heading:
                lines.extend([f"### {heading}", ""])
            lines.extend(entries)
            lines.append("")
    else:
        lines.extend([f"- Updated from EnhanceQoL {version}.", ""])

    output_path.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Extract Damage Meter changelog entries from EnhanceQoL.")
    parser.add_argument("source")
    parser.add_argument("version")
    parser.add_argument("output")
    args = parser.parse_args()

    source_path = Path(args.source)
    output_path = Path(args.output)
    lines = source_path.read_text(encoding="utf-8").splitlines()
    section = read_version_section(lines, args.version)
    grouped = extract_entries(section)
    write_changelog(output_path, args.version, grouped)


if __name__ == "__main__":
    main()
