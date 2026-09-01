;;; Emacs Bedrock  -*- lexical-binding: t; -*-
;;;
;;; Extra config: Org-mode (base only)
;;;
;;; Usage: load from init.el (the load-file line is added there):
;;;
;;;   (load-file (expand-file-name "extras/org.el" user-emacs-directory))
;;;
;;; This file only sets up the core/built-in Org-mode.  Ecosystem packages
;;; (org-roam, org-modern, ...) are intentionally NOT installed here; see the
;;; recommended list at the end of this file and enable what you want.
;;;
;;; See "org-intro.txt" for a high-level introduction to Org-mode.

;;; Contents:
;;;
;;;  - Critical variables (directories, tags, refile)
;;;  - Phase 1: editing and exporting
;;;  - Phase 2: todos, agenda, capture

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Critical variables
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Where your Org files live.  Relative paths in agenda/capture look here.
;; Task files (inbox/work/study) are kept under a "tasks/" subdir so you can
;; keep a separate notes folder (e.g. ~/Documents/org/notes/) for other stuff.
(setq org-directory "~/Documents/org/")
(setq org-agenda-files '("tasks/inbox.org" "tasks/work.org" "tasks/study.org"))

;; Default TODO keyword set.
(setq org-todo-keywords
      '((sequence "TODO(t)" "WAITING(w@/!)" "STARTED(s!)"
                  "|" "DONE(d!)" "OBSOLETE(o@)")))
(setq org-log-done 'time)                 ; timestamp when a task is closed

;; Default tags for quick typing (tag + single-char shortcut).
;; "study" and "work" are mutually exclusive (group) so a task counts as
;; either study or work.
(setq org-tag-alist
      '((:startgroup)
        ("study" . ?s)
        ("work" . ?w)
        (:endgroup)
        (:newline)
        (:startgroup)
        ("math" . ?m)
        ("computer" . ?c)
        (:endgroup)))

;; Where `org-refile' should look for targets.
(setq org-refile-targets '((org-agenda-files :maxlevel . 2)))
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)

;; Custom link abbreviations (expand on open).
;; (currently none; add e.g. ("gh" . "https://github.com/%s") to write
;; [gh:user/repo] as a short link to a GitHub page.)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Phase 1: editing and exporting
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package org
  :hook ((org-mode . visual-line-mode)  ; wrap lines at word breaks
         (org-mode . flyspell-mode))    ; spell checking
  :bind (:map global-map
              ("C-c c" . org-capture)
              ("C-c a" . org-agenda)
              ("C-c l s" . org-store-link)          ; store a link
              ("C-c l i" . org-insert-link-global)) ; insert a link
  :config
  (require 'oc-csl)                     ; citation support
  (add-to-list 'org-export-backends 'md)
  ;; Make org-open-at-point follow file links in the same window.
  (setf (cdr (assoc 'file org-link-frame-setup)) 'find-file)
  ;; Make exported quotes/typography nicer.
  (setq org-export-with-smart-quotes t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Phase 2: todos, agenda generation, and task tracking
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package org
  :config
  (setq org-capture-templates
        '(("c" "Default Capture" entry (file "tasks/inbox.org")
           "* TODO %?\n%U\n%i")
          ("r" "Capture with Reference" entry (file "tasks/inbox.org")
           "* TODO %?\n%U\n%i\n%a")
          ("w" "Work" entry (file "tasks/work.org")
           "* TODO %?\n%U\n%i\n%a")
          ("s" "Study")   ; group: press *s* then choose sm / sc
          ("sm" "Study Math" entry (file+headline "tasks/study.org" "Math")
           "* TODO %?  :study:math:\n%U\n%i")
          ("sc" "Study Computer" entry (file+headline "tasks/study.org" "Computer")
           "* TODO %?  :study:computer:\n%U\n%i")))

  (setq org-agenda-custom-commands
        '(("n" "Agenda and All Todos"
           ((agenda)
            (todo)))
          ("w" "Work" agenda ""
           ((org-agenda-files '("tasks/work.org"))))
          ("d" "Dashboard"
           ((alltodo "" ((org-agenda-overriding-header "Tasks")
                          (org-super-agenda-groups org-super-agenda-groups))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Org modern
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package org-modern
  :ensure t
  :config
  ;; Enable org-modern in every Org buffer (prot-style global mode).
  (global-org-modern-mode)
  ;; Style the agenda font too.
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda)

  ;; Org styling — hide markup, prettify entities, align tags nicely.
  ;; (prot's settings, tuned for org-modern)
  (setq org-auto-align-tags nil
        org-tags-column 0
        org-catch-invisible-edits 'show-and-error
        org-special-ctrl-a/e t
        org-insert-heading-respect-content t
        org-hide-emphasis-markers t
        org-pretty-entities t
        org-agenda-tags-column 0
        org-ellipsis "…"
        ;; Use pretty per-level symbols instead of the default fold-triangles.
        org-modern-star 'replace
        org-modern-replace-stars '("◉" "○" "◈" "◇" "✳")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   org-super-agenda: Doom-style grouped dashboard
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package org-super-agenda
  :ensure t
  :config
  (org-super-agenda-mode))

;; Simple grouping with built-in selectors only.  `:scheduled' has no
;; `tomorrow', so tomorrow's items fall under "Future".  Tasks without a date
;; land in "Unscheduled".
(setq org-super-agenda-groups
      '((:name "Overdue"
               :deadline past
               :order 1)
        (:name "Today"
               :scheduled today
               :order 2)
        (:name "Future"
               :scheduled future
               :order 3)
        (:name "Unscheduled"
               :todo "TODO"
               :order 4)))

;; Remind (non-blocking) to set a date when capturing a TODO that has none.
;; Override if you'd rather be prompted right away.
(defun bedrock--org-capture-remind-date ()
  "Flash a reminder after capture if the item has no schedule/deadline."
  (let ((has-schedule (org-entry-get nil "SCHEDULED" 'local))
        (has-deadline (org-entry-get nil "DEADLINE" 'local)))
    (when (and (not has-schedule) (not has-deadline))
      (message "Reminder: set a date -- C-c C-s (schedule) / C-c C-d (deadline)"))))
(add-hook 'org-capture-before-finalize-hook #'bedrock--org-capture-remind-date)

;;; Recommended ecosystem packages (review and enable as you wish).
;;;
;;; Writing / look
;;;   org-modern         prettier heading/tag/todo rendering        [MELPA]
;;;   org-appear         reveal *emphasis* & links only near point  [MELPA]
;;;   valign             align tables with variable-width (Chinese) [MELPA]
;;;
;;; Notes / knowledge base
;;;   org-roam           networked Zettelkasten notes (your .bak had it) [MELPA]
;;;   denote             simpler note system (filenames as metadata)     [ELPA]
;;;   citar + org-cite   bibliography/reference management              [MELPA]
;;;
;;; Agenda / GTD
;;;   org-super-agenda   grouped/custom agenda views                    [MELPA]
;;;
;;; Execution / export
;;;   ob-async           run Babel code blocks asynchronously           [MELPA]
;;;   ox-hugo            export to Hugo blog                            [MELPA]
;;;   ox-gfm             export to GitHub-flavored Markdown             [MELPA]
;;;   ox-reveal          slides via reveal.js                           [MELPA]
;;;   org-pandoc-import  import/export Markdown/docx via pandoc         [MELPA]
;;;
;;; AI
;;;   gptel              chat/codegen inside Org blocks                 [MELPA]
