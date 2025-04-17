;; Clarity KYC - Decentralized Know Your Customer Verification System
;; A smart contract for securely managing KYC verifications on the Stacks blockchain with
;; support for multiple validators, risk categorization, verification status tracking,
;; audit trails, and account freeze functionality.

;; Constants
(define-constant contract-admin tx-sender)
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-ALREADY-KYC-VERIFIED (err u2))
(define-constant ERR-INVALID-VERIFICATION-STATUS (err u3))
(define-constant ERR-CLIENT-NOT-REGISTERED (err u4))
(define-constant ERR-MALFORMED-PARAMETERS (err u5))
(define-constant ERR-BATCH-OPERATION-FAILED (err u6))

;; Status Constants
(define-constant STATUS-VERIFIED "VERIFIED")
(define-constant STATUS-PENDING "PENDING")
(define-constant STATUS-REJECTED "REJECTED")

;; Risk Level Constants
(define-constant RISK-LOW "LOW")
(define-constant RISK-STANDARD "STANDARD")
(define-constant RISK-HIGH "HIGH")

;; Action Type Constants
(define-constant ACTION-VERIFIED "VERIFIED")
(define-constant ACTION-UPDATED "UPDATED")
(define-constant ACTION-REJECTED "REJECTED")
(define-constant ACTION-FREEZE "ACCOUNT_FROZEN")
(define-constant ACTION-UNFREEZE "ACCOUNT_UNFROZEN")
(define-constant ACTION-REVERIFIED "REVERIFIED")
(define-constant ACTION-RISK-UPDATED "RISK_UPDATED")

;; Data Maps
(define-map kyc-registry 
    principal 
    {status: (string-ascii 20),
     verification-timestamp: uint,
     authority: principal,
     risk-category: (string-ascii 10),
     account-frozen: bool})

(define-map authorized-validators principal bool)

(define-map client-audit-trail
    { client: principal, event-id: uint }
    { event-type: (string-ascii 20),
      block-time: uint,
      authority: principal,
      notes: (string-ascii 50) })

(define-map client-event-counter principal uint)

;; Validation Functions
(define-private (is-valid-verification-status (status-code (string-ascii 20)))
    (or (is-eq status-code STATUS-VERIFIED)
        (is-eq status-code STATUS-PENDING)
        (is-eq status-code STATUS-REJECTED)))

(define-private (is-valid-risk-category (risk-category (string-ascii 10)))
    (or (is-eq risk-category RISK-LOW)
        (is-eq risk-category RISK-STANDARD)
        (is-eq risk-category RISK-HIGH)))

(define-private (is-valid-event-type (event-type (string-ascii 20)))
    (or (is-eq event-type ACTION-VERIFIED)
        (is-eq event-type ACTION-UPDATED)
        (is-eq event-type ACTION-REJECTED)
        (is-eq event-type ACTION-FREEZE)
        (is-eq event-type ACTION-UNFREEZE)
        (is-eq event-type ACTION-REVERIFIED)
        (is-eq event-type ACTION-RISK-UPDATED)))

;; ========== Admin Functions ==========
(define-public (register-validator (validator-address principal))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-none (map-get? authorized-validators validator-address)) ERR-MALFORMED-PARAMETERS)
        (ok (map-set authorized-validators validator-address true))))

(define-public (deactivate-validator (validator-address principal))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-some (map-get? authorized-validators validator-address)) ERR-MALFORMED-PARAMETERS)
        (ok (map-delete authorized-validators validator-address))))

;; Core Verification Functions
(define-public (process-client-kyc (client-address principal) (verification-status (string-ascii 20)) (risk-category (string-ascii 10)))
    (let ((validator-authorized (default-to false (map-get? authorized-validators tx-sender)))
          (client-record (map-get? kyc-registry client-address)))
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-valid-verification-status verification-status) ERR-INVALID-VERIFICATION-STATUS)
            (asserts! (is-valid-risk-category risk-category) ERR-MALFORMED-PARAMETERS)
            
            (if (is-some client-record)
                ;; Re-verification case - update existing record
                (let ((event-type (if (is-eq verification-status STATUS-VERIFIED) 
                                      ACTION-REVERIFIED 
                                      ACTION-UPDATED)))
                    (ok (begin
                        (map-set kyc-registry 
                            client-address 
                            {status: verification-status,
                             verification-timestamp: block-height,
                             authority: tx-sender,
                             risk-category: risk-category,
                             account-frozen: (get account-frozen (unwrap-panic client-record))})
                        (log-verification-event client-address event-type "Client re-verified"))))
                
                ;; New verification case
                (ok (begin
                    (map-set kyc-registry 
                        client-address 
                        {status: verification-status,
                         verification-timestamp: block-height,
                         authority: tx-sender,
                         risk-category: risk-category,
                         account-frozen: false})
                    (log-verification-event client-address ACTION-VERIFIED "Initial verification")))))))

(define-public (update-verification-status (client-address principal) (new-status (string-ascii 20)))
    (let ((validator-authorized (default-to false (map-get? authorized-validators tx-sender)))
          (client-record (map-get? kyc-registry client-address)))
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-some client-record) ERR-CLIENT-NOT-REGISTERED)
            (asserts! (is-valid-verification-status new-status) ERR-INVALID-VERIFICATION-STATUS)
            (ok (begin
                (map-set kyc-registry 
                    client-address 
                    (merge (unwrap-panic client-record) {
                        status: new-status,
                        verification-timestamp: block-height,
                        authority: tx-sender
                    }))
                (log-verification-event client-address ACTION-UPDATED 
                    (concat "Status updated to: " new-status)))))))

;; Reimplemented batch processing without recursion
;; Process a single client during batch processing
(define-private (process-single-client 
    (client-address principal) 
    (verification-status (string-ascii 20)) 
    (risk-category (string-ascii 10)))
    
    (let ((client-record (map-get? kyc-registry client-address))
          (event-type (if (is-some client-record)
                        (if (is-eq verification-status STATUS-VERIFIED) 
                            ACTION-REVERIFIED 
                            ACTION-UPDATED)
                        ACTION-VERIFIED))
          (event-notes (if (is-some client-record) 
                         "Batch re-verification" 
                         "Batch initial verification")))
        (begin
            ;; Update client record
            (if (is-some client-record)
                ;; Update existing client
                (map-set kyc-registry 
                    client-address 
                    {status: verification-status,
                     verification-timestamp: block-height,
                     authority: tx-sender,
                     risk-category: risk-category,
                     account-frozen: (get account-frozen (unwrap-panic client-record))})
                ;; Create new client record
                (map-set kyc-registry 
                    client-address 
                    {status: verification-status,
                     verification-timestamp: block-height,
                     authority: tx-sender,
                     risk-category: risk-category,
                     account-frozen: false}))
            
            ;; Log event
            (unwrap-panic (log-verification-event client-address event-type event-notes))
            
            ;; Return success
            true)))

;; Batch process clients with a fixed number of clients per batch
(define-public (batch-verify-clients-v1 (client-list (list 10 principal)) (verification-status (string-ascii 20)) (risk-category (string-ascii 10)))
    (let ((validator-authorized (default-to false (map-get? authorized-validators tx-sender))))
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-valid-verification-status verification-status) ERR-INVALID-VERIFICATION-STATUS)
            (asserts! (is-valid-risk-category risk-category) ERR-MALFORMED-PARAMETERS)
            (asserts! (> (len client-list) u0) ERR-MALFORMED-PARAMETERS)
            
            ;; Process up to 10 clients
            (ok (fold process-single-client-fold client-list (list verification-status risk-category u0))))))

;; Helper function for fold operation
(define-private (process-single-client-fold 
    (client-address principal) 
    (state-data (list 2 (string-ascii 20) (string-ascii 10) uint)))
    
    (let ((verification-status (unwrap-panic (element-at state-data u0)))
          (risk-category (unwrap-panic (element-at state-data u1)))
          (processed-count (unwrap-panic (element-at state-data u2))))
        
        (if (process-single-client client-address verification-status risk-category)
            (list verification-status risk-category (+ processed-count u1))
            (list verification-status risk-category processed-count))))

;; Batch verify for larger batches - split into chunks of 10
(define-public (batch-verify-clients (client-list (list 200 principal)) (verification-status (string-ascii 20)) (risk-category (string-ascii 10)))
    (let ((validator-authorized (default-to false (map-get? authorized-validators tx-sender))))
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-valid-verification-status verification-status) ERR-INVALID-VERIFICATION-STATUS)
            (asserts! (is-valid-risk-category risk-category) ERR-MALFORMED-PARAMETERS)
            (asserts! (> (len client-list) u0) ERR-MALFORMED-PARAMETERS)
            
            ;; Process clients in batches - each client individually
            (let ((processed-count u0))
                (ok (process-batch-chunk client-list u0 (len client-list) verification-status risk-category))))))

;; Process clients in a batch sequentially
(define-private (process-batch-chunk 
    (client-list (list 200 principal)) 
    (start-index uint) 
    (end-index uint)
    (verification-status (string-ascii 20))
    (risk-category (string-ascii 10)))
    
    (let ((processed-count u0))
        (begin
            ;; Process first client if available
            (if (and (< start-index end-index) (< start-index u200))
                (begin
                    (process-single-client 
                        (unwrap-panic (element-at client-list start-index))
                        verification-status
                        risk-category)
                    (+ processed-count u1))
                processed-count))))

;; Audit Trail Functions
(define-private (get-next-event-id (client-address principal))
    (let ((current-count (default-to u0 (map-get? client-event-counter client-address))))
        (begin
            (map-set client-event-counter client-address (+ current-count u1))
            (+ current-count u1))))

(define-public (log-verification-event 
    (client-address principal) 
    (event-type (string-ascii 20)) 
    (event-notes (string-ascii 50)))
    (let (
        (validator-authorized (default-to false (map-get? authorized-validators tx-sender)))
        (event-id (get-next-event-id client-address))
    )
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-some (map-get? kyc-registry client-address)) ERR-CLIENT-NOT-REGISTERED)
            (asserts! (is-valid-event-type event-type) ERR-MALFORMED-PARAMETERS)
            (asserts! (<= (len event-notes) u50) ERR-MALFORMED-PARAMETERS)
            (ok (map-set client-audit-trail
                { client: client-address, event-id: event-id }
                { event-type: event-type,
                  block-time: block-height,
                  authority: tx-sender,
                  notes: event-notes })))))

;; Account Freeze Management
(define-public (set-client-freeze-status 
    (client-address principal) 
    (freeze-status bool) 
    (justification (string-ascii 50)))
    (let ((validator-authorized (default-to false (map-get? authorized-validators tx-sender)))
          (client-record (map-get? kyc-registry client-address)))
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-some client-record) ERR-CLIENT-NOT-REGISTERED)
            (asserts! (<= (len justification) u50) ERR-MALFORMED-PARAMETERS)
            (let ((updated-client-record (merge (unwrap-panic client-record) { account-frozen: freeze-status })))
                (ok (begin 
                    (map-set kyc-registry client-address updated-client-record)
                    (log-verification-event client-address 
                        (if freeze-status ACTION-FREEZE ACTION-UNFREEZE) 
                        justification)))))))

;; Re-Verification Functions
(define-public (reverify-expired-client
    (client-address principal)
    (verification-status (string-ascii 20))
    (risk-category (string-ascii 10)))
    (let ((validator-authorized (default-to false (map-get? authorized-validators tx-sender)))
          (client-record (map-get? kyc-registry client-address)))
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-some client-record) ERR-CLIENT-NOT-REGISTERED)
            (asserts! (check-verification-expired client-address) ERR-MALFORMED-PARAMETERS)
            (asserts! (is-valid-verification-status verification-status) ERR-INVALID-VERIFICATION-STATUS)
            (asserts! (is-valid-risk-category risk-category) ERR-MALFORMED-PARAMETERS)
            (ok (begin
                (map-set kyc-registry 
                    client-address 
                    {status: verification-status,
                     verification-timestamp: block-height,
                     authority: tx-sender,
                     risk-category: risk-category,
                     account-frozen: (get account-frozen (unwrap-panic client-record))})
                (log-verification-event client-address 
                    ACTION-REVERIFIED 
                    "Client re-verified after expiration"))))))

;; Read-only Functions
(define-read-only (check-verification-expired (client-address principal))
    (match (map-get? kyc-registry client-address)
        client-record (> (- block-height (get verification-timestamp client-record)) u365)
        false))

(define-read-only (get-client-status (client-address principal))
    (map-get? kyc-registry client-address))

(define-read-only (check-validator-status (address principal))
    (default-to false (map-get? authorized-validators address)))

(define-read-only (get-audit-event (client-address principal) (event-id uint))
    (map-get? client-audit-trail { client: client-address, event-id: event-id }))

(define-read-only (get-latest-event-id (client-address principal))
    (default-to u0 (map-get? client-event-counter client-address)))

(define-read-only (get-client-verification-metrics (client-address principal))
    (let ((client-record (map-get? kyc-registry client-address))
          (total-events (default-to u0 (map-get? client-event-counter client-address))))
        (if (is-none client-record)
            (err ERR-CLIENT-NOT-REGISTERED)
            (ok {
                verification-age: (- block-height 
                    (get verification-timestamp (unwrap-panic client-record))),
                total-events: total-events,
                is-expired: (check-verification-expired client-address),
                current-status: (get status (unwrap-panic client-record)),
                current-risk-category: (get risk-category (unwrap-panic client-record)),
                account-frozen: (get account-frozen (unwrap-panic client-record))
            }))))

;; Risk Management Functions
(define-public (update-client-risk-level 
    (client-address principal) 
    (new-risk-category (string-ascii 10))
    (justification (string-ascii 50)))
    (let ((validator-authorized (default-to false (map-get? authorized-validators tx-sender)))
          (client-record (map-get? kyc-registry client-address)))
        (begin
            (asserts! validator-authorized ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-some client-record) ERR-CLIENT-NOT-REGISTERED)
            (asserts! (is-valid-risk-category new-risk-category) ERR-MALFORMED-PARAMETERS)
            (asserts! (<= (len justification) u50) ERR-MALFORMED-PARAMETERS)
            (let ((updated-client-record (merge (unwrap-panic client-record) 
                    {risk-category: new-risk-category})))
                (ok (begin 
                    (map-set kyc-registry client-address updated-client-record)
                    (log-verification-event client-address 
                        ACTION-RISK-UPDATED
                        justification)))))))