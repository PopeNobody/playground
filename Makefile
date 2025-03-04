
export PERL5LIB:=$(PWD)/lib$(if $(PERL5LIB),:$(PERL5LIB),)
export PATH:=$(PWD)/bin$(if $(PATH),:$(PATH),)


check:
#	perl test-gpt.pl

distcheck:check
