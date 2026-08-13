# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

.PHONY: all check check-filesystem

all: check

check: check-filesystem

check-filesystem:
	@tests/contracts/check_filesystem_boundary.sh
