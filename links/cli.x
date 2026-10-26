; # x-links -- a terminal browser on x-lang
;
; ## links/cli.x -- the command line, and the terminal
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;   x -l links -- [LOCATION ...]               browse, a tab for each
;   x -l links -- -dump [-width N] LOCATION    the document as text
;
; With no location the browser opens the current directory.  Browsing
; takes the terminal: raw, on the alternate screen, the cursor hidden,
; given back as it was on the way out.  The size is asked again whenever
; no key comes for a quarter of a second, and the tabs laid out again
; when it has changed.

(module links/cli)

(import x/type/vector)
(import x/sys/posix)
(import x/sys/gc)
(import x/repl/term)
(import x/tui/screen)
(import x/tui/tabs)
(import links/browse browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit?
  browse-repaint? browse-tabs browse-message)
(import links/dump links-dump)

(def links-version "0.1.0")

(def %usage
  (Str8 join "\n"
    (list "usage: x -l links -- [LOCATION ...]"
          "       x -l links -- -dump [-width N] LOCATION"
          ""
          "A location is a path, an http:// or https:// url, or about:help."
          "Browsing, ? shows the keys."
          "")))

(def %say (fn (_ fd text) (Sys fd-write fd text)))

(def %to-int
  (fn (_ s) (guard (e ()) ((prim-ref (lit convert) (lit to)) s (Type named INTEGER) 10))))

; The options in ARGS, as an alist: (dump . #t), (width . N), (help . #t),
; (version . #t), (locations . LIST), or (error . TEXT).
(def %options
  (fn (self args opts locs)
    (match
      ((null? args) (pair (pair (lit locations) (List reverse locs)) opts))
      ((str=? (first args) "-dump") (self (rest args) (pair (pair (lit dump) #t) opts) locs))
      ((match ((str=? (first args) "-h") #t) ((str=? (first args) "-help") #t) ((str=? (first args) "--help") #t) (#t #f))
        (self (rest args) (pair (pair (lit help) #t) opts) locs))
      ((match ((str=? (first args) "-version") #t) ((str=? (first args) "--version") #t) (#t #f))
        (self (rest args) (pair (pair (lit version) #t) opts) locs))
      ((str=? (first args) "-width")
        ((fn (_ n)
           (if (if (null? n) #t (< n 10)) (list (pair (lit error) "-width takes a number of columns, 10 or more"))
             (self (List drop 2 args) (pair (pair (lit width) n) opts) locs)))
         (if (null? (rest args)) () (%to-int (List ref 1 args)))))
      ((if (Str8 starts? "-" (first args)) (< 1 (Str8 length (first args))) #f)
        (list (pair (lit error) (Str8 append "no such option: " (first args)))))
      (#t (self (rest args) opts (pair (first args) locs))))))

(def %opt (fn (_ opts k) ((fn (_ p) (if (null? p) () (rest p))) (Assoc find k opts))))

(def %dump
  (fn (_ locs width)
    (if (null? locs) (do (%say 2 %usage) 2)
      (guard (e (do (%say 2 (Str8 append "x-links: " (%err-text e) ": " (first locs) "\n")) 1))
        (do (%say 1 (links-dump (first locs) width)) 0)))))

(def %err-text
  (fn (_ e)
    (match ((Err err? e) (e msg))
           ((str? e) e)
           (#t (Err code-of e)))))

; --- the terminal --------------------------------------------------------------

; A byte reader over standard input, as (Term key) takes one, with its
; bytes read 64 at a time: (reader) answers a byte or nil at the end,
; (reader #t) whether there are bytes read and not yet taken.
(def %reader
  (fn (_)
    (def box (Vector of ()))
    (fn (self . ask)
      (if (null? ask)
        (do (when (null? (Vector ref 0 box)) (Vector set! 0 (Sys fd-read 0 64) box))
            (if (null? (Vector ref 0 box)) ()
              ((fn (_ b) (Vector set! 0 (rest (Vector ref 0 box)) box) b) (first (Vector ref 0 box)))))
        (not (null? (Vector ref 0 box)))))))

(def %show!
  (fn (_ b screen)
    (when (browse-repaint? b) (Screen repaint screen))
    (browse-draw! b screen)
    (Term emit 1 (Screen render screen))))

; The next key, the screen kept the terminal's size while it waits.
(def %key
  (fn (self b screen reader)
    (if (reader #t) (Term key reader)
      (if (null? (Sys poll (list (pair 0 (list (lit in)))) 250))
        (do ((fn (_ size)
               (unless (if (= (first size) (Screen cols screen)) (= (rest size) (Screen rows screen)) #f)
                 (do (Screen resize screen (rest size) (first size))
                     (browse-resize! b (rest size) (first size))
                     (%show! b screen))))
             (Term window 0))
            (self b screen reader))
        (Term key reader)))))

(def %loop
  (fn (self b screen reader)
    (%show! b screen)
    (unless (browse-quit? b)
      ((fn (_ key)
         (unless (null? key)
           (do (browse-key! b key)
               (Heap collect)
               (self b screen reader))))
       (%key b screen reader)))))

(def %esc (fn (_ text) (Str8 append "\x1b" text)))

(def %browse
  (fn (_ locs)
    ; x.sh parks the user's terminal on fd 3 while the boot stream holds
    ; fd 0; it is taken back, as the REPL and x-tmux take it.
    (guard (e ()) (when (Sys isatty 3) (do (Sys dup2 3 0) (Sys close 3))))
    (if (not (if (Term tty? 0) (Sys isatty 1) #f))
      (do (%say 2 "x-links: not a terminal: -dump writes a document as text\n") 1)
      (do
        (def size (Term window 0))
        (def b (browse-make (rest size) (first size)))
        (List for-each (fn (_ loc) (browse-open! b loc (lit tab))) locs)
        (if (= (Tabs count (browse-tabs b)) 0)
          (do (%say 2 (Str8 append "x-links: " (browse-message b) "\n")) 1)
          (do
            (Tabs select (browse-tabs b) 0)
            (def screen (Screen make (rest size) (first size)))
            (def token (Term raw! 0))
            (Term emit 1 (Str8 append (%esc "[?1049h") (%esc "[?25l")))
            (def failed (guard (e e) (do (%loop b screen (%reader)) ())))
            (Term emit 1 (Str8 append (%esc "[0m") (%esc "[?25h") (%esc "[?1049l")))
            (Term restore! 0 token)
            (if (null? failed) 0
              (do (%say 2 (Str8 append "x-links: " (%err-text failed) "\n")) 1))))))))

; ARGS, the command line after the launcher's options: the exit status.
(def links-main
  (fn (_ args)
    (def opts (%options args () ()))
    (match
      ((not (null? (%opt opts (lit error))))
        (do (%say 2 (Str8 append "x-links: " (%opt opts (lit error)) "\n" %usage)) 2))
      ((%opt opts (lit help)) (do (%say 1 %usage) 0))
      ((%opt opts (lit version)) (do (%say 1 (Str8 append "x-links " links-version "\n")) 0))
      ((%opt opts (lit dump))
        (%dump (%opt opts (lit locations)) (if (null? (%opt opts (lit width))) 80 (%opt opts (lit width)))))
      (#t (%browse (if (null? (%opt opts (lit locations))) (list ".") (%opt opts (lit locations))))))))

(provide links/cli links-main links-version)
