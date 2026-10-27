; # x-links -- a terminal browser on x-lang
;
; ## links/browse.x -- tabs of documents, the keys, and what is drawn
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
; a message, or a question being typed.  Nothing here touches a
; terminal, so a spec drives it with keys and reads the screen back.
;
; Documents are loaded by the browser's loader, (doc-load LOC) unless
; one is given: a spec loads from a list instead.

(module links/browse)

(import x/type/vector)
(import x/codec/utf8 utf8-cp-at utf8-width)
(import x/tui/width char-width text-width)
(import x/tui/style)
(import x/tui/screen)
(import x/tui/page)
(import x/tui/window)
(import x/tui/tabs)
(import links/doc doc-resolve doc-fragment doc-slug doc-load doc-title)

; A browser is a vector: 0 the tabs, 1 each tab's state in the tabs'
; order, 2 rows, 3 columns, 4 the message shown, 5 the question being
; asked, 6 whether to quit, 7 the loader, 8 whether the screen is to be
; drawn whole.  A tab's state is a vector: 0 the location, 1 the
; document, 2 the history, newest first, each (LOCATION DOCUMENT TOP
; SELECTED).  A question is (WHERE . TEXT): WHERE here or tab.
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
    (if (eq? (first doc) (lit markdown)) (Page markdown (rest doc) width) (Page text (rest doc) width))))

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

; LOC's document, or nil with the reason said.
(def %load
  (fn (_ b loc)
    (guard (e (do (%say! b (Str8 append (%err-text e) ": " loc)) ()))
      ((%get b 7) loc))))

(def %show!
  (fn (_ b w loc doc top selected)
    (Window show w (%page doc (%cols b)) (%body-rows b))
    (Window retitle w (doc-title loc doc))
    (Window go w top (%body-rows b))
    (Window select w selected (%body-rows b))))

; LOC opened: WHERE here replaces the current tab's document, keeping
; the one it had in the tab's history; tab adds a tab for it.  Answers
; whether it opened.
(def browse-open!
  (fn (_ b loc where)
    (def doc (%load b loc))
    (unless (null? doc)
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
            (%go-fragment! b w loc))))
    (not (null? doc))))

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
    (def doc (%load b (Vector ref 0 s)))
    (unless (null? doc)
      (do (Vector set! 1 doc s)
          ((fn (_ w) (%show! b w (Vector ref 0 s) doc (Window top w) (Window selected w))) (%window b))))))

; Where the selected link goes, or nil with none selected.
(def %target
  (fn (_ b)
    (def l (Window link (%window b)))
    (if (null? l) () (doc-resolve (Vector ref 0 (%state b)) (first l)))))

(def %follow!
  (fn (_ b where)
    (def l (Window link (%window b)))
    (match
      ((null? l) (%say! b "no link selected"))
      ((if (eq? where (lit here)) (Str8 starts? "#" (first l)) #f)
        (%go-fragment! b (%window b) (first l)))
      (#t (browse-open! b (%target b) where)))))

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
    (def b (Vector make 9 ()))
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

(def %ask-key!
  (fn (_ b key)
    (def q (%get b 5))
    (match
      ((%key? key (list (lit enter)))
        (do (%put! b 5 ())
            (unless (str=? (rest q) "") (browse-open! b (rest q) (first q)))))
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
          ((%key? key (list "n" (lit complete)))
            (when (null? (Window next-link (%window b) n)) (%say! b "no more links")))
          ((%key? key (list "p" "N"))
            (when (null? (Window prev-link (%window b) n)) (%say! b "no more links")))
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
      (match ((not (null? q)) (Str8 append (if (eq? (first q) (lit tab)) "Open in a new tab: " "Open: ") (rest q)))
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

(provide links/browse browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit?
  browse-repaint? browse-tabs browse-location browse-message)
