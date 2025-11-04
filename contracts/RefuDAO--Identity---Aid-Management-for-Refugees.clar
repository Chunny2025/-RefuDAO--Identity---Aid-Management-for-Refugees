(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ID (err u101))
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-NOT-FOUND (err u104))
(define-constant ERR-NOT-ELIGIBLE (err u105))

(define-constant MIN-AID-INTERVAL u144)
(define-constant MAX-AID-PER-PERIOD u1000000)

(define-data-var dao-admin principal tx-sender)
(define-data-var aid-pool uint u0)
(define-data-var contract-paused bool false)

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

(define-public (toggle-pause)
    (begin
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-paused (not (var-get contract-paused))))))

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

(define-public (update-refugee-status (refugee-address principal) (new-status bool))
   (begin
       (asserts! (default-to false (map-get? verified-ngos tx-sender)) ERR-NOT-AUTHORIZED)
       (let ((current-data (unwrap! (map-get? refugee-identities refugee-address) ERR-NOT-FOUND)))
           (ok (map-set refugee-identities refugee-address (merge current-data { status: new-status }))))))

(define-public (deposit-aid)
    (begin
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
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
(define-private (is-aid-eligible (refugee-data {id-hash: (buff 32), status: bool, aid-received: uint, last-aid-date: uint}) (requested-amount uint))
    (let (
        (blocks-since-aid (- burn-block-height (get last-aid-date refugee-data)))
        (period-aid-total (if (< blocks-since-aid MIN-AID-INTERVAL) (get aid-received refugee-data) u0))
    )
        (and 
            (get status refugee-data)
            (>= blocks-since-aid MIN-AID-INTERVAL)
            (<= (+ period-aid-total requested-amount) MAX-AID-PER-PERIOD))))

(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? aid-proposals proposal-id) ERR-NOT-FOUND))
        (refugee-data (unwrap! (map-get? refugee-identities (get beneficiary proposal)) ERR-NOT-FOUND))
    )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (default-to false (map-get? verified-ngos tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (>= (get votes proposal) u3) ERR-NOT-AUTHORIZED)
        (asserts! (not (get executed proposal)) ERR-NOT-AUTHORIZED)
        (asserts! (is-aid-eligible refugee-data (get amount proposal)) ERR-NOT-ELIGIBLE)
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

(define-read-only (check-aid-eligibility (refugee-address principal) (requested-amount uint))
    (match (map-get? refugee-identities refugee-address)
        refugee-data (is-aid-eligible refugee-data requested-amount)
        false))

(define-read-only (get-blocks-until-eligible (refugee-address principal))
     (match (map-get? refugee-identities refugee-address)
         refugee-data
             (let ((blocks-since-aid (- burn-block-height (get last-aid-date refugee-data))))
                 (if (>= blocks-since-aid MIN-AID-INTERVAL)
                     u0
                     (- MIN-AID-INTERVAL blocks-since-aid)))
         u0))

(define-public (emergency-aid (refugee-address principal) (amount uint))
    (let ((refugee-data (unwrap! (map-get? refugee-identities refugee-address) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get aid-pool)) ERR-INSUFFICIENT-FUNDS)
        (asserts! (is-aid-eligible refugee-data amount) ERR-NOT-ELIGIBLE)
        (try! (as-contract (stx-transfer? amount tx-sender refugee-address)))
        (map-set refugee-identities refugee-address
            (merge refugee-data
                {
                    aid-received: (+ (get aid-received refugee-data) amount),
                    last-aid-date: burn-block-height
                }))
        (var-set aid-pool (- (var-get aid-pool) amount))
        (ok true)))