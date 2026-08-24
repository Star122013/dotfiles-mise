;;; extras-org.el --- Minimal Org-mode config -*- lexical-binding: t; -*-

;;; Commentary:
;;; A minimal starting point for exploring Org-mode from scratch.
;;;
;;; Org-mode does three main things:
;;;   1. Markup — write structured documents (like Markdown, but richer)
;;;   2. Task tracking — TODO lists, agendas, deadlines
;;;   3. Computational notebook — evaluate code blocks inline
;;;
;;; This config only sets up the basics for writing and exporting org files.
;;; As you get comfortable, add features one at a time.
;;;
;;; Quick start:
;;;   - C-c C-e  → export menu
;;;   - *bold*   /italic/  _underline_  +strikethrough+  ~code~
;;;   - * Heading  → top-level heading
;;;   - ** Subheading  → second-level heading

;;; Code:

(use-package org
  :hook
  ((org-mode . visual-line-mode))   ; soft word-wrap in org buffers
  :custom
  (org-directory "~/Documents/org/")
  (org-export-with-smart-quotes t)
  (org-export-backends '(md html)))

(provide 'extras-org)
;; Local Variables:
;; no-byte-compile: t
;; End:
;;; extras-org.el ends here
