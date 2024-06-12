;; Simplified AI Assistant for Helix
;; Uses helix commands to pipe selection through AI tool

(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")

(define (current-file-path)
  ;; Mirror upstream current-path helper so we avoid relying on deprecated cx-> API
  (with-handler
    (lambda (_err) #f)
    (let* ([focus (editor-focus)]
           [doc-id (editor->doc-id focus)])
      (editor-document->path doc-id))))

(provide ai-simple-assist)

;; Simple AI assistant that prompts for input and inserts a canned response
;; This is a starting point - real implementation would shell out to llm/AI tool
(define (ai-simple-assist)
  (push-component!
    (prompt "AI Request: "
      (lambda (user-input)
        (when (> (string-length user-input) 0)
          ;; Get current selection for context - use empty string if none
          (define selection "")  ;; TODO: get actual selection
          (define file-path (current-file-path))
          
          ;; Show thinking message
          (set-status! (string-append "AI thinking about: " user-input))
          
          ;; For now, insert a response that shows we got the input
          ;; In real version, this would shell out to llm command
          (helix.static.insert_mode)
          (helix.static.insert_string 
            (string-append 
              "\n;; AI Response to: " user-input "\n"
              ";; Context: " (if file-path file-path "no file") "\n"
              ";; Selection: " (substring selection 0 (min 50 (string-length selection))) "...\n"
              ";; TODO: Implement actual AI call via shell pipe\n"))
          (helix.static.command_mode)
          
          (set-status! "AI response inserted (demo mode)"))))))
