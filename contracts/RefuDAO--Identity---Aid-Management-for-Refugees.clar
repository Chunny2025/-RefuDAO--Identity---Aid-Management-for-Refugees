(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ID (err u101))
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-NOT-FOUND (err u104))

(define-data-var dao-admin principal tx-sender)
(define-data-var aid-pool uint u0)

(define-map verified-ngos principal bool)
(define-map refugee-identities 
    principal 
    {
        id-hash: (buff 32),
        status: bool,
        aid-received: uint,
        last-aid-date: uint
    }
)

(define-map aid-proposals 
    uint 
    {
        proposer: principal,
        amount: uint,
        beneficiary: principal,
        votes: uint,
        executed: bool
    }
)

(define-data-var proposal-counter uint u0)

(define-public (register-ngo (ngo-address principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (ok (map-set verified-ngos ngo-address true))))

(define-public (register-refugee (refugee-address principal) (identity-hash (buff 32)))
    (begin

        (asserts! (default-to false (map-get? verified-ngos tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? refugee-identities refugee-address)) ERR-ALREADY-REGISTERED)
        (ok (map-set refugee-identities 
            refugee-address
            {
                id-hash: identity-hash,
                status: true,
                aid-received: u0,
                last-aid-date: u0
            }
        ))))

(define-public (deposit-aid)
    (begin
        (var-set aid-pool (+ (var-get aid-pool) (stx-get-balance tx-sender)))
        (ok (stx-transfer? (stx-get-balance tx-sender) tx-sender (as-contract tx-sender)))))

(define-public (create-aid-proposal (beneficiary principal) (amount uint))
    (let ((proposal-id (+ (var-get proposal-counter) u1)))
        (asserts! (default-to false (map-get? verified-ngos tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get aid-pool)) ERR-INSUFFICIENT-FUNDS)
        (var-set proposal-counter proposal-id)
        (ok (map-set aid-proposals proposal-id
            {
                proposer: tx-sender,
                amount: amount,
                beneficiary: beneficiary,
                votes: u0,
                executed: false
            }))))
(define-public (vote-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? aid-proposals proposal-id) ERR-NOT-FOUND)))
        (asserts! (default-to false (map-get? verified-ngos tx-sender)) ERR-NOT-AUTHORIZED)
        (ok (map-set aid-proposals proposal-id
            (merge proposal { votes: (+ (get votes proposal) u1) })))))
(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? aid-proposals proposal-id) ERR-NOT-FOUND))
        (refugee-data (unwrap! (map-get? refugee-identities (get beneficiary proposal)) ERR-NOT-FOUND))
    )

        (asserts! (default-to false (map-get? verified-ngos tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (>= (get votes proposal) u3) ERR-NOT-AUTHORIZED)
        (asserts! (not (get executed proposal)) ERR-NOT-AUTHORIZED)
        (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get beneficiary proposal))))
        (map-set refugee-identities (get beneficiary proposal)
            (merge refugee-data 
                { 
                    aid-received: (+ (get aid-received refugee-data) (get amount proposal)),
                    last-aid-date: burn-block-height
                }))
        (map-set aid-proposals proposal-id (merge proposal { executed: true }))
        (var-set aid-pool (- (var-get aid-pool) (get amount proposal)))
        (ok true)))
(define-read-only (get-refugee-data (refugee-address principal))
    (map-get? refugee-identities refugee-address))

(define-read-only (get-proposal (proposal-id uint))
    (map-get? aid-proposals proposal-id))

(define-read-only (get-aid-pool-balance)
    (var-get aid-pool))