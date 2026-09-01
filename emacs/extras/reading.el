;;; Emacs Bedrock  -*- lexical-binding: t; -*-
;;;
;;; Extra config: Reading (PDF via pdf-tools, EPUB via nov)
;;;
;;; Usage: This file gives you a solid, basic PDF-reading setup that you can
;;; build on later (annotations, org-noter note-taking, synctex, etc.).
;;;
;;; PREREQUISITE: pdf-tools renders via a C backend (`epdfinfo`) built against
;;; poppler.  It is NOT pure Lisp.  Before this works you must:
;;;
;;;   1. Install system deps (e.g. on Gentoo):
;;;        emerge media-libs/poppler[utils,cairo]  imagemagick  (dev-util/pkgconf)
;;;      (poppler built WITH cairo; along with a C toolchain)
;;;
;;;   2. Run M-x pdf-tools-install RET   (compiles the epdfinfo executable)
;;;
;;; After that, opening a .pdf enters `pdf-view-mode' automatically.
;;;
;;; If you can't build the backend yet, Emacs can still show PDFs with the
;;; built-in `doc-view-mode' (raster images, no text selection/annotations).

;;; Contents:
;;;
;;;  - PDF (pdf-tools)
;;;  - Fallback (built-in doc-view)
;;;  - Annotated reading with Org (org-noter)
;;;  - EPUB (nov)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   PDF reading — pdf-tools
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package pdf-tools
  :ensure t
  :defer t                       ; load when you first open a PDF
  :mode (("\\.[pP][dD][fF]\\'" . pdf-view-mode))
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-tools-install)            ; build/find the epdfinfo C backend
  (setq pdf-view-display-size 'fit-page
        pdf-view-use-imagemagick nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Fallback: built-in doc-view
;;;
;;; If pdf-tools' backend isn't built yet, .pdf files won't trigger
;;; pdf-view-mode above.  Enable doc-view manually when needed:
;;   M-x doc-view-mode
;; (Alternative: bind it here once you confirm you need it.)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Annotated reading with Org — org-noter
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; org-noter lets you take notes in an Org buffer that stay anchored to page
;; positions in the PDF opened by pdf-tools.  Open the PDF, then:
;;
;;   M-x org-noter RET
;;
;; and start writing under headings that sync with the PDF page.
(use-package org-noter
  :ensure t
  :defer t
  :after pdf-tools)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   EPUB — nov.el
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; nov.el reads EPUB files (not PDF), nice companion for reading books:
;;   M-x nov-find-document RET  (or open a .epub)
(use-package nov
  :ensure t
  :defer t
  :mode (("\\.[eE][pP][uU][bB]\\'" . nov-mode)))
