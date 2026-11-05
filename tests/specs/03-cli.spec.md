# The command line
# @weight 1

browse/cli declares its options to the platform's Opts: what parse
accepts is what usage prints, in short and --long spellings.


## the declaration

### the usage names every option, short and long

```browse
(def text (Opts usage browse-options))
(write (List map (fn (_ s) (Str8 includes? s text)) (list "-d,--dump" "-w,--width" "-V,--version" "-h,--help" "x -l browse --")))
```
---
    (#t #t #t #t #t)

### short, long and --long=value spell one option; locations pass through; an unknown option is named

```browse
(import x/sys/opts)
(def o1 (Opts parse browse-options (list "-d" "-w" "40" "a.md")))
(def o2 (Opts parse browse-options (list "--dump" "--width=40" "a.md" "b.md")))
(def o3 (Opts parse browse-options (list "-dump" "a.md")))
(write (list (Opts on? o1 "-d") (Opts value o1 "-w") (Opts operands o1)
             (Opts on? o2 "-d") (Opts value o2 "-w") (Opts operands o2)
             (Opts unknown o3)))
```
---
    (#t "40" ("a.md") #t "40" ("a.md" "b.md") "-dump")
