;;; record.el --- Record what orderless shows in vertico, for orderless-tests.ts  -*- lexical-binding: t -*-

;; Copyright (C) 2026 The E8 contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;; In an interactive Emacs on a terminal, fed keys from timers, from the
;; repository's top directory:
;;
;;   script -q /dev/null emacs -Q -nw -l test/record.el
;;
;; The packages load from E8_ELPA, else ~/.emacs.d/elpaca/repos, each in
;; a directory of its own name, vertico-sort.el with them, as a package
;; manager's autoloads make it the default sort.  Each case in cases.json
;; turns vertico-mode on with the `vars' it gives, opens a prompt with <f5>
;; reading one of its `collection', or with `reader' "file" a file name in
;; a directory holding its `files', with `history' as the prompt's
;; history, and after <f5> and each of its `keys' records the input, the
;; count before the prompt and the candidates after the input, or the
;; answer once the prompt has closed, into golden.json, the directory the
;; files are in written as DIR/.

(require 'json)
(defvar cr-elpa (file-name-as-directory (or (getenv "E8_ELPA") (expand-file-name "~/.emacs.d/elpaca/repos"))))
(dolist (p '("vertico" "vertico/extensions" "orderless")) (add-to-list 'load-path (expand-file-name p cr-elpa)))
(require 'vertico)
(require 'vertico-sort)
(require 'orderless)

(menu-bar-mode -1)
(setq inhibit-message nil)

(defvar cr-dir (file-name-directory (or load-file-name buffer-file-name)))
(defvar cr-cases (append (json-read-file (expand-file-name "cases.json" cr-dir)) nil))
(defvar cr-results nil)
(defvar cr-states nil)
(defvar cr-answer nil)
(defvar cr-reader nil)
(defvar cr-history nil)

(defun cr-without-dir (text)
  (if (and text (stringp text))
      (replace-regexp-in-string (regexp-quote (abbreviate-file-name cr-files-dir)) "DIR/"
                                (replace-regexp-in-string (regexp-quote cr-files-dir) "DIR/" text t t) t t)
    text))

(defun cr-state ()
  (let ((mb (active-minibuffer-window)))
    (if (not mb)
        `((exited . t) (answer . ,(cr-without-dir cr-answer)))
      (with-current-buffer (window-buffer mb)
        `((input . ,(cr-without-dir (minibuffer-contents-no-properties)))
          (before . ,(or (and (overlayp vertico--count-ov) (overlay-get vertico--count-ov 'before-string)
                              (substring-no-properties (overlay-get vertico--count-ov 'before-string)))
                         ""))
          (after . ,(or (and (overlayp vertico--candidates-ov) (overlay-get vertico--candidates-ov 'before-string)
                             (substring-no-properties (overlay-get vertico--candidates-ov 'before-string)))
                        "")))))))

(defvar cr-defaults
  `((vertico-count . 10) (vertico-cycle . nil) (vertico-sort-function . vertico-sort-history-length-alpha) (vertico-preselect . directory) (vertico-scroll-margin . 2)
    (completion-styles . (basic partial-completion emacs22)) (completion-category-defaults . ,completion-category-defaults)
    (completion-category-overrides . nil)))

(defvar cr-files-dir (file-name-as-directory (make-temp-file "orderless-tests-" t)))

(defun cr-make-files (case)
  "Make the files of CASE in a directory of its own, and return it."
  (let ((dir (file-name-as-directory (expand-file-name (alist-get 'name case) cr-files-dir))))
    (when (file-exists-p dir) (delete-directory dir t))
    (make-directory dir t)
    (dolist (file (append (alist-get 'files case) nil))
      (let ((path (expand-file-name file dir)))
        (if (string-suffix-p "/" file)
            (make-directory path t)
          (make-directory (file-name-directory path) t)
          (write-region "" nil path nil 'silent))))
    dir))

(defun cr-to-lisp (v)
  "V, a JSON array of strings and arrays, as a list of symbols and lists."
  (if (vectorp v) (mapcar #'cr-to-lisp (append v nil)) (if (stringp v) (intern v) v)))

(defun cr-setup (case)
  (dolist (v cr-defaults) (set (car v) (cdr v)))
  (dolist (v (alist-get 'vars case))
    (let ((value (cdr v)))
      (set (car v) (cond ((vectorp value) (cr-to-lisp value))
                         ((eq value :json-false) nil)
                         ((and (stringp value) (memq (car v) '(vertico-preselect))) (intern value))
                         (t value)))))
  (vertico-mode 1)
  (setq cr-answer nil cr-states nil
        cr-history (append (alist-get 'history case) nil))
  (let ((collection (append (alist-get 'collection case) nil))
        (require-match (eq (alist-get 'require_match case) t))
        (default (alist-get 'default case)))
    (setq cr-reader
          (if (equal (alist-get 'reader case) "file")
              (let ((dir (cr-make-files case)))
                (lambda () (setq cr-answer (read-file-name "File: " dir))))
            (lambda () (setq cr-answer (completing-read "Pick: " collection nil require-match nil 'cr-history default)))))))

(global-set-key (kbd "<f5>") (lambda () (interactive) (funcall cr-reader)))

(defun cr-finish ()
  (with-temp-file (expand-file-name "golden.json" cr-dir)
    (insert (json-encode `((cases . ,(vconcat (nreverse cr-results))))))
    (json-pretty-print-buffer))
  (delete-directory cr-files-dir t)
  (kill-emacs 0))

(defun cr-run-case (cases)
  (if (null cases)
      (cr-finish)
    (let ((case (car cases)))
      (cr-setup case)
      (cr-step case (cons "<f5>" (append (alist-get 'keys case) nil)) (cdr cases)))))

(defun cr-step (case keys rest)
  (if (null keys)
      (progn
        (push `((name . ,(alist-get 'name case)) (states . ,(vconcat (nreverse cr-states)))) cr-results)
        (setq unread-command-events (listify-key-sequence (kbd "C-g C-g C-g")))
        (run-with-timer 0.05 nil #'cr-run-case rest))
    (setq unread-command-events (append unread-command-events (listify-key-sequence (kbd (car keys)))))
    (run-with-timer 0.05 nil
                    (lambda ()
                      (push (cr-state) cr-states)
                      (if (active-minibuffer-window)
                          (cr-step case (cdr keys) rest)
                        (cr-step case nil rest))))))

(run-with-timer 0.3 nil #'cr-run-case cr-cases)

;;; record.el ends here
