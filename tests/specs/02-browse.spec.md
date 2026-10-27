# The browser
# @weight 1

links/browse driven by keys, as (Term key) decodes them, on a small
site of Markdown held in a list; what it draws read back a row at a
time: the tab bar, the window, and the status line.


## moving

### the first screen, then a line down and to the bottom

```links
(write (list (spec-screen (spec-browse 6 24 spec-pages "home.md" ()) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list "j")) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list "G")) 6 24)))
```
---
    ((" 1 Home" "Home" "" "See one and two." "" "home.md           1-4/11") (" 1 Home" "" "See one and two." "" "line" "home.md           2-5/11") (" 1 Home" "" "line" "" "last" "home.md          8-11/11"))

## links

### Tab selects a link and the status line shows where it goes; Enter follows it, Left comes back

```links
(write (list (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete)) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete 'enter)) 6 24)
             (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete 'enter 'left)) 6 24)
             (browse-message (spec-browse 6 24 spec-pages "home.md" (list 'left)))))
```
---
    ((" 1 Home" "Home" "" "See one and two." "" "one.md            1-4/11") (" 1 One" "One" "" "Back home." "" "one.md             1-3/3") (" 1 Home" "Home" "" "See one and two." "" "one.md            1-4/11") "nothing to go back to")

### a link's fragment goes to the heading of that slug

```links
(write (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'complete 'complete 'enter)) 6 24))
```
---
    (" 1 Two" "" "Later" "" "end" "two.md#later     8-11/11")

## tabs

### t opens a link in a new tab; ] and [ move between them; x closes one

```links
(def b (spec-browse 6 30 spec-pages "home.md" (list 'complete "t")))
(def at (fn (_) (list (List ref 0 (spec-screen b 6 30)) (browse-location b))))
(write (list (at) (do (browse-key! b "[") (at)) (do (browse-key! b "]") (at))
             (do (browse-key! b "x") (at)) (do (browse-key! b "x") (browse-message b))))
```
---
    ((" 1 Home         2 One" "one.md") (" 1 Home         2 One" "home.md") (" 1 Home         2 One" "one.md") (" 1 Home" "home.md") "the last tab stays open: q quits")

## asking

### o asks for a location; Enter opens it, a missing one is said

```links
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

```links
(write (List ref 5 (spec-screen (spec-browse 6 24 (list (pair "a/very/long/path/to/home.md" (rest (first spec-pages)))) "a/very/long/path/to/home.md" ()) 6 24)))
```
---
    "…path/to/home.md  1-4/11"

## paging

### PgDn and PgUp move a page, as Space and b do

```links
(write (list (List ref 1 (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'page-down)) 6 24))
             (List ref 1 (spec-screen (spec-browse 6 24 spec-pages "home.md" (list 'page-down 'page-up)) 6 24))))
```
---
    ("line" "Home")
