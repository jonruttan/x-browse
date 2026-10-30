; # x-browse -- a terminal browser on x-lang
;
; ## browse/browser.x -- tabs of documents, the keys, and what is drawn
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A browser holds tabs (x/tui/tabs), each a window on a document, and
; beside each tab where its document is and the documents it came from.
; It takes keys as x/repl/term's (Term key) decodes them and draws on a
; screen (x/tui/screen): the tab bar on the first row, the current tab's
; window below it, and on the last row the selected link, the location,
; a message, or a question being typed: a location to open, text to
; search for, or a field's text.  Nothing here touches a terminal, so a
; spec drives it with keys and reads the screen back.
;
; A form's fields are selected as links are.  Enter on a text field asks
; for its text, on a checkbox or radio button turns it on or off, on a
; select moves to its next option, and on a submit button sends the form:
; by GET as its action with the fields as the query, by POST through the
; loader with them as the body.  A field's value lives in the tab's
; document, whose field inline is rewritten, so going back finds the
; values as they were left.
;
; Documents are loaded by the browser's loader, (doc-load LOC) unless
; one is given, and (LOADER LOC post BODY) for a form sent by POST: a
; spec loads from a list instead.

(module browse/browser)

(import x/type/vector)
(import x/codec/utf8 utf8-cp-at utf8-width)
(import x/tui/width char-width text-width)
(import x/tui/style)
(import x/tui/screen)
(import x/tui/page)
(import x/tui/window)
(import x/tui/tabs)
(import browse/doc doc-resolve doc-fragment doc-slug doc-load doc-at doc-blocks doc-title doc-query)

; A browser is a vector: 0 the tabs, 1 each tab's state in the tabs'
; order, 2 rows, 3 columns, 4 the message shown, 5 the question being
; asked, 6 whether to quit, 7 the loader, 8 whether the screen is to be
; drawn whole, 9 the text last searched for, 10 the line it was found
; on, or nil.  A tab's state is a vector: 0 the location, 1 the
; document, 2 the history, newest first, each (LOCATION DOCUMENT TOP
; SELECTED).  A question is (WHAT . TEXT): WHAT here or tab for a
; location to open there, search, or field for the selected field's text.
(def %quot (prim-ref (lit int) (lit /)))
(def %and (prim-ref (lit int) (lit &)))
(def %min (fn (_ a b) (if (< a b) a b)))

(def %get (fn (_ b k) (Vector ref k b)))
(def %put! (fn (_ b k x) (Vector set! k x b)))
(def %tabs (fn (_ b) (%get b 0)))
(def %rows (fn (_ b) (%get b 2)))
(def %cols (fn (_ b) (%get b 3)))
(def %body-rows (fn (_ b) (if (< (%rows b) 3) 1 (- (%rows b) 2))))
(def %say! (fn (_ b text) (%put! b 4 text)))

(def %index (fn (_ b) (Tabs index (%tabs b))))
(def %window (fn (_ b) (Tabs current (%tabs b))))
(def %state (fn (_ b) (if (< (%index b) 0) () (List ref (%index b) (%get b 1)))))

(def %page
  (fn (_ doc width)
    (if (eq? (first doc) (lit text)) (Page text (rest doc) width) (Page markdown (doc-blocks doc) width))))

(def %err-text
  (fn (_ e)
    (match ((Err err? e) (e msg))
           ((str? e) e)
           (#t ((fn (_ c s) (if (str=? s "") c (Str8 append c ": " s))) (Err code-of e) (Err subject-of e))))))

; The line of the window's page whose text has the slug FRAG, or nil.
(def %anchor
  (fn (_ page frag)
    (def n (Page count page))
    ((fn (self i)
       (match ((= i n) ())
              ((str=? (doc-slug (Page line-text page i)) frag) i)
              (#t (self (+ i 1)))))
     0)))

(def %go-fragment!
  (fn (_ b w loc)
    (def frag (rest (doc-fragment loc)))
    (unless (null? frag)
      ((fn (_ line)
         (if (null? line) (%say! b (Str8 append "no heading #" frag))
           (Window go w line (%body-rows b))))
       (%anchor (Window page w) frag)))))

; LOC's document, asked with MORE (a method and a body, or nothing), as
; (LOCATION . DOCUMENT), the location where it came from; nil with the
; reason said.
(def %load
  (fn (_ b loc more)
    (guard (e (do (%say! b (Str8 append (%err-text e) ": " loc)) ()))
      (doc-at loc (if (null? more) ((%get b 7) loc) ((%get b 7) loc (first more) (List ref 1 more)))))))

(def %show!
  (fn (_ b w loc doc top selected)
    (Window show w (%page doc (%cols b)) (%body-rows b))
    (Window retitle w (doc-title loc doc))
    (Window go w top (%body-rows b))
    (Window select w selected (%body-rows b))))

; LOC opened: WHERE here replaces the current tab's document, keeping
; the one it had in the tab's history; tab adds a tab for it.  MORE, a
; method and a body, sends a form.  Answers whether it opened.
(def browse-open!
  (fn (_ b asked where . more)
    (def got (%load b asked more))
    (unless (null? got)
      (do
        (def loc (first got))
        (def doc (rest got))
        (if (if (eq? where (lit tab)) #t (< (%index b) 0))
          (do (def w (Window make (doc-title loc doc) (%page doc (%cols b))))
              (Tabs add (%tabs b) w)
              (%put! b 1 (List append (%get b 1) (list (Vector of loc doc ()))))
              (%go-fragment! b w loc))
          (do (def s (%state b))
              (def w (%window b))
              (Vector set! 2 (pair (list (Vector ref 0 s) (Vector ref 1 s) (Window top w) (Window selected w))
                                   (Vector ref 2 s))
                      s)
              (Vector set! 0 loc s)
              (Vector set! 1 doc s)
              (%show! b w loc doc 0 ())
              (%go-fragment! b w loc)))))
    (not (null? got))))

(def %back!
  (fn (_ b)
    (def s (%state b))
    (if (null? (Vector ref 2 s)) (%say! b "nothing to go back to")
      ((fn (_ h)
         (Vector set! 2 (rest (Vector ref 2 s)) s)
         (Vector set! 0 (List ref 0 h) s)
         (Vector set! 1 (List ref 1 h) s)
         (%show! b (%window b) (List ref 0 h) (List ref 1 h) (List ref 2 h) (List ref 3 h)))
       (first (Vector ref 2 s))))))

(def %reload!
  (fn (_ b)
    (def s (%state b))
    (def got (%load b (Vector ref 0 s) ()))
    (unless (null? got)
      (do (Vector set! 0 (first got) s)
          (Vector set! 1 (rest got) s)
          ((fn (_ w) (%show! b w (first got) (rest got) (Window top w) (Window selected w))) (%window b))))))

; --- fields ------------------------------------------------------------------

; A field inline, (field TYPE NAME VALUE ON OPTIONS FORM) as x/codec/html
; answers one: its parts, and a copy with one changed.
(def %f-type (fn (_ f) (List ref 1 f)))
(def %f-name (fn (_ f) (List ref 2 f)))
(def %f-value (fn (_ f) (List ref 3 f)))
(def %f-on (fn (_ f) (List ref 4 f)))
(def %f-options (fn (_ f) (List ref 5 f)))
(def %f-form (fn (_ f) (List ref 6 f)))
(def %f-with-value
  (fn (_ f v) (list (lit field) (%f-type f) (%f-name f) v (%f-on f) (%f-options f) (%f-form f))))
(def %f-with-on
  (fn (_ f on) (list (lit field) (%f-type f) (%f-name f) (%f-value f) on (%f-options f) (%f-form f))))
(def %f-form-index (fn (_ f) (if (null? (%f-form f)) () (first (%f-form f)))))

; BLOCKS with every field replaced by (F K FIELD), K the field's number
; among the document's fields in order: the order the page files them in
; with the links, so a selected entry's field is found by counting.
(def %map-fields
  (fn (_ blocks f)
    (def k (Vector of 0))
    (def inlines
      (fn (self xs)
        (List map
          (fn (_ x)
            (match
              ((str? x) x)
              ((eq? (first x) (lit field))
                ((fn (_ n) (Vector set! 0 (+ n 1) k) (f n x)) (Vector ref 0 k)))
              ((eq? (first x) (lit link)) (list (lit link) (List ref 1 x) (List ref 2 x) (self (List ref 3 x))))
              ((match ((eq? (first x) (lit emph)) #t) ((eq? (first x) (lit strong)) #t) (#t #f))
                (list (first x) (self (List ref 1 x))))
              (#t x)))
          xs)))
    ((fn (self bs)
       (List map
         (fn (_ b)
           (match
             ((eq? (first b) (lit heading)) (list (lit heading) (List ref 1 b) (inlines (List ref 2 b))))
             ((eq? (first b) (lit paragraph)) (list (lit paragraph) (inlines (List ref 1 b))))
             ((eq? (first b) (lit block-quote)) (list (lit block-quote) (self (List ref 1 b))))
             ((eq? (first b) (lit list))
               (list (lit list) (List ref 1 b) (List ref 2 b) (List ref 3 b)
                     (List map (fn (_ item) (self item)) (List ref 4 b))))
             (#t b)))
         bs))
     blocks)))

; DOC with BLOCKS in place of its own.
(def %with-blocks
  (fn (_ doc blocks)
    (if (eq? (first doc) (lit html)) (pair (lit html) (pair (first (rest doc)) blocks)) (pair (lit markdown) blocks))))

; The selected entry's number among the page's fields.
(def %field-ordinal
  (fn (_ b)
    (def w (%window b))
    (List count-if (fn (_ l) (not (str? (first l)))) (List take (Window selected w) (Page links (Window page w))))))

; The current tab's document with its fields mapped through F, shown
; again where it was, the selection kept.
(def %edit-fields!
  (fn (_ b f)
    (def s (%state b))
    (def w (%window b))
    (def doc (%with-blocks (Vector ref 1 s) (%map-fields (doc-blocks (Vector ref 1 s)) f)))
    (Vector set! 1 doc s)
    (%show! b w (Vector ref 0 s) doc (Window top w) (Window selected w))))

; Whether Y is a radio button of X's group: the same name in the same form.
(def %same-group?
  (fn (_ x y)
    (match ((not (eq? (%f-type y) (lit radio))) #f)
           ((null? (%f-name x)) #f)
           ((null? (%f-name y)) #f)
           ((not (str=? (%f-name x) (%f-name y))) #f)
           (#t (eq? (%f-form-index x) (%f-form-index y))))))

; The value of the option after F's, the first after the last.
(def %next-option
  (fn (_ f)
    (def opts (%f-options f))
    (if (null? opts) (%f-value f)
      ((fn (self os)
         (match ((null? os) (first (first opts)))
                ((str=? (first (first os)) (%f-value f))
                  (if (null? (rest os)) (first (first opts)) (first (first (rest os)))))
                (#t (self (rest os)))))
       opts))))

; The (NAME . VALUE) pairs the form numbered FORM sends from BLOCKS: its
; named fields in order, a checkbox or radio button only when on, a
; submit button only the one pressed, field PRESSED.
(def %form-params
  (fn (_ blocks form pressed)
    (def out (Vector of ()))
    (def add! (fn (_ y) (Vector set! 0 (pair (pair (%f-name y) (%f-value y)) (Vector ref 0 out)) out)))
    (%map-fields blocks
      (fn (_ j y)
        (when (if (null? (%f-name y)) #f (eq? (%f-form-index y) form))
          ((fn (_ t)
             (match ((eq? t (lit submit)) (when (= j pressed) (add! y)))
                    ((match ((eq? t (lit checkbox)) #t) (#t (eq? t (lit radio)))) (when (%f-on y) (add! y)))
                    (#t (add! y))))
           (%f-type y)))
        y))
    (List reverse (Vector ref 0 out))))

; URL with PARAMS as its query, in place of any it has.
(def %with-query
  (fn (_ url params)
    (def q (Str8 index-of "?" url))
    (Str8 append (if (null? q) url (Str8 sub 0 q url)) "?" (doc-query params))))

; Where the form of the submit button X, field PRESSED, sends: its
; action resolved against the document, with the query for GET.
(def %form-target
  (fn (_ b x pressed)
    (def form (%f-form x))
    (def action (first (doc-fragment (doc-resolve (Vector ref 0 (%state b)) (List ref 1 form)))))
    (if (eq? (List ref 2 form) (lit post)) action
      (%with-query action (%form-params (doc-blocks (Vector ref 1 (%state b))) (first form) pressed)))))

(def %submit!
  (fn (_ b x k where)
    (def form (%f-form x))
    (if (null? form) (%say! b "a button in no form")
      (if (eq? (List ref 2 form) (lit post))
        (browse-open! b (%form-target b x k) where (lit post)
                      (doc-query (%form-params (doc-blocks (Vector ref 1 (%state b))) (first form) k)))
        (browse-open! b (%form-target b x k) where)))))

; Enter on the selected field X.
(def %act-field!
  (fn (_ b x where)
    (def k (%field-ordinal b))
    (def t (%f-type x))
    (match
      ((eq? t (lit checkbox)) (%edit-fields! b (fn (_ j y) (if (= j k) (%f-with-on y (not (%f-on y))) y))))
      ((eq? t (lit radio))
        (%edit-fields! b (fn (_ j y) (match ((= j k) (%f-with-on y #t)) ((%same-group? x y) (%f-with-on y #f)) (#t y)))))
      ((eq? t (lit select)) (%edit-fields! b (fn (_ j y) (if (= j k) (%f-with-value y (%next-option y)) y))))
      ((eq? t (lit submit)) (%submit! b x k where))
      (#t (%put! b 5 (pair (lit field) (%f-value x)))))))

; What the status line says of the selected field X: what it is and its
; name, or for a submit button where its form sends.
(def %describe
  (fn (_ b x)
    (def t (%f-type x))
    (def named (if (null? (%f-name x)) "" (Str8 append " \"" (%f-name x) "\"")))
    (match
      ((eq? t (lit submit))
        (if (null? (%f-form x)) "a button in no form"
          (Str8 append (if (eq? (List ref 2 (%f-form x)) (lit post)) "POST " "") (%form-target b x (%field-ordinal b)))))
      ((eq? t (lit checkbox)) (Str8 append "checkbox" named))
      ((eq? t (lit radio)) (Str8 append "radio button" named))
      ((eq? t (lit select)) (Str8 append "select" named))
      ((eq? t (lit textarea)) (Str8 append "text area" named))
      ((eq? t (lit password)) (Str8 append "password field" named))
      (#t (Str8 append "text field" named)))))

; Where the selected link goes, or what the selected field is; nil with
; none selected.
(def %target
  (fn (_ b)
    (def l (Window link (%window b)))
    (match ((null? l) ())
           ((str? (first l)) (doc-resolve (Vector ref 0 (%state b)) (first l)))
           (#t (%describe b (first l))))))

(def %follow!
  (fn (_ b where)
    (def l (Window link (%window b)))
    (match
      ((null? l) (%say! b "no link selected"))
      ((not (str? (first l))) (%act-field! b (first l) where))
      ((if (eq? where (lit here)) (Str8 starts? "#" (first l)) #f)
        (%go-fragment! b (%window b) (first l)))
      (#t (browse-open! b (doc-resolve (Vector ref 0 (%state b)) (first l)) where)))))

(def %close!
  (fn (_ b)
    (if (< (Tabs count (%tabs b)) 2) (%say! b "the last tab stays open: q quits")
      ((fn (_ k)
         (%put! b 1 (List append (List take k (%get b 1)) (List drop (+ k 1) (%get b 1))))
         (Tabs close (%tabs b) k))
       (%index b)))))

; Every tab laid out again, ROWS by COLS.
(def browse-resize!
  (fn (_ b rows cols)
    (%put! b 2 rows)
    (%put! b 3 cols)
    (%put! b 8 #t)
    ((fn (self k states)
       (unless (null? states)
         (do (Window show (Tabs window (%tabs b) k) (%page (Vector ref 1 (first states)) cols) (%body-rows b))
             (self (+ k 1) (rest states)))))
     0 (%get b 1))))

(def browse-make
  (fn (_ rows cols . loader)
    (def b (Vector make 11 ()))
    (%put! b 0 (Tabs make))
    (%put! b 2 rows)
    (%put! b 3 cols)
    (%put! b 6 #f)
    (%put! b 7 (if (null? loader) doc-load (first loader)))
    (%put! b 8 #t)
    b))

; --- keys --------------------------------------------------------------------

(def %key? (fn (_ key names) (List any? (fn (_ n) (if (str? n) (if (str? key) (str=? key n) #f) (eq? key n))) names)))

; TEXT without its last character.
(def %chop
  (fn (_ text)
    ((fn (self i)
       (if (< i 1) ""
         (if (= (%and (Char ->int (Str8 ref (- i 1) text)) 192) 128) (self (- i 1)) (Str8 sub 0 (- i 1) text))))
     (Str8 length text))))

; --- searching ---------------------------------------------------------------

; The line of PAGE, from I onwards in direction D (1 down, -1 up), whose
; text has TEXT in it, any case; nil with none.
(def %find
  (fn (self page text i d)
    (match ((< i 0) ())
           ((< (Page count page) (+ i 1)) ())
           ((Str8 includes? text (Str8 downcase (Page line-text page i))) i)
           (#t (self page text (+ i d) d)))))

; The next match (D 1) or the previous (D -1) of the text last searched
; for, put on the first row: past the last match while it is on the
; screen, else from the screen's top line.
(def %search-on!
  (fn (_ b d)
    (def w (%window b))
    (def n (%body-rows b))
    (def top (Window top w))
    (def m (%get b 10))
    (def shown? (if (null? m) #f (if (< m top) #f (< m (+ top n)))))
    (def line
      (%find (Window page w) (Str8 downcase (%get b 9)) (match (shown? (+ m d)) ((< d 0) (- top 1)) (#t top)) d))
    (if (null? line) (%say! b (Str8 append "not found " (if (< d 0) "above" "below") ": " (%get b 9)))
      (do (%put! b 10 line) (Window go w line n)))))

(def %search-next!
  (fn (_ b d)
    (if (null? (%get b 9)) (%say! b "nothing to search for") (%search-on! b d))))

; TEXT searched for from the screen's top line; an empty TEXT is the
; last one again.
(def %search!
  (fn (_ b text)
    (unless (str=? text "") (%put! b 9 text))
    (%put! b 10 ())
    (%search-next! b 1)))

(def %ask-key!
  (fn (_ b key)
    (def q (%get b 5))
    (match
      ((%key? key (list (lit enter)))
        (do (%put! b 5 ())
            (match ((eq? (first q) (lit search)) (%search! b (rest q)))
                   ((eq? (first q) (lit field))
                     ((fn (_ k) (%edit-fields! b (fn (_ j y) (if (= j k) (%f-with-value y (rest q)) y))))
                      (%field-ordinal b)))
                   ((str=? (rest q) "") ())
                   (#t (browse-open! b (rest q) (first q))))))
      ((%key? key (list (lit escape) (lit abort) (lit interrupt))) (%put! b 5 ()))
      ((%key? key (list (lit backspace))) (%put! b 5 (pair (first q) (%chop (rest q)))))
      ((str? key) (%put! b 5 (pair (first q) (Str8 append (rest q) key))))
      (#t ()))))

(def %scroll! (fn (_ b n) (Window scroll (%window b) n (%body-rows b))))

; KEY taken: a string of text typed, or a key's name, as (Term key)
; answers them.
(def browse-key!
  (fn (_ b key)
    (%say! b ())
    (if (null? (%get b 5))
      (do
        (def n (%body-rows b))
        (match
          ((%key? key (list "q" (lit interrupt))) (%put! b 6 #t))
          ((%key? key (list "j" (lit down))) (%scroll! b 1))
          ((%key? key (list "k" (lit up))) (%scroll! b -1))
          ((%key? key (list " " "f" (lit page-down))) (%scroll! b n))
          ((%key? key (list "b" (lit page-up))) (%scroll! b (- 0 n)))
          ((%key? key (list "d")) (%scroll! b (%quot (+ n 1) 2)))
          ((%key? key (list "u")) (%scroll! b (- 0 (%quot (+ n 1) 2))))
          ((%key? key (list "g" (lit home))) (Window go (%window b) 0 n))
          ((%key? key (list "G" (lit end))) (Window go (%window b) (Page count (Window page (%window b))) n))
          ((%key? key (list (lit complete)))
            (when (null? (Window next-link (%window b) n)) (%say! b "no more links")))
          ((%key? key (list "p"))
            (when (null? (Window prev-link (%window b) n)) (%say! b "no more links")))
          ((%key? key (list "/" (lit search-forward))) (%put! b 5 (pair (lit search) "")))
          ((%key? key (list "n")) (%search-next! b 1))
          ((%key? key (list "N")) (%search-next! b -1))
          ((%key? key (list "l" (lit enter) (lit right))) (%follow! b (lit here)))
          ((%key? key (list "t")) (%follow! b (lit tab)))
          ((%key? key (list "h" (lit left) (lit backspace))) (%back! b))
          ((%key? key (list "o")) (%put! b 5 (pair (lit here) "")))
          ((%key? key (list "O")) (%put! b 5 (pair (lit tab) "")))
          ((%key? key (list "r")) (%reload! b))
          ((%key? key (list "]" ">")) (Tabs next (%tabs b)))
          ((%key? key (list "[" "<")) (Tabs prev (%tabs b)))
          ((%key? key (list "1" "2" "3" "4" "5" "6" "7" "8" "9"))
            (Tabs select (%tabs b) (- (Char ->int (Str8 ref 0 key)) 49)))
          ((%key? key (list "x")) (%close! b))
          ((%key? key (list "?" (lit f1))) (browse-open! b "about:help" (lit tab)))
          ((%key? key (list (lit clear))) (%put! b 8 #t))
          (#t ())))
      (%ask-key! b key))
    b))

(def browse-quit? (fn (_ b) (%get b 6)))
(def browse-tabs (fn (_ b) (%tabs b)))
(def browse-location (fn (_ b) (if (null? (%state b)) () (Vector ref 0 (%state b)))))
(def browse-message (fn (_ b) (%get b 4)))

; Whether the whole screen is to be drawn again, asked once.
(def browse-repaint?
  (fn (_ b)
    (def r (%get b 8))
    (%put! b 8 #f)
    r))

; --- drawing -----------------------------------------------------------------

; The bytes of S, from I, that fit in W columns: their end.
(def %fit
  (fn (self s i w)
    (match ((= i (Str8 length s)) i)
           ((< w (char-width (utf8-cp-at s i))) i)
           (#t (self s (+ i (utf8-width s i)) (- w (char-width (utf8-cp-at s i))))))))
(def %cut (fn (_ s w) (if (< w 1) "" (Str8 sub 0 (%fit s 0 w) s))))

; S's end that fits in W columns, led by an ellipsis when its start is
; left out: a location's end says the most.
(def %cut-start
  (fn (_ s w)
    (if (< (text-width s) (+ w 1)) s
      ((fn (self i)
         (match ((= i (Str8 length s)) "")
                ((= (%and (Char ->int (Str8 ref i s)) 192) 128) (self (+ i 1)))
                ((< (text-width (Str8 sub i (- (Str8 length s) i) s)) w)
                  (Str8 append "\xe2\x80\xa6" (Str8 sub i (- (Str8 length s) i) s)))
                (#t (self (+ i 1)))))
       0))))

(def %status-style (Style make (lit (bold)) () ()))

; The last row: on the left a question, a message, the selected link's
; target or the location; on the right the lines shown and how many.
(def %draw-status!
  (fn (_ b screen)
    (def row (- (%rows b) 1))
    (def cols (%cols b))
    (def q (%get b 5))
    (def w (%window b))
    (def right
      (if (null? w) ""
        ((fn (_ count)
           (Str8 append " " (%number->str (if (= count 0) 0 (+ (Window top w) 1))) "-"
                     (%number->str (%min count (+ (Window top w) (%body-rows b)))) "/" (%number->str count)))
         (Page count (Window page w)))))
    (def left
      (match ((not (null? q))
               (Str8 append (match ((eq? (first q) (lit tab)) "Open in a new tab: ")
                                   ((eq? (first q) (lit search)) "Search: ")
                                   ((eq? (first q) (lit field))
                                     ((fn (_ n) (if (null? n) "Text: " (Str8 append n ": ")))
                                      (%f-name (first (Window link w)))))
                                   (#t "Open: "))
                            (rest q)))
             ((not (null? (%get b 4))) (%get b 4))
             ((null? w) "")
             ((not (null? (Window selected w))) (%target b))
             (#t (browse-location b))))
    (Screen fill screen row 0 cols 0)
    (if (null? q)
      (do (Screen put screen row 0
            ((if (null? (%get b 4)) %cut-start %cut) left (- cols (+ (text-width right) 1)))
            (if (null? (%get b 4)) 0 %status-style))
          (Screen put screen row (- cols (text-width right)) right 0)
          (Screen cursor screen row (- cols 1)))
      ((fn (_ shown)
         (Screen put screen row 0 shown 0)
         (Screen cursor screen row (%min (text-width shown) (- cols 1))))
       ; the end of the question is what is being typed
       ((fn (_ over) (if (< 0 over) (Str8 sub over (- (Str8 length left) over) left) left))
        (- (Str8 length left) (- cols 1)))))))

(def browse-draw!
  (fn (_ b screen)
    (Tabs draw (%tabs b) screen 0 (- (%rows b) 1))
    (%draw-status! b screen)
    screen))

(provide browse/browser browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit?
  browse-repaint? browse-tabs browse-location browse-message)
