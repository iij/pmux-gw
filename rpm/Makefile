
RUBY_VERID?=default
TOP_DIR:=$(shell pwd)

default: rpmbuild

rpmbuild: clean
	mkdir -p SOURCES
	mkdir -p RPMS
	mkdir -p SRPMS
	mkdir -p BUILD
	mkdir -p BUILDROOT
	mkdir -p SPECS
	mkdir -p INSTALL
	cp ../pkg/pmux-gw-*.gem SOURCES/
	rpmbuild -ba --define "_topdir $(TOP_DIR)" --define "_ruby_verid \"$(RUBY_VERID)\"" pmux-gw.spec

clean:
	rm -rf SOURCES RPMS SRPMS BUILD BUILDROOT SPECS INSTALL
