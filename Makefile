SHELL := bash
.ONESHELL:
.SHELLFLAGS := -euc
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

SCRIPTS := $(wildcard .github/workflows/*.sh)

all: $(SCRIPTS)
.PHONY: all

$(SCRIPTS):
	shfmt -w $@
	shellcheck $@
.PHONY: $(SCRIPTS)
