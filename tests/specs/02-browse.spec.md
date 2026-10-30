# The browser
# @weight 1

browse/browser driven by keys, as (Term key) decodes them, on a small
site of Markdown held in a list; what it draws read back a row at a
time: the tab bar, the window, and the status line.


## moving

### the first screen, then a line down and to the bottom

```browse
(write (list (spec-screen (spec-browse 6 24 spec-pages "home.md" ()) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list "j")) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list "G")) 6 24)))
```
---
    ((" 1 Home" "Home" "" "See one and two." "" "home.md           1-4/11") (" 1 Home" "" "See one and two." "" "line" "home.md           2-5/11") (" 1 Home" "" "line" "" "last" "home.md          8-11/11"))

## links

### Tab selects a link and the status line shows where it goes; Enter follows it, Left comes back

```browse
(write (list (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete)) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete 'enter)) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete 'enter 'left)) 6 24)
             (browse-message (spec-browse 6 24 spec-pages "home.md" (list 'left)))))
```
---
    ((" 1 Home" "Home" "" "See one and two." "" "one.md            1-4/11") (" 1 One" "One" "" "Back home." "" "one.md             1-3/3") (" 1 Home" "Home" "" "See one and two." "" "one.md            1-4/11") "nothing to go back to")

### a link's fragment goes to the heading of that slug

```browse
(write (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete 'complete 'enter)) 6 24))
```
---
    (" 1 Two" "" "Later" "" "end" "two.md#later     8-11/11")

## tabs

### t opens a link in a new tab; ] and [ move between them; x closes one

```browse
(def b (spec-browse 6 30 spec-pages "home.md" (list 'complete "t")))
(def at (fn (_) (list (List ref 0 (spec-screen b 6 30)) (browse-location b))))
(write (list (at) (do (browse-key! b "[") (at)) (do (browse-key! b "]") (at))
             (do (browse-key! b "x") (at)) (do (browse-key! b "x") (browse-message b))))
```
---
    ((" 1 Home         2 One" "one.md") (" 1 Home         2 One" "home.md") (" 1 Home         2 One" "one.md") (" 1 Home" "home.md") "the last tab stays open: q quits")

## asking

### o asks for a location; Enter opens it, a missing one is said

```browse
(def b (spec-browse 6 30 spec-pages "home.md" (list "o" "t" "w" "o" ".")))
(write (list (List ref 5 (spec-screen b 6 30))
             (do (List for-each (fn (_ k) (browse-key! b k)) (list "m" "d" 'enter)) (browse-location b))
             (do (List for-each (fn (_ k) (browse-key! b k)) (list "o" "n" "o" 'enter)) (List ref 5 (spec-screen b 6 30)))
             (browse-quit? (browse-key! b "q"))))
```
---
    ("Open: two." "two.md" "no such file: no        1-4/11" #t)

## the status line

### a location too long for it keeps its end

```browse
(write (List ref 5 (spec-screen (spec-browse 6 24 (list (pair "a/very/long/path/to/home.md" (rest (first spec-pages)))) "a/very/long/path/to/home.md" ()) 6 24)))
```
---
    "…path/to/home.md  1-4/11"

## paging

### PgDn and PgUp move a page, as Space and b do

```browse
(write (list (List ref 1 (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'page-down)) 6 24))
             (List ref 1 (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'page-down 'page-up)) 6 24))))
```
---
    ("line" "Home")

## searching

### / asks for text; Enter finds it from the top, any case; n and N move between matches

```browse
(def b (spec-browse 6 24 spec-pages "home.md" (list "/" "LINE")))
(def row (fn (_ k) (List ref k (spec-screen b 6 24))))
(write (list (row 5)
             (do (browse-key! b 'enter) (row 1))
             (do (browse-key! b "n") (browse-key! b "n") (row 5))
             (do (browse-key! b "n") (browse-message b))
             (do (browse-key! b "N") (row 5))
             (do (browse-key! b "N") (browse-key! b "N") (browse-message b))))
```
---
    ("Search: LINE" "line" "home.md          8-11/11" "not found below: LINE" "home.md          7-10/11" "not found above: LINE")

### n before any search says so; / with nothing typed searches for the last text again

```browse
(def b (spec-browse 6 24 spec-pages "home.md" (list "n")))
(write (list (browse-message b)
             (do (List for-each (fn (_ k) (browse-key! b k)) (list "/" "last" 'enter "g" "/" 'enter))
                 (List ref 4 (spec-screen b 6 24)))))
```
---
    ("nothing to search for" "last")

## forms

### fields are selected as links are and drawn as lynx draws them; Enter on a text field asks for its text, on a checkbox turns it on, on a select moves to its next option

```browse
(def b (spec-browse 6 40 spec-forms "form.html" (list 'complete)))
(def row (fn (_ k) (List ref k (spec-screen b 6 40))))
(def keys (fn (_ ks) (List for-each (fn (_ k) (browse-key! b k)) ks)))
(write (list (row 0) (row 1) (row 3) (row 5)
             (do (keys (list 'enter "d" "u")) (row 5))
             (do (keys (list 'enter)) (row 1))
             (do (keys (list 'complete)) (row 5))
             (do (keys (list 'enter 'complete 'enter 'enter)) (row 1))
             (do (keys (list 'complete)) (row 5))))
```
---
    (" 1 Ask" "Q: ____________________ [ ] [a] [Go]" "(*) ( ) [Send]" "text field \"q\"                     1-3/3" "q: du" "Q: du__________________ [ ] [a] [Go]" "checkbox \"c\"                       1-3/3" "Q: du__________________ [X] [a] [Go]" "found.md?q=du&c=1&s=a              1-3/3")

### Enter on a button sends the form by GET, the fields as the query; back finds the values kept; Esc leaves a text field as it was

```browse
(def b (spec-browse 6 40 spec-forms "form.html" (list 'complete 'enter "d" "u" 'enter 'complete 'enter 'complete 'complete 'enter)))
(def row (fn (_ k) (List ref k (spec-screen b 6 40))))
(write (list (browse-location b) (row 1)
             (do (browse-key! b 'left) (list (browse-location b) (row 1)))
             (do (List for-each (fn (_ k) (browse-key! b k)) (list "p" "p" "p" 'enter "x" 'escape)) (row 1))))
```
---
    ("found.md?q=du&c=1&s=a" "Found" ("form.html" "Q: du__________________ [X] [a] [Go]") "Q: du__________________ [X] [a] [Go]")

### a radio button turns the others of its group off; a form sent by POST goes through the loader with its body

```browse
(def b (spec-browse 6 40 spec-forms "form.html" (list 'complete 'complete 'complete 'complete 'complete 'complete 'enter)))
(def row (fn (_ k) (List ref k (spec-screen b 6 40))))
(write (list (row 3) (do (browse-key! b 'complete) (row 5))
             (do (browse-key! b 'enter) (list (browse-location b) (row 1) (row 3)))))
```
---
    ("( ) (*) [Send]" "POST in.md                         1-3/3" ("in.md" "Sent" "post r=y&b=1"))
