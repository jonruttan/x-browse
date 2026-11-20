; # x-browse -- a terminal browser on x-lang
;
; ## browse/dump.x -- --dump and --to: a document as text, or in a format
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; As lynx -dump writes one: the document laid out as the browser shows
; it, each link's text led by its number in brackets, and after it a
; list of where the links go, by number.  In another format it is the
; document's blocks, written by the platform's writer for it.

(module browse/dump)

(import x/type/vector)
(import x/tui/page)
(import x/tui/picture)
(import x/codec/document)
(import browse/doc doc-resolve doc-load doc-at doc-blocks doc-title)

; INLINES with each link and image led by "[N]", N counted in BOX.
(def %mark-inlines
  (fn (self inlines box)
    (List flat-map
      (fn (_ x)
        (match
          ((str? x) (list x))
          ((match ((eq? (first x) (lit link)) #t) ((eq? (first x) (lit image)) #t) (#t #f))
            (do (Vector set! 0 (+ (Vector ref 0 box) 1) box)
                (list (Str8 append "[" (%number->str (Vector ref 0 box)) "]")
                      (list (first x) (List ref 1 x) (List ref 2 x) (self (List ref 3 x) box)))))
          ((match ((eq? (first x) (lit emph)) #t) ((eq? (first x) (lit strong)) #t) (#t #f))
            (list (list (first x) (self (List ref 1 x) box))))
          (#t (list x))))
      inlines)))

(def %mark-blocks
  (fn (self blocks box)
    (List map
      (fn (_ b)
        (match
          ((eq? (first b) (lit heading)) (list (lit heading) (List ref 1 b) (%mark-inlines (List ref 2 b) box)))
          ((eq? (first b) (lit paragraph)) (list (lit paragraph) (%mark-inlines (List ref 1 b) box)))
          ((eq? (first b) (lit block-quote)) (list (lit block-quote) (self (List ref 1 b) box)))
          ((eq? (first b) (lit list))
            (list (lit list) (List ref 1 b) (List ref 2 b) (List ref 3 b)
                  (List map (fn (_ item) (self item box)) (List ref 4 b))))
          (#t b)))
      blocks)))

(def %lines
  (fn (_ page)
    (List map (fn (_ i) (Str8 trim-right (Page line-text page i))) (List range 0 (Page count page)))))

; The document at LOC as -dump writes it, WIDTH wide.  An image is its
; picture in half blocks and 24-bit colour, WIDTH columns at most, its
; shape kept.  A form's fields are
; drawn as the page draws them, unnumbered: the page numbers them with
; the links, the references list only the links.
(def browse-dump
  (fn (_ at width)
    (def got (doc-at at (doc-load at)))
    (def loc (first got))
    (def doc (rest got))
    (match
      ((eq? (first doc) (lit image))
        (Str8 join "" (List map (fn (_ l) (Str8 append l "\n")) (Picture lines (rest doc) width (List ref 2 doc) (lit rgb)))))
      ((not (eq? (first doc) (lit text)))
        ((fn (_ page)
           (def links (List filter (fn (_ l) (str? (first l))) (Page links page)))
           (Str8 append
             (Str8 join "" (List map (fn (_ l) (Str8 append l "\n")) (%lines page)))
             (if (null? links) ""
               (Str8 append "\nReferences\n\n"
                 (Str8 join ""
                   (List map
                     (fn (_ k)
                       (Str8 append (Str8 pad-left 5 #\space (Str8 append (%number->str (+ k 1)) ".")) " "
                                    (doc-resolve loc (first (List ref k links))) "\n"))
                     (List range 0 (List length links))))))))
         (Page markdown (%mark-blocks (doc-blocks doc) (Vector of 0)) width)))
      (#t (Str8 join "" (List map (fn (_ l) (Str8 append l "\n")) (%lines (Page text (rest doc) width))))))))

; The document at LOC written as FORMAT, a format the platform writes
; (Document formats): the file, (BUF START LENGTH), its blocks under its
; title.  A text document is the one block (Document read) reads text as;
; an image is no document to write.
(def browse-write
  (fn (_ at format)
    (def got (doc-at at (doc-load at)))
    (def doc (rest got))
    (when (eq? (first doc) (lit image)) (Err raise (lit value) "an image is not a document to write" at))
    (Document write format
      (if (eq? (first doc) (lit text)) (rest (Document read "text" (rest doc))) (doc-blocks doc))
      (doc-title (first got) doc))))

; The document at LOC as an HTML page.
(def browse-html (fn (_ at) (first (browse-write at "html"))))

(provide browse/dump browse-dump browse-html browse-write)
