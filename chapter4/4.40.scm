(define (multiple-dwelling)
    (let ((baker (amb 1 2 3 4)))
          (let ((cooper (amb 2 3 4 5)))
               (require (not (= cooper baker)))
               (let ((miller (amb 3 4 5)))
                    (require (not (or (= miller cooper) 
                                      (= miller baker))))
                    (require (> miller cooper))
                    (let ((fletcher (amb 2 3 4)))
                        (require (not (or (= fletcher cooper) 
                                          (= fletcher baker)
                                          (= fletcher miller))))
                        (require (not (= (abs (- fletcher cooper)) 1)))
                        (let ((smith (amb 1 2 3 4)))
                            (require (not (or (= smith cooper) 
                                          (= smith baker)
                                          (= smith miller)
                                          (= smith fletcher))))
                            (require (not (= (abs (- smith fletcher)) 1)))
                            (list (list 'baker baker)
                                  (list 'cooper cooper)
                                  (list 'fletcher fletcher)
                                  (list 'miller miller)
                                  (list 'smith smith))))))))
