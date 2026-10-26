; # x-links -- a terminal browser on x-lang
;
; ## tests/harness.x -- what the spec harness adds to the dialect
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The lang kit's generator writes tests/lib/harness.gen.x: the dialect
; lang.xon declares, the bundle's root on the import path, then this file.
(import links/base)
(import x/sys/gc)
(import x/codec/markdown)
(import x/tui/screen)

; A loader over SITE, ((LOCATION . MARKDOWN) ...): a location not there
; is no such file.
(def spec-site
  (fn (_ site)
    (fn (_ loc)
      ((fn (_ p) (if (null? p) (Err raise (lit io) "no such file" loc) (pair (lit markdown) (Markdown parse (rest p)))))
       (Assoc find (first (doc-fragment loc)) site)))))

; A ROWS by COLS browser on SITE, LOCATION open, and each of KEYS taken:
; the browser.  The heap is collected first: x collects only when asked,
; and a spec file's cases run in one process.
(def spec-browse
  (fn (_ rows cols site location keys)
    (Heap collect)
    (def b (browse-make rows cols (spec-site site)))
    (browse-open! b location (lit tab))
    (List for-each (fn (_ k) (browse-key! b k)) keys)
    b))

; What B draws, row by row, the trailing blanks dropped.
(def spec-screen
  (fn (_ b rows cols)
    (def s (browse-draw! b (Screen make rows cols)))
    (List map (fn (_ r) (Str8 trim-right (Screen row-text s r))) (List range 0 rows))))

; The fixtures' directory, as a location.
(def spec-fixtures "tests/fixtures/")

; A small site: a home page linking two others, one by a fragment.
(def spec-pages
  (list (pair "home.md" "# Home\n\nSee [one](one.md) and [two](two.md#later).\n\nline\n\nline\n\nline\n\nlast")
        (pair "one.md" "# One\n\nBack [home](home.md).")
        (pair "two.md" "# Two\n\na\n\nb\n\nc\n\n## Later\n\nend")))
