(define (contains-cycle? x)
    (define (search_until elem lst index)
        (cond ((or (null? lst) (< index 0)) false)
              ((eq? elem lst) true)
              (else (search_until elem (cdr lst) (- index 1)))))
    (define (cc? cur cur_pos)
        (cond ((null? cur) false)
              ((search_until (cdr cur) x cur_pos) true)
              (else (cc? (cdr cur) (+ cur_pos 1)))))
    (cc? x 0))