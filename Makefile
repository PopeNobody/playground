
export PERL5LIB:=$(PWD)/lib$(if $(PERL5LIB),:$(PERL5LIB),)
export PATH:=$(PWD)/bin$(if $(PATH),:$(PATH),)


check:
	echo perl test-gpt.pl
	vi-perl dry-run.pl

distcheck:check
