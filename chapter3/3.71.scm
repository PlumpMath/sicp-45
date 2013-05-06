;weight procedure
(define (ramanujan-weight pair)
    (let ((i (car pair))
          (j (cadr pair)))
        (+ (* i i i) (* j j j))))

(define ramanujan-weighted-pairs (weighted-pairs integers
                                                 integers
                                                 ramanujan-weight))

(define (search-ram-pairs pairs n)
    (if (> n 0)
        (let ((cur (stream-car pairs))
              (next (stream-car (stream-cdr pairs))))
            (cond ((= (ramanujan-weight cur) (ramanujan-weight next))
                    (display (ramanujan-weight cur))
                    (display "\n")
                    (search-ram-pairs (stream-cdr pairs) (- n 1)))
                  (else (search-ram-pairs (stream-cdr pairs) n))))))

(define (display-pair p)
    (display "(")
    (display (car p))
    (display ", ")
    (display (cadr p))
    (display ")\n"))

(search-ram-pairs ramanujan-weighted-pairs 6)
;1729
;4104
;13832
;20683
;32832
;39312