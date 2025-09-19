;; web3-activity-tracker
;;
;; A smart contract to monitor and track web3 interactions, 
;; milestone achievements, and user progress across blockchain ecosystems.
;; This contract enables tracking, verification, and organization of 
;; decentralized activities in a structured, immutable manner.
;; =============================
;; Constants & Error Codes
;; =============================
(define-constant CONTRACT-OWNER tx-sender)
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-NOT-FOUND (err u101))
(define-constant ERR-ACTIVITY-NOT-FOUND (err u102))
(define-constant ERR-ACTIVITY-ALREADY-EXISTS (err u103))
(define-constant ERR-NAMESPACE-NOT-FOUND (err u104))
(define-constant ERR-NAMESPACE-ALREADY-EXISTS (err u105))
(define-constant ERR-PARENT-ACTIVITY-NOT-FOUND (err u106))
(define-constant ERR-ACTIVITY-ALREADY-COMPLETED (err u107))
(define-constant ERR-PREREQUISITES-NOT-COMPLETED (err u108))
(define-constant ERR-INVALID-PARAMETERS (err u109))
(define-constant ERR-INVALID-USER-ROLE (err u110))
(define-constant ERR-ENTITY-NOT-REGISTERED (err u111))
(define-constant ERR-DUPLICATE-RELATIONSHIP (err u112))

;; =============================
;; Data Maps & Variables
;; =============================
;; User roles: 1=Admin, 2=Developer, 3=Analyst, 4=User
(define-map entities
  { entity-id: principal }
  {
    role: uint,
    name: (string-ascii 100),
    registered-at: uint,
  }
)

;; Stores relationships between entities
(define-map entity-relationships
  {
    primary-entity: principal,
    related-entity: principal,
  }
  { relationship-type: (string-ascii 20) }
)

;; Namespaces represent collections of activity tracking domains
(define-map namespaces
  { namespace-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    created-by: principal,
    created-at: uint,
  }
)

;; Activity definitions for tracking
(define-map activities
  { activity-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    complexity-level: uint, ;; 1-5 representing complexity
    namespace-id: uint,
    parent-activity-id: (optional uint),
    created-by: principal,
    created-at: uint,
  }
)

;; Tracks activity completion by entities
(define-map activity-completions
  {
    activity-id: uint,
    entity-id: principal,
  }
  {
    completed-at: uint,
    verified-by: principal,
    evidence-hash: (optional (string-utf8 64)),
  }
)

;; Activity prerequisites
(define-map activity-prerequisites
  {
    activity-id: uint,
    prerequisite-id: uint,
  }
  { added-at: uint }
)

;; Counters
(define-data-var activity-id-counter uint u1)
(define-data-var namespace-id-counter uint u1)

;; =============================
;; Private Functions
;; =============================
;; Check if an entity can manage activities
(define-private (can-manage-entity
    (manager-id principal)
    (target-entity-id principal)
  )
  (or
    (is-eq manager-id CONTRACT-OWNER)
    (match (map-get? entity-relationships {
      primary-entity: manager-id,
      related-entity: target-entity-id,
    })
      relationship
      true
      false
    )
  )
)

;; Increment activity ID counter
(define-private (get-next-activity-id)
  (let ((next-id (var-get activity-id-counter)))
    (var-set activity-id-counter (+ next-id u1))
    next-id
  )
)

;; Increment namespace ID counter
(define-private (get-next-namespace-id)
  (let ((next-id (var-get namespace-id-counter)))
    (var-set namespace-id-counter (+ next-id u1))
    next-id
  )
)

;; =============================
;; Read-Only Functions
;; =============================
;; Get entity information
(define-read-only (get-entity (entity-id principal))
  (map-get? entities { entity-id: entity-id })
)

;; Get activity information
(define-read-only (get-activity (activity-id uint))
  (map-get? activities { activity-id: activity-id })
)

;; Get namespace information
(define-read-only (get-namespace (namespace-id uint))
  (map-get? namespaces { namespace-id: namespace-id })
)

;; Check if an activity is completed by an entity
(define-read-only (is-activity-completed
    (activity-id uint)
    (entity-id principal)
  )
  (is-some (map-get? activity-completions {
    activity-id: activity-id,
    entity-id: entity-id,
  }))
)

;; Get activity completion details
(define-read-only (get-activity-completion
    (activity-id uint)
    (entity-id principal)
  )
  (map-get? activity-completions {
    activity-id: activity-id,
    entity-id: entity-id,
  })
)

;; Get relationship between two entities
(define-read-only (get-entity-relationship
    (primary-entity principal)
    (related-entity principal)
  )
  (map-get? entity-relationships {
    primary-entity: primary-entity,
    related-entity: related-entity,
  })
)

;; =============================
;; Public Functions
;; =============================
;; Register a new entity
(define-public (register-entity
    (name (string-ascii 100))
    (role uint)
  )
  (let ((entity-id tx-sender))
    (asserts! (and (>= role u1) (<= role u4)) ERR-INVALID-USER-ROLE)
    (asserts! (is-none (map-get? entities { entity-id: entity-id }))
      ERR-ACTIVITY-ALREADY-EXISTS
    )
    (map-set entities { entity-id: entity-id } {
      role: role,
      name: name,
      registered-at: block-height,
    })
    (ok true)
  )
)

;; Create a new activity
(define-public (create-activity
    (title (string-ascii 100))
    (description (string-ascii 500))
    (category (string-ascii 50))
    (complexity-level uint)
    (namespace-id uint)
    (parent-activity-id (optional uint))
  )
  (let (
      (entity-id tx-sender)
      (activity-id (get-next-activity-id))
    )
    ;; Ensure namespace exists
    (asserts! (is-some (map-get? namespaces { namespace-id: namespace-id }))
      ERR-NAMESPACE-NOT-FOUND
    )
    ;; Validate complexity level (1-5)
    (asserts! (and (>= complexity-level u1) (<= complexity-level u5))
      ERR-INVALID-PARAMETERS
    )
    ;; If parent activity is specified, ensure it exists
    (asserts!
      (match parent-activity-id
        parent-id (is-some (map-get? activities { activity-id: parent-id }))
        true
      )
      ERR-PARENT-ACTIVITY-NOT-FOUND
    )
    (map-set activities { activity-id: activity-id } {
      title: title,
      description: description,
      category: category,
      complexity-level: complexity-level,
      namespace-id: namespace-id,
      parent-activity-id: parent-activity-id,
      created-by: entity-id,
      created-at: block-height,
    })
    (ok activity-id)
  )
)