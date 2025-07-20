;; Conservation Incentive Contract
;; Rewards users for reduced water consumption

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-USER-NOT-FOUND (err u402))
(define-constant ERR-GOAL-NOT-FOUND (err u403))
(define-constant ERR-INSUFFICIENT-TOKENS (err u404))
(define-constant ERR-REWARD-CLAIMED (err u405))

;; Token name and symbol
(define-fungible-token conservation-token)

;; Data Variables
(define-data-var next-user-id uint u1)
(define-data-var next-goal-id uint u1)
(define-data-var token-reward-rate uint u10) ;; tokens per gallon saved
(define-data-var bonus-multiplier uint u150) ;; 1.5x for exceeding goals

;; Data Maps
(define-map conservation-users
  { user-id: uint }
  {
    address: principal,
    name: (string-ascii 50),
    baseline-usage: uint, ;; monthly baseline in gallons
    current-period-usage: uint,
    total-tokens-earned: uint,
    active: bool,
    joined-at: uint
  }
)

(define-map user-lookup
  { address: principal }
  { user-id: uint }
)

(define-map conservation-goals
  { goal-id: uint }
  {
    user-id: uint,
    target-reduction: uint, ;; percentage reduction target
    period-start: uint,
    period-end: uint,
    baseline-usage: uint,
    actual-usage: uint,
    achieved: bool,
    reward-amount: uint,
    claimed: bool
  }
)

(define-map monthly-performance
  { user-id: uint, month: uint }
  {
    usage: uint,
    reduction-percentage: uint,
    tokens-earned: uint,
    bonus-applied: bool
  }
)

(define-map community-challenges
  { challenge-id: uint }
  {
    name: (string-ascii 50),
    target-participants: uint,
    current-participants: uint,
    collective-goal: uint, ;; total gallons to save
    current-savings: uint,
    reward-pool: uint,
    start-block: uint,
    end-block: uint,
    active: bool
  }
)

;; Public Functions

;; Register user for conservation program
(define-public (register-conservation-user
  (user-address principal)
  (name (string-ascii 50))
  (baseline-usage uint))
  (let ((user-id (var-get next-user-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> baseline-usage u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? user-lookup { address: user-address })) ERR-INVALID-INPUT)

    (map-set conservation-users
      { user-id: user-id }
      {
        address: user-address,
        name: name,
        baseline-usage: baseline-usage,
        current-period-usage: u0,
        total-tokens-earned: u0,
        active: true,
        joined-at: block-height
      }
    )

    (map-set user-lookup
      { address: user-address }
      { user-id: user-id }
    )

    (var-set next-user-id (+ user-id u1))
    (ok user-id)
  )
)

;; Set conservation goal for user
(define-public (set-conservation-goal
  (user-id uint)
  (target-reduction uint)
  (period-duration uint))
  (let (
    (goal-id (var-get next-goal-id))
    (user-data (unwrap! (map-get? conservation-users { user-id: user-id }) ERR-USER-NOT-FOUND))
  )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get address user-data))) ERR-NOT-AUTHORIZED)
    (asserts! (and (> target-reduction u0) (<= target-reduction u100)) ERR-INVALID-INPUT)
    (asserts! (> period-duration u0) ERR-INVALID-INPUT)

    (map-set conservation-goals
      { goal-id: goal-id }
      {
        user-id: user-id,
        target-reduction: target-reduction,
        period-start: block-height,
        period-end: (+ block-height period-duration),
        baseline-usage: (get baseline-usage user-data),
        actual-usage: u0,
        achieved: false,
        reward-amount: u0,
        claimed: false
      }
    )

    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

;; Record monthly usage and calculate rewards
(define-public (record-monthly-usage (user-id uint) (month uint) (usage uint))
  (let (
    (user-data (unwrap! (map-get? conservation-users { user-id: user-id }) ERR-USER-NOT-FOUND))
    (baseline (get baseline-usage user-data))
    (reduction-pct (if (< usage baseline)
      (/ (* (- baseline usage) u100) baseline)
      u0))
    (tokens-earned (if (> reduction-pct u0)
      (* (- baseline usage) (var-get token-reward-rate))
      u0))
    (bonus-applied (>= reduction-pct u20)) ;; 20% reduction gets bonus
    (final-tokens (if bonus-applied
      (/ (* tokens-earned (var-get bonus-multiplier)) u100)
      tokens-earned))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> usage u0) ERR-INVALID-INPUT)

    (map-set monthly-performance
      { user-id: user-id, month: month }
      {
        usage: usage,
        reduction-percentage: reduction-pct,
        tokens-earned: final-tokens,
        bonus-applied: bonus-applied
      }
    )

    ;; Update user's current period usage
    (map-set conservation-users
      { user-id: user-id }
      (merge user-data {
        current-period-usage: usage,
        total-tokens-earned: (+ (get total-tokens-earned user-data) final-tokens)
      })
    )

    ;; Mint tokens if earned
    (if (> final-tokens u0)
      (ft-mint? conservation-token final-tokens (get address user-data))
      (ok true)
    )
  )
)

;; Check and update goal achievement
(define-public (check-goal-achievement (goal-id uint))
  (let (
    (goal-data (unwrap! (map-get? conservation-goals { goal-id: goal-id }) ERR-GOAL-NOT-FOUND))
    (user-data (unwrap! (map-get? conservation-users { user-id: (get user-id goal-data) }) ERR-USER-NOT-FOUND))
    (actual-usage (get current-period-usage user-data))
    (baseline (get baseline-usage goal-data))
    (target-usage (- baseline (/ (* baseline (get target-reduction goal-data)) u100)))
    (achieved (<= actual-usage target-usage))
    (reward-amount (if achieved (* (- baseline actual-usage) u5) u0)) ;; 5 tokens per gallon saved
  )
    (asserts! (>= block-height (get period-end goal-data)) ERR-INVALID-INPUT)

    (map-set conservation-goals
      { goal-id: goal-id }
      (merge goal-data {
        actual-usage: actual-usage,
        achieved: achieved,
        reward-amount: reward-amount
      })
    )

    (ok achieved)
  )
)

;; Claim goal achievement reward
(define-public (claim-goal-reward (goal-id uint))
  (let (
    (goal-data (unwrap! (map-get? conservation-goals { goal-id: goal-id }) ERR-GOAL-NOT-FOUND))
    (user-data (unwrap! (map-get? conservation-users { user-id: (get user-id goal-data) }) ERR-USER-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get address user-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get achieved goal-data) ERR-INVALID-INPUT)
    (asserts! (not (get claimed goal-data)) ERR-REWARD-CLAIMED)
    (asserts! (> (get reward-amount goal-data) u0) ERR-INVALID-INPUT)

    (map-set conservation-goals
      { goal-id: goal-id }
      (merge goal-data { claimed: true })
    )

    (try! (ft-mint? conservation-token (get reward-amount goal-data) (get address user-data)))
    (ok true)
  )
)

;; Transfer tokens between users
(define-public (transfer-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (try! (ft-transfer? conservation-token amount tx-sender recipient))
    (ok true)
  )
)

;; Update reward parameters
(define-public (update-reward-parameters (reward-rate uint) (bonus-mult uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (> reward-rate u0) (> bonus-mult u100)) ERR-INVALID-INPUT)

    (var-set token-reward-rate reward-rate)
    (var-set bonus-multiplier bonus-mult)
    (ok true)
  )
)

;; Read-only Functions

;; Get conservation user details
(define-read-only (get-conservation-user (user-id uint))
  (map-get? conservation-users { user-id: user-id })
)

;; Get user ID by address
(define-read-only (get-conservation-user-id (address principal))
  (map-get? user-lookup { address: address })
)

;; Get conservation goal
(define-read-only (get-conservation-goal (goal-id uint))
  (map-get? conservation-goals { goal-id: goal-id })
)

;; Get monthly performance
(define-read-only (get-monthly-performance (user-id uint) (month uint))
  (map-get? monthly-performance { user-id: user-id, month: month })
)

;; Get token balance
(define-read-only (get-token-balance (address principal))
  (ft-get-balance conservation-token address)
)

;; Get total token supply
(define-read-only (get-total-supply)
  (ft-get-supply conservation-token)
)

;; Get current reward parameters
(define-read-only (get-reward-parameters)
  {
    token-reward-rate: (var-get token-reward-rate),
    bonus-multiplier: (var-get bonus-multiplier)
  }
)

;; Calculate potential savings for target reduction
(define-read-only (calculate-potential-savings (baseline-usage uint) (target-reduction uint))
  (let ((target-usage (- baseline-usage (/ (* baseline-usage target-reduction) u100))))
    {
      target-usage: target-usage,
      gallons-saved: (- baseline-usage target-usage),
      potential-tokens: (* (- baseline-usage target-usage) (var-get token-reward-rate))
    }
  )
)
