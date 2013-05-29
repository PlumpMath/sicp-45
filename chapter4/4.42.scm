(define (xor x y)
    (not (eq? x y)))

;Nondeterministic
(define (liars-puzzle)
    (let ((betty (amb 1 2 3 4 5))
          (ethel (amb 1 2 3 4 5))
          (joan (amb 1 2 3 4 5))
          (kitty (amb 1 2 3 4 5))
          (mary (amb 1 2 3 4 5)))
        (require (distinct? (list betty ethel joan kitty mary)))
        (require (xor (= kitty 2) (= betty 3)))
        (require (xor (= ethel 1) (= joan 2)))
        (require (xor (= joan 3) (= ethel 5)))
        (require (xor (= kitty 2) (= mary 4)))
        (require (xor (= mary 4) (= betty 1)))
        (list (list 'betty betty)
              (list 'ethel ethel)
              (list 'joan joan)
              (list 'kitty kitty)
              (list 'mary mary))))

;Ordinary
(define (logic-puzzle)
    (define (check-restrictions betty ethel joan kitty mary)
        (and (distinct? (list betty ethel joan kitty mary))
             (xor (= kitty 2) (= betty 3))
             (xor (= ethel 1) (= joan 2))
             (xor (= joan 3) (= ethel 5))
             (xor (= kitty 2) (= mary 4))
             (xor (= mary 4) (= betty 1))))
    (define (next-batch betty ethel joan kitty mary)
        (cond ((= betty ethel joan kitty mary 5) "No luck. Reached the end of the line")
              ((= ethel joan kitty mary 5) (solver-loop (+ betty 1) 1 1 1 1))
              ((= joan kitty mary 5) (solver-loop betty (+ ethel 1) 1 1 1))
              ((= kitty mary 5) (solver-loop betty ethel (+ joan 1) 1 1))
              ((= mary 5) (solver-loop betty ethel joan (+ kitty 1) 1))
              (else (solver-loop betty ethel joan kitty (+ mary 1)))))
    (define (solver-loop betty ethel joan kitty mary)
        (if (check-restrictions betty ethel joan kitty mary)
            (list (list 'betty betty)
                  (list 'ethel ethel)
                  (list 'joan joan)
                  (list 'kitty kitty)
                  (list 'mary mary))
            (next-batch betty ethel joan kitty mary)))
    (solver-loop 1 1 1 1 1))

;Result:
;((betty 3) (ethel 5) (joan 2) (kitty 1) (mary 4))
