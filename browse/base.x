; # x-browse -- a terminal browser on x-lang
;
; ## browse/base.x -- what the entry and the specs reach
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)

(provide browse/base browse-version browse-main browse-dump
  doc-scheme? doc-web? doc-fragment doc-resolve doc-slug doc-load doc-at doc-blocks doc-title doc-query
  browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit? browse-tabs
  browse-location browse-message)

(import browse/doc doc-scheme? doc-web? doc-fragment doc-resolve doc-slug doc-load doc-at doc-blocks doc-title doc-query)
(import browse/dump browse-dump)
(import browse/browser browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit?
  browse-tabs browse-location browse-message)
(import browse/cli browse-main browse-version)
