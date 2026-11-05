; # x-browse -- a terminal browser on x-lang
;
; ## browse/cli.x -- the command line, and the terminal
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;   x -l browse -- [LOCATION ...]               browse, a tab for each
;   x -l browse -- -d [-w N] LOCATION           the document as text
;
; The options are one declaration to the platform's Opts, which parses
; them and prints the help.  With no location the browser opens the
; current directory.  Browsing
; takes the terminal: raw, on the alternate screen, the cursor hidden,
; given back as it was on the way out.  The size is asked again whenever
; no key comes for a quarter of a second, and the tabs laid out again
; when it has changed.

(module browse/cli)

(import x/type/vector)
(import x/sys/posix)
(import x/sys/gc)
(import x/repl/term)
(import x/tui/screen)
(import x/tui/tabs)
(import x/sys/opts)
(import browse/browser browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit?
  browse-repaint? browse-tabs browse-message)
(import browse/dump browse-dump)

(def browse-version "0.1.0")

; The options and the help text, one declaration: what parse accepts is
; what usage prints.
(def browse-options
  (Opts declare "x -l browse --" "[OPTIONS] [LOCATION ...]"
    "A terminal browser for Markdown and HTML, a tab a location.\nA location is a path, an http:// or https:// url, or about:help.  Browsing, ? shows the keys."
    (list (Opts flag "-d" "--dump" "Write the first location as text and exit, as lynx -dump does")
          (Opts arg "-w" "--width" "N" "Columns for --dump, 80 unless given, 10 at least")
          (Opts flag "-V" "--version" "Print the version and exit")
          (Opts flag "-h" "--help" "Print this help and exit"))
    (pair (lit help) #f)))

(def %say (fn (_ fd text) (Sys fd-write fd text)))

(def %to-int
  (fn (_ s) (guard (e ()) ((prim-ref (lit convert) (lit to)) s (Type named INTEGER) 10))))

(def %dump
  (fn (_ locs width)
    (if (null? locs) (do (%say 2 (Opts usage browse-options)) 2)
      (guard (e (do (%say 2 (Str8 append "x-browse: " (%err-text e) ": " (first locs) "\n")) 1))
        (do (%say 1 (browse-dump (first locs) width)) 0)))))

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
      (do (%say 2 "x-browse: not a terminal: --dump writes a document as text\n") 1)
      (do
        (def size (Term window 0))
        (def b (browse-make (rest size) (first size)))
        (List for-each (fn (_ loc) (browse-open! b loc (lit tab))) locs)
        (if (= (Tabs count (browse-tabs b)) 0)
          (do (%say 2 (Str8 append "x-browse: " (browse-message b) "\n")) 1)
          (do
            (Tabs select (browse-tabs b) 0)
            (def screen (Screen make (rest size) (first size)))
            (def token (Term raw! 0))
            (Term emit 1 (Str8 append (%esc "[?1049h") (%esc "[?25l")))
            (def failed (guard (e e) (do (%loop b screen (%reader)) ())))
            (Term emit 1 (Str8 append (%esc "[0m") (%esc "[?25h") (%esc "[?1049l")))
            (Term restore! 0 token)
            (if (null? failed) 0
              (do (%say 2 (Str8 append "x-browse: " (%err-text failed) "\n")) 1))))))))

; ARGS, the command line after the launcher's options: the exit status.
(def browse-main
  (fn (_ args)
    (def opts (Opts parse browse-options args))
    (def locs (Opts operands opts))
    (def width (if (null? (Opts value opts "-w")) 80 (%to-int (Opts value opts "-w"))))
    (match
      ((not (null? (Opts unknown opts)))
        (do (%say 2 (Str8 append "x-browse: no such option: " (Opts unknown opts) "\n" (Opts usage browse-options))) 2))
      ((Opts on? opts "-h") (do (%say 1 (Opts usage browse-options)) 0))
      ((Opts on? opts "-V") (do (%say 1 (Str8 append "x-browse " browse-version "\n")) 0))
      ((if (null? width) #t (< width 10))
        (do (%say 2 "x-browse: --width takes a number of columns, 10 or more\n") 2))
      ((Opts on? opts "-d") (%dump locs width))
      (#t (%browse (if (null? locs) (list ".") locs))))))

(provide browse/cli browse-main browse-options browse-version)
