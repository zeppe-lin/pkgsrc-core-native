# pkgsrc-core

`pkgsrc-core` is the native core package-source collection for Zeppe-Lin 2.0.
It contains the package declarations and package-local source material required
to construct the foundational Zeppe-Lin system.

Each visible package directory is one package entry and contains a mandatory
`recipe.yml`. The collection is consumed as source authority by the native
Zeppe-Lin catalog and transaction toolchain; directory enumeration is not a
package-selection policy.

Recipes in this collection may require packages from this collection. Higher
collections may require `pkgsrc-core`; core recipes must not depend on higher
collection authority.

The collection metadata and Zeppe-Lin-authored recipe files are licensed under
GPL-3.0-or-later. `package.licenses` records the license of the software
specified by a recipe. Package-local material derived from third-party sources
retains its own copyright and license terms.
