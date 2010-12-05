PO4AFLAGS = -k 100

all: translate

include Makefile.common

# Patch level, may be empty
P = 

#  Download tarball
get-orig-source: man-pages-$(V).tar.bz2
man-pages-$(V).tar.bz2:
	wget http://www.kernel.org/pub/linux/docs/man-pages/man-pages-$(V).tar.bz2

#  Unpack sources
unpack: stamp-unpack
stamp-unpack:
	-rm -rf man-pages-$(V) man-pages
	$(MAKE) man-pages-$(V).tar.bz2
	tar jxf man-pages-$(V).tar.bz2
	#  Remove version from top-level directory so that V variable
	#  does not have to be used in targets below
	mv man-pages-$(V) man-pages
	#  Remove stamp-setup to force re-run of 'setup' target
	-rm -f stamp-setup
	touch $@

#  Prepare sources for being used by po4a.
#  This target is called once after manual pages are unpacked.
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
	set -e; cd man-pages; for f in man?/*.?; do \
	  if sed -e '1,3!d' $$f | grep -q '^\.so'; \
	  then \
	    grep '^\.so' $$f | sed -e '1!d' -e 's/^\.so //' -e "s,$$, $$f," >> ../build/C/link; \
	  else \
	    cp $$f ../build/C/$$f; \
	  fi; \
	done
	LC_ALL=C sort build/C/link > temp && mv temp build/C/link
	#  Remove empty directories, if any
	-rmdir build/C/man* 2>/dev/null
	#  armscii-8 encoding is missing in Perl, convert to UTF-8 to make po4a work
	iconv -f armscii-8 -t UTF-8 build/C/man7/armscii-8.7 | sed -e '1s/coding: ARMSCII-8/coding: UTF-8/' > temp && mv temp build/C/man7/armscii-8.7
	#  Apply patches to fix groff syntax errors which  prevent po4a processing
	if test -f po4a-fixes.patch; \
	then \
	  cd build/C && patch -p1 < $(CURDIR)/po4a-fixes.patch; \
	fi
	touch $@

process-man7: translate-man7
	for f in build/[!C]*/man7/*.7; do sed -i -e '1s/coding: *[^ ]*/coding: UTF-8/' $$f; done

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

.PHONY: unpack setup
