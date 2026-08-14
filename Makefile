# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

.PHONY: all check check-dependencies check-filesystem check-glibc check-glibc-bootstrap check-libgcc check-linux-api-headers

all: check

check: check-filesystem check-dependencies check-linux-api-headers check-glibc check-glibc-bootstrap check-libgcc

check-filesystem:
	@tests/contracts/check_filesystem_boundary.sh

check-dependencies:
	@tests/contracts/check_dependency_authority.sh

check-linux-api-headers:
	@tests/contracts/check_linux_api_headers.sh

check-glibc:
	@tests/contracts/check_glibc_boundary.sh

check-glibc-bootstrap:
	@tests/contracts/check_glibc_bootstrap_boundary.sh

check-libgcc:
	@tests/contracts/check_libgcc_boundary.sh
