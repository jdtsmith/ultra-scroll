;;; ultra-scroll.el --- Fast and smooth scrolling -*- lexical-binding: t; -*-
;; Copyright (C) 2023-2025  J.D. Smith

;; Author: J.D. Smith
;; Homepage: https://github.com/jdtsmith/ultra-scroll
;; Package-Requires: ((emacs "29.1"))
;; Version: 0.3
;; Keywords: convenience
;; Prefix: ultra-scroll
;; Separator: -

;; ultra-scroll is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; ultra-scroll is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; ultra-scroll enables fast, smooth, jump-free scrolling for Emacs on
;; all builds that support varying pixel scroll delta event data.  On
;; emacs-mac it retains the swipe-to-scroll and pinch-out for tab
;; overview capabilities of that port.  On all ports, it can scroll
;; past images or other content taller than the window without issue.
;;
;; The strongly recommended scroll settings are:
;; 
;;  scroll-margin=0
;;  scroll-conservatively=101
;;
;; See also `pixel-scroll-precision-mode' in pixel-scroll.el.

;;; Code:
;;;; Requires
(require 'mac-win nil 'noerror)
(require 'pixel-scroll)
(require 'mwheel)
(require 'timer)

;;;; Customize
(defcustom ultra-scroll-mac-multiplier 1.
  "Multiplier for smooth scroll step for wheeled mice on emacs-mac.
This multiplies the fractional delta-y values generated by
regular mouse wheels by the value returned by
`frame-char-height'.  Increase it to increase scrolling speed on
such mice.  Note that some mice drivers emulate trackpads, and so
will not be affected by this setting.  Adjust scrolling speed
directly with those drivers instead."
  :group 'scrolling
  :type 'float)

(defcustom ultra-scroll-gc-percentage 0.67
  "Value to temporarily set `gc-cons-percentage'.
This is set on initial scrolling, and restored during idle
time (see `ultra-scroll-gc-idle-time')."
  :type '(choice (const :value nil :tag "Disable") (float :tag "Fraction"))
  :group 'scrolling)

(defcustom ultra-scroll-gc-idle-time 0.5
  "Idle time in sec after which to restore `gc-cons-percentage'.
Operates only if `ultra-scroll-gc-percentage' is non-nil."
  :type 'float
  :group 'scrolling)

(defcustom ultra-scroll-hide-cursor 0.25
  "Hide the cursor during scrolls after it reaches the window bounds.
Time in sec after which to restore the cursor.  Set to nil to
disable cursor hiding.  Note that `hl-line' highlights are also
hidden, if active."
  :type '(choice (const nil) float)
  :group 'scrolling)

;;;; Event callback/scroll
(defun ultra-scroll-down (delta)
  "Scroll the current window down by DELTA pixels.
DELTA should not be larger than the height of the current window."
  (let* ((initial (point))
	 (edges (window-edges nil t nil t))
	 (current-vs (window-vscroll nil t))
	 (off (+ (window-tab-line-height) (window-header-line-height)))
         (new-start (or (posn-point (posn-at-x-y 0 (+ delta off))) (window-start))))
    (goto-char new-start)
    (unless (zerop (window-hscroll))
      (setq new-start (beginning-of-visual-line)))
    (if (>= (line-pixel-height) (- (nth 3 edges) (nth 1 edges)))
	;; Jumbo line at top: just stay on it and increment vscroll
	(set-window-vscroll nil (+ current-vs delta) t t)
      (if (eq new-start (window-start))	; same start: just vscroll a bit more
	  (setq delta (+ current-vs delta))
	(setq delta (- delta (cdr (posn-x-y (posn-at-point new-start)))))
	(set-window-start nil new-start (not (zerop delta))))
      (set-window-vscroll nil delta t t)
      ;; Avoid recentering
      (goto-char (posn-point (posn-at-x-y 0 off))) ; window-start may be above
      (if (zerop (vertical-motion 1))	; move down 1 line from top
	  (signal 'end-of-buffer nil))
      (if (> initial (point)) (goto-char initial)))))

(defun ultra-scroll-up (delta)
  "Scroll the current window up by DELTA pixels.
DELTA should be less than the window's height."
  (let* ((initial (point))
	 (edges (window-edges nil t nil t))
	 (win-height (- (nth 3 edges) (nth 1 edges)))
	 (win-start (window-start))
	 (current-vs (window-vscroll nil t))
	 (start win-start))
    (if (<= delta current-vs)	    ; simple case: just reduce vscroll
	(setq delta (- current-vs delta))
      ; Not enough vscroll: measure size above window-start
      (let* ((dims (window-text-pixel-size nil (cons start (- current-vs delta))
					   start nil nil nil t))
	     (pos (nth 2 dims))
	     (height (nth 1 dims)))
	(when (or (not pos) (eq pos (point-min)))
	  (signal 'beginning-of-buffer nil))
	(setq start (nth 2 dims)
	      delta (- (+ height current-vs) delta))) ; should be >= 0
      (unless (eq start win-start)
	(set-window-start nil start (not (zerop delta)))))
    (when (>= delta 0) (set-window-vscroll nil delta t t))
    
    ;; Position point to avoid recentering, moving up one line from
    ;; the bottom, if necessary.  "Jumbo" lines (taller than the
    ;; window height, usually due to images) must be handled
    ;; carefully.  Once they are within the window, point should stay
    ;; on the first tall object on the line until the top of the jumbo
    ;; line clears the top of the window, then immediately moved off
    ;; (above), via the full height character.  The is the only way to
    ;; avoid unwanted re-centering/motion trapping.
    (if (> (line-pixel-height) win-height) ; a jumbo on the line!
	(let ((end (max (point)
			(save-excursion
			  (end-of-visual-line)
			  (1- (point)))))) ; don't fall off
	  (when-let ((pv (pos-visible-in-window-p end nil t))
		     ((and (> (length pv) 2) ; falls outside window
			   (zerop (nth 2 pv))))) ; but not at the top
	    (goto-char end) ; eol is usually full height
	    (goto-char start))) ; now move up
      (when-let ((p (posn-at-x-y 0 (1- win-height))))
	(goto-char (posn-point p))
	(vertical-motion -1)
	(if (< initial (point)) (goto-char initial))))))

(defvar ultra-scroll--gc-percentage-orig nil)
(defvar ultra-scroll--gc-timer nil)
(defun ultra-scroll--restore-gc ()
  "Reset GC variable during idle time."
  (setq gc-cons-percentage
	(or ultra-scroll--gc-percentage-orig 0.1)
	ultra-scroll--gc-timer nil))

(defsubst ultra-scroll--scroll (delta window)
  "Scroll WINDOW by DELTA pixels (positive or negative)."
  (let (ignore)
    (unless (or (zerop delta)
		(and (setq ignore (window-parameter window 'ultra-scroll--ignore))
		     (or (and (eq (point) (car ignore)) ; ignoring this window this direction
			      (eq (cdr ignore) (< delta 0)))
			 (set-window-parameter window 'ultra-scroll--ignore nil))))
      (with-selected-window window
	(condition-case err
	    (if (< delta 0)
		(ultra-scroll-down (- delta))
	      (ultra-scroll-up delta))
	  ;; Do not ding at buffer limits.  Show a message instead (once!).
	  ((beginning-of-buffer end-of-buffer)
	   (let* ((end (eq (car err) 'end-of-buffer))
		  (p (if end (point-max) (point-min))))
	     (goto-char p)
	     (set-window-start window p)
	     (set-window-vscroll window 0 t t)
	     (set-window-parameter window 'ultra-scroll--ignore
				   (cons (point) end))
	     (message (error-message-string
		       (if end '(end-of-buffer) '(beginning-of-buffer)))))))
        (ultra-scroll--hide-cursor window)))))

(defsubst ultra-scroll--maybe-relax-gc ()
  "Lift the GC threshold percentage to avoid GC during scroll.
See `ultra-scroll-gc-percentage' to configuring whether this
occurs and the `gc-cons-percentage' level to set temporarily."
  (when (and ultra-scroll-gc-percentage (not ultra-scroll--gc-timer))
    (setq gc-cons-percentage		; reduce GC's during scroll
	  (max gc-cons-percentage ultra-scroll-gc-percentage)
	  ultra-scroll--gc-timer
	  (run-with-idle-timer ultra-scroll-gc-idle-time nil
			       #'ultra-scroll--restore-gc))))

(defun ultra-scroll (event &optional arg)
  "Smooth scroll EVENT.
EVENT and optional ARG are passed to `mwheel-scroll', unless
EVENT is a scrolling event."
  (interactive "e")
  (let ((delta (nth 4 event)))
    (if (not delta)
	(mwheel-scroll event arg)
      (ultra-scroll--maybe-relax-gc)
      (ultra-scroll--scroll (round (cdr delta)) (mwheel-event-window event)))))

(declare-function mac-forward-wheel-event "mac-win")
(defun ultra-scroll-mac (event &optional arg)
  "Smooth scroll EVENT for emacs-mac.
EVENT and optional ARG are passed on to `mwheel-scroll', for any
events not handled here.  If swipe-tracking is enabled for
swipe-between-pages at the OS level, left-/right-swipe events
will be replayed for left/right touch ends."
  (interactive "e")
  (let ((ev-type (event-basic-type event))
	(plist (nth 3 event)))
    (if (not (memq ev-type '(wheel-up wheel-down)))
	(when (memq ev-type '(wheel-left wheel-right))
	  (if mouse-wheel-tilt-scroll
	      (mac-forward-wheel-event t 'mwheel-scroll event arg)
	    (when (and ;; "Swipe between pages" enabled.
		   (plist-get plist :swipe-tracking-from-scroll-events-enabled-p)
		   (eq (plist-get plist :momentum-phase) 'began))
	      ;; Post a swipe event when left/right momentum phase begins
	      (push (cons (event-convert-list
			   (nconc (delq 'click
					(delq 'double
					      (delq 'triple
						    (event-modifiers event))))
				  (if (eq (event-basic-type event) 'wheel-left)
				      '(swipe-left) '(swipe-right))))
			  (cdr event))
		    unread-command-events))))
      ;;  Note: emacs-mac encodes all scrolling information in the PLIST, as follows:
      ;;    trackpads:
      ;;      - `:scrolling-delta-x' and `:scrolling-delta-y' are set
      ;;        to pixel scroll amounts.
      ;;      - `:phase' is set to `began' on first scroll, then `changed'.
      ;;      - During momentum scroll, `:momentum-phase' is set to
      ;;        `began' then `changed', while `:phase' is `none'.
      ;;    some regular wheeled mice:
      ;;      - `:delta-x' and `:delta-y' are set to floating
      ;;        fractional line scroll amounts.
      ;;      - `:phase' is set to `began' on first scroll, then `changed'.
      ;;      - `:momentum-phase' is always `none'.
      (when (eq (plist-get plist :phase) 'began)
	(ultra-scroll--maybe-relax-gc))
      (let* ((scroll-delta (plist-get plist :scrolling-delta-y))
	     (delta (or scroll-delta
			;; regular non-touch scroll: fraction of a line
			(* (plist-get plist :delta-y) (frame-char-height)
			   ultra-scroll-mac-multiplier))))
	(ultra-scroll--scroll (round delta) (mwheel-event-window event))))))

; scroll-isearch support
(put 'ultra-scroll 'scroll-command t)
(put 'ultra-scroll-mac 'scroll-command t)

(defun ultra-scroll-check (event-cnt)
  "Check and report on the scrolling event data your system provides.
This reads EVENT-CNT independent scroll events (default: 30) and checks
their PIXEL-DELTA values to see if they differ."
  (interactive "p")
  (let
      ((buf (get-buffer-create "*ultra-scroll-report*"))
       (nc (string-match "\\bNATIVE_COMP\\b" system-configuration-features))
       (inhibit-read-only t)
       (max-cnt (max event-cnt 30)) (cnt 1) deltas mac-basic ev tm)
    (message (concat "ultra-scroll: checking scroll data\n"
		     (format
		      "Scroll your mouse wheel or track-pad slow then fast to generate %d events"
		      max-cnt)))
    (while (and (setq ev (read-event)) (< cnt max-cnt))
      (when (memq (event-basic-type ev) '(wheel-up wheel-down))
	(unless tm (setq tm (current-time)))
	(message "Detected %2d/%2d wheel event%s" cnt max-cnt (if (> cnt 1) "s" ""))
	(cl-incf cnt)
	(if (featurep 'mac-win)
	    (let ((plist (nth 3 ev)))
	      (when (null plist)
		(error "Malformed wheel event detected! %s" ev))
	      (if-let ((sdy (plist-get plist :scrolling-delta-y)))
		  (push sdy deltas)
		(if-let ((dy (plist-get plist :delta-y)))
		    (progn
		      (push dy deltas)
		      (setq mac-basic t))
		  (error "Malformed wheel event detected!  %s" ev))))
	  (if-let ((pix-delta (nth 4 ev)))
	      (push (cdr pix-delta) deltas)
	    (error "Malformed wheel event detected!  %s" ev)))))
    (setq tm (float-time (time-since tm)))
    (with-current-buffer buf
      (erase-buffer)
      (help-mode)
      (insert "  == ultra-scroll Scroll Event Report ==\n\n")
      (insert "* " (emacs-version) "\n* " (if nc "" "No ") "Native Comp Detected"
	      (if nc "\n" " (use native-comp for fastest scrolling performance)\n")
	      "\n")
      (when (and (featurep 'x) (not (featurep 'xinput2)))
	(insert " *** WARNING: Emacs on Linux/X11 must be compiled --with-xinput2\n"))
      (insert (format " ** %s scroll events%s detected in %0.2fs (%0.1f events/s)\n" cnt
		      (if mac-basic " [Mac basic mouse]" "") tm (/ (float cnt) tm)))
      (if (cl-every (lambda (x) (= (abs x) (abs (car deltas)))) deltas)
	  (insert (format " *** WARNING, all pixel scroll values == %0.2f No real pixel scroll data stream?\n"
			  (car deltas))
		  " ** (try again, or use pixel-scroll-precision instead)\n")
	(let* ((deltas (mapcar #'abs deltas))
	       (mean (/ (cl-reduce #'+ deltas ) max-cnt))
	       (min (apply #'min deltas))
	       (max (apply #'max deltas)))
	  (insert (format " *** %s pixel scroll data: %0.1f to %0.1f (%0.2f mean)\n"
			  (if mac-basic "Mac line-based" "Normal") min max mean)))))
    (display-buffer buf)))

(defvar-local ultra-scroll--hide-cursor-start nil)
(defvar-local ultra-scroll--hide-cursor-timer nil)
(defvar-local ultra-scroll--hide-cursor-undo nil)

(defun ultra-scroll--hide-cursor-undo (buf)
  "Undo cursor hiding in BUF."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      ;; TODO It would be nice to recenter the point here,
      ;; but this leads to problems with tall images.
      ;; (when-let ((win (get-buffer-window buf)))
      ;;   (with-selected-window win
      ;;     (goto-char (/ (+ (window-start) (window-end nil t)) 2))
      ;;     (beginning-of-line)))
      (mapc #'funcall ultra-scroll--hide-cursor-undo)
      (kill-local-variable 'ultra-scroll--hide-cursor-start)
      (kill-local-variable 'ultra-scroll--hide-cursor-timer)
      (kill-local-variable 'ultra-scroll--hide-cursor-undo))))

(defun ultra-scroll--hide-cursor (window)
  "Hide cursor in WINDOW."
  (when ultra-scroll-hide-cursor
    (if ultra-scroll--hide-cursor-timer
	(timer-set-time ultra-scroll--hide-cursor-timer ; reschedule
			(timer-relative-time nil ultra-scroll-hide-cursor))
      (setq ultra-scroll--hide-cursor-start (window-point window)
            ultra-scroll--hide-cursor-timer
	    (run-at-time ultra-scroll-hide-cursor nil
			 #'ultra-scroll--hide-cursor-undo
			 (window-buffer window))))
    (unless (or ultra-scroll--hide-cursor-undo
		(eq (window-point window) ;hide when window point reaches edge
		    ultra-scroll--hide-cursor-start))
      (push (if (local-variable-p 'cursor-type)
                (let ((orig cursor-type))
                  (lambda () (setq-local cursor-type orig)))
	      (lambda () (kill-local-variable 'cursor-type)))
            ultra-scroll--hide-cursor-undo)
      (setq-local cursor-type nil)
      (when (bound-and-true-p hl-line-mode)
        (push #'hl-line-mode ultra-scroll--hide-cursor-undo)
        (hl-line-mode -1)))))

;;;; Mode
;;;###autoload
(define-minor-mode ultra-scroll-mode
  "Toggle pixel precision scrolling.
When enabled, this minor mode scrolls the display precisely using
full trackpad or modern mouse capabilities.  It correctly scrolls
past images taller than the window height.  The mode enables
`pixel-scroll-precision-mode-map', overriding that mode's scroll
command, but other mode features, including interpolated page
scrolling, still function (if enabled).

Note that `ultra-scroll' does NOT do any interpolation of scroll
wheel data, and is intended for use with mouse/trackpad hardware
on systems providing pixel-level scroll data; see
`ultra-scroll-check' to investigate what kind of scrolling data
your system and hardware provide."
  :global t
  :group 'scrolling
  (pixel-scroll-precision-mode (if ultra-scroll-mode 1 -1)) ;; reuse
  (cond
   (ultra-scroll-mode
    (unless (> scroll-conservatively 0)
      (warn "ultra-scroll: scroll-conservatively > 0 is required for smooth scrolling of large images; 101 recommended"))
    (unless (= scroll-margin 0)
      (warn "ultra-scroll: scroll-margin = 0 is required for glitch-free smooth scrolling"))
    (when (and (featurep 'x) (not (featurep 'xinput2)))
      (warn "ultra-scroll: Emacs on Linux/X11 must be compiled --with-xinput2"))
    (define-key pixel-scroll-precision-mode-map [remap pixel-scroll-precision]
		(if (featurep 'mac-win) #'ultra-scroll-mac #'ultra-scroll))
    (setf (get 'pixel-scroll-precision-use-momentum 'us-orig-value)
	  pixel-scroll-precision-use-momentum)
    (setq pixel-scroll-precision-use-momentum nil)
    (setq ultra-scroll--gc-percentage-orig gc-cons-percentage))
   (t
    (define-key pixel-scroll-precision-mode-map [remap pixel-scroll-precision] nil)
    (setq pixel-scroll-precision-use-momentum
	  (get 'pixel-scroll-precision-use-momentum 'us-orig-value)))))

(provide 'ultra-scroll)
;;; ultra-scroll.el ends here

