;;; lang-config.el --- Per-language configuration -*- lexical-binding: t; -*-

;;; Commentary:
;;; Per-language configuration — tree-sitter, Eglot LSP, and major-mode setup.
;;; Each language section configures the mode hook and LSP server if applicable.

;;; Code:

;; ── Tree-sitter core ──────────────────────────────────────────────────────

(use-package treesit
  :custom
  (treesit-font-lock-level 4)
  (treesit-auto-install-grammar 'always)
  (treesit-enabled-modes t))

;; ── Bash ──────────────────────────────────────────────────────────────────

;; (no extra config needed)

;; ── CSS ───────────────────────────────────────────────────────────────────

;; (no extra config needed)

;; ── Dockerfile ────────────────────────────────────────────────────────────

(use-package dockerfile-mode
  :ensure t
  :mode ("Dockerfile\\'" "Containerfile\\'"))

;; ── Elixir ────────────────────────────────────────────────────────────────

(use-package eglot
  :hook ((elixir-mode . eglot-ensure)
         (elixir-ts-mode . eglot-ensure)))

;; ── Emacs Lisp ────────────────────────────────────────────────────────────

(use-package elisp-autofmt
  :ensure t
  :commands (elisp-autofmt-mode elisp-autofmt-buffer)
  :hook (emacs-lisp-mode . elisp-autofmt-mode)
  :custom
  (elisp-autofmt-style 'fixed))

;; ── Haskell ───────────────────────────────────────────────────────────────

(use-package eglot
  :hook ((haskell-mode . eglot-ensure))
  :custom
  (eglot-server-programs '(haskell-mode . ("haskell-language-server-wrapper" "--lsp")))
  :config (defvar eglot-server-programs))

;; ── JavaScript ────────────────────────────────────────────────────────────

;; (no extra config needed)

;; ── JSON ──────────────────────────────────────────────────────────────────

(use-package json-mode
  :ensure t
  :mode "\\.jsonc?\\'")

;; ── Markdown ──────────────────────────────────────────────────────────────

(use-package markdown-mode
  :ensure t
  :mode "\\.md\\'"
  :hook ((markdown-mode . visual-line-mode)))

;; markdown-ts-mode is built-in in Emacs 31 (experimental).
;; (treesit-enabled-modes t) does NOT auto-enable it yet.
;; Uncomment to opt in:
;; (use-package markdown-ts-mode :ensure nil)

;; ── Nix ───────────────────────────────────────────────────────────────────

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook ((nix-mode . eglot-ensure)
         (nix-ts-mode . eglot-ensure))
  :custom
  (eglot-server-programs '(nix-mode . ("nixd")))
  :config (defvar eglot-server-programs))

;; ── Python ────────────────────────────────────────────────────────────────

(use-package eglot
  :hook ((python-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)))

;; ── Ruby ──────────────────────────────────────────────────────────────────

(use-package eglot
  :hook ((ruby-mode . eglot-ensure)
         (ruby-ts-mode . eglot-ensure)))

;; ── Rust ──────────────────────────────────────────────────────────────────

;; (no extra config needed)

;; ── TOML ──────────────────────────────────────────────────────────────────

;; (no extra config needed)

;; ── TypeScript ────────────────────────────────────────────────────────────

;; (no extra config needed)

;; ── YAML ──────────────────────────────────────────────────────────────────

(use-package yaml-mode
  :ensure t
  :mode "\\.ya?ml\\'")

;; ── Zig ───────────────────────────────────────────────────────────────────

(use-package zig-mode
  :ensure t
  :mode ("\\.zig\\'" "\\.zon\\'")
  :hook ((zig-mode . eglot-ensure)
         (zig-ts-mode . eglot-ensure))
  :custom
  (eglot-server-programs '((zig-ts-mode . ("zls")) (zig-mode . ("zls"))))
  :config (defvar eglot-server-programs))

(use-package zig-ts-mode
  :vc (:url "https://codeberg.org/meow_king/zig-ts-mode" :rev :newest)
  :after zig-mode)

(provide 'lang-config)
;; Local Variables:
;; no-byte-compile: t
;; End:
;;; lang-config.el ends here
