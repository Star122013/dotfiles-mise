;;; extras-ui.el --- UI enhancements -*- lexical-binding: t; -*-

;;; Commentary:
;;; Set up doom-modeline and other UI enhancements.
;;;
;;; This configures:
;;;  - doom-modeline (status bar)
;;;  - diff-hl (git signs)
;;;  - tab-bar (built-in workspace tabs)
;;;  - colorful-mode (color preview)
;;;  - dashboard (startup screen)

;;; Code:

(use-package lambda-line
  :vc (:url "https://codeberg.org/Lambda-Emacs/lambda-line" :rev :newest)
  :custom
  (lambda-line-abbrev t)
  (lambda-line-position 'bottom)
  (lambda-line-hspace " ")
  (lambda-line-prefix t)
  (lambda-line-icon-time t)
  (lambda-line-time-format "  %H:%M ")
  (lambda-line-position-format "%l:%c")
  (lambda-line-prefix-padding nil)
  (lambda-line-status-invert nil)
  ;; 前缀图标用纯 Unicode 字符（lambda-line 会覆盖 face 属性，
  ;; 所以 nerd-icons 的字体族会被冲掉，改用通用符号）
  (lambda-line-gui-ro-symbol  " ◌")  ;; 只读：虚线圈
  (lambda-line-gui-mod-symbol " ●")  ;; 修改：实心圆
  (lambda-line-gui-rw-symbol  " ○")  ;; 读写：空心圆
  ;; VC 图标在 primary 段，lambda-line 用 add-face-text-property 追加，
  ;; 不会覆盖 nerd-icons 字体，所以可以用 nerd-icons
  (lambda-line-vc-symbol (concat " " (nerd-icons-octicon "nf-oct-git_branch")))
  (lambda-line-space-top +.25)
  (lambda-line-space-bottom -.25)
  (lambda-line-symbol-position 0.1)
  :custom-face
  (lambda-line-visual-bell
   ((t (:background ,(doom-color 'red)))))
  :config
  ;; 自动下载并安装 ClockFace 字体（用于最右侧的模拟时钟图标）
  (defun aiser/install-clockface-fonts ()
    "Download ClockFace fonts if not already installed."
    (let* ((font-dir (expand-file-name "fonts/" (or (getenv "XDG_DATA_HOME") "~/.local/share")))
           (fonts-list '("ClockFace-Regular.ttf"
                         "ClockFaceRect-Regular.ttf"
                         "ClockFaceSolid-Regular.ttf"
                         "ClockFaceRectSolid-Regular.ttf"))
           (needed (seq-filter (lambda (f) (not (file-exists-p (expand-file-name f font-dir))))
                               fonts-list)))
      (when needed
        (message "lambda-line: 下载 ClockFace 字体...")
        (make-directory font-dir t)
        (dolist (font needed)
          (url-copy-file (format "https://ocodo.github.io/ClockFace-font/%s" font)
                         (expand-file-name font font-dir) t))
        (call-process "fc-cache" nil nil nil "-f")
        (message "lambda-line: ClockFace 字体安装完成"))))
  ;; 只在字体被下载后才跑 fc-cache，平时不拖慢启动
  (when (display-graphic-p)
    (make-directory (expand-file-name "fonts/" (or (getenv "XDG_DATA_HOME") "~/.local/share")) t)
    (aiser/install-clockface-fonts))
  ;; 设置 ClockFace 字体映射到 PUA #xF0000..#xF008F 范围
  (lambda-line-clockface-update-fontset "ClockFaceRect")
  (lambda-line-mode)
  (customize-set-variable 'flymake-mode-line-counter-format '("" flymake-mode-line-error-counter flymake-mode-line-warning-counter flymake-mode-line-note-counter ""))
  (customize-set-variable 'flymake-mode-line-format '(" " flymake-mode-line-exception flymake-mode-line-counters))
  ;; (lambda-line-visual-bell-config)
  ;; set divider line in footer
  (when (eq lambda-line-position 'top)
    (setq-default mode-line-format (list "%_"))
    (setq mode-line-format (list "%_"))))

;; (use-package
;;   doom-modeline
;;   :ensure t
;;   :hook (after-init . doom-modeline-mode)
;;   :custom
;;   (doom-modeline-height 25)
;;   (doom-modeline-icon t)
;;   (doom-modeline-bar-width 4)
;;   (doom-modeline-project-name t)
;;   (doom-modeline-workspace-name t)
;;   (doom-modeline-buffer-file-name-style 'file-name)
;;   (doom-modeline-position-column-line-format '("%l:%c"))
;;   (doom-modeline-minor-modes t)
;;   (doom-modeline-indent-info t)
;;   (doom-modeline-vcs-icon t)
;;   (doom-modeline-vcs-max-length 15)
;;   (doom-modeline-check 'auto)
;;   (doom-modeline-lsp t)
;;   (doom-modeline-time t)
;;   (doom-modeline-time-analogue-clock t))

(use-package minions :ensure t :commands minions-mode :init (minions-mode 1))

;; diff-hl: git diff indicators in the fringe (left margin)
;; Uses VC, so vc-handled-backends must not be nil.
(use-package diff-hl
  :ensure t
  :hook ((prog-mode . diff-hl-mode)
         (text-mode . diff-hl-mode))
  :custom
  (diff-hl-draw-borders nil)
  :config
  ;; Update on save and revert
  (diff-hl-flydiff-mode 1)
  ;; Show margin instead of fringe in terminal
  (unless (display-graphic-p)
    (diff-hl-margin-mode 1))
  ;; Pause flydiff timer during completion to avoid flicker
  (defun my/diff-hl-pause ()
    (when (bound-and-true-p diff-hl-flydiff-timer)
      (cancel-timer diff-hl-flydiff-timer)
      (setq diff-hl-flydiff-timer nil)))
  (defun my/diff-hl-resume ()
    (when diff-hl-flydiff-mode
      (setq diff-hl-flydiff-timer
            (run-with-idle-timer diff-hl-flydiff-delay t
                                 #'diff-hl-flydiff-update))))
  (add-hook 'completion-in-region-mode-hook
            (defun my/diff-hl-completion-hook ()
              (if completion-in-region-mode
                  (my/diff-hl-pause)
                (my/diff-hl-resume)))))

;; centaur-tabs: show buffers in header-line, filtered by current workspace
(use-package
  centaur-tabs
  :ensure t
  :custom
  (centaur-tabs-enable-key-bindings t)
  (centaur-tabs-style "bar")
  (centaur-tabs-height 32)
  (centaur-tabs-set-icons t)
  (centaur-tabs-show-new-tab-button t)
  (centaur-tabs-set-modified-marker t)
  (centaur-tabs-show-navigation-buttons t)
  (centaur-tabs-set-bar 'under)
  (centaur-tabs-show-count nil)
  (x-underline-at-descent-line t)
  (centaur-tabs-left-edge-margin nil)
  :config
  (centaur-tabs-headline-match)
  (centaur-tabs-mode t)
  (setq uniquify-separator "/")
  (setq uniquify-buffer-name-style 'forward)

  ;; Only show buffers from the current tabspaces workspace
  (defun my/centaur-tabs-buffer-list ()
    "Like `centaur-tabs-buffer-list' but filtered by current workspace."
    (seq-filter
     (lambda (b)
       (and (cond ((eq (current-buffer) b) t)
                  ((buffer-file-name b) t)
                  ((char-equal ?\s (aref (buffer-name b) 0)) nil)
                  ((buffer-live-p b) t))
            (or (not (bound-and-true-p tabspaces-mode))
                (tabspaces--local-buffer-p b))))
     (buffer-list)))
  (setq centaur-tabs-buffer-list-function #'my/centaur-tabs-buffer-list)

  (defun centaur-tabs-buffer-groups ()
    "Group centaur-tabs by buffer type."
    (list
      (cond
        ((or (string-equal "*" (substring (buffer-name) 0 1))
             (memq major-mode
                   '(magit-process-mode magit-status-mode magit-diff-mode
                     magit-log-mode magit-file-mode magit-blob-mode
                     magit-blame-mode)))
         "Emacs")
        ((derived-mode-p 'prog-mode) "Editing")
        ((derived-mode-p 'dired-mode) "Dired")
        ((memq major-mode '(helpful-mode help-mode)) "Help")
        ((memq major-mode
               '(org-mode org-agenda-clockreport-mode org-src-mode
                 org-agenda-mode org-beamer-mode org-indent-mode
                 org-bullets-mode org-cdlatex-mode org-agenda-log-mode
                 diary-mode))
         "OrgMode")
        (t (centaur-tabs-get-group-name (current-buffer))))))
  :hook
  (dashboard-mode . centaur-tabs-local-mode)
  (term-mode . centaur-tabs-local-mode)
  (calendar-mode . centaur-tabs-local-mode)
  (org-agenda-mode . centaur-tabs-local-mode)
  :bind
  ("C-<prior>" . centaur-tabs-backward)
  ("C-<next>" . centaur-tabs-forward)
  ("C-S-<prior>" . centaur-tabs-move-current-tab-to-left)
  ("C-S-<next>" . centaur-tabs-move-current-tab-to-right))

;; Colorize color names in buffers
(use-package
  colorful-mode
  :ensure t
  :diminish
  :hook (after-init . global-colorful-mode)
  :init (setq colorful-use-prefix t)
  :custom
  (global-colorful-modes '(html-mode php-mode emacs-lisp-mode help-mode helpful-mode)))


;; ─── Dashboard ──────────────────────────────────────────────────────────────
;;
;; An extensible Emacs startup screen (like Doom Emacs's dashboard).
;; https://github.com/emacs-dashboard/dashboard
;;

;; Helper: insert a page break (^L) that page-break-lines renders as a line.
(defun dashboard-insert-page-break ()
  "Insert a page break separator for `dashboard'."
  (insert "\n\f\n\n"))

(use-package dashboard
  :ensure t
  :custom
  ;; ── Banner ──────────────────────────────────────────────────────────────
  (dashboard-startup-banner
   "~/.config/emacs/assets/GNUEmacs.png")
  (dashboard-banner-logo-title "♦ Do what I mean")
  (dashboard-image-banner-max-width 600)
  (dashboard-image-banner-max-height 300)

  ;; ── Layout ──────────────────────────────────────────────────────────────
  (dashboard-center-content t)
  (dashboard-vertically-center-content t)
  (dashboard-show-shortcuts t)
  (dashboard-navigation-cycle t)

  ;; ── Items ───────────────────────────────────────────────────────────────
  (dashboard-items '((recents   . 5)
                     (bookmarks . 5)
                     (projects  . 5)))
  (dashboard-item-shortcuts '((recents   . "r")
                              (bookmarks . "m")
                              (projects  . "p")))
  (dashboard-heading-shorcut-format " [%s]")

  ;; ── Icons (nerd-icons) ──────────────────────────────────────────────────
  (dashboard-display-icons-p t)
  (dashboard-icon-type 'nerd-icons)
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)

  ;; ── Projects ────────────────────────────────────────────────────────────
  ;; Use the built-in `project' package (configured in dev.el) instead of
  ;; `projectile', which is not installed.
  (dashboard-projects-backend 'project-el)

  ;; ── Path display ────────────────────────────────────────────────────────
  (dashboard-path-max-length 60)

  ;; ── Widget order ────────────────────────────────────────────────────────
  (dashboard-startupify-list
   '(dashboard-insert-banner
     dashboard-insert-banner-title
     dashboard-insert-page-break
     dashboard-insert-items
     dashboard-insert-page-break
     dashboard-insert-footer
     dashboard-insert-init-info))
  :config
  (setq initial-buffer-choice 'dashboard-open)
  (dashboard-setup-startup-hook))

;; Display ugly ^L page breaks as tidy horizontal lines
(use-package
  page-break-lines
  :ensure t
  :defer t
  :diminish
  :hook (after-init . global-page-break-lines-mode)
  :custom
  (page-break-lines-modes '(dashboard-mode emacs-news-mode)))

(provide 'extras-ui)
;; Local Variables:
;; no-byte-compile: t
;; End:
;;; extras-ui.el ends here
