;; Community Resource Allocation
;; A contract for communities to collectively manage and allocate shared resources

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-COMMUNITY-NOT-FOUND u2)
(define-constant ERR-RESOURCE-NOT-FOUND u3)
(define-constant ERR-MEMBER-NOT-FOUND u4)
(define-constant ERR-ALREADY-EXISTS u5)
(define-constant ERR-INSUFFICIENT-CONTRIBUTION u6)
(define-constant ERR-RESOURCE-DEPLETED u7)
(define-constant ERR-ALLOCATION-LIMIT-REACHED u8)
(define-constant ERR-INVALID-PARAMETERS u9)
(define-constant ERR-DISPUTE-NOT-FOUND u10)
(define-constant ERR-VOTE-ALREADY-CAST u11)
(define-constant ERR-VOTING-CLOSED u12)
(define-constant ERR-EXPANSION-NOT-FOUND u13)
(define-constant ERR-REQUEST-NOT-FOUND u14)
(define-constant ERR-ALLOCATION-NOT-FOUND u15)
(define-constant ERR-CANNOT-OVERALLOCATE u16)
(define-constant ERR-USAGE-LIMIT-EXCEEDED u17)
(define-constant ERR-INACTIVE-MEMBER u18)
(define-constant ERR-COOLDOWN-PERIOD u19)

;; Constants for resource types
(define-constant RESOURCE-TYPE-DIVISIBLE u1)  ;; Can be divided into units (e.g., tokens, water)
(define-constant RESOURCE-TYPE-TIME-BASED u2) ;; Allocated by time slots (e.g., meeting room)
(define-constant RESOURCE-TYPE-UNIQUE u3)     ;; Unique resources (e.g., equipment)

;; Constants for dispute status
(define-constant DISPUTE-STATUS-OPEN u1)
(define-constant DISPUTE-STATUS-VOTING u2)
(define-constant DISPUTE-STATUS-RESOLVED u3)
(define-constant DISPUTE-STATUS-CANCELED u4)

;; Constants for allocation status
(define-constant ALLOCATION-STATUS-PENDING u1)
(define-constant ALLOCATION-STATUS-APPROVED u2)
(define-constant ALLOCATION-STATUS-DENIED u3)
(define-constant ALLOCATION-STATUS-COMPLETED u4)
(define-constant ALLOCATION-STATUS-CANCELLED u5)

;; Constants for expansion status
(define-constant EXPANSION-STATUS-PROPOSAL u1)
(define-constant EXPANSION-STATUS-VOTING u2)
(define-constant EXPANSION-STATUS-APPROVED u3)
(define-constant EXPANSION-STATUS-DENIED u4)
(define-constant EXPANSION-STATUS-IMPLEMENTED u5)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-community-id uint u1)
(define-data-var next-resource-id uint u1)
(define-data-var next-member-id uint u1)
(define-data-var next-dispute-id uint u1)
(define-data-var next-allocation-id uint u1)
(define-data-var next-expansion-id uint u1)
(define-data-var next-vote-id uint u1)
(define-data-var next-request-id uint u1)



;; Mapping for communities
(define-map communities
  { community-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    founder: principal,
    creation-block: uint,
    membership-type: (string-utf8 20), ;; "open", "approval", "invitation"
    contribution-threshold: uint,      ;; Minimum contribution required
    active-member-count: uint,
    total-contribution: uint,          ;; Total community contributions
    resource-count: uint,
    is-active: bool
  }
)

;; Mapping for community admins
(define-map community-admins
  { community-id: uint, admin-principal: principal }
  { added-at: uint }
)

;; Mapping for resources
(define-map resources
  { resource-id: uint }
  {
    community-id: uint,
    name: (string-utf8 100),
    description: (string-utf8 500),
    resource-type: uint,
    total-supply: uint,           ;; Total available units/slots
    remaining-supply: uint,       ;; Currently available units/slots
    minimum-contribution: uint,   ;; Contribution required to access
    max-per-allocation: uint,     ;; Maximum units per allocation
    cooldown-period: uint,        ;; Blocks between allocations
    is-active: bool,
    created-at: uint,
    updated-at: uint
  }
)

;; Mapping for community members
(define-map members
  { community-id: uint, member-id: uint }
  {
    principal: principal,
    contribution: uint,
    join-block: uint,
    last-contribution-block: uint,
    allocation-count: uint,
    reputation-score: uint,       ;; 0-100 score
    is-active: bool,
    roles: (list 5 (string-utf8 50))
  }
)

;; Mapping for principal to member ID
(define-map principals-to-members
  { community-id: uint, principal: principal }
  { member-id: uint }
)

;; Mapping for resource allocations
(define-map allocations
  { allocation-id: uint }
  {
    resource-id: uint,
    community-id: uint,
    member-id: uint,
    amount: uint,               ;; Units or time slots
    start-block: uint,
    end-block: (optional uint), ;; For time-based resources
    status: uint,
    created-at: uint,
    updated-at: uint,
    notes: (string-utf8 200)
  }
)

;; Mapping for allocation requests
(define-map allocation-requests
  { request-id: uint }
  {
    resource-id: uint,
    community-id: uint,
    member-id: uint,
    amount: uint,
    requested-start: uint,
    requested-duration: (optional uint), ;; For time-based resources
    justification: (string-utf8 500),
    created-at: uint,
    status: uint,
    votes-for: uint,
    votes-against: uint
  }
)

;; Mapping for resource usage history
(define-map resource-usage
  { resource-id: uint, member-id: uint }
  {
    total-usage: uint,
    last-usage-block: uint,
    usage-count: uint,
    average-duration: uint,      ;; For time-based resources
    contribution-at-last-usage: uint
  }
)

;; Mapping for resource disputes
(define-map disputes
  { dispute-id: uint }
  {
    community-id: uint,
    resource-id: uint,
    allocation-id: (optional uint),
    raised-by: uint,             ;; member-id
    raised-against: (optional uint), ;; member-id (if applicable)
    dispute-type: (string-utf8 50),  ;; "overuse", "misuse", "fairness", etc.
    description: (string-utf8 500),
    status: uint,
    created-at: uint,
    resolution: (optional (string-utf8 500)),
    votes-for: uint,
    votes-against: uint,
    resolved-at: (optional uint)
  }
)

;; Mapping for dispute votes
(define-map dispute-votes
  { dispute-id: uint, member-id: uint }
  {
    vote: bool,                  ;; true = for, false = against
    justification: (string-utf8 200),
    weight: uint,                ;; Based on contribution/reputation
    vote-time: uint
  }
)

;; Mapping for resource expansion proposals
(define-map expansion-proposals
  { expansion-id: uint }
  {
    community-id: uint,
    resource-id: (optional uint), ;; If expanding existing resource
    name: (string-utf8 100),
    description: (string-utf8 500),
    proposed-by: uint,            ;; member-id
    resource-type: uint,
    proposed-supply: uint,
    estimated-cost: uint,
    funding-source: (string-utf8 100),
    status: uint,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    voting-ends-at: uint,
    implemented-at: (optional uint)
  }
)

;; Mapping for expansion votes
(define-map expansion-votes
  { expansion-id: uint, member-id: uint }
  {
    vote: bool,                  ;; true = for, false = against
    weight: uint,                ;; Based on contribution/reputation
    vote-time: uint
  }
)

;; Read-only functions

;; Get community details
(define-read-only (get-community (community-id uint))
  (map-get? communities { community-id: community-id })
)

;; Get resource details
(define-read-only (get-resource (resource-id uint))
  (map-get? resources { resource-id: resource-id })
)

;; Get member details
(define-read-only (get-member (community-id uint) (member-id uint))
  (map-get? members { community-id: community-id, member-id: member-id })
)
;; Get member ID from principal
(define-read-only (get-member-id (community-id uint) (user-principal principal))
  (map-get? principals-to-members { community-id: community-id, principal: user-principal })
)

;; Get allocation details
(define-read-only (get-allocation (allocation-id uint))
  (map-get? allocations { allocation-id: allocation-id })
)

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

;; Get expansion proposal details
(define-read-only (get-expansion-proposal (expansion-id uint))
  (map-get? expansion-proposals { expansion-id: expansion-id })
)

;; Calculate member's allocation entitlement based on contribution
(define-read-only (calculate-allocation-entitlement (community-id uint) (resource-id uint) (member-id uint))
  (let
    (
      (community (unwrap! (get-community community-id) (tuple (max-allocation u0))))
      (resource (unwrap! (get-resource resource-id) (tuple (max-allocation u0))))
      (member (unwrap! (get-member community-id member-id) (tuple (max-allocation u0))))
    )
    
    (if (< (get contribution member) (get minimum-contribution resource))
      ;; Not enough contribution
      (tuple (max-allocation u0))
      (let
        (
          (contribution-ratio (/ (* (get contribution member) u100) (get total-contribution community)))
          ;; Basic fair share = contribution percentage * total supply
          (fair-share (/ (* contribution-ratio (get total-supply resource)) u100))
          ;; Capped by max-per-allocation
          (capped-allocation (min fair-share (get max-per-allocation resource)))
        )
        (tuple (max-allocation capped-allocation))
      )
    )
  )
)

;; Check if member can allocate a resource now
(define-read-only (can-allocate-now (community-id uint) (resource-id uint) (member-id uint) (amount uint))
  (let
    (
      (resource (unwrap! (get-resource resource-id) false))
      (member (unwrap! (get-member community-id member-id) false))
      (usage (default-to { last-usage-block: u0, total-usage: u0, usage-count: u0, average-duration: u0, contribution-at-last-usage: u0 }
                       (map-get? resource-usage { resource-id: resource-id, member-id: member-id })))
    )
    
    (and
      ;; Resource is active
      (get is-active resource)
      ;; Member is active
      (get is-active member)
      ;; Sufficient contribution
      (>= (get contribution member) (get minimum-contribution resource))
      ;; Sufficient remaining supply
      (>= (get remaining-supply resource) amount)
      ;; Not in cooldown period
      (>= block-height (+ (get last-usage-block usage) (get cooldown-period resource)))
      ;; Amount is within member's entitlement
      (<= amount (get max-allocation (calculate-allocation-entitlement community-id resource-id member-id)))
    )
  )
)

;; Calculate vote weight based on member's contribution and reputation
(define-read-only (calculate-vote-weight (community-id uint) (member-id uint))
  (match (get-member community-id member-id)
    member
    (let
      (
        (contribution-weight (get contribution member))
        (reputation-modifier (/ (get reputation-score member) u50)) ;; 0.5-2x modifier based on reputation
      )
      (/ (* contribution-weight reputation-modifier) u100)
    )
    u0
  )
)

;; Public functions

;; Create a new community
(define-public (create-community 
  (name (string-utf8 100)) 
  (description (string-utf8 500)) 
  (membership-type (string-utf8 20))
  (contribution-threshold uint)
)
  (let
    (
      (community-id (var-get next-community-id))
      (member-id (var-get next-member-id))
    )
    
    ;; Create community
    (map-set communities
      { community-id: community-id }
      {
        name: name,
        description: description,
        founder: tx-sender,
        creation-block: block-height,
        membership-type: membership-type,
        contribution-threshold: contribution-threshold,
        active-member-count: u1, ;; Founder is first member
        total-contribution: contribution-threshold, ;; Initial contribution from founder
        resource-count: u0,
        is-active: true
      }
    )
    
    ;; Add founder as admin
    (map-set community-admins
      { community-id: community-id, admin-principal: tx-sender }
      { added-at: block-height }
    )
    
    ;; Add founder as member
    (map-set members
      { community-id: community-id, member-id: member-id }
      {
        principal: tx-sender,
        contribution: contribution-threshold,
        join-block: block-height,
        last-contribution-block: block-height,
        allocation-count: u0,
        reputation-score: u75, ;; Founder starts with good reputation
        is-active: true,
        roles: (list "founder" "admin")
      }
    )