;;; Emacs Bedrock  -*- lexical-binding: t; -*-
;;;
;;; Extra config: Writer

;;; Usage: Append or require this file from init.el for writing aids.
;;;
;;; Jinx is a spell-checking package that is performant and flexible.
;;; You can use Jinx inside of programming modes and it will only
;;; check spelling inside of strings and comments. (Configurable, of
;;; course.) It also supports having multiple languages (e.g. English
;;; and German) in the same file.
;;;
;;; Olivetti narrows the window margins so that your text is centered.
;;; This makes writing in a wide, dedicated window more pleasant.
;;;
;;; NOTE: the Olivetti package lives on the MELPA repository; you will
;;; need to update the `package-archives' variable in init.el before
;;; before loading this file; see the comment in init.el under
;;; "Package initialization".

;;; Contents:
;;;
;;;  - General prose-friendly behavior
;;;  - Markdown (built-in tree-sitter mode)
;;;  - Spell checking
;;;  - Dictionary
;;;  - Distraction mitigation

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   General prose-friendly behavior
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(when (>= emacs-major-version 30)       ; compat test
  (add-hook 'text-mode-hook 'visual-wrap-prefix-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Markdown (built-in tree-sitter mode)
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Emacs 31 ships a built-in tree-sitter Markdown mode, `markdown-ts-mode'.
;; It is experimental, so we register it for .md/.markdown/.mdown files via
;; `:mode' and let use-package defer-load it on first match.
;;
;; Install the right tree-sitter grammars yourself once:
;;   M-x treesit-install-language-grammar RET markdown RET
;;   M-x treesit-install-language-grammar RET markdown-inline RET
(use-package markdown-ts-mode
  :ensure nil                              ; built-in, don't fetch it
  :mode (("\\.md\\'" . markdown-ts-mode)
         ("\\.markdown\\'" . markdown-ts-mode)
         ("\\.mdown\\'" . markdown-ts-mode))
  :hook ((markdown-ts-mode . visual-line-mode)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Typst
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package typst-ts-mode
  :vc (:url "https://codeberg.org/meow_king/typst-ts-mode.git")
  :mode (("\\.typ\\'" . typst-ts-mode))
  :hook ((typst-ts-mode . visual-line-mode)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Spell checking
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Jinx: Enchanted spell-checking
;; Only enable in writing modes: Markdown, Typst, and Org.
(use-package jinx
  :ensure t
  :hook ((markdown-ts-mode typst-ts-mode org-mode) . jinx-mode)
  :bind (("C-;" . jinx-correct))
  :custom
  (jinx-camel-modes '(markdown-ts-mode typst-ts-mode org-mode))
  (jinx-delay 0.01))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Dictionary
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setopt dictionary-use-single-buffer t)
(setopt dictionary-server "dict.org")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Distraction mitigation
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Olivetti: Set the window margins so your text is centered
;; Only auto-enable in writing modes: Markdown, Typst, and Org.
(use-package olivetti
  :ensure t
  :hook ((markdown-ts-mode typst-ts-mode org-mode) . olivetti-mode))
