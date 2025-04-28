;; LitSwap: P2P Book Exchange Protocol
;; Version: 1.1.0
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-LISTING-NOT-FOUND (err u2))
(define-constant ERR-ALREADY-LISTED (err u3))
(define-constant ERR-INVALID-STATUS (err u4))
(define-constant ERR-INVALID-QUANTITY (err u5))
(define-constant ERR-INVALID-GENRE (err u6))
(define-constant ERR-INVALID-CONDITION (err u7))
(define-constant ERR-INVALID-TITLE (err u8))
(define-constant ERR-INVALID-DESCRIPTION (err u9))
(define-constant ERR-EXCHANGE-NOT-FOUND (err u10))
(define-constant ERR-SELF-EXCHANGE (err u11))
(define-constant ERR-LISTING-UNAVAILABLE (err u12))
(define-constant ERR-EXCHANGE-INVALID-STATUS (err u13))
(define-constant MIN-QUANTITY u1)

(define-data-var next-listing-id uint u1)
(define-data-var next-exchange-id uint u1)

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

(define-map exchanges
    uint
    {
        requester: principal,
        owner: principal,
        requested-listing-id: uint,
        offered-listing-id: uint,
        status: (string-utf8 10)
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

;; New Exchange Functionality

(define-public (propose-exchange (requested-listing-id uint) (offered-listing-id uint))
    (let
        (
            (requested-listing (unwrap! (map-get? listings requested-listing-id) ERR-LISTING-NOT-FOUND))
            (offered-listing (unwrap! (map-get? listings offered-listing-id) ERR-LISTING-NOT-FOUND))
            (exchange-id (var-get next-exchange-id))
        )
        ;; Validate that requested listing is available
        (asserts! (is-eq (get status requested-listing) u"available") ERR-LISTING-UNAVAILABLE)
        
        ;; Validate that offered listing is available and owned by sender
        (asserts! (is-eq (get status offered-listing) u"available") ERR-LISTING-UNAVAILABLE)
        (asserts! (is-eq (get owner offered-listing) tx-sender) ERR-NOT-AUTHORIZED)
        
        ;; Prevent self-exchanges
        (asserts! (not (is-eq tx-sender (get owner requested-listing))) ERR-SELF-EXCHANGE)
        
        ;; Create exchange record
        (map-set exchanges exchange-id {
            requester: tx-sender,
            owner: (get owner requested-listing),
            requested-listing-id: requested-listing-id,
            offered-listing-id: offered-listing-id,
            status: u"pending"
        })
        
        ;; Update the status of both listings to pending
        (map-set listings requested-listing-id (merge requested-listing { status: u"pending" }))
        (map-set listings offered-listing-id (merge offered-listing { status: u"pending" }))
        
        ;; Increment exchange ID
        (var-set next-exchange-id (+ exchange-id u1))
        
        (ok exchange-id)
    )
)

(define-public (accept-exchange (exchange-id uint))
    (let
        (
            (exchange (unwrap! (map-get? exchanges exchange-id) ERR-EXCHANGE-NOT-FOUND))
            (requested-listing-id (get requested-listing-id exchange))
            (offered-listing-id (get offered-listing-id exchange))
            (requested-listing (unwrap! (map-get? listings requested-listing-id) ERR-LISTING-NOT-FOUND))
            (offered-listing (unwrap! (map-get? listings offered-listing-id) ERR-LISTING-NOT-FOUND))
        )
        ;; Validate that sender is the owner of the requested listing
        (asserts! (is-eq tx-sender (get owner exchange)) ERR-NOT-AUTHORIZED)
        
        ;; Validate that exchange is pending
        (asserts! (is-eq (get status exchange) u"pending") ERR-EXCHANGE-INVALID-STATUS)
        
        ;; Update exchange status
        (map-set exchanges exchange-id (merge exchange { status: u"completed" }))
        
        ;; Swap ownership of the books
        (map-set listings requested-listing-id (merge requested-listing { 
            owner: (get requester exchange),
            status: u"available"
        }))
        (map-set listings offered-listing-id (merge offered-listing { 
            owner: tx-sender,
            status: u"available"
        }))
        
        (ok true)
    )
)

(define-public (reject-exchange (exchange-id uint))
    (let
        (
            (exchange (unwrap! (map-get? exchanges exchange-id) ERR-EXCHANGE-NOT-FOUND))
            (requested-listing-id (get requested-listing-id exchange))
            (offered-listing-id (get offered-listing-id exchange))
            (requested-listing (unwrap! (map-get? listings requested-listing-id) ERR-LISTING-NOT-FOUND))
            (offered-listing (unwrap! (map-get? listings offered-listing-id) ERR-LISTING-NOT-FOUND))
        )
        ;; Validate that sender is the owner of the requested listing
        (asserts! (is-eq tx-sender (get owner exchange)) ERR-NOT-AUTHORIZED)
        
        ;; Validate that exchange is pending
        (asserts! (is-eq (get status exchange) u"pending") ERR-EXCHANGE-INVALID-STATUS)
        
        ;; Update exchange status
        (map-set exchanges exchange-id (merge exchange { status: u"rejected" }))
        
        ;; Reset listing status back to available
        (map-set listings requested-listing-id (merge requested-listing { status: u"available" }))
        (map-set listings offered-listing-id (merge offered-listing { status: u"available" }))
        
        (ok true)
    )
)

(define-public (cancel-exchange (exchange-id uint))
    (let
        (
            (exchange (unwrap! (map-get? exchanges exchange-id) ERR-EXCHANGE-NOT-FOUND))
            (requested-listing-id (get requested-listing-id exchange))
            (offered-listing-id (get offered-listing-id exchange))
            (requested-listing (unwrap! (map-get? listings requested-listing-id) ERR-LISTING-NOT-FOUND))
            (offered-listing (unwrap! (map-get? listings offered-listing-id) ERR-LISTING-NOT-FOUND))
        )
        ;; Validate that sender is the requester
        (asserts! (is-eq tx-sender (get requester exchange)) ERR-NOT-AUTHORIZED)
        
        ;; Validate that exchange is pending
        (asserts! (is-eq (get status exchange) u"pending") ERR-EXCHANGE-INVALID-STATUS)
        
        ;; Update exchange status
        (map-set exchanges exchange-id (merge exchange { status: u"cancelled" }))
        
        ;; Reset listing status back to available
        (map-set listings requested-listing-id (merge requested-listing { status: u"available" }))
        (map-set listings offered-listing-id (merge offered-listing { status: u"available" }))
        
        (ok true)
    )
)

(define-read-only (get-exchange (exchange-id uint))
    (ok (map-get? exchanges exchange-id))
)

(define-read-only (is-exchange-for-user (exchange-id uint) (user principal))
    (match (map-get? exchanges exchange-id)
        exchange (or (is-eq (get requester exchange) user) 
                     (is-eq (get owner exchange) user))
        false
    )
)

(define-read-only (check-exchange-status (exchange-id uint))
    (match (map-get? exchanges exchange-id)
        exchange (get status exchange)
        u""
    )
)