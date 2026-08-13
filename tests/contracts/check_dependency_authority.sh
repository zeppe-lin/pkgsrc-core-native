#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

fail()
{
    printf '%s\n' "pkgsrc-core-native: dependency authority contract: $*" >&2
    exit 1
}

require_text()
{
    file=$1
    text=$2
    grep -F -- "$text" "$file" >/dev/null ||
        fail "$file lacks required authority text: $text"
}

build_packages()
{
    awk '
        /^requirements:$/ { in_requirements = 1; next }
        in_requirements && /^[^ ]/ { exit }
        in_requirements && /^  build:$/ { in_build = 1; next }
        in_build && /^  [a-zA-Z_-]+:/ { in_build = 0 }
        in_build && /^    - package: / {
            sub(/^    - package: /, "")
            print
        }
    ' "$1"
}

# Every direct package build requirement must be consumed through the native
# package-input namespace. A declared build edge may not merely bless a tool or
# library that the recipe actually obtains from some other authority.
for recipe in "$root"/*/recipe.yml; do
    for package in $(build_packages "$recipe"); do
        require_text "$recipe" "PKG_BUILD_INPUT_ROOT/$package"
    done
done

# zstd deliberately enables these optional formats. The same three package
# authorities are therefore required both while constructing the CLI and while
# running the installed CLI.
for package in lz4 xz zlib; do
    count=$(grep -F -- "- package: $package" "$root/zstd/recipe.yml" | wc -l | tr -d ' ')
    [ "$count" = 2 ] ||
        fail "zstd must retain exactly one build and one run edge for $package"
done

# Root-view tools are not package inputs in the current bootstrap model. Refuse
# ceremonial dependency edges that would claim otherwise while recipes still
# execute those tools as bare commands from the provisioned root view.
for package in bash binutils cmake coreutils gcc make ninja pkg-config sed tar; do
    if grep -R -F -- "- package: $package" "$root"/*/recipe.yml >/dev/null 2>&1; then
        fail "root-view tool is declared as a package requirement without package-input composition: $package"
    fi
done

# Namespace bootstrap is composition policy, not a universal runtime edge.
# A future genuine consumer of filesystem-owned runtime semantics may change
# this deliberately together with this contract.
if grep -R -F -- '- package: filesystem' "$root"/*/recipe.yml >/dev/null 2>&1; then
    fail "filesystem is being used as a generic package dependency"
fi

# Keep the architectural statement repository-owned rather than leaving the
# distinction in review folklore.
require_text "$root/DESIGN.md" 'Recipe requirements are package relations.'
require_text "$root/DESIGN.md" 'Run requirements describe target runtime closure.'
require_text "$root/DESIGN.md" 'initial native core is bootstrapped with an explicitly provisioned'
require_text "$root/DESIGN.md" 'packages are not required to name `filesystem` merely because'

printf '%s\n' 'dependency authority contract: ok'
