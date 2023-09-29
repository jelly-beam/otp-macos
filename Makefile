SHELL := bash
.ONESHELL:
.SHELLFLAGS := -euc
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

SCRIPTS := $(wildcard .github/workflows/*.sh)
WORKFLOWS := $(wildcard .github/workflows/*.yml)

SHELLCHECK_OPTS="-o all"

all: $(SCRIPTS) $(WORKFLOWS)
.PHONY: all

$(SCRIPTS):
	shfmt -i 4 -w $@
	SHELLCHECK_OPTS=$(SHELLCHECK_OPTS) shellcheck $@
.PHONY: $(SCRIPTS)

$(WORKFLOWS):
	SHELLCHECK_OPTS=$(SHELLCHECK_OPTS) actionlint $@
.PHONY: $(WORKFLOWS)
