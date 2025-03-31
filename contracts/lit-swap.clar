;; LitSwap: P2P Book Exchange Protocol
;; Version: 1.0.0
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-LISTING-NOT-FOUND (err u2))
(define-constant ERR-ALREADY-LISTED (err u3))
(define-constant ERR-INVALID-STATUS (err u4))
(define-constant ERR-INVALID-QUANTITY (err u5))
(define-constant ERR-INVALID-GENRE (err u6))
(define-constant ERR-INVALID-CONDITION (err u7))
(define-constant ERR-INVALID-TITLE (err u8))
(define-constant ERR-INVALID-DESCRIPTION (err u9))
(define-constant MIN-QUANTITY u1)
(define-data-var next-listing-id uint u1)
(define-map listings
    uint
    {
        owner: principal,
        book-title: (string-utf8 50),
        description: (string-utf8 200),
        genre: (string-utf8 10),
        condition: (string-utf8 20),
        status: (string-utf8 10),
        quantity: uint
    }
)
(define-private (validate-genre (genre (string-utf8 10)))
    (or 
        (is-eq genre u"Fiction")
        (is-eq genre u"Non-Fiction")
        (is-eq genre u"Mystery")
        (is-eq genre u"Sci-Fi")
        (is-eq genre u"Biography")
        (is-eq genre u"Education")
    )
)
(define-private (validate-condition (condition (string-utf8 20)))
    (or 
        (is-eq condition u"New")
        (is-eq condition u"Like New")
        (is-eq condition u"Good")
        (is-eq condition u"Fair")
        (is-eq condition u"Poor")
    )
)
(define-private (validate-text-length (text (string-utf8 200)) (min-length uint) (max-length uint))
    (let 
        (
            (text-length (len text))
        )
        (and 
            (>= text-length min-length)
            (<= text-length max-length)
        )
    )
)
(define-public (create-listing 
    (book-title (string-utf8 50))
    (description (string-utf8 200))
    (genre (string-utf8 10))
    (condition (string-utf8 20))
    (quantity uint)
)
    (let
        (
            (listing-id (var-get next-listing-id))
        )
        (asserts! (validate-text-length book-title u3 u50) ERR-INVALID-TITLE)
        (asserts! (validate-text-length description u10 u200) ERR-INVALID-DESCRIPTION)
        (asserts! (>= quantity MIN-QUANTITY) ERR-INVALID-QUANTITY)
        (asserts! (validate-genre genre) ERR-INVALID-GENRE)
        (asserts! (validate-condition condition) ERR-INVALID-CONDITION)
        
        (map-set listings listing-id {
            owner: tx-sender,
            book-title: book-title,
            description: description,
            genre: genre,
            condition: condition,
            status: u"available",
            quantity: quantity
        })
        (var-set next-listing-id (+ listing-id u1))
        (ok listing-id)
    )
)
(define-public (withdraw-listing (listing-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings listing-id) ERR-LISTING-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get owner listing)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status listing) u"available") ERR-INVALID-STATUS)
        (ok (map-set listings listing-id (merge listing { status: u"withdrawn" })))
    )
)
(define-read-only (get-listing (listing-id uint))
    (ok (map-get? listings listing-id))
)
(define-read-only (get-owner (listing-id uint))
    (ok (get owner (unwrap! (map-get? listings listing-id) ERR-LISTING-NOT-FOUND)))
)