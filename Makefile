
export PERL5LIB:=$(PWD)/lib$(if $(PERL5LIB),:$(PERL5LIB),)
export PATH:=$(PWD)/bin$(if $(PATH),:$(PATH),)


check:
	vi-perl bin/dry-run

distcheck:check
