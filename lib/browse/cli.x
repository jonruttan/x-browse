; # x-browse -- a terminal browser on x-lang
;
; ## lib/browse/cli.x -- the command line, and the terminal
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;   x -l browse -- [LOCATION ...]               browse, a tab for each
;   x -l browse -- -d [-w N] LOCATION           the document as text
;   x -l browse -- -t FORMAT LOCATION           the document in a format
;
; The options are one declaration to the platform's Opts, which parses
; them and prints the help.  With no location the browser opens the
; current directory, or standard input when that is not a terminal; -
; names standard input, as more takes it.  Browsing
; takes the terminal: raw, on the alternate screen, the cursor hidden,
; given back as it was on the way out.  The size is asked again whenever
; no key comes for a quarter of a second, and the tabs laid out again
; when it has changed.  Pictures, an image's or a page's images inline,
; are written over the window after the screen, in 24-bit colour when
; COLORTERM says the terminal has it (truecolor or 24bit), else in the
; 256-colour palette; the screen is drawn whole when the pictures shown
; change or move, so none is left behind.

(module browse/cli)

(import x/type/vector)
(import x/sys/posix)
(import x/sys/gc)
(import x/repl/term)
(import x/tui/screen)
(import x/tui/tabs)
(import x/sys/opts)
(import x/sys/file)
(import x/codec/document)
(import x/codec/bytes)
(import browse/doc doc-load doc-piped)
(import browse/browser browse-make browse-open! browse-refresh! browse-key! browse-resize! browse-draw! browse-quit?
  browse-repaint? browse-tabs browse-message browse-pictures)
(import browse/dump browse-dump browse-html browse-write)

(def browse-version "0.1.0")

; The options and the help text, one declaration: what parse accepts is
; what usage prints.
(def browse-options
  (Opts declare "x -l browse --" "[OPTIONS] [LOCATION ...]"
    "A terminal browser for Markdown and HTML, a tab a location.\nA location is a path, an http:// or https:// url, a data: url, about:help, or - for standard input.  Browsing, ? shows the keys."
    (list (Opts flag "-d" "--dump" "Write the first location as text and exit, as lynx -dump does")
          (Opts arg "-w" "--width" "N" "Columns for --dump, 80 unless given, 10 at least")
          (Opts arg "-t" "--to" "FORMAT" "Write the first location as FORMAT and exit: text, as --dump, or markdown, html or pdf")
          (Opts flag "-V" "--version" "Print the version and exit")
          (Opts flag "-h" "--help" "Print this help and exit"))
    (pair (lit help) #f)))

(def %say (fn (_ fd text) (Sys fd-write fd text)))

(def %to-int
  (fn (_ s) (guard (e ()) ((prim-ref (lit convert) (lit to)) s (Type named INTEGER) 10))))

; The formats --to takes, the platform's: their names.
(def %formats (fn (_) (List map first (Document formats))))

; The whole of FILE, (BUF START LENGTH), written to FD: a PDF is bytes,
; and its length is not a string's.
(def %emit
  (fn (self fd file)
    (def n (List ref 2 file))
    (when (< 0 n)
      ((fn (_ wrote)
         (if (< wrote 1) (Err raise (lit io) "cannot write" ())
           (self fd (list (first file) (+ (List ref 1 file) wrote) (- n wrote)))))
       (File write fd (if (= (List ref 1 file) 0) (first file) (Str8 sub (List ref 1 file) n (first file))) n)))))

; The first of LOCS written in FORMAT: text is the dump, the document laid
; out as the browser shows it with its links listed; any other is the
; platform's writer for it.  For -, standard input is read to its end
; first: the whole document is written.
(def %dump
  (fn (_ locs width format)
    (if (null? locs) (do (%say 2 (Opts usage browse-options)) 2)
      (guard (e (do (%say 2 (Str8 append "x-browse: " (%err-text e) ": " (first locs) "\n")) 1))
        (do (def load (if (str=? (first locs) "-")
                        ((fn (_ in) (%input-all! in) (%loader in)) (%input-make (%input-fd)))
                        doc-load))
            (if (str=? format "text") (%say 1 (browse-dump (first locs) width load)) (%emit 1 (browse-write (first locs) format load)))
            0)))))

(def %err-text
  (fn (_ e)
    (match ((Err err? e) (e msg))
           ((str? e) e)
           (#t (Err code-of e)))))

; --- standard input --------------------------------------------------------------
;
; Standard input is read a piece at a time as it comes, never whole
; before the page is shown: the first piece is shown, and the page laid
; out again when the bytes not yet shown are as many as those shown, so
; laying out costs the input's length a few times over however it comes,
; and when the input pauses, so a slow writer's lines appear as they
; are written.  Its keys come from the terminal, /dev/tty.

; The descriptor standard input is on: 3 when the wrapper parked it there
; (x.sh holds fd 0 for the boot stream), else 0.
(def %input-fd
  (fn (_)
    (if (List any? (fn (_ r) (List includes? (lit nval) (rest r))) (Sys poll (list (pair 3 (list (lit in)))) 0)) 0 3)))

; A read takes what a pipe holds, 64 KiB (pipe(7)).
(def %piece 65536)

; Standard input being read: a vector of 0 its descriptor, 1 a writer
; (x/codec/bytes) holding what has been read, 2 how many of those bytes
; the page shows, 3 whether the input has ended, 4 the buffer a read
; takes.
(def %input-make (fn (_ fd) (Vector of fd (Bytes writer) 0 #f (str-make %piece))))
(def %input-open? (fn (_ in) (if (null? in) #f (not (Vector ref 3 in)))))
(def %input-unshown (fn (_ in) (- (Bytes size (Vector ref 1 in)) (Vector ref 2 in))))

; One read of IN; at the end its descriptor is closed.  Answers whether
; to lay the page out now: at the end with bytes not shown, or when those
; are as many as the page shows.
(def %input-read!
  (fn (_ in)
    (def n (File read (Vector ref 0 in) (Vector ref 4 in) %piece))
    (if (< 0 n)
      (Bytes put (Vector ref 1 in) (Bytes region (Vector ref 4 in) 0 n))
      (do (Vector set! 3 #t in) (File close (Vector ref 0 in))))
    (if (< 0 (%input-unshown in))
      (if (Vector ref 3 in) #t (not (< (%input-unshown in) (Vector ref 2 in))))
      #f)))
(def %input-all!
  (fn (self in) (when (%input-open? in) (do (%input-read! in) (self in)))))

; The document of what IN has read, its bytes now shown.
(def %input-doc
  (fn (_ in)
    (def r (Bytes written (Vector ref 1 in)))
    (Vector set! 2 (List ref 2 r) in)
    (doc-piped (first r) (List ref 2 r))))

; The loader that answers IN's document for -, and loads any other
; location as doc-load does.
(def %loader
  (fn (_ in)
    (fn (_ loc . more)
      (match ((str=? loc "-") (%input-doc in))
             ((null? more) (doc-load loc))
             (#t (doc-load loc (first more) (List ref 1 more)))))))

; Standard input taken for reading and the terminal for keys: fd 0 the
; terminal, and the input moved off 0 when it was there.  Answers the
; input, or a reason there is none.
(def %take-input!
  (fn (_)
    (def fd (%input-fd))
    (def t (Sys open-read "/dev/tty"))
    (match
      ((Sys isatty fd) (do (when (< -1 t) (Sys close t)) "- reads standard input, which is the terminal: pipe a page to it"))
      ((< t 0) "no terminal for the keys: --dump writes a document as text")
      ((= fd 3) (do (Sys dup2 t 0) (Sys close t) (%input-make 3)))
      (#t ((fn (_ u) (Sys dup2 0 u) (Sys dup2 t 0) (Sys close t) (%input-make u))
           (Sys open-read "/dev/tty"))))))

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

(def %esc (fn (_ text) (Str8 append "\x1b" text)))

; The colours the terminal shows: rgb when COLORTERM says 24-bit.
(def %colours
  (fn (_)
    ((fn (_ c)
       (if (if (str? c) (if (str=? c "truecolor") #t (str=? c "24bit")) #f) (lit rgb) (lit indexed)))
     (guard (e ()) (Sys getenv "COLORTERM")))))

; The screen drawn, then the pictures in the window over it, each line
; on its row.  SHOWN holds the rows last written, to tell a change: the
; screen's own cells under a picture are blank, so a picture moved or
; gone is cleared by drawing the screen whole.
(def %show!
  (fn (_ b screen shown colours)
    (def rows (browse-pictures b colours))
    (when (if (browse-repaint? b) #t (not (equal? rows (Vector ref 0 shown)))) (Screen repaint screen))
    (Vector set! 0 rows shown)
    (browse-draw! b screen)
    (Term emit 1 (Screen render screen))
    (unless (null? rows)
      (Term emit 1
        (Str8 join ""
          (List map (fn (_ r) (Str8 append (%esc "[") (%number->str (+ (first r) 1)) ";1H" (rest r))) rows))))))

; The next key, the screen kept the terminal's size while it waits, and
; standard input read as it comes when IN is reading it.  A key waiting
; is answered before more input is read.
(def %ready? (fn (_ ready fd) (List any? (fn (_ r) (= (first r) fd)) ready)))
(def %refresh!
  (fn (_ b screen shown colours)
    (browse-refresh! b "-")
    (%show! b screen shown colours)))
(def %key
  (fn (self b screen reader shown colours in)
    (if (reader #t) (Term key reader)
      ((fn (_ ready)
         (match
           ((%ready? ready 0) (Term key reader))
           ((not (null? ready))
             (do (when (%input-read! in) (%refresh! b screen shown colours))
                 (self b screen reader shown colours in)))
           (#t
             (do ((fn (_ size)
                    (unless (if (= (first size) (Screen cols screen)) (= (rest size) (Screen rows screen)) #f)
                      (do (Screen resize screen (rest size) (first size))
                          (browse-resize! b (rest size) (first size))
                          (%show! b screen shown colours))))
                  (Term window 0))
                 (when (if (null? in) #f (< 0 (%input-unshown in))) (%refresh! b screen shown colours))
                 (self b screen reader shown colours in)))))
       (Sys poll (pair (pair 0 (list (lit in))) (if (%input-open? in) (list (pair (Vector ref 0 in) (list (lit in)))) ()))
                 250)))))

; The garbage a key made collected once its frame is shown, and only when
; no key waits: a collect of a large page's heap takes longer than the
; frame, so keys typed ahead are answered first.  Keys that never stop
; coming still collect every 32nd.
(def %uncollected 0)
(def %collect!
  (fn (_ reader)
    (set! %uncollected (+ %uncollected 1))
    (when (if (< 31 %uncollected) #t
            (if (reader #t) #f (null? (Sys poll (list (pair 0 (list (lit in)))) 0))))
      (Heap collect)
      (set! %uncollected 0))))

(def %loop
  (fn (self b screen reader shown colours in)
    (%show! b screen shown colours)
    (unless (browse-quit? b)
      (%collect! reader)
      ((fn (_ key)
         (unless (null? key)
           (do (browse-key! b key)
               (self b screen reader shown colours in))))
       (%key b screen reader shown colours in)))))

(def %browse
  (fn (_ locs)
    (def in (if (List any? (fn (_ l) (str=? l "-")) locs) (%take-input!) ()))
    ; x.sh parks the user's terminal on fd 3 while the boot stream holds
    ; fd 0; it is taken back, as the REPL and x-tmux take it.
    (when (null? in) (guard (e ()) (when (Sys isatty 3) (do (Sys dup2 3 0) (Sys close 3)))))
    (match
      ((str? in) (do (%say 2 (Str8 append "x-browse: " in "\n")) 1))
      ((not (if (Term tty? 0) (Sys isatty 1) #f))
        (do (%say 2 "x-browse: not a terminal: --dump writes a document as text\n") 1))
      (#t
        (do
          (def size (Term window 0))
          (unless (null? in) (%input-read! in))
          (def b (if (null? in) (browse-make (rest size) (first size)) (browse-make (rest size) (first size) (%loader in))))
          (List for-each (fn (_ loc) (browse-open! b loc (lit tab))) locs)
          (if (= (Tabs count (browse-tabs b)) 0)
            (do (%say 2 (Str8 append "x-browse: " (browse-message b) "\n")) 1)
            (do
              (Tabs select (browse-tabs b) 0)
              (def screen (Screen make (rest size) (first size)))
              (def token (Term raw! 0))
              (Term emit 1 (Str8 append (%esc "[?1049h") (%esc "[?25l")))
              (def failed (guard (e e) (do (%loop b screen (%reader) (Vector of ()) (%colours) in) ())))
              (Term emit 1 (Str8 append (%esc "[0m") (%esc "[?25h") (%esc "[?1049l")))
              (Term restore! 0 token)
              (if (null? failed) 0
                (do (%say 2 (Str8 append "x-browse: " (%err-text failed) "\n")) 1)))))))))

; ARGS, the command line after the launcher's options: the exit status.
(def browse-main
  (fn (_ args)
    (def opts (Opts parse browse-options args))
    (def locs (Opts operands opts))
    (def width (if (null? (Opts value opts "-w")) 80 (%to-int (Opts value opts "-w"))))
    (def format (if (null? (Opts value opts "-t")) "text" (Opts value opts "-t")))
    (match
      ((not (null? (Opts unknown opts)))
        (do (%say 2 (Str8 append "x-browse: no such option: " (Opts unknown opts) "\n" (Opts usage browse-options))) 2))
      ((Opts on? opts "-h") (do (%say 1 (Opts usage browse-options)) 0))
      ((Opts on? opts "-V") (do (%say 1 (Str8 append "x-browse " browse-version "\n")) 0))
      ((if (null? width) #t (< width 10))
        (do (%say 2 "x-browse: --width takes a number of columns, 10 or more\n") 2))
      ((not (List includes? format (%formats)))
        (do (%say 2 (Str8 append "x-browse: --to takes " (Str8 join ", " (%formats)) ", not " format "\n")) 2))
      ((if (Opts on? opts "-d") #t (not (null? (Opts value opts "-t")))) (%dump locs width format))
      (#t (%browse (if (null? locs) (list (if (Sys isatty (%input-fd)) "." "-")) locs))))))

(provide browse/cli browse-main browse-options browse-version)
