#!/usr/bin/env python3
"""Prepare standalone updates from published stable Retail source releases."""
import argparse
from datetime import date
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def latest_retail(pages):
    eligible = [r for page in pages for r in page
                if not r['draft'] and not r['prerelease']
                and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', r['tag_name'])
                and any(a['name'] == f"EnhanceQoL-{r['tag_name']}.zip" for a in r['assets'])]
    return max(eligible, key=lambda r: r['published_at']) if eligible else None


def snapshot(source, commit, target, version):
    target.mkdir()
    archive = subprocess.check_output(['git', '-C', str(source), 'archive', commit])
    with tarfile.open(fileobj=io.BytesIO(archive)) as files:
        files.extractall(target, members=[p for p in files.getmembers() if p.isfile() or p.isdir()], filter='data')
    # The gate script uses the index to enumerate maintained files.
    subprocess.run(['git', 'init', '-q', str(target)], check=True)
    subprocess.run(['git', '-C', str(target), 'add', '-f', '.'], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['bash', str(target / 'scripts/prepare_packager_gates.sh'), version], check=True)


def payload(source, commit, target, version):
    snapshot(source, commit, target / 'source', version)
    output = target / 'addon'
    subprocess.run(['bash', str(ROOT / 'scripts/build.sh'), str(output), str(target / 'source')], check=True)
    return {str(p.relative_to(output)): p.read_bytes() for p in output.rglob('*') if p.is_file()}


def differences(before, after):
    return sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--releases', type=Path, required=True)
    parser.add_argument('--github-output', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads((ROOT / 'source.json').read_text())
    release = latest_retail(json.loads(args.releases.read_text()))
    if not release:
        print('No published stable Retail release found.')
        return
    version = release['tag_name']
    commit = subprocess.check_output(['git', '-C', str(args.source), 'rev-parse', '--verify',
                                      f'refs/tags/{version}^{{commit}}'], text=True).strip()
    ancestor = subprocess.run(['git', '-C', str(args.source), 'merge-base', '--is-ancestor', config['ref'], commit])
    if ancestor.returncode == 1:
        print('Published source does not contain the baseline; refusing downgrade.')
        return
    ancestor.check_returncode()
    assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', config['version'])
    if commit == config['ref'] or tuple(map(int, version.split('.'))) <= tuple(map(int, config['version'].split('.'))):
        print('No newer published source.')
        return
    with tempfile.TemporaryDirectory(prefix='edm-source-') as temp:
        temp = Path(temp)
        (temp / 'before').mkdir()
        (temp / 'after').mkdir()
        before = payload(args.source, config['ref'], temp / 'before', config['version'])
        after = payload(args.source, commit, temp / 'after', version)
        changes = differences(before, after)
    report = '# Source comparison\n\n' + ('\n'.join('- ' + p for p in changes) if changes else 'No changes in the extracted addon.') + '\n'
    (ROOT / 'source-report.md').write_text(report)
    print(report)
    if not changes:
        return
    config.update(ref=commit, version=version)
    (ROOT / 'source.json').write_text(json.dumps(config, indent=2) + '\n')
    changelog = ROOT / 'CHANGELOG.md'
    section = (f'## [{version}] - {date.today().isoformat()}\n\n### Changed\n\n'
               f'- Updated the Damage Meter and shared helpers with changes from Enhance QoL {version}.\n\n')
    text = changelog.read_text()
    assert '## Unreleased\n\n' in text
    changelog.write_text(text.replace('## Unreleased\n\n', '## Unreleased\n\n' + section, 1))
    with args.github_output.open('a') as output:
        output.write(f'changed=true\nversion={version}\n')
    print(f'Prepared {version} from {commit}; validation must pass before publication.')


if __name__ == '__main__':
    main()
