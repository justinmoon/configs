;; init.scm - runs when Helix starts
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/configuration.scm")
(require "helix/keymaps.scm")

;; Load our custom commands
;; (require "./helix.scm")
(require "./colorscheme.scm")
;; (require "./ai-simple.scm")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(init-colorscheme)

;;;;;;;;;;;;;;;;;;;;;;;;;; Options ;;;;;;;;;;;;;;;;;;;;;;;;;;;

(file-picker (fp-hidden #f))
(cursorline #t)
(soft-wrap (sw-enable #t))

;;;;;;;;;;;;;;;;;;;;;;;;;; Keybindings ;;;;;;;;;;;;;;;;;;;;;;;

;; Use keymap syntax instead of add-global-keybinding
;; (keymap (global)
;;         (normal (C-t ":insert-timestamp")
;;                 (C-b ":file-tree-open")
;;                 (C-a ":ai-simple-assist")))

;; Steel language server gives inline docs while authoring plugins
(define-lsp "steel-language-server" (command "steel-language-server") (args '()))

;; New language definition
(define-language "scheme"
                 (formatter (command "raco") (args '("fmt" "-i")))
                 (auto-format #true)
                 (language-servers '("steel-language-server")))
