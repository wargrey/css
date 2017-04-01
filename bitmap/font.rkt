#lang typed/racket

(provide (all-defined-out))

(require typed/racket/draw)
(require racket/bool)

(require "digitama/digicore.rkt")
(require "digitama/cheat.rkt")
(require "digitama/font.rkt")

(define-type CSS-Font (Instance CSS-Font%))

(define-type CSS-Font%
  (Class #:implements Font%
         (init-field [face String]
                     [size Real #:optional]
                     [style Font-Style #:optional]
                     [weight Font-Weight #:optional]
                     [underline? Any #:optional]
                     [smoothing Font-Smoothing #:optional]
                     [hinting Font-Hinting #:optional]
                     [combine? Any #:optional])
         (init-rest Null) ; this line is annoying.
         [get-combine? (-> Boolean)]
         [get-font-scalar (-> Symbol Nonnegative-Flonum)]
         [take-charge (-> Boolean Void)]))

(define css-font% : CSS-Font%
  (class font%
    (init-field face [size 12.0] [style 'normal] [weight 'normal] [underline? #true]
                [smoothing 'default] [hinting 'aligned] [combine? #true])

    ;;; NOTE
    ; The generic font `system-ui` is a virtual font that relatives to host system or device
    ; which may hard to obtain, thus, it is the default one if the alternative face is not available.
    
    (super-make-object size face 'system style weight underline? smoothing #true hinting)

    (define em : Nonnegative-Flonum +nan.0)
    (define ex : Nonnegative-Flonum 0.0)
    (define cap : Nonnegative-Flonum 0.0)
    (define ch : Nonnegative-Flonum 0.0)
    (define ic : Nonnegative-Flonum 0.0)

    (define/public (get-font-scalar unit)
      (when (nan? em)
        ;;; WARNING
        ;; 'xh' seems to be impractical, the font% size is just a nominal size
        ;; and usually smaller than the generated text in which case the 'ex' is
        ;; always surprisingly larger than the size, the '0w' therefore is used instead,
        ;; same consideration to 'cap'.
        #;(define-values (xw xh xd xs) (send the-dc get-text-extent "x" this))
        (define-values (0w 0h 0d 0s) (send the-dc get-text-extent "0" this))
        (define-values (ww wh wd ws) (send the-dc get-text-extent "水" this))
        (set! em (smart-font-size this))
        (set! ex (real->double-flonum 0w))
        (set! cap (real->double-flonum (max (- em 0d 0s) 0d)))
        (set! ch (real->double-flonum 0w))
        (set! ic (real->double-flonum ww)))
      (case unit
        [(em)  em]
        [(cap) cap]
        [(ex)  ex]
        [(ch)  ch]
        [(ic)  ic]
        [else +nan.0]))

    (define/public (take-charge root-element?)
      (void))
    
    (define/public (get-combine?)
      (and combine? #true))

    (define/override (get-family)
      (let try-next ([families : (Listof Font-Family) '(swiss roman modern decorative script symbol system)])
        (cond [(null? families) (super get-family)]
              [(string=? face (font-family->font-face (car families))) (car families)]
              [else (try-next (cdr families))])))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-cheat-opaque css-font%? #:is-a? CSS-Font% css-font%)

(define make-font+ : (->* () (Font #:size Real #:family (U String Symbol False) #:style (Option Font-Style) #:weight (Option Font-Weight)
                                   #:hinting (Option Font-Hinting) #:underlined? (U Boolean Symbol) #:smoothing (Option Font-Smoothing)
                                   #:combine? (U Boolean Symbol)) CSS-Font)
  (let ([fontbase : (HashTable Any CSS-Font) (make-hash)])
    (lambda [[basefont (default-css-font)] #:size [size +nan.0] #:family [face #false] #:style [style #false] #:weight [weight #false]
                                           #:hinting [hinting #false] #:smoothing [smoothing #false] #:underlined? [underlined 'inherit]
                                           #:combine? [combine? 'inherit]]
      (define font-size : Real
        (min 1024.0 (cond [(positive? size) size]
                          [(or (zero? size) (nan? size)) (smart-font-size basefont)]
                          [else (* (- size) (smart-font-size basefont))])))
      (define font-face : String
        (cond [(string? face) face]
              [(symbol? face) (font-family->font-face face)]
              [(send basefont get-face) => values]
              [else (font-family->font-face (send basefont get-family))]))
      (define font-style : Font-Style (or style (send basefont get-style)))
      (define font-weight : Font-Weight (or weight (send basefont get-weight)))
      (define font-smoothing : Font-Smoothing (or smoothing (send basefont get-smoothing)))
      (define font-underlined? : Boolean (if (boolean? underlined) underlined (send basefont get-underlined)))
      (define font-hinting : Font-Hinting (or hinting (send basefont get-hinting)))
      (define font-combine? : Boolean (if (boolean? combine?) combine? (implies (css-font%? basefont) (send basefont get-combine?))))
      (hash-ref! fontbase
                 (list font-face font-size font-style font-weight font-underlined? font-smoothing font-hinting font-combine?)
                 (λ [] (make-object css-font% font-face font-size font-style font-weight
                         font-underlined? font-smoothing font-hinting font-combine?))))))

(define racket-font-family->font-face : (-> Symbol String)
  (let ([os (system-type)]
        [ui (delay (with-handlers ([exn? (λ _ #false)])
                     (and (collection-file-path "base.rkt" "racket" "gui")
                          (let ([system-ui (dynamic-require 'racket/gui/base 'normal-control-font)])
                            (and (font%? system-ui) (send system-ui get-face))))))])
    (lambda [family]
      (case family
        [(swiss default) (case os [(macosx) "Lucida Grande"] [(windows) "Tahoma"] [else "Sans"])]
        [(roman)         (case os [(macosx) "Times"] [(windows) "Times New Roman"] [else "Serif"])]
        [(modern)        (case os [(macosx windows) "Courier New"] [else "Monospace"])]
        [(decorative)    (case os [(windows) "Arial"] [else "Helvetica"])]
        [(script)        (case os [(macosx) "Apple Chancery, Italic"] [(windows) "Palatino Linotype, Italic"] [else "Chancery"])]
        [(symbol)        (case os [else "Symbol"])]
        [(system)        (or (force ui) (racket-font-family->font-face 'default))]
        [else (racket-font-family->font-face (generic-font-family-map family))]))))

(define default-font-family->font-face : (Parameterof (-> Symbol (Option String))) (make-parameter racket-font-family->font-face))

(define font-family->font-face : (-> Symbol String)
  (lambda [family]
    (or ((default-font-family->font-face) family)
        (racket-font-family->font-face family))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define text-size : (->* (String Font) (Boolean #:with-dc (Instance DC<%>)) (Values Nonnegative-Flonum Nonnegative-Flonum))
  (lambda [text font [combined? #true] #:with-dc [dc the-dc]]
    (define-values (w h d a) (send dc get-text-extent text font combined?))
    (values (real->double-flonum w) (real->double-flonum h))))