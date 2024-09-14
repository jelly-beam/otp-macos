SHELL := bash
.ONESHELL:
.SHELLFLAGS := -euc
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

SH := $(wildcard .github/workflows/*.sh)
YML_WORKFLOWS := $(wildcard .github/workflows/*.yml)
YML_CONFIGS := $(wildcard .*.yml)
MD := $(wildcard .github/ISSUE_TEMPLATE/*.md .github/*.md *.md LICENSE)
ACTIONLINT := actionlint

SHELLCHECK_OPTS="-o all"

all: $(SH) $(YML_WORKFLOWS) $(YML_CONFIGS) $(MD) $(ACTIONLINT)
.PHONY: all

$(SH):
	shfmt -i 4 -w $@
	SHELLCHECK_OPTS=$(SHELLCHECK_OPTS) shellcheck $@
.PHONY: $(SH)

$(YML_WORKFLOWS):
	yamllint -s -c .yamllint.yml $@
	SHELLCHECK_OPTS=$(SHELLCHECK_OPTS) actionlint $@
.PHONY: $(YML_WORKFLOWS)

$(YML_CONFIGS):
	yamllint -s -c .yamllint.yml $@
.PHONY: $(YML_CONFIGS)

$(MD):
	markdownlint -c .markdownlint.yml $@
.PHONY: $(MD)

$(ACTIONLINT):
	actionlint
.PHONY: $(ACTIONLINT)
