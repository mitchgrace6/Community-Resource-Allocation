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
      ;; Map principal to member ID
    (map-set principals-to-members
      { community-id: community-id, principal: tx-sender }
      { member-id: member-id }
    )
    
    ;; Increment IDs
    (var-set next-community-id (+ community-id u1))
    (var-set next-member-id (+ member-id u1))
    
    (ok community-id)
  )
)

;; Add a new resource to a community
(define-public (add-resource
  (community-id uint)
  (name (string-utf8 100))
  (description (string-utf8 500))
  (resource-type uint)
  (total-supply uint)
  (minimum-contribution uint)
  (max-per-allocation uint)
  (cooldown-period uint)
)
  (let
    (
      (resource-id (var-get next-resource-id))
      (member-mapping (unwrap! (get-member-id community-id tx-sender) (err ERR-NOT-AUTHORIZED)))
      (member-id (get member-id member-mapping))
      (community (unwrap! (get-community community-id) (err ERR-COMMUNITY-NOT-FOUND)))
    )
    
    ;; Check if caller is admin
    (asserts! (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
              (err ERR-NOT-AUTHORIZED))
    
    ;; Create resource
    (map-set resources
      { resource-id: resource-id }
      {
        community-id: community-id,
        name: name,
        description: description,
        resource-type: resource-type,
        total-supply: total-supply,
        remaining-supply: total-supply,
        minimum-contribution: minimum-contribution,
        max-per-allocation: max-per-allocation,
        cooldown-period: cooldown-period,
        is-active: true,
        created-at: block-height,
        updated-at: block-height
      }
    )
    
    ;; Update community resource count
    (map-set communities
      { community-id: community-id }
      (merge community {
        resource-count: (+ (get resource-count community) u1)
      })
    )
    
    ;; Increment resource ID
    (var-set next-resource-id (+ resource-id u1))
    
    (ok resource-id)
  )
)

;; Join a community
(define-public (join-community (community-id uint) (initial-contribution uint))
  (let
    (
      (community (unwrap! (get-community community-id) (err ERR-COMMUNITY-NOT-FOUND)))
      (member-id (var-get next-member-id))
    )
    
    ;; Check if already a member
    (asserts! (is-none (get-member-id community-id tx-sender)) (err ERR-ALREADY-EXISTS))
    
    ;; Check contribution threshold
    (asserts! (>= initial-contribution (get contribution-threshold community)) (err ERR-INSUFFICIENT-CONTRIBUTION))
    
    ;; Check membership type
    (asserts! (or
               (is-eq (get membership-type community) "open")
               (and 
                 (is-eq (get membership-type community) "approval")
                 ;; For approval type, would need additional logic for approval workflow
                 true)
              ) 
              (err ERR-NOT-AUTHORIZED))
    
    ;; Add new member
    (map-set members
      { community-id: community-id, member-id: member-id }
      {
        principal: tx-sender,
        contribution: initial-contribution,
        join-block: block-height,
        last-contribution-block: block-height,
        allocation-count: u0,
        reputation-score: u50, ;; Default starting reputation
        is-active: true,
        roles: (list "member")
      }
    )
     ;; Map principal to member ID
    (map-set principals-to-members
      { community-id: community-id, principal: tx-sender }
      { member-id: member-id }
    )
    
    ;; Update community stats
    (map-set communities
      { community-id: community-id }
      (merge community {
        active-member-count: (+ (get active-member-count community) u1),
        total-contribution: (+ (get total-contribution community) initial-contribution)
      })
    )
    
    ;; Increment member ID
    (var-set next-member-id (+ member-id u1))
    
    (ok member-id)
  )
)

;; Make a contribution
(define-public (contribute (community-id uint) (amount uint))
  (let
    (
      (member-mapping (unwrap! (get-member-id community-id tx-sender) (err ERR-MEMBER-NOT-FOUND)))
      (member-id (get member-id member-mapping))
      (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
      (community (unwrap! (get-community community-id) (err ERR-COMMUNITY-NOT-FOUND)))
    )
    
    ;; Update member contribution
    (map-set members
      { community-id: community-id, member-id: member-id }
      (merge member {
        contribution: (+ (get contribution member) amount),
        last-contribution-block: block-height
      })
    )
    
    ;; Update community total contribution
    (map-set communities
      { community-id: community-id }
      (merge community {
        total-contribution: (+ (get total-contribution community) amount)
      })
    )
    
    (ok true)
  )
)

;; Request resource allocation
(define-public (request-allocation
  (community-id uint)
  (resource-id uint)
  (amount uint)
  (requested-start uint)
  (requested-duration (optional uint))
  (justification (string-utf8 500))
)
  (let
    (
      (request-id (var-get next-request-id))
      (member-mapping (unwrap! (get-member-id community-id tx-sender) (err ERR-MEMBER-NOT-FOUND)))
      (member-id (get member-id member-mapping))
      (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
      (resource (unwrap! (get-resource resource-id) (err ERR-RESOURCE-NOT-FOUND)))
    )
    
    ;; Check if member is active
    (asserts! (get is-active member) (err ERR-INACTIVE-MEMBER))
    
    ;; Check if resource belongs to community
    (asserts! (is-eq (get community-id resource) community-id) (err ERR-RESOURCE-NOT-FOUND))
    
    ;; Check if member is active
    (asserts! (get is-active member) (err ERR-INACTIVE-MEMBER))
    
    ;; Create dispute
    (map-set disputes
      { dispute-id: dispute-id }
      {
        community-id: community-id,
        resource-id: resource-id,
        allocation-id: allocation-id,
        raised-by: member-id,
        raised-against: against-member-id,
        dispute-type: dispute-type,
        description: description,
        status: DISPUTE-STATUS-OPEN,
        created-at: block-height,
        resolution: none,
        votes-for: u0,
        votes-against: u0,
        resolved-at: none
      }
    )
    
    ;; Increment dispute ID
    (var-set next-dispute-id (+ dispute-id u1))
    
    (ok dispute-id)
  )
)

;; Vote on a dispute
(define-public (vote-on-dispute (dispute-id uint) (vote bool) (justification (string-utf8 200)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) (err ERR-DISPUTE-NOT-FOUND)))
      (community-id (get community-id dispute))
      (member-mapping (unwrap! (get-member-id community-id tx-sender) (err ERR-MEMBER-NOT-FOUND)))
      (member-id (get member-id member-mapping))
      (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
      (vote-weight (calculate-vote-weight community-id member-id))
    )
    
    ;; Check if member is active
    (asserts! (get is-active member) (err ERR-INACTIVE-MEMBER))
    
    ;; Check if dispute is open for voting
    (asserts! (is-eq (get status dispute) DISPUTE-STATUS-VOTING) (err ERR-VOTING-CLOSED))
    
    ;; Check if member hasn't already voted
    (asserts! (is-none (map-get? dispute-votes { dispute-id: dispute-id, member-id: member-id })) (err ERR-VOTE-ALREADY-CAST))
    
    ;; Record vote
    (map-set dispute-votes
      { dispute-id: dispute-id, member-id: member-id }
      {
        vote: vote,
        justification: justification,
        weight: vote-weight,
        vote-time: block-height
      }
    )
    
    ;; Update vote tally
    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute {
        votes-for: (if vote 
                     (+ (get votes-for dispute) vote-weight)
                     (get votes-for dispute)),
        votes-against: (if vote 
                         (get votes-against dispute)
                         (+ (get votes-against dispute) vote-weight))
      })
    )
    
    (ok true)
  )
)

;; Resolve a dispute
(define-public (resolve-dispute (dispute-id uint) (resolution (string-utf8 500)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) (err ERR-DISPUTE-NOT-FOUND)))
      (community-id (get community-id dispute))
    )
    
    ;; Check if caller is admin
    (asserts! (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
              (err ERR-NOT-AUTHORIZED))
    
    ;; Check if dispute is still open or in voting
    (asserts! (or (is-eq (get status dispute) DISPUTE-STATUS-OPEN)
                 (is-eq (get status dispute) DISPUTE-STATUS-VOTING))
              (err ERR-INVALID-PARAMETERS))
    
    ;; Update dispute
    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute {
        status: DISPUTE-STATUS-RESOLVED,
        resolution: (some resolution),
        resolved-at: (some block-height)
      })
    )
    
    ;; Apply penalties or adjustments based on resolution
    ;; This would be more complex in a full implementation
    
    (ok true)
  )
)
;; Propose a resource expansion
(define-public (propose-expansion
  (community-id uint)
  (resource-id (optional uint))
  (name (string-utf8 100))
  (description (string-utf8 500))
  (resource-type uint)
  (proposed-supply uint)
  (estimated-cost uint)
  (funding-source (string-utf8 100))
)
  (let
    (
      (expansion-id (var-get next-expansion-id))
      (member-mapping (unwrap! (get-member-id community-id tx-sender) (err ERR-MEMBER-NOT-FOUND)))
      (member-id (get member-id member-mapping))
      (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
      (community (unwrap! (get-community community-id) (err ERR-COMMUNITY-NOT-FOUND)))
    )
    
    ;; Check if member is active
    (asserts! (get is-active member) (err ERR-INACTIVE-MEMBER))
    
    ;; If expanding existing resource, check if it exists
    (when (is-some resource-id)
      (let
        (
          (resource (unwrap! (get-resource (unwrap-panic resource-id)) (err ERR-RESOURCE-NOT-FOUND)))
        )
        ;; Check if resource belongs to community
        (asserts! (is-eq (get community-id resource) community-id) (err ERR-RESOURCE-NOT-FOUND))
      )
    )
    
    ;; Create expansion proposal
    (map-set expansion-proposals
      { expansion-id: expansion-id }
      {
        community-id: community-id,
        resource-id: resource-id,
        name: name,
        description: description,
        proposed-by: member-id,
        resource-type: resource-type,
        proposed-supply: proposed-supply,
        estimated-cost: estimated-cost,
        funding-source: funding-source,
        status: EXPANSION-STATUS-PROPOSAL,
        votes-for: u0,
        votes-against: u0,
        created-at: block-height,
        voting-ends-at: (+ block-height u1440), ;; ~10 days (assuming 1 block/min)
        implemented-at: none
      }
    )
    
    ;; Increment expansion ID
    (var-set next-expansion-id (+ expansion-id u1))
    
    (ok expansion-id)
  )
)

;; Start voting on expansion proposal
(define-public (start-expansion-voting (expansion-id uint))
  (let
    (
      (expansion (unwrap! (map-get? expansion-proposals { expansion-id: expansion-id }) (err ERR-EXPANSION-NOT-FOUND)))
      (community-id (get community-id expansion))
    )
    
    ;; Check if caller is admin
    (asserts! (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
              (err ERR-NOT-AUTHORIZED))
    
    ;; Check if proposal is in proposal state
    (asserts! (is-eq (get status expansion) EXPANSION-STATUS-PROPOSAL) (err ERR-INVALID-PARAMETERS))
    
    ;; Update status to voting
    (map-set expansion-proposals
      { expansion-id: expansion-id }
      (merge expansion {
        status: EXPANSION-STATUS-VOTING,
        voting-ends-at: (+ block-height u1440) ;; ~10 days from now
      })
    )
    
    (ok true)
  )
)

;; Vote on expansion proposal
(define-public (vote-on-expansion (expansion-id uint) (vote bool))
  (let
    (
      (expansion (unwrap! (map-get? expansion-proposals { expansion-id: expansion-id }) (err ERR-EXPANSION-NOT-FOUND)))
      (community-id (get community-id expansion))
      (member-mapping (unwrap! (get-member-id community-id tx-sender) (err ERR-MEMBER-NOT-FOUND)))
      (member-id (get member-id member-mapping))
      (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
      (vote-weight (calculate-vote-weight community-id member-id))
    )
    
    ;; Check if member is active
    (asserts! (get is-active member) (err ERR-INACTIVE-MEMBER))
    
    ;; Check if expansion is in voting phase
    (asserts! (is-eq (get status expansion) EXPANSION-STATUS-VOTING) (err ERR-VOTING-CLOSED))
    
    ;; Check if voting period hasn't ended
    (asserts! (<= block-height (get voting-ends-at expansion)) (err ERR-VOTING-CLOSED))
    
    ;; Check if member hasn't already voted
    (asserts! (is-none (map-get? expansion-votes { expansion-id: expansion-id, member-id: member-id })) (err ERR-VOTE-ALREADY-CAST))
    
    ;; Record vote
    (map-set expansion-votes
      { expansion-id: expansion-id, member-id: member-id }
      {
        vote: vote,
        weight: vote-weight,
        vote-time: block-height
      }
    )
    
    ;; Update vote tally
    (map-set expansion-proposals
      { expansion-id: expansion-id }
      (merge expansion {
        votes-for: (if vote 
                     (+ (get votes-for expansion) vote-weight)
                     (get votes-for expansion)),
        votes-against: (if vote 
                         (get votes-against expansion)
                         (+ (get votes-against expansion) vote-weight))
      })
    )
    
    (ok true)
  )
)

;; Finalize expansion proposal voting
(define-public (finalize-expansion-voting (expansion-id uint))
  (let
    (
      (expansion (unwrap! (map-get? expansion-proposals { expansion-id: expansion-id }) (err ERR-EXPANSION-NOT-FOUND)))
      (community-id (get community-id expansion))
    )
    
    ;; Check if caller is admin
    (asserts! (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
              (err ERR-NOT-AUTHORIZED))
    
    ;; Check if expansion is in voting phase
    (asserts! (is-eq (get status expansion) EXPANSION-STATUS-VOTING) (err ERR-INVALID-PARAMETERS))
    
    ;; Check if voting period has ended
    (asserts! (> block-height (get voting-ends-at expansion)) (err ERR-INVALID-PARAMETERS))
    
    ;; Determine outcome
    (let
      (
        (total-votes (+ (get votes-for expansion) (get votes-against expansion)))
        (result (if (> (get votes-for expansion) (get votes-against expansion))
                  EXPANSION-STATUS-APPROVED
                  EXPANSION-STATUS-DENIED))
      )
      
      ;; Update expansion status
      (map-set expansion-proposals
        { expansion-id: expansion-id }
        (merge expansion {
          status: result
        })
      )
      
      (ok result)
    )
  )
)

;; Implement approved expansion
(define-public (implement-expansion (expansion-id uint))
  (let
    (
      (expansion (unwrap! (map-get? expansion-proposals { expansion-id: expansion-id }) (err ERR-EXPANSION-NOT-FOUND)))
      (community-id (get community-id expansion))
    )
    
    ;; Check if caller is admin
    (asserts! (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
              (err ERR-NOT-AUTHORIZED))
    
    ;; Check if expansion is approved
    (asserts! (is-eq (get status expansion) EXPANSION-STATUS-APPROVED) (err ERR-INVALID-PARAMETERS))
    
    ;; If expanding existing resource
    (match (get resource-id expansion)
      existing-resource-id
      (let
        (
          (resource (unwrap! (get-resource existing-resource-id) (err ERR-RESOURCE-NOT-FOUND)))
        )
        ;; Update resource
        (map-set resources
          { resource-id: existing-resource-id }
          (merge resource {
            total-supply: (+ (get total-supply resource) (get proposed-supply expansion)),
            remaining-supply: (+ (get remaining-supply resource) (get proposed-supply expansion)),
            updated-at: block-height
          })
        )
      )
      ;; Creating new resource
      (let
        (
          (resource-id (var-get next-resource-id))
          (community (unwrap! (get-community community-id) (err ERR-COMMUNITY-NOT-FOUND)))
        )
        ;; Create new resource
        (map-set resources
          { resource-id: resource-id }
          {
            community-id: community-id,
            name: (get name expansion),
            description: (get description expansion),
            resource-type: (get resource-type expansion),
            total-supply: (get proposed-supply expansion),
            remaining-supply: (get proposed-supply expansion),
            minimum-contribution: u0, ;; Default, should be set by admin later
            max-per-allocation: (get proposed-supply expansion), ;; Default, should be set by admin later
            cooldown-period: u0, ;; Default, should be set by admin later
            is-active: true,
            created-at: block-height,
            updated-at: block-height
          }
        )
        
        ;; Update community resource count
        (map-set communities
          { community-id: community-id }
          (merge community {
            resource-count: (+ (get resource-count community) u1)
          })
        )
        
        ;; Increment resource ID
        (var-set next-resource-id (+ resource-id u1))
      )
    )
    
    ;; Update expansion status
    (map-set expansion-proposals
      { expansion-id: expansion-id }
      (merge expansion {
        status: EXPANSION-STATUS-IMPLEMENTED,
        implemented-at: (some block-height)
      })
    )
    
    (ok true)
  )
)
;; Make admin
(define-public (make-admin (community-id uint) (user-principal principal))
  (let
    (
      (community (unwrap! (get-community community-id) (err ERR-COMMUNITY-NOT-FOUND)))
    )
    
    ;; Check if caller is admin
    (asserts! (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
              (err ERR-NOT-AUTHORIZED))
    
    ;; Check if user is a member
    (asserts! (is-some (get-member-id community-id user-principal)) (err ERR-MEMBER-NOT-FOUND))
    
    ;; Add user as admin
    (map-set community-admins
      { community-id: community-id, admin-principal: user-principal }
      { added-at: block-height }
    )
    
    ;; Update member roles
    (match (get-member-id community-id user-principal)
      member-mapping
      (let
        (
          (member-id (get member-id member-mapping))
          (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
          (current-roles (get roles member))
        )
        (map-set members
          { community-id: community-id, member-id: member-id }
          (merge member {
            roles: (append current-roles "admin")
          })
        )
      )
      (err ERR-MEMBER-NOT-FOUND)
    )
    
    (ok true)
  )
)

;; Update member reputation
(define-public (update-reputation (community-id uint) (member-id uint) (score-change int))
  (let
    (
      (community (unwrap! (get-community community-id) (err ERR-COMMUNITY-NOT-FOUND)))
      (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
    )
    
    ;; Check if caller is admin
    (asserts! (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
              (err ERR-NOT-AUTHORIZED))
    
    ;; Calculate new reputation score (bounded 0-100)
    (let
      (
        (current-score (get reputation-score member))
        (new-score (+ current-score score-change))
        (bounded-score (max (min new-score u100) u0))
      )
      
      ;; Update member
      (map-set members
        { community-id: community-id, member-id: member-id }
        (merge member {
          reputation-score: bounded-score
        })
      )
      
      (ok bounded-score)
    )
  )
)
d resource) community-id) (err ERR-RESOURCE-NOT-FOUND))
    
    ;; Check if resource is active
    (asserts! (get is-active resource) (err ERR-RESOURCE-NOT-FOUND))
    
    ;; Check if sufficient contribution
    (asserts! (>= (get contribution member) (get minimum-contribution resource)) (err ERR-INSUFFICIENT-CONTRIBUTION))
    
    ;; Check if resource has sufficient supply
    (asserts! (>= (get remaining-supply resource) amount) (err ERR-RESOURCE-DEPLETED))
    
    ;; Create allocation request
    (map-set allocation-requests
      { request-id: request-id }
      {
        resource-id: resource-id,
        community-id: community-id,
        member-id: member-id,
        amount: amount,
        requested-start: requested-start,
        requested-duration: requested-duration,
        justification: justification,
        created-at: block-height,
        status: ALLOCATION-STATUS-PENDING,
        votes-for: u0,
        votes-against: u0
      }
    )
    
    ;; Increment request ID
    (var-set next-request-id (+ request-id u1))
    
    (ok request-id)
  )
)

;; Process allocation request (auto-approval based on entitlement)
(define-public (process-allocation-request (request-id uint))
  (let
    (
      (request (unwrap! (map-get? allocation-requests { request-id: request-id }) (err ERR-REQUEST-NOT-FOUND)))
      (resource-id (get resource-id request))
      (community-id (get community-id request))
      (member-id (get member-id request))
      (amount (get amount request))
      (resource (unwrap! (get-resource resource-id) (err ERR-RESOURCE-NOT-FOUND)))
      (entitlement (calculate-allocation-entitlement community-id resource-id member-id))
      (allocation-id (var-get next-allocation-id))
    )
    
    ;; Check if requester or admin
    (asserts! 
      (or 
        (is-eq tx-sender (get principal (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND))))
        (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
      )
      (err ERR-NOT-AUTHORIZED)
    )
    
    ;; Check if request is pending
    (asserts! (is-eq (get status request) ALLOCATION-STATUS-PENDING) (err ERR-INVALID-PARAMETERS))
    
    ;; Check entitlement
    (asserts! (<= amount (get max-allocation entitlement)) (err ERR-ALLOCATION-LIMIT-REACHED))
    
    ;; Check current supply
    (asserts! (>= (get remaining-supply resource) amount) (err ERR-RESOURCE-DEPLETED))
    
    ;; Create allocation
    (map-set allocations
      { allocation-id: allocation-id }
      {
        resource-id: resource-id,
        community-id: community-id,
        member-id: member-id,
        amount: amount,
        start-block: (get requested-start request),
        end-block: (match (get requested-duration request)
                    duration (some (+ (get requested-start request) duration))
                    none),
        status: ALLOCATION-STATUS-APPROVED,
        created-at: block-height,
        updated-at: block-height,
        notes: "Auto-approved based on contribution entitlement"
      }
    )
    
    ;; Update resource remaining supply
    (map-set resources
      { resource-id: resource-id }
      (merge resource {
        remaining-supply: (- (get remaining-supply resource) amount),
        updated-at: block-height
      })
    )
    
    ;; Update request status
    (map-set allocation-requests
      { request-id: request-id }
      (merge request {
        status: ALLOCATION-STATUS-APPROVED
      })
    )
    
    ;; Update member allocation count
    (match (get-member community-id member-id)
      member
      (map-set members
        { community-id: community-id, member-id: member-id }
        (merge member {
          allocation-count: (+ (get allocation-count member) u1)
        })
      )
      (err ERR-MEMBER-NOT-FOUND)
    )
    
    ;; Update usage tracking
    (match (map-get? resource-usage { resource-id: resource-id, member-id: member-id })
      usage
      (map-set resource-usage
        { resource-id: resource-id, member-id: member-id }
        {
          total-usage: (+ (get total-usage usage) amount),
          last-usage-block: block-height,
          usage-count: (+ (get usage-count usage) u1),
          average-duration: (match (get requested-duration request)
                            duration 
                            (/ (+ (* (get average-duration usage) (get usage-count usage)) duration)
                               (+ (get usage-count usage) u1))
                            (get average-duration usage)),
          contribution-at-last-usage: (get contribution (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
        }
      )
      ;; First usage
      (map-set resource-usage
        { resource-id: resource-id, member-id: member-id }
        {
          total-usage: amount,
          last-usage-block: block-height,
          usage-count: u1,
          average-duration: (default-to u0 (get requested-duration request)),
          contribution-at-last-usage: (get contribution (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
        }
      )
    )
    
    ;; Increment allocation ID
    (var-set next-allocation-id (+ allocation-id u1))
    
    (ok allocation-id)
  )
)

;; Complete a resource allocation (release the resource)
(define-public (complete-allocation (allocation-id uint))
  (let
    (
      (allocation (unwrap! (map-get? allocations { allocation-id: allocation-id }) (err ERR-ALLOCATION-NOT-FOUND)))
      (resource-id (get resource-id allocation))
      (community-id (get community-id allocation))
      (member-id (get member-id allocation))
      (resource (unwrap! (get-resource resource-id) (err ERR-RESOURCE-NOT-FOUND)))
    )
    
    ;; Check if requester or admin
    (asserts! 
      (or 
        (is-eq tx-sender (get principal (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND))))
        (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
      )
      (err ERR-NOT-AUTHORIZED)
    )
    
    ;; Check if allocation is approved
    (asserts! (is-eq (get status allocation) ALLOCATION-STATUS-APPROVED) (err ERR-INVALID-PARAMETERS))
    
    ;; For time-based resources, check if end time has passed
    (match (get end-block allocation)
      end-time
      (when (> end-time block-height) 
        ;; If still in use, allow early return only for the user themselves or admin
        (asserts! 
          (or 
            (is-eq tx-sender (get principal (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND))))
            (is-some (map-get? community-admins { community-id: community-id, admin-principal: tx-sender }))
          )
          (err ERR-NOT-AUTHORIZED)
        ))
      true
    )
    
    ;; Update allocation status
    (map-set allocations
      { allocation-id: allocation-id }
      (merge allocation {
        status: ALLOCATION-STATUS-COMPLETED,
        updated-at: block-height
      })
    )
    
    ;; For unique or time-based resources, return the resource to the pool
    (when (or (is-eq (get resource-type resource) RESOURCE-TYPE-UNIQUE)
             (is-eq (get resource-type resource) RESOURCE-TYPE-TIME-BASED))
      (map-set resources
        { resource-id: resource-id }
        (merge resource {
          remaining-supply: (+ (get remaining-supply resource) (get amount allocation)),
          updated-at: block-height
        })
      )
    )
    
    ;; For consumable resources, don't return to pool
    
    (ok true)
  )
)

;; Raise a dispute over resource usage
(define-public (raise-dispute
  (community-id uint)
  (resource-id uint)
  (allocation-id (optional uint))
  (against-member-id (optional uint))
  (dispute-type (string-utf8 50))
  (description (string-utf8 500))
)
  (let
    (
      (dispute-id (var-get next-dispute-id))
      (member-mapping (unwrap! (get-member-id community-id tx-sender) (err ERR-MEMBER-NOT-FOUND)))
      (member-id (get member-id member-mapping))
      (member (unwrap! (get-member community-id member-id) (err ERR-MEMBER-NOT-FOUND)))
      (resource (unwrap! (get-resource resource-id) (err ERR-RESOURCE-NOT-FOUND)))
    )
    
