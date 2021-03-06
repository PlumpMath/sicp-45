(define (make-monitored proc)
    (let ((num-calls 0))
        (lambda (arg)
            (cond ((eq? arg 'how-many-calls?) num-calls)
                  ((eq? arg 'reset-count) (begin (set! num-calls 0) num-calls))
                  (else (begin (set! num-calls (+ num-calls 1)) (proc arg)))))))
