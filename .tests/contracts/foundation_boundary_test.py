#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Alexandr Savca
# SPDX-License-Identifier: GPL-3.0-or-later

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    print(f'pkgsrc-foundation:foundation-boundary: {message}', file=sys.stderr)
    raise SystemExit(1)


expected_recipes = {
    'filesystem',
    'glibc',
    'glibc-bootstrap',
    'libgcc',
    'linux-api-headers',
}
visible_dirs = {
    path.name
    for path in ROOT.iterdir()
    if path.is_dir() and not path.name.startswith('.')
}
if visible_dirs != expected_recipes:
    fail(
        'visible collection namespace differs: expected ' +
        ', '.join(sorted(expected_recipes)) +
        '; got ' + ', '.join(sorted(visible_dirs)))

recipe_dirs = {
    path.parent.name
    for path in ROOT.glob('*/recipe.yml')
}
if recipe_dirs != expected_recipes:
    fail(
        'recipe ownership differs: expected ' +
        ', '.join(sorted(expected_recipes)) +
        '; got ' + ', '.join(sorted(recipe_dirs)))

for name in sorted(expected_recipes):
    text = (ROOT / name / 'recipe.yml').read_text(encoding='utf-8')
    match = re.search(r'^  name: ([^\s]+)$', text, re.MULTILINE)
    if match is None or match.group(1) != name:
        fail(f'{name}/recipe.yml does not seal package name {name}')

profiles = (ROOT / 'profiles.yml').read_text(encoding='utf-8')
profile_members = re.findall(r'^\s+- package: ([^\s]+)$', profiles, re.MULTILINE)
if profile_members != ['filesystem', 'glibc', 'libgcc']:
    fail('@foundation must contain exactly filesystem, glibc, libgcc')
for construction_only in ('linux-api-headers', 'glibc-bootstrap'):
    if construction_only in profile_members:
        fail(f'construction-only package {construction_only} became deployable profile state')

for misplaced in ('acl', 'attr', 'lz4', 'xz', 'zlib', 'zstd'):
    if (ROOT / misplaced / 'recipe.yml').exists():
        fail(f'unproven non-foundation recipe {misplaced} returned below the seed boundary')

glibc = (ROOT / 'glibc' / 'recipe.yml').read_text(encoding='utf-8')
required_glibc_fragments = (
    '  release: 5',
    'C.UTF-8',
    '"$PKG_DESTDIR/usr/bin/localedef"',
    '--prefix="$PKG_DESTDIR"',
    '-i ../glibc-2.44/localedata/locales/C',
    '-f ../glibc-2.44/localedata/charmaps/UTF-8',
    "--list-archive | grep -Fx 'C.utf8' >/dev/null",
    'rootsbindir=/usr/sbin',
    'LINGUAS=C',
    'locale.alias',
    'unexpected message-catalog payload',
    'find "$locale_dir" -mindepth 1',
    '! -path "$locale_dir/locale.alias"',
    'normalize_lib_alias lib64',
    'normalize_lib_alias usr/lib64',
    'final payload retains merged-/usr descendants below $alias',
)
for fragment in required_glibc_fragments:
    if fragment not in glibc:
        fail(f'glibc does not close C.UTF-8 authority: missing {fragment!r}')
if 'localedef failed (non-fatal)' in glibc or 'localedef ||' in glibc:
    fail('glibc C.UTF-8 creation became best-effort')
if 'rmdir "$PKG_DESTDIR/usr/share/locale"' in glibc:
    fail('glibc deletes its locale alias authority while suppressing translations')

readme = (ROOT / 'README.md').read_text(encoding='utf-8')
readme_words = ' '.join(readme.split())
for fragment in (
        'Seed-retirement boundary',
        'historical seed root is inaccessible',
        'collection membership is not installation membership'):
    if fragment not in readme_words:
        fail(f'README omits foundation authority invariant {fragment!r}')

print('pkgsrc-foundation:foundation-boundary: PASS')
