(define (ordered-triples n s)
    (filter (lambda (triple) (= (+ (car triple) (cadr triple) (caddr triple)) s))
            (flatmap (lambda (i) (flatmap (lambda (j) (map (lambda (k) (list i j k))
                                                  (enumerate-interval 1 (- j 1))))
                                 (enumerate-interval 1 (- i 1))))
                     (enumerate-interval 1 n))))
