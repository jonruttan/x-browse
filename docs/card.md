# x-browse card

## Run

```sh
x -l browse -- [LOCATION ...]             # browse; a tab a location; q quits
x -l browse                               # the current directory
CMD | x -l browse -- -                    # a page piped in, shown as it comes
x -l browse -- -d [-w N] LOCATION         # the document as text, and exit
x -l browse -- -t FORMAT LOCATION         # the document in a format, and exit
x -l browse -- -d tests/fixtures/notes.txt | sed 1q -> plain text
x -l browse -- -V 2>&1 | tail -1 -> x-browse 0.1.0
x -l browse -- -d nosuchfile 2>&1 -> x-browse: no such file: nosuchfile
```

| Location               | Is                                               |
|------------------------|--------------------------------------------------|
| a path, `file://PATH`  | a file, or a directory as a list of its entries  |
| `http://` `https://`   | a page; https is x-lang's own TLS 1.3            |
| `data:TYPE,TEXT`       | the document in the url itself                   |
| `about:help`           | the keys                                         |
| `-`                    | standard input: HTML when it starts `<!doctype html` or `<html` |
| `.md` `.markdown`, `text/markdown` | read as Markdown                     |
| `.html` `.htm`, `text/html` | read as HTML                                |
| bytes starting `%PDF-` | a PDF: its text, as headings and paragraphs      |
| a PNG or a GIF         | an image, in half blocks                         |
| anything else          | text                                             |

## Dump

```sh
x -l browse -- -d tests/fixtures/index.md | sed -n 3p | cut -c1-9 -> A [1]page
x -l browse -- -d -w 30 tests/fixtures/index.md | sed -n 4p -> page.
x -l browse -- -d tests/fixtures/page.html | sed 1q -> Fixture Page
x -l browse -- -d tests/fixtures/hello.pdf | sed 1q -> A PDF fixture
x -l browse -- -d 'data:text/html,<b>Hi</b> there' -> Hi there
x -l browse -- -d 'data:text/html,<form><input value=a></form>' | tr -s _ -> a_
x -l browse -- -t markdown 'data:text/html,<h1>Hi</h1>' -> # Hi
x -l browse -- -t markdown tests/fixtures/page.html | sed 1q -> # Fixture Page
x -l browse -- -t no LICENSE 2>&1 | cut -d, -f1 -> x-browse: --to takes markdown
printf '<!doctype html><h1>Hi</h1>' | x -l browse -- -d - -> Hi
printf 'plain *text*' | x -l browse -- -d - -> plain *text*
```

| Option                 | Does                                             |
|------------------------|--------------------------------------------------|
| `-d`, `--dump`         | the document as text, as lynx's `-dump`          |
| `-w`, `--width N`      | columns for the dump: 80, 10 at least            |
| `-t`, `--to FORMAT`    | `text`, as the dump; `markdown`, `html` or `pdf` |
| `-V` `-h`              | the version; the help                            |
| `[1]` before a link    | its number in the list after the document        |
| a form's field         | drawn as the browser draws it                    |

## Keys

| Key                    | Does                                             |
|------------------------|--------------------------------------------------|
| `j` Down, `k` Up       | a line down; up                                  |
| Space `f` PgDn, `b` PgUp | a page down; up                                |
| `d` `u`                | half a page down; up                             |
| `g` Home, `G` End      | the top; the bottom                              |
| Tab, `p`               | the next link or field; the previous             |
| Enter Right `l`        | follow the link                                  |
| `t`                    | follow it in a new tab                           |
| Left `h` Backspace     | back                                             |
| `o` `O`                | open a location; in a new tab                    |
| `r`                    | load the document again                          |
| `/` Ctrl-S, `n` `N`    | search for text; the next match, the previous    |
| `]` `>`, `[` `<`       | the next tab; the previous                       |
| `1` to `9`, `x`        | that tab; close this tab                         |
| `i`                    | a page's images inline, or as links again        |
| `?`                    | the keys, in a new tab                           |
| Ctrl-L                 | draw the screen again                            |
| `q` Ctrl-C             | quit                                             |

## Forms

| Field                  | Drawn as, and Enter on it                        |
|------------------------|--------------------------------------------------|
| text                   | its text, padded with `_`; type its text         |
| a checkbox             | `[ ]` or `[X]`; turn it on or off                |
| a radio button         | `( )` or `(*)`; turn it on                       |
| a select               | its chosen option in brackets; the next option   |
| a file field           | a path; the file to send                         |
| a button               | its label in brackets; send the form             |
| a form sent by GET     | opens its action, the fields as the query        |
| by POST                | sends them as the body, urlencoded or multipart  |

## Differs

| Here                                        | In a web browser              |
|---------------------------------------------|-------------------------------|
| images are PNG or GIF, in half blocks       | JPEG and more, in pixels      |
| a GIF shows its first image                 | it moves                      |
| no cookies are kept                         | kept                          |
| no scripts run                              | run                           |
| no stylesheets apply                        | applied                       |

## More

| Where                          | What                                     |
|--------------------------------|------------------------------------------|
| `x -l browse -- about:help`    | the keys                                 |
| `README.md`                    | forms, images, https, what is not built yet |
| `tests/fixtures/`              | the documents this page's rows read      |
| `tests/specs/`                 | the documents, the browser, the options  |
