MAKEFLAGS+= -rR

all: fdpass fdrecv
CXX:=g++

%: %.oo
	$(CXX) -o $@ $<

%.oo: %.cc
	$(CXX) -o $@ $< -c
