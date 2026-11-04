; # x-browse -- a terminal browser on x-lang
;
; ## browse/doc.x -- locations, and the documents found at them
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A location is a path on this machine, an http or https url, or
; about:help.  A link's destination is resolved against the location of
; the document it is in, as a browser resolves a relative url: a path
; against the document's directory, an absolute path against the
; host.  `#FRAGMENT` names a heading of the document, by the slug
; GitHub gives it.
;
; A document is (KIND . CONTENT): markdown with its blocks, html with its
; title (or nil) and then its blocks, or text with its string.  A path
; ending .md, .markdown or .mdown, or a response whose type is
; text/markdown, is Markdown; one ending .html or .htm, or a response
; whose type is text/html, is HTML; a directory is a Markdown list of its
; entries; anything else is text.  (doc-blocks DOC) answers the blocks of
; either kind, as x/tui/page lays them out.  A form sent by POST loads
; its action with the method and the body, (doc-load LOC post BODY), the
; body a query (doc-query) answers: application/x-www-form-urlencoded.
;
; A web location that redirects answers (at URL . DOC), URL where the
; document came from: (doc-at LOC DOC) answers (LOC . DOC) with that
; taken out, the location the final one, keeping LOC's fragment, so
; links and forms resolve against the page as it was served.

(module browse/doc)

(import x/sys/file)
(import x/net/http)
(import x/codec/markdown)
(import x/codec/html)
(import browse/help browse-help)

; --- locations ---------------------------------------------------------------

(def %scheme-char?
  (fn (_ c)
    (match ((Char alphabetic? c) #t) ((Char numeric? c) #t)
           ((eq? c #\+) #t) ((eq? c #\-) #t) ((eq? c #\.) #t)
           (#t #f))))

; Whether S starts with a url scheme and its colon.
(def doc-scheme?
  (fn (_ s)
    (def n (Str8 length s))
    ((fn (self i)
       (match ((= i n) #f)
              ((eq? (Str8 ref i s) #\:) (< 0 i))
              ((= i 0) (if (Char alphabetic? (Str8 ref 0 s)) (self 1) #f))
              ((%scheme-char? (Str8 ref i s)) (self (+ i 1)))
              (#t #f)))
     0)))

(def doc-web? (fn (_ s) (if (Str8 starts? "http://" s) #t (Str8 starts? "https://" s))))

; S cut at its first C: (BEFORE . AFTER), AFTER nil when there is no C.
(def %cut
  (fn (_ c s)
    (def i (Str8 index-of c s))
    (if (null? i) (pair s ())
      (pair (Str8 sub 0 i s) (Str8 sub (+ i 1) (- (Str8 length s) (+ i 1)) s)))))

; LOC without its fragment, and the fragment or nil.
(def doc-fragment (fn (_ loc) (%cut "#" loc)))

; A url's origin, scheme://host[:port], and its path from the first /
; ("/" when it has none).
(def %origin
  (fn (_ url)
    (def start (+ (Str8 index-of "//" url) 2))
    (def rest-url (Str8 sub start (- (Str8 length url) start) url))
    (def slash (Str8 index-of "/" rest-url))
    (if (null? slash) (pair url "/")
      (pair (Str8 sub 0 (+ start slash) url)
            (Str8 sub slash (- (Str8 length rest-url) slash) rest-url)))))

; PATH's . and .. segments taken out.  A relative path keeps the .. it
; cannot go above.
(def %dots
  (fn (_ path)
    (def abs (Str8 starts? "/" path))
    (def segs (Str8 split "/" path))
    (def last (if (null? segs) "" (List last segs)))
    (def out
      (List fold
        (fn (_ acc s)
          (match ((str=? s ".") acc)
                 ((str=? s "") acc)
                 ((str=? s "..")
                   (if (if (null? acc) #f (not (str=? (first acc) ".."))) (rest acc)
                     (if abs acc (pair s acc))))
                 (#t (pair s acc))))
        () segs))
    (def body (Str8 join "/" (List reverse out)))
    (def dir? (if (str=? last "") #t (if (str=? last ".") #t (str=? last ".."))))
    (Str8 append (if abs "/" "")
                 body
                 (if (if dir? (not (str=? body "")) #f) "/" ""))))

; Everything of PATH up to and with its last /, or "" when it has none.
(def %dir
  (fn (_ path)
    (def i (Str8 last-index-of "/" path))
    (if (null? i) "" (Str8 sub 0 (+ i 1) path))))

; DEST resolved against BASE, the location of the document it is in.
(def doc-resolve
  (fn (_ base dest)
    (def b (first (doc-fragment base)))
    (match
      ((str=? dest "") b)
      ((Str8 starts? "#" dest) (Str8 append b dest))
      ((doc-scheme? dest) dest)
      ((doc-web? b)
        ((fn (_ o)
           (match ((Str8 starts? "//" dest) (Str8 append (first (%cut ":" b)) ":" dest))
                  ((Str8 starts? "/" dest) (Str8 append (first o) (%dots dest)))
                  (#t (Str8 append (first o) (%dots (Str8 append (%dir (rest o)) dest))))))
         (%origin b)))
      ((Str8 starts? "/" dest) (%dots dest))
      (#t (%dots (Str8 append (%dir b) dest))))))

; The slug GitHub gives a heading: lower case, spaces to hyphens, and
; anything not a letter, digit, hyphen or underscore left out.
(def doc-slug
  (fn (_ text)
    (def s (Str8 downcase (Str8 trim text)))
    (def n (Str8 length s))
    (Str8 join ""
      ((fn (self i acc)
         (if (= i n) (List reverse acc)
           ((fn (_ c)
              (self (+ i 1)
                (match ((eq? c #\space) (pair "-" acc))
                       ((match ((Char alphabetic? c) #t) ((Char numeric? c) #t) ((eq? c #\-) #t)
                               ((eq? c #\_) #t) ((< 127 (Char ->int c)) #t) (#t #f))
                         (pair (Str8 make 1 c) acc))
                       (#t acc))))
            (Str8 ref i s))))
       0 ()))))

; --- documents ---------------------------------------------------------------

(def %markdown-name?
  (fn (_ loc)
    (def l (Str8 downcase (first (%cut "?" loc))))
    (List any? (fn (_ e) (Str8 ends? e l)) (list ".md" ".markdown" ".mdown"))))

(def %markdown (fn (_ text) (pair (lit markdown) (Markdown parse text))))

(def %html-name?
  (fn (_ loc)
    (def l (Str8 downcase (first (%cut "?" loc))))
    (if (Str8 ends? ".html" l) #t (Str8 ends? ".htm" l))))

(def %html (fn (_ text) (pair (lit html) (pair (Html title text) (Html parse text)))))

; Markdown text listing the directory DIR, its entries linked, a
; directory's name ending /.
(def %listing
  (fn (_ dir)
    (def d (if (Str8 ends? "/" dir) dir (Str8 append dir "/")))
    (def names (List sort (fn (_ a b) (Str8 <? a b)) (File list-dir d)))
    (Str8 append
      "# " d "\n\n"
      "- [../](../)\n"
      (Str8 join ""
        (List map
          (fn (_ n)
            ((fn (_ shown) (Str8 append "- [" shown "](" shown ")\n"))
             (if (eq? (File type (Str8 append d n)) (lit dir)) (Str8 append n "/") n)))
          names)))))

(def %header
  (fn (_ headers name)
    (def h (List find (fn (_ p) (str=? (Str8 downcase (first p)) name)) headers))
    (if (null? h) "" (Str8 downcase (rest h)))))

(def %fetch
  (fn (_ url method body)
    (def r (if (eq? method (lit post))
             (Http post (first (doc-fragment url)) body (list (pair "Content-Type" "application/x-www-form-urlencoded")))
             (Http get (first (doc-fragment url)))))
    (def status (rest (Assoc find (lit status) r)))
    (unless (if (< 199 status) (< status 300) #f)
      (Err raise (lit io) (Str8 append "HTTP " (%number->str status)) url))
    (def text (bytes->str (rest (Assoc find (lit body) r))))
    (def type (%header (rest (Assoc find (lit headers) r)) "content-type"))
    (def from ((fn (_ p) (if (null? p) (first (doc-fragment url)) (rest p))) (Assoc find (lit url) r)))
    (def doc
      (match ((Str8 starts? "text/markdown" type) (%markdown text))
             ((Str8 starts? "text/html" type) (%html text))
             ((%markdown-name? from) (%markdown text))
             ((%html-name? from) (%html text))
             (#t (pair (lit text) text))))
    (if (str=? from (first (doc-fragment url))) doc (pair (lit at) (pair from doc)))))

; LOC and DOC as (LOC . DOC), a redirected document's (at URL . DOC)
; taken out: its location URL, with LOC's fragment when URL has none.
(def doc-at
  (fn (_ loc doc)
    (if (not (eq? (first doc) (lit at))) (pair loc doc)
      ((fn (_ url frag)
         (pair (if (if (null? frag) #t (not (null? (rest (doc-fragment url))))) url (Str8 append url "#" frag))
               (rest (rest doc))))
       (first (rest doc)) (rest (doc-fragment loc))))))

; The document at LOC, (KIND . CONTENT); a web location is asked by
; METHOD, get unless given, with BODY.  Raises an Err when there is none
; to show.
(def doc-load
  (fn (_ loc . more)
    (def path (first (doc-fragment loc)))
    (match
      ((str=? path "about:help") (%markdown browse-help))
      ((doc-web? path)
        (%fetch path (if (null? more) (lit get) (first more)) (if (null? more) () (List ref 1 more))))
      ((Str8 starts? "file://" path) (doc-load (Str8 sub 7 (- (Str8 length loc) 7) loc)))
      ((doc-scheme? path) (Err raise (lit value) "no way to open this" path))
      (#t
        ((fn (_ type)
           (match ((eq? type (lit dir)) (%markdown (%listing path)))
                  ((eq? type (lit file))
                    ((fn (_ text)
                       (match ((%markdown-name? path) (%markdown text))
                              ((%html-name? path) (%html text))
                              (#t (pair (lit text) text))))
                     (File read-all path)))
                  ((null? type) (Err raise (lit io) "no such file" path))
                  (#t (Err raise (lit io) "not a file to read" path))))
         (File type path))))))

; PARAMS, ((NAME . VALUE) ...), as a form sends them: each percent-encoded,
; a space a +, name=value joined by &.
(def doc-query
  (fn (_ params)
    (Str8 join "&"
      (List map
        (fn (_ p) (Str8 replace "%20" "+" (Str8 append (Http url-encode (first p)) "=" (Http url-encode (rest p)))))
        params))))

; The plain text of INLINES.
(def %inline-text
  (fn (self inlines)
    (Str8 join ""
      (List map
        (fn (_ x)
          (match ((str? x) x)
                 ((eq? (first x) (lit code)) (List ref 1 x))
                 ((eq? (first x) (lit softbreak)) " ")
                 ((eq? (first x) (lit hardbreak)) " ")
                 ((eq? (first x) (lit link)) (self (List ref 3 x)))
                 ((eq? (first x) (lit image)) (self (List ref 3 x)))
                 ((eq? (first x) (lit html-inline)) "")
                 (#t (self (List ref 1 x)))))
        inlines))))

; The blocks of a Markdown or HTML document; nil for text.
(def doc-blocks
  (fn (_ doc)
    (match ((eq? (first doc) (lit markdown)) (rest doc))
           ((eq? (first doc) (lit html)) (rest (rest doc)))
           (#t ()))))

; A document's title: an HTML page's <title>, else its first heading's
; text, else the last part of LOC.
(def doc-title
  (fn (_ loc doc)
    (def t (if (eq? (first doc) (lit html)) (first (rest doc)) ()))
    (def h (if (null? t) (List find (fn (_ b) (eq? (first b) (lit heading))) (doc-blocks doc)) ()))
    (match
      ((not (null? t)) t)
      ((null? h)
        ((fn (_ p)
           ((fn (_ q) (if (str=? q "") p q))
            (List last (Str8 split "/" (if (Str8 ends? "/" p) (Str8 sub 0 (- (Str8 length p) 1) p) p)))))
         (first (doc-fragment loc))))
      (#t (%inline-text (List ref 2 h))))))

(provide browse/doc doc-scheme? doc-web? doc-fragment doc-resolve doc-slug doc-load doc-at doc-blocks doc-title doc-query)
