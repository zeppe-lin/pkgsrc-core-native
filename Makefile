# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

.PHONY: all check check-dependencies check-filesystem

all: check

check: check-filesystem check-dependencies

check-filesystem:
	@tests/contracts/check_filesystem_boundary.sh

check-dependencies:
	@tests/contracts/check_dependency_authority.sh
