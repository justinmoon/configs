;; colorscheme.scm - apply the active theme selected by bin/colorscheme
(require (prefix-in helix. "helix/commands.scm"))
(require "helix/misc.scm")
(require "steel/result")
(require-builtin steel/filesystem)
(require-builtin steel/strings)

(provide init-colorscheme
         colorscheme-reload)

(define DEFAULT-SCHEME "nord")

(define (maybe-env var)
  (let ([result (maybe-get-env-var var)])
    (and (Ok? result) (trim (unwrap-ok result)))))

(define (state-root)
  (or (maybe-env "XDG_STATE_HOME")
      (let ([home (maybe-env "HOME")])
        (and home (string-append home "/.local/state")))))

(define (state-path name)
  (let ([root (state-root)])
    (and root (string-append root "/colorscheme/" name))))

(define (read-first-line path)
  (and path
       (path-exists? path)
       (with-handler
         (lambda (_err) #f)
         (with-input-from-file path
           (lambda ()
             (let ([line (read-line)])
               (if (eof-object? line)
                   #f
                   (trim line))))))))

(define (theme-from-state)
  (let ([value (read-first-line (state-path "current"))])
    (if (and value (> (string-length value) 0))
        value
        DEFAULT-SCHEME)))

(define (apply-colorscheme-from-state)
  (let ([theme (theme-from-state)])
    (helix.theme theme)
    theme))

(define (init-colorscheme)
  ;; Defer theme loading using callback to avoid terminal SIXEL blocking
  (enqueue-thread-local-callback
    (lambda ()
      (apply-colorscheme-from-state)
      (void)))
  (void))

(define (colorscheme-reload)
  (let ([theme (apply-colorscheme-from-state)])
    (displayln (string-append "[colorscheme] helix theme -> " theme))
    theme))
