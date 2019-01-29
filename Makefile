CXX?=c++
CXXFLAGS?=-O2 -DNDEBUG
HTSLIB?=-lhts -lm
CLANGTIDY?=clang-tidy
CLANGFORMAT?=clang-format

SOFOSFLAGS=-std=c++11 $(HTSLIB)
GCOVFLAGS=-fprofile-arcs -ftest-coverage -fPIC
GPROFFLAGS=-pg

default: all

all: sofos

.PHONY: default all clean

clean:
	rm -f sofos sofos_debug unittest unittest_coverage sofos_coverage
	rm -f *.gcov *.gcda *.gcno
	rm -f coverage*.html
	rm -f clang-tidy.txt clang-format.patch

SOFOSCC=sofos.cc main.cc
UNITCC=sofos.cc unittest.cc
SOFOSHPP=sofos.hpp vcf.hpp
FORMATFILES=$(SOFOSCC) $(SOFOSHPP) test_utils.hpp

sofos: $(SOFOSCC) $(SOFOSHPP)
	$(CXX) $(CXXFLAGS) $(SOFOSFLAGS) -o $@ $(SOFOSCC)

sofos_debug: $(SOFOSCC) $(SOFOSHPP)
	$(CXX) -g -O0 $(SOFOSFLAGS) -o $@ $(SOFOSCC)

unittest: $(UNITCC) $(SOFOSHPP)
	$(CXX) -g -O0 $(SOFOSFLAGS) -DSOFOS_UNIT_TESTS -o $@ $(UNITCC)

%_cov.o: %.cc
	$(CXX) -c -g -O0 $(SOFOSFLAGS) $(GCOVFLAGS) -o $@ $<

sofos_cov.o : $(SOFOSHPP)

unit_cov.o : $(SOFOSHPP)

sofos_coverage: $(patsubst %.cc,%_cov.o,$(SOFOSCC))
	$(CXX) -g -O0 $(SOFOSFLAGS) $(GCOVFLAGS) -o $@ $^

unittest_coverage: $(patsubst %.cc,%_cov.o,$(UNITCC))
	$(CXX) -g -O0 $(SOFOSFLAGS) $(GCOVFLAGS) -DSOFOS_UNIT_TESTS -o $@ $^

test: unittest sofos_debug
	./unittest
	cd test && bash test-01.bash ../sofos_debug

coverage: sofos_coverage unittest_coverage
	rm -f *.gcda
	./unittest_coverage
	cd test && bash test-01.bash ../sofos_coverage	
	gcovr -r . -e catch.hpp -e unittest.cc --html-details -o coverage.html

test_codecov: sofos_unittest_coverage sofos_coverage
	rm -f *.gcda
	./sofos_unittest_coverage
	cd test && bash test-01.bash ../sofos_coverage
	for filename in $(SOFOSCC); do gcov -n -o . $$filename > /dev/null; done
	bash -c 'bash <(curl -s https://codecov.io/bash)'

tidy:
	$(CLANGTIDY) $(SOFOSCC) -- $(CXXFLAGS) $(SOFOSFLAGS) -Wall

format:
	$(CLANGFORMAT) -i $(SOFOSCC) $(SOFOSHPP) $(SOFOSTESTHPP)

test_format:
	@echo 'Testing for code format issues...'
	@bash -c 'diff -u <(cat $(FORMATFILES)) <($(CLANGFORMAT) $(FORMATFILES) 2>/dev/null) | tee clang-format.patch'
	@test 0 -eq `cat clang-format.patch | wc -l`

test_tidy:
	@echo 'Analyzing code for potential problems...'
	@$(CLANGTIDY) $(SOFOSCC) -- $(CXXFLAGS) $(SOFOSFLAGS) -Wall 2>/dev/null | tee clang-tidy.txt
	@test 0 -eq `cat clang-tidy.txt | wc -l`

.PHONY: coverage tidy format test test_codecov test_format cov
