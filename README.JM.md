About this repository
=====================

This is a forked version of perkamon project [1] repository [2].
It is forked to manage Linux JM (Japanese manual) project [3],
but the repository are frequently synced with the upsream.

[1] http://perkamon.alioth.debian.org/
[2] http://gitorious.org/perkamon/man-pages
[3] http://linuxjm.sourceforge.jp/

How to import changes in the upstream
=====================================

How to merge upstream into this repository:

    $ git remote add upstream git://gitorious.org/perkamon/man-pages.git
    $ git merge upstream/master

Using git-submodule
===================

Migrate to git version
----------------------

First add man-pages.git as a submodule:

    $ git submodule add git://git.kernel.org/pub/scm/docs/man-pages/man-pages.git man-pages-git

Next update Makefile. The version number should be set to the next version.:

    V = 3.78-git

Sample commit message:

    $ git commit -m 'Sync to git 80a7408 (upcoming 3.78)'

Move back to release
--------------------

Remove the submodule entry:

    $ git submodule deinit man-pages-git
    $ rm .gitmodules
    $ rm -rf man-pages-git

Then update Makefile to point the released version:

    V = 3.78

Sample commit message:

    $ git commit -m 'Remove man-pages-git submodule and set V to 3.78'
