(define (make-table same-key?)
  (let ((local-table (list '*table*)))
    (define (assoc key records)
      (cond ((null? records) false)
            ((same-key? key (caar records)) (car records))
            (else (assoc key (cdr records)))))
    (define (lookup keys)
        (define (iter keys table)
            (let ((subtable (assoc (car keys) (cdr table))))
                (if subtable
                    (if (null? (cdr keys))
                        (if (pair? (cdr subtable))
                            false
                            (cdr subtable))
                        (if (not (pair? (cdr subtable)))
                            false
                            (iter (cdr keys) subtable)))
                    false)))
        (iter keys local-table))
    (define (insert! keys value)
        (define (iter keys val table)
            (if (null? (cdr keys))
                (let ((record (assoc (car keys) (cdr table))))
                    (if record
                        (set-cdr! record val)
                        (set-cdr! table
                                  (cons (cons (car keys) val)
                                        (cdr table)))))
                (let ((subtable (assoc (car keys) (cdr table))))
                    (if subtable
                        (iter (cdr keys) val subtable)
                        (begin (set-cdr! table (cons (cons (car keys) '())
                                                     (cdr table)))
                               (iter (cdr keys) val (cadr table)))))))
        (iter keys value local-table))
    (define (dispatch m)
      (cond ((eq? m 'lookup-proc) lookup)
            ((eq? m 'insert-proc!) insert!)
            (else (error "Unknown operation -- TABLE" m))))
    dispatch))
