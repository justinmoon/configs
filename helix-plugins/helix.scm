;; Main helix.scm - defines commands available to Helix
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")

;; Simple example command - insert current timestamp
(provide insert-timestamp)

(define (insert-timestamp)
  (helix.static.insert_mode)
  (helix.static.insert_string "STEEL-OK")
  (helix.static.command_mode))

;; You can add more commands here - just add (provide function-name) at the end
