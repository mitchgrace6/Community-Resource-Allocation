# Community Resource Allocation System

## Overview

This smart contract enables communities to collectively manage and allocate shared resources in a decentralized, fair, and transparent manner. The system implements contribution-based resource allocation with dispute resolution mechanisms and community governance features.

## Key Features

- **Community Governance**: Create and manage communities with configurable membership types
- **Resource Management**: Add and track divisible, time-based, and unique resources
- **Contribution-Based Allocation**: Resources allocated based on member contributions
- **Dispute Resolution**: Framework for raising and voting on resource disputes
- **Expansion Proposals**: Community voting for resource expansion/creation
- **Usage Tracking**: Monitor resource usage patterns and member activity
- **Reputation System**: Member reputation scores influence voting power

## Contract Architecture

### Core Components

1. **Communities**:
   - Configurable membership types (open, approval, invitation)
   - Track total contributions and active members
   - Admin management system

2. **Resources**:
   - Three resource types: divisible, time-based, and unique
   - Configurable allocation limits and cooldown periods
   - Supply tracking and management

3. **Members**:
   - Contribution tracking
   - Reputation scores
   - Role assignments
   - Usage history

4. **Allocation System**:
   - Request-based allocation workflow
   - Automatic entitlement calculation
   - Time-based and quantity-based allocations

5. **Dispute Resolution**:
   - Community voting on disputes
   - Weighted voting based on contribution
   - Resolution tracking

6. **Expansion Proposals**:
   - Community voting for new resources
   - Funding source specification
   - Implementation tracking

## Usage Guide

### Community Management

**Create a Community**:
```clarity
(create-community 
  "Our Community" 
  "A shared resource pool for our neighborhood" 
  "approval" 
  u1000000  ;; Minimum contribution (1 STX)
)
```

**Add a Resource**:
```clarity
(add-resource
  u1                  ;; community-id
  "Community Garden"  ;; name
  "Shared vegetable garden plots" ;; description
  RESOURCE-TYPE-UNIQUE ;; resource-type
  u10                 ;; total-supply (10 plots)
  u500000             ;; minimum-contribution (0.5 STX)
  u2                  ;; max-per-allocation (2 plots)
  u1440               ;; cooldown-period (~1 day in blocks)
)
```

### Member Operations

**Join Community**:
```clarity
(join-community u1 u1000000) ;; community-id, initial contribution (1 STX)
```

**Request Resource Allocation**:
```clarity
(request-allocation
  u1                  ;; community-id
  u1                  ;; resource-id (garden plots)
  u1                  ;; amount (1 plot)
  block-height        ;; requested start time
  none                ;; duration (none for unique resources)
  "I'll grow tomatoes for the community" ;; justification
)
```

### Governance

**Propose Resource Expansion**:
```clarity
(propose-expansion
  u1                  ;; community-id
  none                ;; resource-id (none for new resource)
  "Tool Library"      ;; name
  "Shared tools for community use" ;; description
  RESOURCE-TYPE-UNIQUE ;; type
  u20                 ;; proposed supply (20 tools)
  u5000000            ;; estimated cost (5 STX)
  "Community treasury" ;; funding source
)
```

**Vote on Expansion**:
```clarity
(vote-on-expansion u1 true) ;; expansion-id, vote (true=for)
```

### Dispute Resolution

**Raise Dispute**:
```clarity
(raise-dispute
  u1                  ;; community-id
  u1                  ;; resource-id
  (some u1)           ;; allocation-id (optional)
  (some u2)           ;; against-member-id (optional)
  "overuse"           ;; dispute-type
  "Member has exceeded their plot allocation" ;; description
)
```

**Vote on Dispute**:
```clarity
(vote-on-dispute u1 true "Agree with dispute") ;; dispute-id, vote, justification
```

## Resource Types

1. **Divisible Resources**:
   - Can be divided into units (e.g., tokens, water allocation)
   - Usage reduces available supply
   - Examples: Community currency, irrigation water

2. **Time-Based Resources**:
   - Allocated by time slots
   - Automatically released after time period
   - Examples: Meeting rooms, equipment rentals

3. **Unique Resources**:
   - Indivisible items
   - Must be explicitly released
   - Examples: Tools, garden plots

## Allocation Logic

Resources are allocated based on:
- Member contribution level
- Resource minimum contribution threshold
- Current resource availability
- Member's past usage patterns
- Cooldown periods between allocations

The system calculates a fair share entitlement for each member based on their proportional contribution to the community.

## Voting System

- **Weighted Voting**: Voting power based on contribution and reputation
- **Time-Limited Voting**: Proposals have defined voting periods
- **Transparent Results**: Real-time vote tallying

## Security Features

- Role-based access control
- Contribution requirements for resource access
- Cooldown periods to prevent overuse
- Dispute mechanisms for conflict resolution
- Admin oversight capabilities

## Integration Guide

Applications can interact with this contract to:

1. Display community resources and availability
2. Facilitate resource allocation requests
3. Show voting proposals and results
4. Track member contributions and reputation
5. Monitor dispute resolutions

## License

This contract is provided under the MIT License. For production use, thorough testing and security audits are recommended.