(define-constant contract-owner tx-sender)

(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-ORACLE (err u104))
(define-constant ERR-PRICE-TOO-OLD (err u105))
(define-constant ERR-COLLATERAL-RATIO-TOO-LOW (err u106))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u107))
(define-constant ERR-POSITION-NOT-FOUND (err u108))
(define-constant ERR-LIQUIDATION-THRESHOLD-NOT-MET (err u109))
(define-constant ERR-NO-REWARDS (err u110))

(define-data-var token-name (string-ascii 32) "Synthetic Gold Token")
(define-data-var token-symbol (string-ascii 10) "sGOLD")
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)

(define-data-var oracle-address principal contract-owner)
(define-data-var min-collateral-ratio uint u150)
(define-data-var liquidation-threshold uint u120)
(define-data-var oracle-price uint u0)
(define-data-var oracle-timestamp uint u0)
(define-data-var max-price-age uint u3600)
(define-data-var reward-rate-per-block uint u1)
(define-data-var total-rewards-distributed uint u0)

(define-map token-balances principal uint)
(define-map token-supplies principal uint)
(define-map user-reward-checkpoint {user: principal, block: uint} uint)

(define-map collateral-positions 
    principal 
    {
        stx-collateral: uint,
        synthetic-debt: uint,
        last-update: uint
    }
)

(define-map allowed-spenders {owner: principal, spender: principal} uint)

(define-read-only (get-name)
    (var-get token-name)
)

(define-read-only (get-symbol)
    (var-get token-symbol)
)

(define-read-only (get-decimals)
    (var-get token-decimals)
)

(define-read-only (get-total-supply)
    (var-get total-supply)
)

(define-read-only (get-balance (who principal))
    (default-to u0 (map-get? token-balances who))
)

(define-read-only (get-token-uri)
    none
)

(define-read-only (get-oracle-price)
    (var-get oracle-price)
)

(define-read-only (get-oracle-timestamp)
    (var-get oracle-timestamp)
)

(define-read-only (get-collateral-position (user principal))
    (map-get? collateral-positions user)
)

(define-read-only (get-collateral-ratio (user principal))
    (match (map-get? collateral-positions user)
        position
        (let 
            (
                (stx-value (* (get stx-collateral position) (var-get oracle-price)))
                (debt-value (* (get synthetic-debt position) u1000000))
            )
            (if (> debt-value u0)
                (some (/ (* stx-value u100) debt-value))
                none
            )
        )
        none
    )
)

(define-read-only (is-position-liquidatable (user principal))
    (match (get-collateral-ratio user)
        ratio (< ratio (var-get liquidation-threshold))
        false
    )
)

(define-read-only (calculate-max-synthetic (stx-amount uint))
    (let
        (
            (stx-value (* stx-amount (var-get oracle-price)))
            (max-debt (* stx-value u100))
            (required-ratio (var-get min-collateral-ratio))
        )
        (/ max-debt required-ratio)
    )
)

(define-read-only (calculate-accrued-rewards (user principal))
    (match (map-get? collateral-positions user)
        position
        (let
            (
                (blocks-elapsed (- stacks-block-height (get last-update position)))
                (collateral-amount (get stx-collateral position))
                (reward-rate (var-get reward-rate-per-block))
                (accrued (* (* blocks-elapsed collateral-amount) reward-rate))
            )
            (some accrued)
        )
        none
    )
)

(define-private (is-price-fresh)
    (< (- stacks-block-height (var-get oracle-timestamp)) (var-get max-price-age))
)

(define-public (set-oracle-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get oracle-address)) ERR-INVALID-ORACLE)
        (var-set oracle-price new-price)
        (var-set oracle-timestamp stacks-block-height)
        (ok true)
    )
)

(define-public (update-oracle-address (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
        (var-set oracle-address new-oracle)
        (ok true)
    )
)

(define-public (update-collateral-params (new-min-ratio uint) (new-liquidation-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
        (asserts! (> new-min-ratio new-liquidation-threshold) ERR-INVALID-AMOUNT)
        (var-set min-collateral-ratio new-min-ratio)
        (var-set liquidation-threshold new-liquidation-threshold)
        (ok true)
    )
)

(define-private (mint-tokens (recipient principal) (amount uint))
    (begin
        (map-set token-balances recipient (+ (get-balance recipient) amount))
        (var-set total-supply (+ (var-get total-supply) amount))
        (print {action: "mint", recipient: recipient, amount: amount})
        (ok true)
    )
)

(define-private (burn-tokens (sender principal) (amount uint))
    (let ((sender-balance (get-balance sender)))
        (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
        (map-set token-balances sender (- sender-balance amount))
        (var-set total-supply (- (var-get total-supply) amount))
        (print {action: "burn", sender: sender, amount: amount})
        (ok true)
    )
)

(define-public (deposit-collateral)
    (let 
        (
            (stx-amount (stx-get-balance tx-sender))
            (current-position (default-to {stx-collateral: u0, synthetic-debt: u0, last-update: u0} 
                                          (map-get? collateral-positions tx-sender)))
        )
        (asserts! (> stx-amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
        (map-set collateral-positions tx-sender
            {
                stx-collateral: (+ (get stx-collateral current-position) stx-amount),
                synthetic-debt: (get synthetic-debt current-position),
                last-update: stacks-block-height
            }
        )
        (ok stx-amount)
    )
)

(define-public (mint-synthetic (amount uint))
    (let 
        (
            (current-position (unwrap! (map-get? collateral-positions tx-sender) ERR-POSITION-NOT-FOUND))
            (max-mintable (calculate-max-synthetic (get stx-collateral current-position)))
            (new-debt (+ (get synthetic-debt current-position) amount))
        )
        (asserts! (is-price-fresh) ERR-PRICE-TOO-OLD)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= new-debt max-mintable) ERR-INSUFFICIENT-COLLATERAL)
        
        (map-set collateral-positions tx-sender
            {
                stx-collateral: (get stx-collateral current-position),
                synthetic-debt: new-debt,
                last-update: stacks-block-height
            }
        )
        (unwrap! (mint-tokens tx-sender amount) ERR-INVALID-AMOUNT)
        (ok amount)
    )
)

(define-public (burn-synthetic (amount uint))
    (let 
        (
            (current-position (unwrap! (map-get? collateral-positions tx-sender) ERR-POSITION-NOT-FOUND))
            (current-debt (get synthetic-debt current-position))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= amount current-debt) ERR-INVALID-AMOUNT)
        
        (try! (burn-tokens tx-sender amount))
        (map-set collateral-positions tx-sender
            {
                stx-collateral: (get stx-collateral current-position),
                synthetic-debt: (- current-debt amount),
                last-update: stacks-block-height
            }
        )
        (ok amount)
    )
)

(define-public (withdraw-collateral (amount uint))
    (let 
        (
            (current-position (unwrap! (map-get? collateral-positions tx-sender) ERR-POSITION-NOT-FOUND))
            (remaining-collateral (- (get stx-collateral current-position) amount))
            (debt (get synthetic-debt current-position))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= (get stx-collateral current-position) amount) ERR-INSUFFICIENT-BALANCE)
        
        (if (> debt u0)
            (let ((max-mintable (calculate-max-synthetic remaining-collateral)))
                (asserts! (<= debt max-mintable) ERR-COLLATERAL-RATIO-TOO-LOW)
            )
            true
        )
        
        (map-set collateral-positions tx-sender
            {
                stx-collateral: remaining-collateral,
                synthetic-debt: debt,
                last-update: stacks-block-height
            }
        )
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (ok amount)
    )
)

(define-public (liquidate (user principal) (debt-to-cover uint))
    (let
        (
            (position (unwrap! (map-get? collateral-positions user) ERR-POSITION-NOT-FOUND))
            (user-debt (get synthetic-debt position))
            (user-collateral (get stx-collateral position))
            (liquidator-balance (get-balance tx-sender))
        )
        (asserts! (is-price-fresh) ERR-PRICE-TOO-OLD)
        (asserts! (is-position-liquidatable user) ERR-LIQUIDATION-THRESHOLD-NOT-MET)
        (asserts! (> debt-to-cover u0) ERR-INVALID-AMOUNT)
        (asserts! (<= debt-to-cover user-debt) ERR-INVALID-AMOUNT)
        (asserts! (>= liquidator-balance debt-to-cover) ERR-INSUFFICIENT-BALANCE)

        (let
            (
                (collateral-to-seize (/ (* debt-to-cover user-collateral) user-debt))
                (liquidation-bonus (/ collateral-to-seize u10))
                (total-collateral-reward (+ collateral-to-seize liquidation-bonus))
            )
            (try! (burn-tokens tx-sender debt-to-cover))
            (map-set collateral-positions user
                {
                    stx-collateral: (- user-collateral total-collateral-reward),
                    synthetic-debt: (- user-debt debt-to-cover),
                    last-update: stacks-block-height
                }
            )
            (try! (as-contract (stx-transfer? total-collateral-reward tx-sender tx-sender)))
            (ok total-collateral-reward)
        )
    )
)

(define-public (claim-rewards)
    (let
        (
            (accrued-rewards (unwrap! (calculate-accrued-rewards tx-sender) ERR-NO-REWARDS))
            (position (unwrap! (map-get? collateral-positions tx-sender) ERR-POSITION-NOT-FOUND))
        )
        (asserts! (> accrued-rewards u0) ERR-NO-REWARDS)
        (map-set token-balances tx-sender (+ (get-balance tx-sender) accrued-rewards))
        (var-set total-supply (+ (var-get total-supply) accrued-rewards))
        (map-set collateral-positions tx-sender
            {
                stx-collateral: (get stx-collateral position),
                synthetic-debt: (get synthetic-debt position),
                last-update: stacks-block-height
            }
        )
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) accrued-rewards))
        (print {action: "claim-rewards", user: tx-sender, amount: accrued-rewards})
        (ok accrued-rewards)
    )
)

(define-public (update-reward-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
        (var-set reward-rate-per-block new-rate)
        (ok true)
    )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR-NOT-TOKEN-OWNER)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= amount (get-balance sender)) ERR-INSUFFICIENT-BALANCE)
        
        (map-set token-balances sender (- (get-balance sender) amount))
        (map-set token-balances recipient (+ (get-balance recipient) amount))
        (print {action: "transfer", sender: sender, recipient: recipient, amount: amount, memo: memo})
        (ok true)
    )
)

(define-public (get-allowance (owner principal) (spender principal))
    (ok (default-to u0 (map-get? allowed-spenders {owner: owner, spender: spender})))
)

(define-public (approve (spender principal) (amount uint))
    (begin
        (map-set allowed-spenders {owner: tx-sender, spender: spender} amount)
        (print {action: "approve", owner: tx-sender, spender: spender, amount: amount})
        (ok true)
    )
)

(define-public (transfer-from (amount uint) (owner principal) (recipient principal) (memo (optional (buff 34))))
    (let ((allowance (unwrap! (get-allowance owner tx-sender) ERR-NOT-TOKEN-OWNER)))
        (asserts! (<= amount allowance) ERR-NOT-TOKEN-OWNER)
        (try! (transfer amount owner recipient memo))
        (map-set allowed-spenders {owner: owner, spender: tx-sender} (- allowance amount))
        (ok true)
    )
)

(define-public (mint-and-transfer (amount uint) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (mint-synthetic amount))
        (try! (transfer amount tx-sender recipient memo))
        (ok true)
    )
)
