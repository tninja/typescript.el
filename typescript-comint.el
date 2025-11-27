;;; typescript-comint.el --- Run a TypeScript interpreter in comint  -*- lexical-binding: t; -*-

;; Copyright (C) 2008 Paul Huff
;; Copyright (C) 2015 Stefano Mazzucco
;; Copyright (C) 2016 Jostein Kjonigsen
;; Copyright (C) 2025 Kang Tu
;;
;; Author: Paul Huff <paul.huff@gmail.com>
;; Maintainer: TypeScript.el maintainers
;; URL: http://github.com/ananthakumaran/typescript.el
;; Keywords: typescript languages processes
;; Package-Requires: ((emacs "24.3"))
;; Version: 0.5
;;
;; This file is not part of GNU Emacs.
;;
;; This file is derived from the standalone ts-comint.el by
;; Paul Huff, Stefano Mazzucco, and Jostein Kjonigsen.
;; The TypeScript.el maintainers preserved their original work and
;; integrated it here to provide an optional TypeScript REPL.
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Run a TypeScript interpreter in a comint buffer and provide helpers
;; for sending code from `typescript-mode'.  Usage:
;;
;;   (autoload 'typescript-run-repl "typescript-comint")
;;   (autoload 'typescript-send-region "typescript-comint")
;;
;;   M-x typescript-run-repl
;;
;; The functions keep the `ts-*' aliases for compatibility with the
;; original ts-comint.el interface.

;;; Code:

(require 'ansi-color)
(require 'comint)

(defgroup typescript-comint nil
  "Run a TypeScript process in a buffer."
  :group 'typescript)

(defcustom typescript-comint-program-command "tsun"
  "Program name of the TypeScript interpreter."
  :type 'string
  :group 'typescript-comint)

(defcustom typescript-comint-program-arguments nil
  "List of command line arguments to pass to the TypeScript interpreter."
  :type '(repeat string)
  :group 'typescript-comint)

(defcustom typescript-comint-mode-hook nil
  "Hook for customizing `typescript-comint-mode'."
  :type 'hook
  :group 'typescript-comint)

(defcustom typescript-comint-mode-ansi-color t
  "Whether to enable ANSI colors in the inferior TypeScript buffer."
  :type 'boolean
  :group 'typescript-comint)

(defvar typescript-comint-buffer nil
  "Name of the inferior TypeScript buffer.")

(defvaralias 'ts-comint-program-command 'typescript-comint-program-command)
(defvaralias 'ts-comint-program-arguments 'typescript-comint-program-arguments)
(defvaralias 'ts-comint-mode-hook 'typescript-comint-mode-hook)
(defvaralias 'ts-comint-mode-ansi-color 'typescript-comint-mode-ansi-color)
(defvaralias 'ts-comint-buffer 'typescript-comint-buffer)

(defun typescript-comint--get-load-file-cmd (filename)
  "Generate a TypeScript import statement for FILENAME."
  (concat "import * as "
          (file-name-base filename)
          " from \""
          (file-name-base filename)
          "\"\n"))

;;;###autoload
(defun typescript-run-repl (&optional cmd dont-switch-p)
  "Run an inferior TypeScript process in buffer `*Typescript*'.
If a process already exists, reuse it.  With prefix CMD, prompt
for the full command line instead of `typescript-comint-program-command'.
When DONT-SWITCH-P is non-nil, do not switch to the process buffer."
  (interactive
   (list
    (when current-prefix-arg
      (read-string
       "Run TypeScript: "
       (mapconcat
        #'identity
        (cons typescript-comint-program-command
              typescript-comint-program-arguments)
        " ")))))

  (when cmd
    (setq typescript-comint-program-arguments (split-string cmd))
    (setq typescript-comint-program-command
          (pop typescript-comint-program-arguments)))

  (unless (comint-check-proc "*Typescript*")
    (with-current-buffer
        (apply #'make-comint
               "Typescript"
               typescript-comint-program-command
               nil typescript-comint-program-arguments)
      (typescript-comint-mode)))

  (setq typescript-comint-buffer "*Typescript*")

  (unless dont-switch-p
    (pop-to-buffer "*Typescript*"))

  (if typescript-comint-mode-ansi-color
      (progn
        (ansi-color-for-comint-mode-on)
        (make-local-variable 'comint-preoutput-filter-functions)
        (add-to-list
         'comint-preoutput-filter-functions
         (lambda (output)
           (replace-regexp-in-string "\033\\[[0-9]+[GKJ]" "" output))))
    (setenv "NODE_NO_READLINE" "1")))

;;;###autoload
(defun typescript-send-string (text)
  "Send TEXT to the inferior TypeScript process."
  (interactive "r")
  (typescript-run-repl typescript-comint-program-command t)
  (comint-send-string (get-buffer-process typescript-comint-buffer)
                      (concat text "\n")))

;;;###autoload
(defun typescript-send-region (start end)
  "Send the current region between START and END to the TypeScript process."
  (interactive "r")
  (typescript-send-string (buffer-substring-no-properties start end)))

;;;###autoload
(defun typescript-send-region-and-go (start end)
  "Send the current region to the TypeScript process and focus the REPL."
  (interactive "r")
  (typescript-send-region start end)
  (typescript-switch-to-repl typescript-comint-buffer))

;;;###autoload
(defun typescript-send-last-sexp-and-go ()
  "Send the previous sexp to the TypeScript process and focus the REPL."
  (interactive)
  (typescript-send-region-and-go
   (save-excursion
     (backward-sexp)
     (move-beginning-of-line nil)
     (point))
   (point)))

;;;###autoload
(defun typescript-send-last-sexp ()
  "Send the previous sexp to the inferior TypeScript process."
  (interactive)
  (typescript-send-region
   (save-excursion
     (backward-sexp)
     (move-beginning-of-line nil)
     (point))
   (point)))

;;;###autoload
(defun typescript-send-buffer ()
  "Send the current buffer to the inferior TypeScript process."
  (interactive)
  (typescript-send-region (point-min) (point-max)))

;;;###autoload
(defun typescript-send-buffer-and-go ()
  "Send the current buffer to the TypeScript process and focus the REPL."
  (interactive)
  (typescript-send-region-and-go (point-min) (point-max)))

;;;###autoload
(defun typescript-load-file (filename)
  "Load FILENAME inside the TypeScript interpreter."
  (interactive "f")
  (typescript-send-string
   (typescript-comint--get-load-file-cmd (expand-file-name filename))))

;;;###autoload
(defun typescript-load-file-and-go (filename)
  "Load FILENAME inside the TypeScript interpreter and focus the REPL."
  (interactive "f")
  (typescript-load-file filename)
  (typescript-switch-to-repl typescript-comint-buffer))

;;;###autoload
(defun typescript-switch-to-repl (eob-p)
  "Switch to the TypeScript process buffer.
When EOB-P is non-nil, move point to the end of the buffer."
  (interactive "P")
  (if (and typescript-comint-buffer (get-buffer typescript-comint-buffer))
      (pop-to-buffer typescript-comint-buffer)
    (error "No current process buffer. See `typescript-comint-buffer'"))
  (when eob-p
    (push-mark)
    (goto-char (point-max))))

;;;###autoload
(define-derived-mode typescript-comint-mode comint-mode "Inferior TypeScript"
  "Major mode for interacting with an inferior TypeScript process.

A TypeScript process can be started with \\[typescript-run-repl].

Customization: entry runs `comint-mode-hook' then `typescript-comint-mode-hook'."
  :group 'typescript-comint)

(define-key typescript-comint-mode-map (kbd "C-x C-e") #'typescript-send-last-sexp)
(define-key typescript-comint-mode-map (kbd "C-x l") #'typescript-load-file)

;;; Compatibility aliases (kept for users of the original ts-comint.el)
(define-obsolete-function-alias 'run-ts 'typescript-run-repl "0.5")
(define-obsolete-function-alias 'ts-send-string 'typescript-send-string "0.5")
(define-obsolete-function-alias 'ts-send-region 'typescript-send-region "0.5")
(define-obsolete-function-alias 'ts-send-region-and-go 'typescript-send-region-and-go "0.5")
(define-obsolete-function-alias 'ts-send-last-sexp 'typescript-send-last-sexp "0.5")
(define-obsolete-function-alias 'ts-send-last-sexp-and-go 'typescript-send-last-sexp-and-go "0.5")
(define-obsolete-function-alias 'ts-send-buffer 'typescript-send-buffer "0.5")
(define-obsolete-function-alias 'ts-send-buffer-and-go 'typescript-send-buffer-and-go "0.5")
(define-obsolete-function-alias 'ts-load-file 'typescript-load-file "0.5")
(define-obsolete-function-alias 'ts-load-file-and-go 'typescript-load-file-and-go "0.5")
(define-obsolete-function-alias 'switch-to-ts 'typescript-switch-to-repl "0.5")
(define-obsolete-function-alias 'ts-comint-mode 'typescript-comint-mode "0.5")

(provide 'typescript-comint)

;;; typescript-comint.el ends here
