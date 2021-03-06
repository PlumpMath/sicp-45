;Core of the evaluator
(define (ambeval exp env succeed fail)
  ((analyze exp) env succeed fail))

(define (analyze exp)
  (cond ((self-evaluating? exp) 
         (analyze-self-evaluating exp))
        ((quoted? exp) (analyze-quoted exp))
        ((variable? exp) (analyze-variable exp))
        ((assignment? exp) (analyze-assignment exp))
        ((definition? exp) (analyze-definition exp))
        ((if? exp) (analyze-if exp))
        ((lambda? exp) (analyze-lambda exp))
        ((begin? exp) (analyze-sequence (begin-actions exp)))
        ((cond? exp) (analyze (cond->if exp)))
        ((amb? exp) (analyze-amb exp))
        ;----------extra additions-------------------
        ((or? exp) (analyze-or exp))
        ;-----------4.22-----------------------------
        ((let? exp) (analyze (let->combination exp)))
        ;-----------4.50-----------------------------
        ((ramb? exp) (analyze-ramb exp))
        ;-----------4.51-----------------------------
        ((permanent-assignment? exp) (analyze-permanent-assignment exp))
        ;-----------4.52-----------------------------
        ((if-fail? exp) (analyze-if-fail exp))
        ;--------------------------------------------
        ((application? exp) (analyze-application exp))
        (else
         (error "Unknown expression type -- ANALYZE" exp))))

;---------------extra additions------------------
(define (analyze-or exp)
  (define (sequentially a b)
    (lambda (env succeed fail)
      (a env
         ;; success continuation for calling a
         (lambda (a-value fail2)
           (if a-value
               (succeed true fail2)
               (b env succeed fail2)))
         ;; failure continuation for calling a
         fail)))
  (define (loop first-proc rest-procs)
    (if (null? rest-procs)
        first-proc
        (loop (sequentially first-proc (car rest-procs))
              (cdr rest-procs))))
  (let ((procs (map analyze (or-operands exp))))
    (if (null? procs)
        (error "Empty sequence -- ANALYZE"))
    (loop (car procs) (cdr procs))))
;------------------------------------------------

(define (amb? exp) (tagged-list? exp 'amb))
(define (amb-choices exp) (cdr exp))

(define (analyze-self-evaluating exp)
  (lambda (env succeed fail)
    (succeed exp fail)))

(define (analyze-quoted exp)
  (let ((qval (text-of-quotation exp)))
    (lambda (env succeed fail)
      (succeed qval fail))))

(define (analyze-variable exp)
  (lambda (env succeed fail)
    (succeed (lookup-variable-value exp env)
             fail)))

(define (analyze-assignment exp)
  (let ((var (assignment-variable exp))
        (vproc (analyze (assignment-value exp))))
    (lambda (env succeed fail)
      (vproc env
             (lambda (val fail2)        ; *1*
               (let ((old-value
                      (lookup-variable-value var env))) 
                 (set-variable-value! var val env)
                 (succeed 'ok
                          (lambda ()    ; *2*
                            (set-variable-value! var
                                                 old-value
                                                 env)
                            (fail2)))))
             fail))))

(define (analyze-definition exp)
  (let ((var (definition-variable exp))
        (vproc (analyze (definition-value exp))))
    (lambda (env succeed fail)
      (vproc env                        
             (lambda (val fail2)
               (define-variable! var val env)
               (succeed 'ok fail2))
             fail))))

(define (analyze-if exp)
  (let ((pproc (analyze (if-predicate exp)))
        (cproc (analyze (if-consequent exp)))
        (aproc (analyze (if-alternative exp))))
    (lambda (env succeed fail)
      (pproc env
             ;; success continuation for evaluating the predicate
             ;; to obtain pred-value
             (lambda (pred-value fail2)
               (if (true? pred-value)
                   (cproc env succeed fail2)
                   (aproc env succeed fail2)))
             ;; failure continuation for evaluating the predicate
             fail))))

(define (analyze-lambda exp)
  (let ((vars (lambda-parameters exp))
        (bproc (analyze-sequence (lambda-body exp))))
    (lambda (env succeed fail)
      (succeed (make-procedure vars bproc env)
               fail))))

(define (analyze-sequence exps)
  (define (sequentially a b)
    (lambda (env succeed fail)
      (a env
         ;; success continuation for calling a
         (lambda (a-value fail2)
           (b env succeed fail2))
         ;; failure continuation for calling a
         fail)))
  (define (loop first-proc rest-procs)
    (if (null? rest-procs)
        first-proc
        (loop (sequentially first-proc (car rest-procs))
              (cdr rest-procs))))
  (let ((procs (map analyze exps)))
    (if (null? procs)
        (error "Empty sequence -- ANALYZE"))
    (loop (car procs) (cdr procs))))

(define (analyze-application exp)
  (let ((fproc (analyze (operator exp)))
        (aprocs (map analyze (operands exp))))
    (lambda (env succeed fail)
      (fproc env
             (lambda (proc fail2)
               (get-args aprocs
                         env
                         (lambda (args fail3)
                           (execute-application
                            proc args succeed fail3))
                         fail2))
             fail))))

(define (get-args aprocs env succeed fail)
  (if (null? aprocs)
      (succeed '() fail)
      ((car aprocs) env
                    ;; success continuation for this aproc
                    (lambda (arg fail2)
                      (get-args (cdr aprocs)
                                env
                                ;; success continuation for recursive
                                ;; call to get-args
                                (lambda (args fail3)
                                  (succeed (cons arg args)
                                           fail3))
                                fail2))
                    fail)))

(define (analyze-amb exp)
  (let ((cprocs (map analyze (amb-choices exp))))
    (lambda (env succeed fail)
      (define (try-next choices)
        (if (null? choices)
            (fail)
            ((car choices) env
                           succeed
                           (lambda ()
                             (try-next (cdr choices))))))
      (try-next cprocs))))

;---------------------4.50-----------------------
(define (ramb? exp) (tagged-list? exp 'ramb))
(define (ramb-choices exp) (cdr exp))

(define (analyze-ramb exp)
  (let ((cprocs (map analyze (ramb-choices exp))))
    (lambda (env succeed fail)
      (define (nth choices n)
        (define (loop choices i)
            (if (= n i)
                (car choices)
                (loop (cdr choices) (+ i 1))))
        (loop choices 0))
      (define (except choices n)
        (define (loop choices i)
            (if (= i n) 
                (cdr choices)
                (cons (car choices) (loop (cdr choices) (+ i 1)))))
        (loop choices 0))
      (define (try-next choices)
            (if (null? choices)
                (fail)
                (let ((i (random (length choices))))
                    ((nth choices i) env
                                     succeed
                                     (lambda ()
                                        (try-next (except choices i)))))))
      (try-next cprocs))))
;------------------------------------------------

;---------------------4.51-----------------------
(define (permanent-assignment? exp)
  (tagged-list? exp 'permanent-set!))
(define (permanent-assignment-variable exp) (cadr exp))
(define (permanent-assignment-value exp) (caddr exp))

(define (analyze-permanent-assignment exp)
    (let ((var (permanent-assignment-variable exp))
          (vproc (analyze (permanent-assignment-value exp))))
        (lambda (env succeed fail)
            (vproc env
                   (lambda (val fail2)
                        (set-variable-value! var val env)
                        (succeed 'ok fail2))
                   fail))))
;------------------------------------------------

;--------------------4.52------------------------
(define (if-fail? exp) (tagged-list? exp 'if-fail))
(define (if-fail-predicate exp) (cadr exp))
(define (if-fail-alternate exp) (caddr exp))

(define (analyze-if-fail exp)
    (let ((pproc (analyze (if-fail-predicate exp)))
          (aproc (analyze (if-fail-alternate exp))))
        (lambda (env succeed fail)
            (pproc env
                   (lambda (val fail2)
                        (succeed val fail2))
                   (lambda ()
                        (aproc env
                               (lambda (val fail2)
                                    (succeed val fail2))
                               fail))))))
;------------------------------------------------

(define (execute-application proc args succeed fail)
  (cond ((primitive-procedure? proc)
         (succeed (apply-primitive-procedure proc args)
                  fail))
        ((compound-procedure? proc)
         ((procedure-body proc)
          (extend-environment (procedure-parameters proc)
                              args
                              (procedure-environment proc))
          succeed
          fail))
        (else
         (error
          "Unknown procedure type -- EXECUTE-APPLICATION"
          proc))))

(define (list-of-values exps env)
  (if (no-operands? exps)
      '()
      (cons (eval (first-operand exps) env)
            (list-of-values (rest-operands exps) env))))

(define (eval-if exp env)
  (if (true? (eval (if-predicate exp) env))
      (eval (if-consequent exp) env)
      (eval (if-alternative exp) env)))

(define (eval-sequence exps env)
  (cond ((last-exp? exps) (eval (first-exp exps) env))
        (else (eval (first-exp exps) env)
              (eval-sequence (rest-exps exps) env))))

(define (eval-assignment exp env)
  (set-variable-value! (assignment-variable exp)
                       (eval (assignment-value exp) env)
                       env)
  'ok)

(define (eval-definition exp env)
  (define-variable! (definition-variable exp)
                    (eval (definition-value exp) env)
                    env)
  'ok)

;Representing expressions
(define (self-evaluating? exp)
  (cond ((number? exp) true)
        ((string? exp) true)
        (else false)))

(define (variable? exp) (symbol? exp))

(define (quoted? exp)
  (tagged-list? exp 'quote))

(define (text-of-quotation exp) (cadr exp))

(define (tagged-list? exp tag)
  (if (pair? exp)
      (eq? (car exp) tag)
      false))

(define (assignment? exp)
  (tagged-list? exp 'set!))
(define (assignment-variable exp) (cadr exp))
(define (assignment-value exp) (caddr exp))

(define (definition? exp)
  (tagged-list? exp 'define))
(define (definition-variable exp)
  (if (symbol? (cadr exp))
      (cadr exp)
      (caadr exp)))
(define (definition-value exp)
  (if (symbol? (cadr exp))
      (caddr exp)
      (make-lambda (cdadr exp)   ; formal parameters
                   (cddr exp)))) ; body

(define (lambda? exp) (tagged-list? exp 'lambda))
(define (lambda-parameters exp) (cadr exp))
(define (lambda-body exp) (cddr exp))
(define (make-lambda parameters body)
  (cons 'lambda (cons parameters body)))

(define (if? exp) (tagged-list? exp 'if))
(define (if-predicate exp) (cadr exp))
(define (if-consequent exp) (caddr exp))
(define (if-alternative exp)
  (if (not (null? (cdddr exp)))
      (cadddr exp)
      'false))
(define (make-if predicate consequent alternative)
  (list 'if predicate consequent alternative))

(define (begin? exp) (tagged-list? exp 'begin))
(define (begin-actions exp) (cdr exp))
(define (last-exp? seq) (null? (cdr seq)))
(define (first-exp seq) (car seq))
(define (rest-exps seq) (cdr seq))
(define (sequence->exp seq)
  (cond ((null? seq) seq)
        ((last-exp? seq) (first-exp seq))
        (else (make-begin seq))))
(define (make-begin seq) (cons 'begin seq))

(define (application? exp) (pair? exp))
(define (operator exp) (car exp))
(define (operands exp) (cdr exp))
(define (no-operands? ops) (null? ops))
(define (first-operand ops) (car ops))
(define (rest-operands ops) (cdr ops))

(define (cond? exp) (tagged-list? exp 'cond))
(define (cond-clauses exp) (cdr exp))
(define (cond-else-clause? clause)
  (eq? (cond-predicate clause) 'else))
(define (cond-predicate clause) (car clause))
(define (cond-actions clause) (cdr clause)) ;overriden by exercise 4.5
(define (cond->if exp)
  (expand-clauses (cond-clauses exp)))

(define (expand-clauses clauses)
  (if (null? clauses)
      'false                          ; no else clause
      (let ((first (car clauses))
            (rest (cdr clauses)))
        (if (cond-else-clause? first)
            (if (null? rest)
                (sequence->exp (cond-actions first))
                (error "ELSE clause isn't last -- COND->IF"
                       clauses))
            (make-if (cond-predicate first)
                     (sequence->exp (cond-actions first))
                     (expand-clauses rest))))))

;Exercise additions
;----------4.4----------
;and
(define (and? exp)
    (tagged-list? exp 'and))
(define (and-operands exp) (cdr exp))
(define (no-and-operands? ops) (null? ops))
(define (first-and-operand ops) (car ops))
(define (rest-and-operands ops) (cdr ops))
(define (eval-and ops env)
    (cond ((no-and-operands? ops) true)
          ((false? (eval (first-and-operand ops) env)) false)
          (else (eval-and (rest-and-operands ops) env))))

;or
(define (or? exp)
    (tagged-list? exp 'or))
(define (or-operands exp) (cdr exp))
(define (no-or-operands? ops) (null? ops))
(define (first-or-operand ops) (car ops))
(define (rest-or-operands ops) (cdr ops))
(define (eval-or ops env)
    (cond ((no-or-operands? ops) false)
          ((true? (eval (first-or-operand ops) env)) true)
          (else (eval-or (rest-or-operands ops) env))))

;-------------4.5------------
(define (cond-actions clause) 
    (if (eq? (cadr clause) '=>)
        (list (caddr clause) (car clause))
        (cdr clause)))

;-------------4.6------------
(define (let? exp)
    (tagged-list? exp 'let))
(define (let->combination exp) ;overriden by ex 4.8 to accomodate named-let
    (cons (make-lambda (let-vars exp) 
                       (let-body exp))
            (let-exps exp)))
(define (let-vars exp)
    (map car (cadr exp)))
(define (let-exps exp)
    (map cadr (cadr exp)))
(define (let-body exp)
    (cddr exp))
(define (make-let var-exps body)
    (list 'let var-exps body))

;-------------4.7------------
(define (let*? exp) (tagged-list? exp 'let*))
(define (let*-var-exp-seq exp) (cadr exp))
(define (let*-body exp) (cddr exp))
(define (let*-first-var-exp var-exp-seq) (car var-exp-seq))
(define (let*-last-var-exp? var-exp-seq) (null? (cdr var-exp-seq)))

(define (let*->nested-lets exp)
    (define (transform-iter var-exp-seq)
        (if (let*-last-var-exp? var-exp-seq)
            (make-let (list (let*-first-var-exp var-exp-seq)) (sequence->exp (let*-body exp)))
            (make-let (list (let*-first-var-exp var-exp-seq)) (transform-iter (cdr var-exp-seq)))))
    (transform-iter (let*-var-exp-seq exp)))

;-------------4.8------------
(define (make-define var exp) (list 'define var exp))

(define (named-let? exp) (symbol? (named-let-name exp)))
(define (named-let-name exp) (cadr exp))
(define (named-let-vars exp) (map car (caddr exp)))
(define (named-let-exps exp) (map cadr (caddr exp)))
(define (named-let-body exp) (cdddr exp))

(define (let->combination exp)
    (if (named-let? exp)
        (sequence->exp (list (make-define (named-let-name exp)
                                          (make-lambda (named-let-vars exp)
                                                       (named-let-body exp)))
                             (cons (named-let-name exp) (named-let-exps exp))))
        (cons (make-lambda (let-vars exp) 
                           (let-body exp))
              (let-exps exp))))

;-------------4.20-----------
(define (letrec? exp) (tagged-list? exp 'letrec))

(define (letrec-var-exp-seq exp) (cadr exp))
(define (letrec-body exp) (cddr exp))

(define (letrec->combination exp)
    (define (make-var-bod-seq var-exp-seq)
        (map (lambda (var-exp)
                (cons (list (car var-exp) ''*unassigned)
                      (list 'set! (car var-exp) (cadr var-exp))))
             var-exp-seq))
    (let ((seq (make-var-bod-seq (letrec-var-exp-seq exp))))
        (make-let (map car seq)
                  (sequence->exp (append (map cdr seq)
                                         (letrec-body exp))))))

;Evaluator data structures
(define (true? x)
  (not (eq? x false)))
(define (false? x)
  (eq? x false))

(define (make-procedure parameters body env)
  (list 'procedure parameters body env))
(define (compound-procedure? p)
  (tagged-list? p 'procedure))
(define (procedure-parameters p) (cadr p))
(define (procedure-body p) (caddr p))
(define (procedure-environment p) (cadddr p))

(define (enclosing-environment env) (cdr env))
(define (first-frame env) (car env))
(define the-empty-environment '())

(define (make-frame variables values)
  (cons variables values))
(define (frame-variables frame) (car frame))
(define (frame-values frame) (cdr frame))
(define (add-binding-to-frame! var val frame)
  (set-car! frame (cons var (car frame)))
  (set-cdr! frame (cons val (cdr frame))))

(define (extend-environment vars vals base-env)
  (if (= (length vars) (length vals))
      (cons (make-frame vars vals) base-env)
      (if (< (length vars) (length vals))
          (error "Too many arguments supplied" vars vals)
          (error "Too few arguments supplied" vars vals))))

(define (lookup-variable-value var env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
             (env-loop (enclosing-environment env)))
            ((eq? var (car vars))
             (car vals))
            (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
        (error "Unbound variable" var)
        (let ((frame (first-frame env)))
          (scan (frame-variables frame)
                (frame-values frame)))))
  (env-loop env))

(define (set-variable-value! var val env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
             (env-loop (enclosing-environment env)))
            ((eq? var (car vars))
             (set-car! vals val))
            (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
        (error "Unbound variable -- SET!" var)
        (let ((frame (first-frame env)))
          (scan (frame-variables frame)
                (frame-values frame)))))
  (env-loop env))

(define (define-variable! var val env)
  (let ((frame (first-frame env)))
    (define (scan vars vals)
      (cond ((null? vars)
             (add-binding-to-frame! var val frame))
            ((eq? var (car vars))
             (set-car! vals val))
            (else (scan (cdr vars) (cdr vals)))))
    (scan (frame-variables frame)
          (frame-values frame))))

;Running the evaluator as a program
(define primitive-procedures
  (list (list 'car car)
        (list 'cdr cdr)
        (list 'cons cons)
        (list 'null? null?)
        (list '+ +)
        (list '* *)
        (list '- -)
        (list '/ /)
        (list '= =)
        (list '< <)
        (list '> >)
        (list '<= <=)
        (list '>= >=)
        (list 'display display)
        (list 'list list)
        (list 'not not)
        (list 'remainder remainder)
        (list 'abs abs)
        (list 'eq? eq?)
        ;<more primitives>
        ))
(define (primitive-procedure-names)
  (map car
       primitive-procedures))

(define (primitive-procedure-objects)
  (map (lambda (proc) (list 'primitive (cadr proc)))
       primitive-procedures))

(define (apply-primitive-procedure proc args)
  (apply-in-underlying-scheme
   (primitive-implementation proc) args))

(define (setup-environment)
  (let ((initial-env
         (extend-environment (primitive-procedure-names)
                             (primitive-procedure-objects)
                             the-empty-environment)))
    (define-variable! 'true true initial-env)
    (define-variable! 'false false initial-env)
    initial-env))
(define the-global-environment (setup-environment))

(define (primitive-procedure? proc)
  (tagged-list? proc 'primitive))
(define (primitive-implementation proc) (cadr proc))

;Must be set before our apply is defined
(define apply-in-underlying-scheme apply)

(define input-prompt ";;; Amb-Eval input:")
(define output-prompt ";;; Amb-Eval value:")
(define (driver-loop)
  (define (internal-loop try-again)
    (prompt-for-input input-prompt)
    (let ((input (read)))
      (if (eq? input 'try-again)
          (try-again)
          (begin
            (newline)
            (display ";;; Starting a new problem ")
            (ambeval input
                     the-global-environment
                     ;; ambeval success
                     (lambda (val next-alternative)
                       (announce-output output-prompt)
                       (user-print val)
                       (internal-loop next-alternative))
                     ;; ambeval failure
                     (lambda ()
                       (announce-output
                        ";;; There are no more values of")
                       (user-print input)
                       (driver-loop)))))))
  (internal-loop
   (lambda ()
     (newline)
     (display ";;; There is no current problem")
     (driver-loop))))


(define (prompt-for-input string)
  (newline) (newline) (display string) (newline))

(define (announce-output string)
  (newline) (display string) (newline))

(define (user-print object)
  (if (compound-procedure? object)
      (display (list 'compound-procedure
                     (procedure-parameters object)
                     (procedure-body object)
                     '<procedure-env>))
      (display object)))
