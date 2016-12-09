#lang typed/racket

(provide (all-defined-out))

(require "digicore.rkt")
(require "tokenizer.rkt")

(define css-open-input-port : (-> CSS-StdIn Input-Port)
  ;;; https://drafts.csswg.org/css-syntax/#parser-entry-points
  (lambda [/dev/stdin]
    (if (list? /dev/stdin)
        (let ([total : Index (length /dev/stdin)]
              [cursor : Integer 0])
          (make-input-port (if (pair? /dev/stdin) (css-token-source (car /dev/stdin)) '/dev/cssin/null)
                           (λ [[buf : Bytes]]
                             (λ _ (cond [(>= cursor total) eof]
                                        [(set! cursor (add1 cursor))
                                         => (λ _ (list-ref /dev/stdin (sub1 cursor)))])))
                           (λ [[buf : Bytes] [skip : Nonnegative-Integer] [evt : Any]]
                             (λ _ (cond [(>= (+ skip cursor) total) eof]
                                        [else (list-ref /dev/stdin (+ skip cursor))])))
                           void))
        (let* ([/dev/rawin (cond [(port? /dev/stdin) /dev/stdin]
                                 [(path? /dev/stdin) (open-input-file /dev/stdin)]
                                 [(regexp-match? #px"\\.css$" /dev/stdin) (open-input-file (~a /dev/stdin))]
                                 [(string? /dev/stdin) (open-input-string /dev/stdin '/dev/cssin/string)]
                                 [(bytes? /dev/stdin) (open-input-bytes /dev/stdin '/dev/cssin/bytes)]
                                 [else (open-input-string (~s /dev/stdin) '/dev/cssin/error)])]
               [/dev/cssin : Input-Port (css-fallback-encode-input-port /dev/rawin)]
               [peek-pool : (Listof CSS-Syntax-Any) null])
          (define portname : (U String Symbol)
            (let ([src (object-name /dev/cssin)])
              (cond [(path? src) (path->string (simple-form-path src))]
                    [else (string->symbol (~a src))])))
          (make-input-port portname
                           (λ [[buf : Bytes]]
                             (λ _ (cond [(null? peek-pool) (css-consume-token /dev/cssin portname)]
                                        [else (let-values ([(rest peeked) (split-at-right peek-pool 1)])
                                                (set! peek-pool rest)
                                                (car peeked))])))
                           (λ [[buf : Bytes] [skip : Nonnegative-Integer] [evt : Any]]
                             ; NOTE: It seems that optimize this code to always throw the last peeked token
                             ;        does not improve the performance.
                             (λ _ (and (for ([idx (in-range (length peek-pool) (add1 skip))])
                                         (set! peek-pool (cons (css-consume-token /dev/cssin portname) peek-pool)))
                                       (list-ref peek-pool (- (length peek-pool) skip 1)))))
                           (thunk (unless (eq? /dev/rawin /dev/cssin) (close-input-port /dev/cssin))
                                  (unless (eq? /dev/rawin /dev/stdin) (close-input-port /dev/rawin)))
                           #false #false
                           (thunk (port-next-location /dev/cssin))
                           (thunk (port-count-lines! /dev/cssin)))))))
  
(define css-read-syntax : (-> Input-Port CSS-Syntax-Any)
  (lambda [css]
    (define stx (read-char-or-special css))
    (cond [(or (css-token? stx) (eof-object? stx)) stx]
          [else (css-make-bad-token (css-srcloc css '/dev/cssin/error 0 0 0)
                                    css:bad:stdin struct:css-token (~s stx))])))

(define css-peek-syntax : (->* (Input-Port) (Natural) CSS-Syntax-Any)
  (lambda [css [skip 0]]
    (define stx (peek-char-or-special css skip))
    (cond [(or (css-token? stx) (eof-object? stx)) stx]
          [else (css-make-bad-token (css-srcloc css '/dev/cssin/error 0 0 0)
                                    css:bad:stdin struct:css-token (~s stx))])))
  
(define css-read-syntax/skip-whitespace : (-> Input-Port CSS-Syntax-Any)
  (lambda [css]
    (define token (css-read-syntax css))
    (cond [(not (css:whitespace? token)) token]
          [else (css-read-syntax/skip-whitespace css)])))

(define css-peek-syntax/skip-whitespace : (-> Input-Port CSS-Syntax-Any)
  (lambda [css]
    (let peek/skip-whitespace : CSS-Syntax-Any ([skip : Nonnegative-Fixnum 0])
      (define token (css-peek-syntax css skip))
      (cond [(not (css:whitespace? token)) token]
            [else (peek/skip-whitespace (fx+ skip 1))]))))