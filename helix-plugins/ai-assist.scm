;; AI Coding Assistant for Helix
;; Provides AI-powered code editing via external AI tool

(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")

(provide ai-assist
         ai-edit-selection)

;; Configuration - set via environment or hardcode
(define *ai-command* "llm")  ; Can be "llm", "aider", or custom command
(define *ai-model* "gpt-4")   ; Model to use

;; Get current buffer content
(define (get-buffer-content)
  (current-selection->string))

;; Get current selection or word under cursor
(define (get-selection-or-context)
  (current-selection->string))

;; Get file path and language context
(define (get-file-context)
  (let ([path (cx->current-file)])
    (if path
        (string-append "File: " path "\n")
        "")))

;; Call AI via subprocess (using temporary file approach)
(define (call-ai prompt context)
  ;; Create a temporary file to store the prompt
  (define temp-prompt-file (string-append "/tmp/helix-ai-prompt-" (number->string (current-seconds))))
  (define temp-output-file (string-append "/tmp/helix-ai-output-" (number->string (current-seconds))))
  
  ;; Build the full prompt
  (define full-prompt 
    (string-append 
      "You are a coding assistant. Provide ONLY the code requested, no explanations unless asked.\n\n"
      context "\n\n"
      "Request: " prompt))
  
  ;; Write prompt to file (escaping for shell)
  (define write-cmd 
    (string-append "cat > " temp-prompt-file " << 'HELIX_AI_EOF'\n"
                   full-prompt "\n"
                   "HELIX_AI_EOF"))
  
  ;; Build AI command - using llm CLI
  (define ai-cmd
    (string-append "sh -c '"
                  write-cmd " && "
                  "llm -m " *ai-model* " < " temp-prompt-file " > " temp-output-file " && "
                  "cat " temp-output-file " && "
                  "rm -f " temp-prompt-file " " temp-output-file
                  "'"))
  
  ;; For now, return a placeholder since we can't execute shell directly
  ;; This needs to be implemented by calling Helix's shell-pipe command
  (string-append "AI response placeholder for: " prompt))

;; Escape quotes in strings for shell commands
(define (escape-quotes str)
  (string-replace str "\"" "\\\""))

;; Apply AI response to buffer
(define (apply-ai-response response)
  (cond
    ;; If response looks like a code block, extract it
    [(string-contains response "```")
     (let ([code (extract-code-block response)])
       (if code
           (helix.static.insert_string code)
           (helix.static.insert_string response)))]
    
    ;; Otherwise insert as-is
    [else (helix.static.insert_string response)]))

;; Extract code from markdown code blocks
(define (extract-code-block text)
  (let ([lines (string-split text "\n")])
    (define (find-code-block lines in-block? acc)
      (if (null? lines)
          (if (null? acc) #f (string-join (reverse acc) "\n"))
          (let ([line (car lines)])
            (cond
              [(string-prefix? line "```")
               (if in-block?
                   (string-join (reverse acc) "\n")  ; End of block
                   (find-code-block (cdr lines) #t acc))]  ; Start of block
              [in-block?
               (find-code-block (cdr lines) #t (cons line acc))]
              [else
               (find-code-block (cdr lines) #f acc)]))))
    (find-code-block lines #f '())))

;; Main AI assist command - opens prompt
(define (ai-assist)
  (push-component! 
    (prompt "AI: " 
      (lambda (user-prompt)
        (when (> (string-length user-prompt) 0)
          ;; Get context
          (define context (string-append
                          (get-file-context)
                          "\n"
                          (get-buffer-content)))
          
          ;; Show loading status
          (set-status! "AI thinking...")
          
          ;; Call AI (this will block - in production, should be async)
          (define response (call-ai user-prompt context))
          
          ;; Apply response
          (helix.static.insert_mode)
          (apply-ai-response response)
          (helix.static.command_mode)
          
          (set-status! "AI response applied"))))))

;; Edit selected text with AI
(define (ai-edit-selection)
  (define selection (get-selection-or-context))
  
  (if (= (string-length selection) 0)
      (set-error! "No selection to edit")
      (push-component!
        (prompt (string-append "Edit \"" (substring selection 0 (min 30 (string-length selection))) "...\": ")
          (lambda (instruction)
            (when (> (string-length instruction) 0)
              (define prompt (string-append 
                            "Edit this code according to: " instruction 
                            "\n\nCode:\n" selection
                            "\n\nProvide only the edited code, no explanation."))
              
              (set-status! "AI editing...")
              
              (define response (call-ai prompt selection))
              
              ;; Delete selection and insert AI response
              (helix.static.delete_selection)
              (helix.static.insert_mode)
              (apply-ai-response response)
              (helix.static.command_mode)
              
              (set-status! "Selection edited by AI")))))))

;; Helper: check if string contains substring
(define (string-contains str substr)
  (>= (string-search str substr) 0))

;; Helper: string-search returns index or -1
(define (string-search haystack needle)
  (define (search-from pos)
    (if (> (+ pos (string-length needle)) (string-length haystack))
        -1
        (if (equal? (substring haystack pos (+ pos (string-length needle))) needle)
            pos
            (search-from (+ pos 1)))))
  (search-from 0))

;; Helper: string-prefix?
(define (string-prefix? str prefix)
  (and (>= (string-length str) (string-length prefix))
       (equal? (substring str 0 (string-length prefix)) prefix)))

;; Helper: substring with bounds checking
(define (safe-substring str start end)
  (substring str start (min end (string-length str))))
