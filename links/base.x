; # x-links -- a terminal browser on x-lang
;
; ## links/base.x -- what the entry and the specs reach
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)

(provide links/base links-version links-main links-dump
  doc-scheme? doc-web? doc-fragment doc-resolve doc-slug doc-load doc-title
  browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit? browse-tabs
  browse-location browse-message)

(import links/doc doc-scheme? doc-web? doc-fragment doc-resolve doc-slug doc-load doc-title)
(import links/dump links-dump)
(import links/browse browse-make browse-open! browse-key! browse-resize! browse-draw! browse-quit?
  browse-tabs browse-location browse-message)
(import links/cli links-main links-version)
