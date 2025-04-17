# Clarity KYC

## Decentralized Know Your Customer Verification System

A secure and flexible smart contract for managing KYC (Know Your Customer) verifications on the Stacks blockchain with support for multiple validators, risk categorization, verification status tracking, comprehensive audit trails, and account freeze capabilities.
## Overview

Clarity KYC is a decentralized KYC verification system built on the Stacks blockchain using the Clarity smart contract language. It provides a secure, transparent, and auditable mechanism for managing customer identity verification processes in compliance with regulatory requirements. The contract maintains a registry of verified clients, manages verification statuses, tracks risk categories, and provides a comprehensive audit trail of all verification events.

## Features

- **Multi-Validator Support**: Authorized validators can perform KYC verifications
- **Verification Status Tracking**: Track verification status (VERIFIED, PENDING, REJECTED)
- **Risk Categorization**: Assign and update risk levels (LOW, STANDARD, HIGH) 
- **Comprehensive Audit Trail**: Log all verification events with timestamps and detailed notes
- **Account Freeze Functionality**: Ability to freeze/unfreeze client accounts with justification
- **Batch Processing**: Efficiently verify multiple clients in a single transaction
- **Re-verification Support**: Handle expired verifications and status updates
- **Client Metrics**: Track verification age, event history, and current status

## Technical Details

### Constants

- **Verification Status**: VERIFIED, PENDING, REJECTED
- **Risk Categories**: LOW, STANDARD, HIGH
- **Action Types**: Various events for audit trail (VERIFIED, UPDATED, REJECTED, etc.)

### Data Maps

- `kyc-registry`: Stores client verification details
- `authorized-validators`: Registry of approved validation authorities
- `client-audit-trail`: Comprehensive event history for each client
- `client-event-counter`: Tracks event counts for each client

## Contract Functions

### Admin Functions

#### `register-validator`
Registers a new validator who can perform KYC verifications.
```clarity
(define-public (register-validator (validator-address principal)))
```

#### `deactivate-validator`
Removes a validator from the authorized validators list.
```clarity
(define-public (deactivate-validator (validator-address principal)))
```

### Core Verification Functions

#### `process-client-kyc`
Verifies a new client or updates an existing client's verification.
```clarity
(define-public (process-client-kyc (client-address principal) (verification-status (string-ascii 20)) (risk-category (string-ascii 10))))
```

#### `update-verification-status`
Updates an existing client's verification status.
```clarity
(define-public (update-verification-status (client-address principal) (new-status (string-ascii 20))))
```

#### `batch-verify-clients`
Processes KYC verification for multiple clients in a single transaction.
```clarity
(define-public (batch-verify-clients (client-list (list 100 principal)) (verification-status (string-ascii 20)) (risk-category (string-ascii 10))))
```

#### `reverify-expired-client`
Re-verifies a client whose verification has expired.
```clarity
(define-public (reverify-expired-client (client-address principal) (verification-status (string-ascii 20)) (risk-category (string-ascii 10))))
```

### Audit Trail Functions

#### `log-verification-event`
Logs verification events to maintain a comprehensive audit trail.
```clarity
(define-public (log-verification-event (client-address principal) (event-type (string-ascii 20)) (event-notes (string-ascii 50))))
```

### Account Management Functions

#### `set-client-freeze-status`
Freezes or unfreezes a client's account with justification.
```clarity
(define-public (set-client-freeze-status (client-address principal) (freeze-status bool) (justification (string-ascii 50))))
```

#### `update-client-risk-level`
Updates a client's risk category with justification.
```clarity
(define-public (update-client-risk-level (client-address principal) (new-risk-category (string-ascii 10)) (justification (string-ascii 50))))
```

### Read-only Functions

#### `check-verification-expired`
Checks if a client's verification has expired (older than 365 blocks).
```clarity
(define-read-only (check-verification-expired (client-address principal)))
```

#### `get-client-status`
Returns complete client verification details.
```clarity
(define-read-only (get-client-status (client-address principal)))
```

#### `check-validator-status`
Checks if an address is an authorized validator.
```clarity
(define-read-only (check-validator-status (address principal)))
```

#### `get-audit-event`
Retrieves a specific audit event for a client.
```clarity
(define-read-only (get-audit-event (client-address principal) (event-id uint)))
```

#### `get-latest-event-id`
Returns the latest event ID for a specific client.
```clarity
(define-read-only (get-latest-event-id (client-address principal)))
```

#### `get-client-verification-metrics`
Returns comprehensive verification metrics for a client.
```clarity
(define-read-only (get-client-verification-metrics (client-address principal)))
```

## Usage Examples

### Initial Deployment

The contract is deployed with the deployer as the contract administrator. Only the administrator can register validators.

### Registering a Validator

```clarity
;; Called by the contract administrator
(contract-call? .clarity-kyc register-validator 'SPMYWZ3RZXS2VQGJ10EJ0X9AYXD9UNWPGVDX55Z8)
```

### Performing Client Verification

```clarity
;; Called by a registered validator
(contract-call? .clarity-kyc process-client-kyc 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "VERIFIED" "STANDARD")
```

### Updating Client Risk Level

```clarity
;; Called by a registered validator
(contract-call? .clarity-kyc update-client-risk-level 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "HIGH" "Suspicious transaction pattern detected")
```

### Batch Verification

```clarity
;; Called by a registered validator
(contract-call? .clarity-kyc batch-verify-clients (list 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  'SP1QK1AX59TKCG2YVAZ1VYPTV4GZPTY8VDCM9T9DJ
  'SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB
) "VERIFIED" "STANDARD")
```

### Checking Client Status

```clarity
;; Read-only function, can be called by anyone
(contract-call? .clarity-kyc get-client-status 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## Error Codes

| Code | Description |
|------|-------------|
| u1   | ERR-UNAUTHORIZED-ACCESS: Caller does not have permission |
| u2   | ERR-ALREADY-KYC-VERIFIED: Client is already verified |
| u3   | ERR-INVALID-VERIFICATION-STATUS: Status is not valid |
| u4   | ERR-CLIENT-NOT-REGISTERED: Client does not exist in registry |
| u5   | ERR-MALFORMED-PARAMETERS: Invalid function parameters |
| u6   | ERR-BATCH-OPERATION-FAILED: Error during batch processing |

## Best Practices

1. **Regular Reverification**: Implement procedures to reverify clients whose verification has expired (older than 365 blocks).
2. **Detailed Notes**: Provide clear and detailed notes when updating client status or risk levels for better audit trails.
3. **Validator Management**: Regularly review and update the list of authorized validators.
4. **Risk Monitoring**: Monitor clients with HIGH risk category more frequently.
5. **Batch Processing**: Use batch processing for efficiency when verifying multiple clients in a single transaction.

### Security Considerations

- Ensure proper access control for validator registration
- Implement secure key management for validators
- Consider additional encryption for sensitive data
- Regular security audits of the contract and integration points