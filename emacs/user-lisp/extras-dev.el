;;; extras-dev.el --- Development tools -*- lexical-binding: t; -*-

;;; Commentary:
;;; Extra config: Development tools

;;; Usage: Append or require this file from init.el for some software
;;; development-focused packages.
;;;
;;; It is **STRONGLY** recommended that you use the base.el config if you want to
;;; use Eglot. Lots of completion things will work better.
;;;
;;; This will try to use tree-sitter modes for many languages. Please run
;;;
;;;   M-x treesit-install-language-grammar
;;;
;;; Before trying to use a treesit mode.

;;; Contents:
;;;
;;;  - Built-in config for developers
;;;  - Version Control
;;;  - Language modules
;;;  - Eglot, the built-in LSP client for Emacs
;;;  - Templating
;;;  - Workspace management (tab-bar-mode + tabspaces)

;;; Code:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Built-in config for developers
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package emacs
  :hook
  ;; Auto parenthesis matching
  ((prog-mode . electric-pair-mode)))

(use-package envrc
  :vc (:url "https://codeberg.org/pastor/envrc")
  :bind-keymap ("C-c e" . envrc-command-map)
  :custom (envrc-indicator '(" [" (:eval (envrc--status)) "]"))
  :hook (after-init-hook . envrc-global-mode))

(use-package
  project
  :custom
  (project-mode-line t)) ; show project name in modeline

(use-package
  rainbow-delimiters
  :ensure t
  :hook (prog-mode-hook . rainbow-delimiters-mode))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Version Control
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ban vc-git for remote
;; (setq vc-handled-backends nil)
;; Magit: best Git client to ever exist
(use-package magit :ensure t :bind (("C-x g" . magit-status)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Language modules
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Eglot, the built-in LSP client for Emacs
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Helpful resources:
;;
;;  - https://www.masteringemacs.org/article/seamlessly-merge-multiple-documentation-sources-eldoc

(use-package
  eglot
  ;; no :ensure t here because it's built-in
  :commands (eglot eglot-ensure)
  :bind (:map eglot-mode-map ("C-c f" . eglot-format-buffer))
  :custom
  (eglot-send-changes-idle-time 0.1)
  (eglot-extend-to-xref t) ; activate Eglot in referenced non-project files
  (eglot-documentation-renderer 'markdown-ts-view-mode)
  (eglot-code-action-indications nil)
  :config
  (fset #'jsonrpc--log-event #'ignore)) ; massive perf boost---don't log every event

;; Flymake diagnostics backend (Eglot registers itself as a backend automatically).
(use-package flymake
  :hook (prog-mode . flymake-mode)
  :bind (("C-c n" . flymake-goto-next-error)
         ("C-c p" . flymake-goto-prev-error)
         ("C-c d" . flymake-show-buffer-diagnostics)
         ("C-c D" . flymake-show-project-diagnostics))
  :custom
  (flymake-indication-mode 'right-fringe)
  (flymake-check-start-timeout 1)
  (flymake-no-changes-timeout 0.5))

;; A beautiful inline overlay for Flycheck / Flymake
(use-package flyover
  :ensure t
  :hook ((flycheck-mode . flyover-mode)
         (flymake-mode . flyover-mode))
  :custom
  ;; Checker settings
  (flyover-checkers '(flycheck flymake))
  (flyover-levels '(error warning info))

  ;; Appearance
  (flyover-use-theme-colors t)
  (flyover-background-lightness 45)

  ;; Text tinting
  (flyover-text-tint 'lighter)
  (flyover-text-tint-percent 75)

  ;; Icon tinting (foreground and background)
  (flyover-icon-tint 'lighter)
  (flyover-icon-tint-percent 50)
  (flyover-icon-background-tint 'darker)
  (flyover-icon-background-tint-percent 50)

  ;; Icons
  ;; (flyover-info-icon " ")
  ;; (flyover-warning-icon " ")
  ;; (flyover-error-icon " ")

  ;; Border styles: none, pill, arrow, slant, slant-inv, flames, pixels
  (flyover-border-style 'none)
  (flyover-border-match-icon t)

  ;; Display settings
  (flyover-hide-checker-name t)
  (flyover-show-at-eol t)
  (flyover-show-virtual-line nil)
  (flyover-line-position-offset 0)

  ;; Message wrapping
  (flyover-wrap-messages t)
  ;; (flyover-max-line-length 80)

  ;; Performance
  (flyover-debounce-interval 0.2)
  (flyover-cursor-debounce-interval 0.3)

  ;; Display mode (controls cursor-based visibility)
  (flyover-display-mode 'hide-on-same-line)

  ;; Completion integration
  (flyover-hide-during-completion t))

(global-set-key (kbd "<f1>") #'eldoc)

;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package
  tempel
  :ensure t
  ;; By default, tempel looks at the file "templates" in
  ;; user-emacs-directory, but you can customize that with the
  ;; tempel-path variable:
  ;; :custom
  ;; (tempel-path (concat user-emacs-directory "custom_template_file"))
  :bind
  (("M-*" . tempel-insert)
    ("M-+" . tempel-complete)
    :map
    tempel-map
    ("C-c RET" . tempel-done)
    ("C-<down>" . tempel-next)
    ("C-<up>" . tempel-previous)
    ("M-<down>" . tempel-next)
    ("M-<up>" . tempel-previous))
  :init
  ;; Make a function that adds the tempel expansion function to the
  ;; list of completion-at-point-functions (capf).
  (defun tempel-setup-capf ()
    (add-hook 'completion-at-point-functions #'tempel-expand
      -1
      'local))
  ;; Put tempel-expand on the list whenever you start programming or
  ;; writing prose.
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf))

;; ghostel needs a native module; run M-x ghostel-download-module if you want it.
(use-package ghostel :ensure t :defer t)

;; (setq vc-handled-backends nil)

;; (use-package
;;   tramp-rpc
;;   :after tramp
;;   :vc
;;   (:url
;;     "https://github.com/ArthurHeymans/emacs-tramp-rpc"
;;     :rev
;;     :newest
;;     :lisp-dir "lisp"))

(use-package xterm-color
  :ensure t)

(provide 'extras-dev)
;; Local Variables:
;; no-byte-compile: t
;; End:
;;; extras-dev.el ends here
