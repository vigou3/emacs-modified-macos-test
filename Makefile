# Makefile for GNU Emacs.app Modified

# Copyright (C) 2011 Vincent Goulet

# Author: Vincent Goulet

# This file is part of GNU Emacs.app Modified
# http://vgoulet.act.ulaval.ca/emacs

# This Makefile will create a disk image to distribute a single
# architecture or universal version of GNU Emacs. For a universal
# build, two separate builds (i386 and ppc) are needed.
#
# The code of this Makefile is based on a file created by Remko
# Troncon (http://el-tramo.be/about).

# Set most variables in Makeconf
include ./Makeconf

TMPDIR=${CURDIR}/tmpdir
TMPDMG=${CURDIR}/tmpdmg.dmg
DMGFILE=Emacs-${EMACSVERSION}-universal-${ARCH}.dmg
EMACSDIR=${TMPDIR}/Emacs.app

PREFIX=${EMACSDIR}/Contents
EMACS=${PREFIX}/MacOS/Emacs
EMACSBATCH = $(EMACS) -batch -no-site-file -no-init-file
RSYNC=rsync -n -avu --exclude="*~"

# To override ESS variables defined in Makeconf
DESTDIR=${PREFIX}/Resources
SITELISP=${DESTDIR}/site-lisp
#LISPDIR=${DESTDIR}/site-lisp
ETCDIR=${DESTDIR}/etc
DOCDIR=${DESTDIR}/doc
INFODIR=${DESTDIR}/info

ESS=ess-${ESSVERSION}
AUCTEX=auctex-${AUCTEXVERSION}
ORG=org-${ORGVERSION}

all : emacs

.PHONY : emacs dir ess auctex org polymode dmg www clean

emacs : dir ess auctex org polymode dmg

dir :
	@echo ----- Creating the application in temporary directory...
	if [ -d ${TMPDIR} ]; then rm -rf ${TMPDIR}; fi
	hdiutil attach ${DMGFILE} -noautoopen -quiet
	ditto -rsrc ${VOLUME}/Emacs/Emacs.app ${EMACSDIR}
#	ditto -rsrc Emacs.app ${EMACSDIR}
	hdiutil detach ${VOLUME}/Emacs -quiet
	cp -p default.el ${SITELISP}/
	cp -p site-start.el ${SITELISP}/
	sed -e '/^(defconst/s/<DISTVERSION>/${DISTVERSION}/' \
	    version-modified.el.in > version-modified.el
	cp -p version-modified.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/version-modified.el
	cp -p import-env-from-shell.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/import-env-from-shell.el
	cp -p psvn.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/psvn.el
	cp -p framepop.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/framepop.el
	cp -p Emacs.icns ${DESTDIR}/
	cp -p emacs-document.icns ${DESTDIR}/

ess :
	@echo ----- Making ESS...
	${MAKE} EMACS=${EMACS} -C ${ESS} all
	${MAKE} DESTDIR=${DESTDIR} SITELISP=${SITELISP} \
	        ETCDIR=${ETCDIR}/ess DOCDIR=${DOCDIR}/ess \
	        INFODIR=${INFODIR} -C ${ESS} install
	if [ -f ${SITELISP}/ess-site.el ]; then rm ${SITELISP}/ess-site.el; fi
	@echo ----- Done making ESS

auctex :
	@echo ----- Making AUCTeX...
	cd ${AUCTEX} && ./configure --datarootdir=${DESTDIR} \
		--without-texmf-dir \
		--with-lispdir=${SITELISP} \
		--with-emacs=${EMACS}
	make -C ${AUCTEX}
	make -C ${AUCTEX} install
	@echo ----- Done making AUCTeX

org :
	@echo ----- Making org...
	${MAKE} EMACS=${EMACS} -C ${ORG} all
	${MAKE} EMACS=${EMACS} lispdir=${SITELISP}/org \
	        datadir=${ETCDIR}/org infodir=${INFODIR} -C ${ORG} install
	mkdir -p ${DOCDIR}/org && cp -p ${ORG}/doc/*.pdf ${DOCDIR}/org/
	@echo ----- Done making org

polymode :
	@echo ----- copying markdown-mode and polymode files...
	cp -p markdown-mode.el ${SITELISP}/
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/markdown-mode.el
	mkdir -p ${SITELISP}/polymode
	cp -p polymode/*.el ${SITELISP}/polymode
	$(EMACSBATCH) -f batch-byte-compile ${SITELISP}/polymode/*.el
	mkdir -p ${DOCDIR}/polymode
	cp -p polymode/*.md ${DOCDIR}/polymode
	@echo ----- Done installing polymode

dmg :
	@echo ----- Signing the application...
	codesign --force --deep --sign "Developer ID Application: Vincent Goulet" \
		${EMACSDIR}

	@echo ----- Creating disk image...
	if [ -e ${TMPDMG} ]; then rm ${TMPDMG}; fi
	hdiutil create ${TMPDMG} \
		-size 175m \
	 	-format UDRW \
		-fs HFS+ \
		-srcfolder ${TMPDIR} \
		-volname ${DISTNAME} \
		-quiet

	@echo ----- Mounting disk image...
	hdiutil attach ${TMPDMG} -noautoopen -quiet

	@echo ----- Populating top level image directory...
	sed -e '/^* ESS/s/<ESSVERSION>/${ESSVERSION}/'          \
	    -e '/^* AUCTeX/s/<AUCTEXVERSION>/${AUCTEXVERSION}/' \
	    -e '/^* org/s/<ORGVERSION>/${ORGVERSION}/' \
	    -e '/^* polymode/s/<POLYMODEVERSION>/${POLYMODEVERSION}/' \
	    -e '/^* polymode/s/<MARKDOWNMODEVERSION>/${MARKDOWNMODEVERSION}/' \
	    -e '/^* psvn/s/<PSVNVERSION>/${PSVNVERSION}/' \
	    README.txt.in > README.txt
	cp -p README.txt ${VOLUME}/${DISTNAME}/
	cp -p NEWS ${VOLUME}/${DISTNAME}/
	ln -s /Applications ${VOLUME}/${DISTNAME}/Applications

	@echo ----- Unmounting and compressing disk image...
	hdiutil detach ${VOLUME}/${DISTNAME} -quiet
	if [ -e ${DISTNAME}.dmg ]; then rm ${DISTNAME}.dmg; fi
	hdiutil convert ${TMPDMG} \
		-format UDZO \
		-imagekey zlib-level=9 \
		-o ${DISTNAME}.dmg -quiet

	rm -rf ${TMPDIR} ${TMPDMG}
	@echo ----- Done building the disk image

www :
	@echo ----- Updating web site...
	cp -p ${DISTNAME}.dmg ${WWWLIVE}/htdocs/pub/emacs/
	cp -p NEWS ${WWWLIVE}/htdocs/pub/emacs/NEWS-mac
	cd ${WWWSRC} && svn update
	cd ${WWWSRC}/htdocs/s/emacs/ &&                       \
		LANG=ISO-8859-1 \
		sed -e 's/<ESSVERSION>/${ESSVERSION}/g'       \
		    -e 's/<AUCTEXVERSION>/${AUCTEXVERSION}/g' \
		    -e 's/<PSVNVERSION>/${PSVNVERSION}/g'     \
		    -e 's/<POLYMODEVERSION>/${POLYMODEVERSION}/g' \
		    -e 's/<MARKDOWNMODEVERSION>/${MARKDOWNMODEVERSION}/g' \
		    -e 's/<VERSION>/${VERSION}/g'             \
		    -e 's/<DISTNAME>/${DISTNAME}/g'           \
		    mac.html.in > mac.html
	cp -p ${WWWSRC}/htdocs/s/emacs/mac.html ${WWWLIVE}/htdocs/s/emacs/
	cd ${WWWSRC}/htdocs/en/s/emacs/ &&                    \
		LANG=ISO-8859-1 \
		sed -e 's/<ESSVERSION>/${ESSVERSION}/g'       \
		    -e 's/<AUCTEXVERSION>/${AUCTEXVERSION}/g' \
		    -e 's/<PSVNVERSION>/${PSVNVERSION}/g'     \
		    -e 's/<POLYMODEVERSION>/${POLYMODEVERSION}/g' \
		    -e 's/<MARKDOWNMODEVERSION>/${MARKDOWNMODEVERSION}/g' \
		    -e 's/<VERSION>/${VERSION}/g'             \
		    -e 's/<DISTNAME>/${DISTNAME}/g'           \
		    mac.html.in > mac.html
	cp -p ${WWWSRC}/htdocs/en/s/emacs/mac.html ${WWWLIVE}/htdocs/en/s/emacs/
	cd ${WWWLIVE} && ls -lRa > ${WWWSRC}/ls-lRa
	cd ${WWWSRC} && svn ci -m "Update for Emacs Modified for OS X version ${VERSION}"
	svn ci -m "Version ${VERSION}"
	svn cp ${REPOS}/trunk ${REPOS}/tags/${DISTNAME} -m "Tag version ${VERSION}"
	@echo ----- Done updating web site

clean :
	rm ${DISTNAME}.dmg
	cd ${ESS} && ${MAKE} clean
	cd ${AUCTEX} && ${MAKE} clean

# Targets to byte-compile packages
ELC = version-modified.elc import-env-from-shell.elc \
	psvn.elc framepop.elc markdown-mode.elc

version-modified.elc : version-modified.el.in version-modified.el
	sed -e '/^(defconst/s/<DISTVERSION>/${DISTVERSION}/' \
	    version-modified.el.in > version-modified.el
	$(EMACSBATCH) -f batch-byte-compile version-modified.el

import-env-from-shell.elc : import-env-from-shell.el

psvn.elc : psvn.el

framepop.elc : framepop.el

markdown-mode.elc : markdown-mode.el

