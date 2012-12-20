RUBY_VERID?=default

default: build

build: clean
	rake build

install: clean
	rake install

rpmbuild: clean
	cd rpm && make clean
	rake build
	cd rpm && make RUBY_VERID=$(RUBY_VERID)

clean:
	cd rpm && make clean
	rm -rf pkg
