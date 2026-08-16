# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

BOOTSTRAP_WORK ?= $(CURDIR)/.bootstrap
BOOTSTRAP_BUILD_ROOT ?=
BOOTSTRAP_SEED_SHA256 ?=
BOOTSTRAP_INTERPRETER ?=
BOOTSTRAP_TOOLCHAIN_PREFIX ?= $(NEW_TOOLCHAIN_PREFIX)
BOOTSTRAP_PRIVILEGE ?=
BOOTSTRAP_MAX_STEPS ?= 8
BOOTSTRAP_JOBS ?=
BOOTSTRAP_SOURCE_DATE_EPOCH ?=
PKGCTL ?= pkgctl
PKGSTATE_INIT ?= pkgstate-init

export BOOTSTRAP_WORK BOOTSTRAP_BUILD_ROOT BOOTSTRAP_SEED_SHA256
export BOOTSTRAP_INTERPRETER BOOTSTRAP_TOOLCHAIN_PREFIX BOOTSTRAP_PRIVILEGE BOOTSTRAP_MAX_STEPS
export BOOTSTRAP_JOBS BOOTSTRAP_SOURCE_DATE_EPOCH PKGCTL PKGSTATE_INIT

.PHONY: all check check-bootstrap-harness check-bootstrap-init check-bootstrap-seed-probe check-dependencies check-filesystem check-glibc check-glibc-bootstrap check-libgcc check-linux-api-headers check-runtime-cohort check-source-realization
.PHONY: bootstrap-init bootstrap-qualify bootstrap bootstrap-resume bootstrap-check bootstrap-clean

all: check

check: check-filesystem check-dependencies check-source-realization check-linux-api-headers check-glibc check-glibc-bootstrap check-libgcc check-runtime-cohort check-bootstrap-harness check-bootstrap-seed-probe check-bootstrap-init

check-filesystem:
	@tests/contracts/check_filesystem_boundary.sh

check-dependencies:
	@tests/contracts/check_dependency_authority.sh

check-source-realization:
	@tests/contracts/check_source_realization.sh

check-linux-api-headers:
	@tests/contracts/check_linux_api_headers.sh

check-glibc:
	@tests/contracts/check_glibc_boundary.sh

check-glibc-bootstrap:
	@tests/contracts/check_glibc_bootstrap_boundary.sh

check-libgcc:
	@tests/contracts/check_libgcc_boundary.sh

check-runtime-cohort:
	@tests/contracts/check_runtime_cohort_boundary.sh

check-bootstrap-harness:
	@tests/contracts/check_bootstrap_harness.sh

check-bootstrap-seed-probe:
	@tests/contracts/check_bootstrap_seed_probe.sh

check-bootstrap-init:
	@tests/integration/bootstrap_init_test.sh

bootstrap-init:
	@tools/bootstrap_campaign.sh init

bootstrap-qualify:
	@tools/bootstrap_campaign.sh qualify

bootstrap:
	@tools/bootstrap_campaign.sh start

bootstrap-resume:
	@tools/bootstrap_campaign.sh resume

bootstrap-check:
	@tools/bootstrap_campaign.sh check

bootstrap-clean:
	@tools/bootstrap_campaign.sh clean
