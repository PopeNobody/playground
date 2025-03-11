
export PERL5LIB:=$(PWD)/lib$(if $(PERL5LIB),:$(PERL5LIB),)
export PATH:=$(PWD)/bin$(if $(PATH),:$(PATH),)

all:
	bin/playground-server

test:
	bin/run-all-tests.pl

.PHONY: test check distcheck test-gpt dry-run

check:

distcheck:check


test-gpt:

dry-run:
	vi-perl bin/dry-run
