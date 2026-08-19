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
    'binutils-bootstrap',
    'filesystem',
    'glibc',
    'glibc-bootstrap',
    'gcc-bootstrap',
    'gmp-bootstrap',
    'libgcc',
    'linux-api-headers',
    'mpc-bootstrap',
    'mpfr-bootstrap',
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
for construction_only in (
        'binutils-bootstrap', 'gcc-bootstrap', 'linux-api-headers',
        'glibc-bootstrap',
        'gmp-bootstrap', 'mpc-bootstrap', 'mpfr-bootstrap'):
    if construction_only in profile_members:
        fail(f'construction-only package {construction_only} became deployable profile state')
if re.search(r'^  construction:', profiles, re.MULTILINE):
    fail('partial seed-retirement substrate was prematurely admitted as @construction')

for misplaced in ('acl', 'attr', 'lz4', 'xz', 'zlib', 'zstd'):
    if (ROOT / misplaced / 'recipe.yml').exists():
        fail(f'unproven non-foundation recipe {misplaced} returned below the seed boundary')


def scope_packages(text: str, scope: str) -> list[str]:
    match = re.search(
        rf'^  {scope}:\n((?:    - package: [^\s]+\n)+)', text, re.MULTILINE)
    if match is None:
        return []
    return re.findall(
        r'^    - package: ([^\s]+)$', match.group(1), re.MULTILINE)


bootstrap_authority = {
    'gmp-bootstrap': {
        'version': '6.3.0',
        'sha256': 'a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898',
        'build': [],
        'check': [],
        'run': ['glibc'],
    },
    'mpfr-bootstrap': {
        'version': '4.2.2',
        'sha256': 'b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01',
        'build': ['gmp-bootstrap'],
        'check': ['gmp-bootstrap'],
        'run': ['glibc', 'gmp-bootstrap'],
    },
    'mpc-bootstrap': {
        'version': '1.4.1',
        'sha256': '91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931',
        'build': ['gmp-bootstrap', 'mpfr-bootstrap'],
        'check': ['gmp-bootstrap', 'mpfr-bootstrap'],
        'run': ['glibc', 'gmp-bootstrap', 'mpfr-bootstrap'],
    },
    'binutils-bootstrap': {
        'version': '2.44',
        'sha256': 'ce2017e059d63e67ddb9240e9d4ec49c2893605035cd60e92ad53177f4377237',
        'build': [],
        'check': [],
        'run': ['glibc'],
    },
    'gcc-bootstrap': {
        'version': '16.1.0',
        'sha256': '50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79',
        'build': ['filesystem', 'glibc', 'linux-api-headers', 'gmp-bootstrap', 'mpfr-bootstrap', 'mpc-bootstrap'],
        'check': ['filesystem', 'glibc', 'linux-api-headers', 'binutils-bootstrap'],
        'run': ['filesystem', 'glibc', 'linux-api-headers', 'binutils-bootstrap'],
    },
}
for name, authority in bootstrap_authority.items():
    text = (ROOT / name / 'recipe.yml').read_text(encoding='utf-8')
    version = re.search(r'^  version: ([^\s]+)$', text, re.MULTILINE)
    if version is None or version.group(1) != authority['version']:
        fail(f'{name} version differs from admitted construction coordinate')
    if f"    sha256: {authority['sha256']}" not in text:
        fail(f'{name} source SHA-256 differs from admitted construction source')
    for scope in ('build', 'check', 'run'):
        actual = scope_packages(text, scope)
        if actual != authority[scope]:
            fail(
                f'{name} {scope} authority differs: expected ' +
                ', '.join(authority[scope]) + '; got ' + ', '.join(actual))

binutils_bootstrap = (ROOT / 'binutils-bootstrap' / 'recipe.yml').read_text(
    encoding='utf-8')
for fragment in (
        '--disable-gprofng', '--disable-jansson', '--disable-shared',
        '--without-debuginfod', '--without-system-zlib', '--without-zstd',
        'ar as ld nm objcopy objdump ranlib readelf strip',
        'optional external support-library dependency'):
    if fragment not in binutils_bootstrap:
        fail(f'binutils bootstrap boundary omits {fragment!r}')
gcc_bootstrap = (ROOT / 'gcc-bootstrap' / 'recipe.yml').read_text(
    encoding='utf-8')
for fragment in (
        '  release: 4',
        '--with-sysroot=/', '--with-build-sysroot="$sysroot"',
        '--with-native-system-header-dir=/usr/include',
        '--with-as=/usr/bin/as', '--with-ld=/usr/bin/ld',
        '--disable-bootstrap', '--disable-fixincludes', '--disable-lto',
        '--disable-multilib', '--disable-shared', '--enable-languages=c,c++',
        'all-target-libgcc', 'all-target-libstdc++-v3',
        'shared compiler runtime escaped into bootstrap compiler payload',
        'installed compiler search authority retains bootstrap coordinates',
        'installed compiler does not use the execution root as sysroot',
        'filesystem /lib64 authority is absent',
        'target sysroot authority collision',
        'composed target sysroot lost /lib64 topology',
        'composed target sysroot cannot resolve the glibc loader',
        'composed target sysroot lost Linux UAPI authority',
        'check sysroot authority collision',
        'composed check sysroot lost /lib64 topology',
        'composed check sysroot cannot resolve the glibc loader',
        'normalize_lib_alias usr/lib64',
        'final payload retains merged-/usr descendants below $alias',
        'driver entry is absent',
        'execution loader does not resolve through admitted target root',
        'static libstdc++ construction runtime is not canonical',
        'composed check target root lacks sealed static libstdc++ authority',
        'sealed compiler resolves static libstdc++ outside admitted target root',
        'sealed C compiler rejected admitted target sysroot/binutils authority',
        'sealed C++ compiler rejected admitted target sysroot/binutils authority'):
    if fragment not in gcc_bootstrap:
        fail(f'gcc bootstrap boundary omits {fragment!r}')
for forbidden in (
        'download_prerequisites', '--with-system-zlib',
        'ln -s g++ "$PKG_DESTDIR/usr/bin/c++"'):
    if forbidden in gcc_bootstrap:
        fail(f'gcc bootstrap imports ambient/upstream convenience authority: {forbidden!r}')

for name, soname in (
        ('gmp-bootstrap', 'libgmp.so.10'),
        ('mpfr-bootstrap', 'libmpfr.so.6'),
        ('mpc-bootstrap', 'libmpc.so.3')):
    text = (ROOT / name / 'recipe.yml').read_text(encoding='utf-8')
    for fragment in (
            soname, 'static construction library is absent',
            'carries a construction search path'):
        if fragment not in text:
            fail(f'{name} does not defend construction library authority: {fragment!r}')

glibc = (ROOT / 'glibc' / 'recipe.yml').read_text(encoding='utf-8')
required_glibc_fragments = (
    '  release: 6',
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
run_match = re.search(
    r'^  run:\n((?:    - package: [^\s]+\n)+)', glibc, re.MULTILINE)
if run_match is None:
    fail('glibc omits runtime authority')
glibc_run = re.findall(r'^    - package: ([^\s]+)$', run_match.group(1), re.MULTILINE)
if glibc_run != ['filesystem', 'libgcc']:
    fail(
        'glibc runtime authority must be exactly filesystem, libgcc; got ' +
        ', '.join(glibc_run))
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
