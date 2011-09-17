# Upstream version
V = 3.32

# Patch level, may be empty
P =

# These variables may be defined by derivatives
PO4AFLAGS ?= -k 100
LANGS ?=
WORK_DIR ?= .
PO4A_SUBDIRS ?= $(EXTRA_PO4A_SUBDIRS) \
	aio \
	boot \
	charset \
	complex \
	db \
	dirent \
	epoll \
	error \
	fcntl \
	filesystem \
	iconv \
	inotify \
	intro \
	keyutils \
	ld \
	linux_module \
	locale \
	man2 \
	man3 \
	man5 \
	man7 \
	math \
	memory \
	mqueue \
	net \
	netlink \
	numa \
	process \
	pthread \
	pwdgrp \
	regexp \
	rpc \
	sched \
	search \
	semaphore \
	signal \
	socket \
	special \
	stdio \
	stdlib \
	string \
	time \
	tty \
	unistd \
	utmp \
	wchar \
	wctype

all: translate

#  Download tarball
get-orig-source: man-pages-$(V).tar.bz2
man-pages-$(V).tar.bz2:
	wget http://www.kernel.org/pub/linux/docs/man-pages/man-pages-$(V).tar.bz2

#  Unpack sources
unpack: stamp-unpack
stamp-unpack:
	-rm -rf man-pages-$(V) man-pages
	$(MAKE) man-pages-$(V).tar.bz2
	tar jxf man-pages-$(V).tar.bz2
	#  Remove version from top-level directory so that V variable
	#  does not have to be used in targets below
	mv man-pages-$(V) man-pages
	#  Remove stamp-setup to force re-run of 'setup' target
	-rm -f stamp-setup
	touch $@

#  Prepare sources for being used by po4a.
#  This target is called once after manual pages are unpacked.
setup: stamp-setup
stamp-setup: stamp-unpack
	-rm -rf build
	mkdir -p build/C
	for i in $$(seq 8); do mkdir build/C/man$$i; done
	#  Some manual pages are only aliases, they contain a single line
	#      .so target_man_page
	#  Create a file named 'link', its format is:
	#      target_man_page src_man_page
	#  This file is used after pages are translated to create aliases
	#  of translated manual pages.
	set -e; for f in man-pages/man?/*.?; do \
	  if sed -e '1,3!d' $$f | grep -q '^\.so'; \
	  then \
	    grep '^\.so' $$f | sed -e '1!d' -e 's/^\.so //' -e "s,$$, $${f#man-pages/}," >> build/C/link; \
	  else \
	    cp $$f build/C/$${f#man-pages/}; \
	  fi; \
	done
	LC_ALL=C sort build/C/link > temp && mv temp build/C/link
	#  Remove empty directories, if any
	-rmdir build/C/man* 2>/dev/null
	#  armscii-8 encoding is missing in Perl, convert to UTF-8 to make po4a work
	iconv -f armscii-8 -t UTF-8 build/C/man7/armscii-8.7 | sed -e '1s/coding: ARMSCII-8/coding: UTF-8/' > temp && mv temp build/C/man7/armscii-8.7
	#  Apply patches to fix groff syntax errors which  prevent po4a processing
	if test -f po4a-fixes.patch; \
	then \
	  cd build/C && patch -p1 < $(CURDIR)/po4a-fixes.patch; \
	fi
	touch $@

clean::
	-rm -f stamp-* temp link
	-rm -rf man-pages build
	-rm -rf po4a/*/po
	#  Do not delete tarball in this target
	#rm -f man-pages-*.tar.bz2

reallyclean:: clean
	rm -f man-pages-*.tar.bz2

release: clean
	-rm -rf perkamon*
	mkdir perkamon
	cp man-pages-$(V).tar.bz2 perkamon/
	cp Makefile* README perkamon/
	-cp *.patch perkamon/
	tar cf - --exclude=.svn po4a | tar xf - -C perkamon
	ln -s perkamon perkamon-$(V)$(P)
	tar jchf perkamon-$(V)$(P).tar.bz2 --numeric-owner perkamon-$(V)$(P)

translate: $(patsubst %, process-%, $(PO4A_SUBDIRS))

translate-%: setup
	po4a $(PO4AFLAGS) --variable langs='$(LANGS)' --previous --srcdir $(WORK_DIR) --destdir $(WORK_DIR) po4a/$*/$*.cfg

process-%: translate-%
	@:

process-man7: translate-man7
	for f in $(WORK_DIR)/build/[!C]*/man7/*.7; \
	do \
	  test -e $$f || continue; \
	  sed -i -e '1s/coding: *[^ ]*/coding: UTF-8/' $$f; \
	done

cfg-%: FORCE
	po4a $(PO4AFLAGS) --variable langs='$(LANGS)' --previous --srcdir $(WORK_DIR) --destdir $(WORK_DIR) po4a/$*/$*.cfg

stats:: $(patsubst %, stats-%, $(LANGS))
stats-%:
	@set -e; for subs in $(PO4A_SUBDIRS); do \
	  echo -n "$$subs: "; \
	  msgfmt --statistics -o /dev/null $(WORK_DIR)/po4a/$$subs/po/$*.po; \
	done
	@set -e; for subs in $(PO4A_SUBDIRS); do \
	  LC_ALL=C msgfmt --statistics -o /dev/null $(WORK_DIR)/po4a/$$subs/po/$*.po; \
	done 2>&1 | perl -e '$$f=$$t=$$u; while (<>) {if (/([0-9]*) translated/) {$$t+=$$1;} if (/([0-9]*) untranslated/) {$$u+=$$1;} if (/([0-9]*) fuzzy/) {$$f+=$$1;}} printf "%d translated, %d fuzzy, %d untranslated ==> %.2f%%\n", $$t, $$f, $$u, (100*$$t/($$t+$$f+$$u))'

disable-removed:
	@set -e; for f in po4a/*/*.cfg; do \
	  for i in $$(grep '^\[type: man\]' $$f | sed -e 's,.* build/C/,build/C/,' -e 's, \\,,'); do \
	    test -f $(WORK_DIR)/$$i && continue; \
	    echo "Missing file $$i disabled in $$f"; \
	    sed -i -e '/\[type: man\] '"$$(echo $$i | sed -e 's,/,\\/,g')"'/,/[^\\]$$/s/^/#/' $$f; \
	  done; \
	done

#  Run this target after a new upstream release to see if pages have been added.
#  Copy and paste output in po4a .cfg files
print-new-files:
	@set -e; for f in $(WORK_DIR)/build/C/man?/*.?; do \
	  l="$${f#$(WORK_DIR)/build/C/}"; \
	  grep -q "^\\[type: man\\] build/C/$$l" po4a/*/*.cfg && continue; \
	  o=$$(echo $$l | sed -e 's,/,/local-,'); \
	  printf '[type: man] %s \\\n\t%s \\\n' build/C/$$l "\$$lang:build/\$$lang/$$l"; \
	  if grep -q hlm $$f; then printf '\topt:"-o untranslated=hlm" \\\n'; fi; \
	  printf '\tadd_$$lang:?@po4a/add_$$lang/lists/local-pre.list \\\n'; \
	  printf '\tadd_$$lang:?@po4a/add_$$lang/lists/'$$o'.list \\\n'; \
	  printf '\tadd_$$lang:?po4a/add_$$lang/perkamon \\\n'; \
	  printf '\tadd_$$lang:?@po4a/add_$$lang/lists/'$$l'.list \\\n'; \
	  printf '\tadd_$$lang:?po4a/add_$$lang/addendum \\\n'; \
	  printf '\tadd_$$lang:?@po4a/add_$$lang/lists/local-post.list\n'; \
	  echo; \
	done

.PHONY: unpack setup translate stats disable-removed print-new-files clean release FORCE
