(require (prefix-in helix. "helix/commands.scm"))

(define (load-module module)
  (with-handler
    (lambda (err)
      (displayln "[helix-init] warning: failed to load module")
      (displayln module)
      (displayln err)
      void)
    (eval `(require ,module))
    void))

;; Override show-splash BEFORE loading upstream to disable the SIXEL logo
(provide show-splash)
(define (show-splash) void)

;; Temporarily disable extra plugin bundle until compatibility issues are resolved
;; (load-module "./helix.scm")
(load-module "./upstream-init.scm")
;; Temporarily skip local overrides while debugging input freeze
;; (load-module "./local/init.scm")
