 #lang at-exp typed/racket/base

(require string-constants typed/racket/gui/base
         #;racket/contract/base typed/racket/class)
(require scribble/srcdoc)
(require/doc typed/racket/base scribble/manual)

(require/typed racket/gui
               [message-box/custom (->* [String String
                                                (U String (Instance Bitmap%) False)
                                                (U String (Instance Bitmap%) False)
                                                (U String (Instance Bitmap%) False)]
                                        [(U (Instance Frame%) (Instance Dialog%) False)
                                        (Listof (U 'stop 'caution 'no-icon 'number-order 'disallow-close
                                                   'no-default 'default=1 'default=2 'default=3))
                                        (U Any False) 
                                        #:dialog-mixin (Frame% . -> . Frame%)]
                                        (U 1 2 3))]
               [message+check-box/custom (->* [String String String
                                                (U String (Instance Bitmap%) False)
                                                (U String (Instance Bitmap%) False)
                                                (U String (Instance Bitmap%) False)]
                                        [(U (Instance Frame%) (Instance Dialog%) False)
                                        (Listof (U 'stop 'caution 'no-icon 'number-order 'disallow-close
                                                   'no-default 'default=1 'default=2 'default=3))
                                        (U Any False) 
                                        #:dialog-mixin (Frame% . -> . Frame%)]
                                        (Values (U 1 2 3) Boolean))])


(: trim-string (-> String Positive-Integer String))
(define (trim-string str size)
  (let ([str-size (string-length str)])
    (cond
      [(<= str-size size)
       str]
      [else
       (let* ([between "..."]
              [pre-length (- (quotient size 2)
                             (quotient (string-length between) 2))]
              [post-length (- size
                              pre-length
                              (string-length between))])
         (cond
           [(or (<= pre-length 0)
                (<= post-length 0))
            (substring str 0 size)]
           [else
            (string-append
             (substring str 0 pre-length)
             between
             (substring str
                        (- str-size post-length)
                        str-size))]))])))

(: maximum-string-label-length Positive-Integer)
(define maximum-string-label-length 200)

;; format-literal-label: string any* -> string
(: format-literal-label (-> String Any * String))
(define (format-literal-label format-str . args)
  (quote-literal-label (apply format format-str args)))

;; quote-literal-label: string -> string
(: quote-literal-label (-> String (#:quote-amp? Boolean) String))
(define (quote-literal-label a-str #:quote-amp? [quote-amp? #t])
  (define quoted (if quote-amp?
                     (regexp-replace* #rx"(&)" a-str "\\1\\1")
                     a-str))
  (trim-string quoted maximum-string-label-length))


;; selected-text-color : color
(: selected-text-color (U (Instance Color%) False))
(define selected-text-color (send the-color-database find-color "black"))

;; unselected-text-color : color
(: unselected-text-color (U (Instance Color%) False))
(define unselected-text-color (case (system-type 'os)
                                [(macosx) (make-object color% 75 75 75)]
                                [else (send the-color-database find-color "black")]))

;; selected-brush : brush
(: selected-brush (U (Instance Brush%) False))
(define selected-brush (send the-brush-list find-or-create-brush "WHITE" 'solid))

;; unselected-brush : brush
(: unselected-brush (U (Instance Brush%) False))
(define unselected-brush (send the-brush-list find-or-create-brush (get-panel-background) 'solid))

;; button-down/over-brush : brush
(: button-down/over-brush (U (Instance Brush%) False))
(define button-down/over-brush 
  (case (system-type 'os)
    [(macosx) (send the-brush-list find-or-create-brush
                    "light blue"
                    'solid)]
    [else
     (send the-brush-list find-or-create-brush
           (make-object color% 225 225 255)
           'solid)]))


;; name-box-pen : pen
;; this pen draws the lines around each individual item
(: name-box-pen (U (Instance Pen%) False))
(define name-box-pen (send the-pen-list find-or-create-pen "black" 1 'solid))

;; background-brush : brush
;; this brush is set when drawing the background for the control
(: background-brush (U (Instance Brush%) False))
(define background-brush 
  (case (system-type 'os)
    [(macosx) (send the-brush-list find-or-create-brush (get-panel-background) 'panel)]
    [else (send the-brush-list find-or-create-brush "white" 'solid)]))

;; background-pen : pen
;; this pen is set when drawing the background for the control
(: background-pen (U (Instance Pen%) False))
(define background-pen (send the-pen-list find-or-create-pen "black" 1 'transparent))

;; label-font : font
(: label-font (U (Instance Font%) False))
(define label-font (send the-font-list find-or-create-font
                         (if (eq? (system-type 'os) 'windows) 10 12)
                         'system 'normal
                         (if (eq? (system-type 'os) 'macosx) 'bold 'normal)
                         #f))

;; name-gap : number
;; the space between each name
(: name-gap Positive-Real)
(define name-gap 4)

;; hang-over : number
;; the amount of space a single entry "slants" over
(: hang-over Positive-Real)
(define hang-over 8)

;; top-space : number
;; the gap at the top of the canvas, above all the choices
(: top-space Positive-Real)
(define top-space 4)

;; bottom-space : number
;; the extra space below the words
(: bottom-space Positive-Real)
(define bottom-space 2)

;; end choices-canvas%

(: cancel-on-right? (-> Boolean))
(define (cancel-on-right?) (system-position-ok-before-cancel?))

(: ok/cancel-buttons (->* ((Instance Area-Container<%>)
                          (-> (Instance Button%) (Instance Event%) Any)
                          (-> (Instance Button%) (Instance Event%) Any))
                          (String String #:confirm-style (Listof (U 'deleted 'border)))
                          (Values (Instance Button%) (Instance Button%))))
                         
(define (ok/cancel-buttons parent ;; (: ok/cancel-buttons (Values (Instance Button%) (Instance Button%)))
                           confirm-callback
                           cancel-callback 
                           [confirm-str (string-constant ok)]
                           [cancel-str (string-constant cancel)]
                           #:confirm-style [confirm-style '(border)]) 
  (let ([confirm (λ ()
                   (instantiate button% ()
                     (parent parent)
                     (callback confirm-callback)
                     (label confirm-str)
                     (style confirm-style)))]
        [cancel (λ ()
                  (instantiate button% ()
                    (parent parent)
                    (callback cancel-callback)
                    (label cancel-str)))])
    (let-values ([(b1 b2) ;; let-values: ([([b1 : (Instance Brush%)] [b2 : (Instance Brush%)])
                  (cond
                    [(cancel-on-right?)
                     (values (confirm) (cancel))]
                    [else
                     (values (cancel) (confirm))])])
      (let ([w (max (send b1 get-width) ;; (let: ([[w : Real]
                    (send b2 get-width))])
        (send b1 min-width w)
        (send b2 min-width w)
        (if (cancel-on-right?)
            (values b1 b2)
            (values b2 b1))))))

(: clickback-delta (Instance Style-Delta%))
(define clickback-delta (make-object style-delta% 'change-underline #t))

(: white-on-black-clickback-delta (Instance Style-Delta%))
(define white-on-black-clickback-delta (make-object style-delta% 'change-underline #t))
(let ()
  (send clickback-delta set-delta-foreground "BLUE")
  (send white-on-black-clickback-delta set-delta-foreground "deepskyblue")
  (void))

(: get-clickback-delta (-> Boolean (Instance Style-Delta%)))
(define get-clickback-delta
  (lambda ([white-on-black? #f])
    (if white-on-black? 
        white-on-black-clickback-delta
        clickback-delta)))

(: clicked-clickback-delta (Instance Style-Delta%))
(define clicked-clickback-delta (make-object style-delta%))

(: white-on-black-clicked-clickback-delta (Instance Style-Delta%))
(define white-on-black-clicked-clickback-delta (make-object style-delta%))
(let ()
  (send clicked-clickback-delta set-delta-background "BLACK")
  (send white-on-black-clicked-clickback-delta set-delta-background "white")
  (void))

(: get-clicked-clickback-delta (->* (Boolean) (Instance Style-Delta%)))
(define get-clicked-clickback-delta
  (lambda ([white-on-black? #f])
    (if white-on-black? 
        white-on-black-clicked-clickback-delta
        clicked-clickback-delta)))

;; case lambda 
(: next-untitled-name (-> String))
(define next-untitled-name
  (let ([n 1])
    (λ ()
      (begin0
        (cond
          [(= n 1) (string-constant untitled)]
          [else (format (string-constant untitled-n) n)])
        (set! n (+ n 1))))))


(: cursor-delay (case-> (-> Float) (-> Float Float)))
(define cursor-delay
  (let ([x 0.25])
    (case-lambda
      [() x]
      [(v) (set! x v) x])))

(: show-busy-cursor (->* ((-> Any)) [Real] Any)) 
(define show-busy-cursor
  (lambda (thunk [delay (cursor-delay)])
    (local-busy-cursor #f thunk delay)))

(: delay-action (-> Real (-> Void) (-> Void) (-> Void)))
(define delay-action
  (λ (delay-time open close)
    (let: ([semaphore : Semaphore (make-semaphore 1)]
          [open? : Boolean #f]
          [skip-it? : Boolean #f])
      (thread 
       (λ ()
         (sleep delay-time)
         (semaphore-wait semaphore)
         (unless skip-it?
           (set! open? #t)
           (open))
         (semaphore-post semaphore)))
      (λ ()
        (semaphore-wait semaphore)
        (set! skip-it? #t)
        (when open?
          (close))
        (semaphore-post semaphore)))))

(: local-busy-cursor (->* [(U False (Instance Window<%>)) (-> Any)] [Real] Any))
(define local-busy-cursor
  (let ([watch (make-object cursor% 'watch)])
    (case-lambda
      [(win thunk) (local-busy-cursor win thunk (cursor-delay))]
      [(win thunk delay)
       (let*: ([old-cursor  : (U False (Instance Cursor%)) #f]
              [cursor-off : (-> Void) void])
         (dynamic-wind
          (λ ()
            (set! cursor-off 
                  (delay-action
                   delay
                   (λ ()
                     (if win
                         (begin (set! old-cursor (send win get-cursor))
                                (send win set-cursor watch))
                         (begin-busy-cursor)))
                   (λ ()
                     (if win
                         (send win set-cursor old-cursor)
                         (end-busy-cursor))))))
          (λ () (thunk))
          (λ () (assert (cursor-off)))))])))

(: unsaved-warning (->* (String String)
                       (Boolean (U (Instance Frame%) (Instance Dialog%) False) Boolean)
                       (U 'continue 'save 'cancel)))
(define (unsaved-warning filename action-anyway [can-save-now? #f] [parent #f] [cancel? #t])
  (define: key-closed : (U False 'continue 'save 'cancel) #f)
  
  (: unsaved-warning-mixin (-> Frame% Frame%))
  (define (unsaved-warning-mixin %)
    (class %
      (inherit show)
      (: on-subwindow-char (-> (Instance Window<%>) (Instance Key-Event%) Boolean))
      (define/override (on-subwindow-char receiver evt)
        (: is-menu-key? (-> Char Boolean))
        (define (is-menu-key? char)
          (and (send evt get-meta-down)
               (equal? (send evt get-key-code) char)))
        (cond
          [(is-menu-key? #\d)
           (set! key-closed 'continue)
           (show #f)
           #t] ;; #t here shouldn't be needed
          [(is-menu-key? #\s)
           (set! key-closed 'save)
           (show #f)
           #t]
          [(is-menu-key? #\c)
           (set! key-closed 'cancel)
           (show #f)
           #t]
          [else
           (super on-subwindow-char receiver evt)]))
      (super-new))) 

  (define mb-res
    (message-box/custom 
     (string-constant warning) 
     (format (string-constant file-is-not-saved) filename)
     (string-constant save)
     (and cancel? (string-constant cancel)) 
     action-anyway
     parent
     (if can-save-now?
         '(default=1 caution) 
         '(default=2 caution))
     2
     #:dialog-mixin (if (equal? (system-type 'os) 'macosx)
                        unsaved-warning-mixin
                        values)))  
  (or key-closed
      (case mb-res
        [(1) 'save]
        [(2) 'cancel]
        [(3) 'continue]
        [else (error 'FIXME)]))) ;; else case shouldn't be needed

(: get-choice (->* (String String String)
                  [String Any (U False (Instance Dialog%) (Instance Frame%))
                   (U 'caution 'stop) (U False (case-> (-> Boolean Void) (-> Boolean))) String]
                  Any))
(define get-choice
  (lambda (message 
           true-choice
           false-choice 
           (title (string-constant warning))
           (default-result 'disallow-close)
           (parent #f)
           (style 'app)
           (checkbox-proc #f)
           (checkbox-label (string-constant dont-ask-again)))
    (let* ([check? (and checkbox-proc (checkbox-proc))]
           [style  (if (eq? style 'app) `(default=1) `(default=1 ,style))]
           [style  (if (eq? 'disallow-close default-result)
                       (cons 'disallow-close style) style)]
            ;; moved to if statment comment out below to parameter in 
            ;; (return (messa-box/custom ... )call for type checker work around
            #;
           [style  (if check? (cons 'checked style) style)]
           [return (λ (mb-res) (case mb-res [(1) #t] [(2) #f] [else mb-res]))])
      (if checkbox-proc
          (let-values ([(mb-res checked)
                        (message+check-box/custom title message checkbox-label
                                                  true-choice false-choice #f
                                                  parent style default-result)]) 
            (checkbox-proc checked)
            (return mb-res))
          (return (message-box/custom title message true-choice false-choice #f
                                      parent (if check? (cons 'checked style) style) default-result))))))

;; manual renaming
(define gui-utils:trim-string trim-string)
(define gui-utils:quote-literal-label quote-literal-label)
(define gui-utils:format-literal-label format-literal-label)
(define gui-utils:next-untitled-name next-untitled-name)
(define gui-utils:show-busy-cursor show-busy-cursor)
(define gui-utils:delay-action delay-action)
(define gui-utils:local-busy-cursor local-busy-cursor)
(define gui-utils:unsaved-warning unsaved-warning)
(define gui-utils:get-choice get-choice)
(define gui-utils:get-clicked-clickback-delta get-clicked-clickback-delta)
(define gui-utils:get-clickback-delta get-clickback-delta)
(define gui-utils:ok/cancel-buttons ok/cancel-buttons)
(define gui-utils:cancel-on-right? cancel-on-right?)
(define gui-utils:cursor-delay cursor-delay)

(provide gui-utils:trim-string
         gui-utils:quote-literal-label
         gui-utils:format-literal-label
         gui-utils:next-untitled-name
         gui-utils:show-busy-cursor
         gui-utils:delay-action
         gui-utils:local-busy-cursor
         gui-utils:unsaved-warning
         gui-utils:get-choice
         gui-utils:get-clicked-clickback-delta
         gui-utils:get-clickback-delta
         gui-utils:ok/cancel-buttons
         gui-utils:cancel-on-right?
         gui-utils:cursor-delay)

#;
(provide/doc
 (proc-doc
  gui-utils:trim-string
  (->i ([str string?]
        [size (and/c number? positive?)])
       ()
       [res (size)
            (and/c string?
                   (λ (str)
                     ((string-length str) . <= . size)))])
  @{Constructs a string whose size is less
    than @racket[size] by trimming the @racket[str]
    and inserting an ellispses into it.})

 (proc-doc/names
  gui-utils:quote-literal-label
  (->* (string?)
       (#:quote-amp? any/c)
       (and/c string?
              (λ (str) ((string-length str) . <= . 200))))
  ((string)
   ((quote-amp? #t)))
  @{Constructs a string whose length is less than @racket[200] and,
    if @racket[quote-amp?] is not @racket[#f], then it also quotes
    the ampersand in the result (making the string suitable for use in
    @racket[menu-item%] label, for example).})

 (proc-doc
  gui-utils:format-literal-label
  (->i ([str string?])
       ()
       #:rest [rest (listof any/c)]
       [res (str)
            (and/c string?
                   (lambda (str)
                     ((string-length str) . <= . 200)))])
  @{Formats a string whose ampersand characters are
    mk-escaped; the label is also trimmed to <= 200
    mk-characters.})

 (proc-doc/names
  gui-utils:cancel-on-right?
  (-> boolean?)
  ()
  @{Returns @racket[#t] if cancel should be on the right-hand side (or below)
    in a dialog and @racket[#f] otherwise.
    
    Just returns what @racket[system-position-ok-before-cancel?] does.
    
    See also @racket[gui-utils:ok/cancel-buttons].})

 (proc-doc/names
  gui-utils:ok/cancel-buttons
  (->* ((is-a?/c area-container<%>)
        ((is-a?/c button%) (is-a?/c event%) . -> . any)
        ((is-a?/c button%) (is-a?/c event%) . -> . any))
       (string?
        string?
        #:confirm-style (listof symbol?))
       (values (is-a?/c button%)
               (is-a?/c button%)))
  ((parent
    confirm-callback
    cancel-callback)
   ((confirm-label (string-constant ok))
    (cancel-label (string-constant cancel))
    (confirm-style '(border))))
  @{Adds an Ok and a cancel button to a panel, changing the order
    to suit the platform. Under Mac OS X and unix, the confirmation action
    is on the right (or bottom) and under Windows, the canceling action is on
    the right (or bottom).
    The buttons are also sized to be the same width.
    
    The first result is be the OK button and the second is
    the cancel button.
    
    By default, the confirmation action button has the @racket['(border)] style,
    meaning that hitting return in the dialog will trigger the confirmation action.
    The @racket[confirm-style] argument can override this behavior, tho.
    See @racket[button%] for the precise list of allowed styles.
    
    See also @racket[gui-utils:cancel-on-right?].})
 
 (proc-doc/names
  gui-utils:next-untitled-name
  (-> string?)
  ()
  @{Returns a name for the next opened untitled frame. The first
    name is ``Untitled'', the second is ``Untitled 2'',
    the third is ``Untitled 3'', and so forth.})
 (proc-doc/names
  gui-utils:cursor-delay
  (case->
   (-> real?)
   (real? . -> . void?))
  (() (new-delay))
  @{This function is @italic{not} a parameter.
    Instead, the state is just stored in the closure.
    
    The first case in the case lambda
    returns the current delay in seconds before a watch cursor is shown,
    when either @racket[gui-utils:local-busy-cursor] or
    @racket[gui-utils:show-busy-cursor] is called.
    
    The second case in the case lambda
    Sets the delay, in seconds, before a watch cursor is shown, when
    either @racket[gui-utils:local-busy-cursor] or
    @racket[gui-utils:show-busy-cursor] is called.})
 (proc-doc/names
  gui-utils:show-busy-cursor
  (->* ((-> any/c))
       (integer?)
       any/c)
  ((thunk)
   ((delay (gui-utils:cursor-delay))))
  @{Evaluates @racket[(thunk)] with a watch cursor. The argument
    @racket[delay] specifies the amount of time before the watch cursor is
    opened. Use @racket[gui-utils:cursor-delay] to set this value
    to all calls.
    
    This function returns the result of @racket[thunk].})
 (proc-doc/names
  gui-utils:delay-action
  (real?
   (-> void?)
   (-> void?)
   . -> .
   (-> void?))
  (delay-time open close)
  @{Use this function to delay an action for some period of time. It also
    supports canceling the action before the time period elapses. For
    example, if you want to display a watch cursor, but you only want it
    to appear after 2 seconds and the action may or may not take more than
    two seconds, use this pattern:
    
    @racketblock[(let ([close-down
                        (gui-utils:delay-action
                         2
                         (λ () .. init watch cursor ...)
                         (λ () .. close watch cursor ...))])
                   ;; .. do action ...
                   (close-down))]
    
    Creates a thread that waits @racket[delay-time]. After @racket[delay-time]
    has elapsed, if the result thunk has @italic{not} been called, call
    @racket[open]. Then, when the result thunk is called, call
    @racket[close]. The function @racket[close] will only be called if
    @racket[open] has been called.})
 
 (proc-doc/names
  gui-utils:local-busy-cursor
  (->*
   ((is-a?/c window<%>)
    (-> any/c))
   (integer?)
   any/c)
  ((window thunk)
   ((delay (gui-utils:cursor-delay))))
  @{Evaluates @racket[(thunk)] with a watch cursor in @racket[window]. If
    @racket[window] is @racket[#f], the watch cursor is turned on globally.
    The argument @racket[delay] specifies the amount of time before the watch
    cursor is opened. Use @racket[gui-utils:cursor-delay]
    to set this value for all uses of this function.
    
    The result of this function is the result of @racket[thunk].})
 
 (proc-doc/names
  gui-utils:unsaved-warning
  (->*
   (string?
    string?)
   (boolean?
    (or/c false/c
          (is-a?/c frame%)
          (is-a?/c dialog%))
    boolean?)
   (symbols 'continue 'save 'cancel))
  ((filename action)
   ((can-save-now? #f)
    (parent #f)
    (cancel? #t)))
  
  @{This displays a dialog that warns the user of a unsaved file.
    
    The string, @racket[action], indicates what action is about to
    take place, without saving. For example, if the application
    is about to close a file, a good action is @racket["Close Anyway"].
    The result symbol indicates the user's choice. If
    @racket[can-save-now?] is @racket[#f], this function does not
    give the user the ``Save'' option and thus will not return
    @racket['save].
    
    If @racket[cancel?] is @racket[#t] there is a cancel button
    in the dialog and the result may be @racket['cancel]. If it
    is @racket[#f], then there is no cancel button, and @racket['cancel]
    will not be the result of the function.
    
    })
 
 (proc-doc/names
  gui-utils:get-choice
  (->* (string?
        string?
        string?)
       (string?
        any/c
        (or/c false/c (is-a?/c frame%) (is-a?/c dialog%))
        (symbols 'app 'caution 'stop)
        (or/c false/c (case-> (boolean? . -> . void?)
                              (-> boolean?)))
        string?)
       any/c)
  ((message true-choice false-choice)
   ((title (string-constant warning))
    (default-result 'disallow-close)
    (parent #f)
    (style 'app)
    (checkbox-proc #f)
    (checkbox-label (string-constant dont-ask-again))))
  
  @{Opens a dialog that presents a binary choice to the user. The user is
    forced to choose between these two options, ie cancelling or closing the
    dialog opens a message box asking the user to actually choose one of the
    two options.
    
    The dialog will contain the string @racket[message] and two buttons,
    labeled with the @racket[true-choice] and the @racket[false-choice].  If the
    user clicks on @racket[true-choice] @racket[#t] is returned. If the user
    clicks on @racket[false-choice], @racket[#f] is returned.
    
    The argument @racket[default-result] determines how closing the window is
    treated. If the argument is @racket['disallow-close], closing the window
    is not allowed. If it is anything else, that value is returned when
    the user closes the window.
    
    If @racket[gui-utils:cancel-on-right?]
    returns @racket[#t], the false choice is on the right.
    Otherwise, the true choice is on the right.
    
    The @racket[style] parameter is (eventually) passed to
    @racket[message]
    as an icon in the dialog.
    
    If @racket[checkbox-proc] is given, it should be a procedure that behaves
    like a parameter for getting/setting a boolean value.  The intention for
    this value is that it can be used to disable the dialog.  When it is
    given, a checkbox will appear with a @racket[checkbox-label] label
    (defaults to the @racket[dont-ask-again] string constant), and that
    checkbox value will be sent to the @racket[checkbox-proc] when the dialog
    is closed.  Note that the dialog will always pop-up --- it is the
    caller's responsibility to avoid the dialog if not needed.})
 
 (proc-doc/names
  gui-utils:get-clicked-clickback-delta
  (->* ()
       (boolean?)
       (is-a?/c style-delta%))
  (()
   ((white-on-black? #f)))
  @{This delta is designed for use with
    @method[text set-clickback].
    Use it as one of the @racket[style-delta%] argument to
    @method[text% set-clickback].
    
    If @racket[white-on-black?] is true, the function returns
    a delta suitable for use on a black background.
    
    See also @racket[gui-utils:get-clickback-delta].})
 
 (proc-doc/names
  gui-utils:get-clickback-delta
  (->* ()
       (boolean?)
       (is-a?/c style-delta%))
  (()
   ((white-on-black? #f)))
  @{This delta is designed for use with @method[text% set-clickback].
    Use the result of this function as the style
    for the region text where the clickback is set.
    
    If @racket[white-on-black?] is true, the function returns
    a delta suitable for use on a black background.
    
    See also
    @racket[gui-utils:get-clicked-clickback-delta].}))
