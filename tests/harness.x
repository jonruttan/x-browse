; # x-browse -- a terminal browser on x-lang
;
; ## tests/harness.x -- what the spec harness adds to the dialect
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The lang kit's generator writes tests/lib/harness.gen.x: the dialect
; lang.xon declares, the bundle's root on the import path, then this file.
(import browse/base)
(import x/sys/gc)
(import x/codec/markdown)
(import x/codec/html)
(import x/tui/screen)

; A loader over SITE, ((LOCATION . TEXT) ...), a location ending .html
; HTML and any other Markdown; a location's query is left off to find
; it.  A form sent by POST, (LOADER LOC post BODY), is answered with a
; page saying what was sent.  A location not there is no such file.
(def spec-site
  (fn (_ site)
    (fn (_ loc . more)
      (def path (first (doc-fragment loc)))
      (def q (Str8 index-of "?" path))
      (def name (if (null? q) path (Str8 sub 0 q path)))
      (def p (Assoc find name site))
      (match
        ((null? p) (Err raise (lit io) "no such file" loc))
        ((not (null? more))
          (pair (lit markdown) (Markdown parse (Str8 append "# Sent\n\npost " (List ref 1 more)))))
        ((Str8 ends? ".html" name) (pair (lit html) (pair (Html title (rest p)) (Html parse (rest p)))))
        (#t (pair (lit markdown) (Markdown parse (rest p))))))))

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

; A site with two forms: one sent by GET to a page, one by POST.
(def spec-forms
  (list (pair "form.html"
              (Str8 append "<title>Ask</title><form action=\"found.md\"><p>Q: <input name=q> <input type=checkbox name=c value=1>"
                           " <select name=s><option>a<option value=2>b</select> <input type=submit value=Go></p></form>"
                           "<form method=post action=\"in.md\"><p><input type=radio name=r value=x checked>"
                           " <input type=radio name=r value=y> <button name=b value=1>Send</button></p></form>"))
        (pair "found.md" "# Found\n\nresults")
        (pair "in.md" "# In")))
