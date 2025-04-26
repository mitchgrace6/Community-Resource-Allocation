import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Test constants
const ERR_NOT_AUTHORIZED = 1;
const ERR_COMMUNITY_NOT_FOUND = 2;
const ERR_RESOURCE_NOT_FOUND = 3;
const ERR_MEMBER_NOT_FOUND = 4;
const ERR_ALREADY_EXISTS = 5;
const ERR_INSUFFICIENT_CONTRIBUTION = 6;

Clarinet.test({
  name: "Can create a new community",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Create a new community
    let block = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Clarity Devs"), // name
          types.utf8("A community for Clarity developers"), // description
          types.utf8("open"), // membership-type
          types.uint(100), // contribution-threshold
        ],
        deployer.address
      )
    ]);
    
    // Check that the transaction succeeded
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    assertEquals(block.receipts[0].result, '(ok u1)'); // First community id is 1
    
    // Get the community details to verify
    let communityCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-community',
      [types.uint(1)],
      deployer.address
    );
    
    // Verify community details
    let community = communityCall.result.expectTuple();
    assertEquals(community.name, types.utf8("Clarity Devs"));
    assertEquals(community.description, types.utf8("A community for Clarity developers"));
    assertEquals(community.founder, deployer.address);
    assertEquals(community['membership-type'], types.utf8("open"));
    assertEquals(community['contribution-threshold'], types.uint(100));
    assertEquals(community['active-member-count'], types.uint(1)); // Founder is first member
    assertEquals(community['total-contribution'], types.uint(100));
    assertEquals(community['resource-count'], types.uint(0));
    assertEquals(community['is-active'], types.bool(true));
  },
});

Clarinet.test({
  name: "Can join an existing community",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // First create a community
    let block = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Clarity Devs"),
          types.utf8("A community for Clarity developers"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      )
    ]);
      // Now join the community with another account
      block = chain.mineBlock([
        Tx.contractCall(
          'community-resource-allocation',
          'join-community',
          [
            types.uint(1), // community-id
            types.uint(150), // initial-contribution - over the threshold
          ],
          wallet1.address
        )
      ]);
      
      // Check that joining succeeded
      assertEquals(block.receipts.length, 1);
      assertEquals(block.receipts[0].result, '(ok u2)'); // Second member id is 2
      
      // Verify community stats updated
      let communityCall = chain.callReadOnlyFn(
        'community-resource-allocation',
        'get-community',
        [types.uint(1)],
        deployer.address
      );
      
      let community = communityCall.result.expectTuple();
      assertEquals(community['active-member-count'], types.uint(2)); // Now 2 members
      assertEquals(community['total-contribution'], types.uint(250)); // 100 + 150 = 250
      
      // Try joining with insufficient contribution
      block = chain.mineBlock([
        Tx.contractCall(
          'community-resource-allocation',
          'join-community',
          [
            types.uint(1), // community-id
            types.uint(50), // initial-contribution - under the threshold
          ],
          accounts.get('wallet_2')!.address
        )
      ]);
      
      // Should fail with insufficient contribution error
      assertEquals(block.receipts[0].result, `(err u${ERR_INSUFFICIENT_CONTRIBUTION})`);
    },
  });
  
  Clarinet.test({
    name: "Can add a resource to a community",
    async fn(chain: Chain, accounts: Map<string, Account>) {
      const deployer = accounts.get('deployer')!;
      const wallet1 = accounts.get('wallet_1')!;
      
      // Create a community
      let block = chain.mineBlock([
        Tx.contractCall(
          'community-resource-allocation',
          'create-community',
          [
            types.utf8("Resource Testers"),
            types.utf8("Testing resource functionality"),
            types.utf8("open"),
            types.uint(100),
          ],
          deployer.address
        )
      ]);
      
      // Add a resource as the community founder/admin
      block = chain.mineBlock([
        Tx.contractCall(
          'community-resource-allocation',
          'add-resource',
          [
            types.uint(1), // community-id
            types.utf8("Computing Time"), // name
            types.utf8("Shared computing resources"), // description
            types.uint(2), // resource-type (TIME-BASED)
            types.uint(100), // total-supply (100 time slots)
            types.uint(10), // minimum-contribution
            types.uint(5), // max-per-allocation
            types.uint(20), // cooldown-period (20 blocks)
          ],
          deployer.address
        )
      ]);
      
      // Check resource creation succeeded
      assertEquals(block.receipts.length, 1);
      assertEquals(block.receipts[0].result, '(ok u1)'); // First resource ID is 1
      
      // Verify resource details
      let resourceCall = chain.callReadOnlyFn(
        'community-resource-allocation',
        'get-resource',
        [types.uint(1)],
        deployer.address
      );
      
      let resource = resourceCall.result.expectTuple();
      assertEquals(resource.name, types.utf8("Computing Time"));
      assertEquals(resource.description, types.utf8("Shared computing resources"));
      assertEquals(resource['resource-type'], types.uint(2));
      assertEquals(resource['total-supply'], types.uint(100));
      assertEquals(resource['remaining-supply'], types.uint(100));
      assertEquals(resource['minimum-contribution'], types.uint(10));
      assertEquals(resource['max-per-allocation'], types.uint(5));
      assertEquals(resource['is-active'], types.bool(true));
      
      // Non-admin cannot add a resource
      block = chain.mineBlock([
        Tx.contractCall(
          'community-resource-allocation',
          'join-community',
          [
            types.uint(1), // community-id
            types.uint(100), // initial-contribution
          ],
          wallet1.address
        ),
        Tx.contractCall(
          'community-resource-allocation',
          'add-resource',
          [
            types.uint(1), // community-id
            types.utf8("Storage Space"), // name
            types.utf8("Shared storage"), // description
            types.uint(1), // resource-type (DIVISIBLE)
            types.uint(1000), // total-supply
            types.uint(10), // minimum-contribution
            types.uint(100), // max-per-allocation
            types.uint(20), // cooldown-period
          ],
          wallet1.address
        )
      ]);
         // Second transaction should fail with not authorized
    assertEquals(block.receipts.length, 2);
    assertEquals(block.receipts[0].result.startsWith('(ok'), true); // Join succeeded
    assertEquals(block.receipts[1].result, `(err u${ERR_NOT_AUTHORIZED})`); // Add resource failed
  },
});

Clarinet.test({
  name: "Can contribute to a community",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Create community and join
    let block = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Contributors"),
          types.utf8("Testing contributions"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      ),
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(100), // initial-contribution
        ],
        wallet1.address
      )
    ]);
    
    // Make additional contribution
    block = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'contribute',
        [
          types.uint(1), // community-id
          types.uint(50), // amount
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result, '(ok true)');
    
    // Verify member's contribution updated
    let memberCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-member',
      [types.uint(1), types.uint(2)], // community-id, member-id
      deployer.address
    );
    
    let member = memberCall.result.expectTuple();
    assertEquals(member.contribution, types.uint(150)); // 100 + 50 = 150
    
    // Verify community total contribution updated
    let communityCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-community',
      [types.uint(1)],
      deployer.address
    );
    
    let community = communityCall.result.expectTuple();
    assertEquals(community['total-contribution'], types.uint(250)); // 100 (founder) + 150 (member) = 250
  },
});

Clarinet.test({
  name: "Can request and process resource allocation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Setup: Create community, add member, add resource
    let setup = chain.mineBlock([
      // Create community
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Resource Users"),
          types.utf8("Testing resource allocation"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      ),
      // Add resource
      Tx.contractCall(
        'community-resource-allocation',
        'add-resource',
        [
          types.uint(1), // community-id
          types.utf8("Computing Time"), // name
          types.utf8("Shared computing resources"), // description
          types.uint(2), // resource-type (TIME-BASED)
          types.uint(100), // total-supply
          types.uint(100), // minimum-contribution
          types.uint(10), // max-per-allocation
          types.uint(20), // cooldown-period
        ],
        deployer.address
      ),
      // Join community with sufficient contribution
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(150), // initial-contribution
        ],
        wallet1.address
      ),
    ]);
    
    // Request allocation
    let requestBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'request-allocation',
        [
          types.uint(1), // community-id
          types.uint(1), // resource-id
          types.uint(5), // amount
          types.uint(50), // requested-start (block height)
          types.some(types.uint(10)), // requested-duration
          types.utf8("Need computing time for project"), // justification
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(requestBlock.receipts.length, 1);
    assertEquals(requestBlock.receipts[0].result, '(ok u1)'); // First request ID is 1
    
    // Process the allocation request
    let processBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'process-allocation-request',
        [
          types.uint(1), // request-id
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(processBlock.receipts.length, 1);
    assertEquals(processBlock.receipts[0].result, '(ok u1)'); // First allocation ID is 1
    
    // Verify resource remaining supply updated
    let resourceCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-resource',
      [types.uint(1)],
      deployer.address
    );
    
    let resource = resourceCall.result.expectTuple();
    assertEquals(resource['remaining-supply'], types.uint(95)); // 100 - 5 = 95
    
    // Check allocation details
    let allocationCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-allocation',
      [types.uint(1)],
      deployer.address
    );
    
    let allocation = allocationCall.result.expectTuple();
    assertEquals(allocation['resource-id'], types.uint(1));
    assertEquals(allocation['community-id'], types.uint(1));
    assertEquals(allocation['member-id'], types.uint(2)); // wallet1 is member 2
    assertEquals(allocation.amount, types.uint(5));
    assertEquals(allocation.status, types.uint(2)); // APPROVED
  },
});

Clarinet.test({
  name: "Can complete resource allocation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Setup: Create community, add resource, join, request and approve allocation
    let setup = chain.mineBlock([
      // Create community
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Resource Users"),
          types.utf8("Testing resource allocation"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      ),
      // Add resource
      Tx.contractCall(
        'community-resource-allocation',
        'add-resource',
        [
          types.uint(1), // community-id
          types.utf8("Computing Time"), // name
          types.utf8("Shared computing resources"), // description
          types.uint(2), // resource-type (TIME-BASED)
          types.uint(100), // total-supply
          types.uint(100), // minimum-contribution
          types.uint(10), // max-per-allocation
          types.uint(20), // cooldown-period
        ],
        deployer.address
      ),
      // Join community
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(150), // initial-contribution
        ],
        wallet1.address
      ),
    ]);
    
    // Request and process allocation
    let allocationBlock = chain.mineBlock([
      // Request allocation
      Tx.contractCall(
        'community-resource-allocation',
        'request-allocation',
        [
          types.uint(1), // community-id
          types.uint(1), // resource-id
          types.uint(5), // amount
          types.uint(50), // requested-start
          types.some(types.uint(10)), // requested-duration
          types.utf8("Need computing time for project"), // justification
        ],
        wallet1.address
      ),
      // Process request
      Tx.contractCall(
        'community-resource-allocation',
        'process-allocation-request',
        [
          types.uint(1), // request-id
        ],
        wallet1.address
      ),
    ]);
    
    // Verify resource supply reduced
    let resourceBeforeCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-resource',
      [types.uint(1)],
      deployer.address
    );
    
    let resourceBefore = resourceBeforeCall.result.expectTuple();
    assertEquals(resourceBefore['remaining-supply'], types.uint(95)); // 100 - 5 = 95
    
    // Complete the allocation
    let completeBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'complete-allocation',
        [
          types.uint(1), // allocation-id
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(completeBlock.receipts.length, 1);
    assertEquals(completeBlock.receipts[0].result, '(ok true)');
    
    // Verify allocation marked as completed
    let allocationCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-allocation',
      [types.uint(1)],
      deployer.address
    );
    
    let allocation = allocationCall.result.expectTuple();
    assertEquals(allocation.status, types.uint(4)); // COMPLETED
    
    // Verify resource supply returned for TIME-BASED resource
    let resourceAfterCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-resource',
      [types.uint(1)],
      deployer.address
    );
    
    let resourceAfter = resourceAfterCall.result.expectTuple();
    assertEquals(resourceAfter['remaining-supply'], types.uint(100)); // Back to 100
  },
});

Clarinet.test({
  name: "Can raise and resolve disputes",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Setup: Create community with members and resource
    let setup = chain.mineBlock([
      // Create community
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Dispute Handlers"),
          types.utf8("Testing dispute resolution"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      ),
      // Add members
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(150), // initial-contribution
        ],
        wallet1.address
      ),
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(200), // initial-contribution
        ],
        wallet2.address
      ),
      // Add resource
      Tx.contractCall(
        'community-resource-allocation',
        'add-resource',
        [
          types.uint(1), // community-id
          types.utf8("Equipment"), // name
          types.utf8("Shared equipment"), // description
          types.uint(3), // resource-type (UNIQUE)
          types.uint(5), // total-supply
          types.uint(100), // minimum-contribution
          types.uint(1), // max-per-allocation
          types.uint(20), // cooldown-period
        ],
        deployer.address
      ),
    ]);
    
    // Create and process allocation
    let allocationBlock = chain.mineBlock([
      // Request allocation
      Tx.contractCall(
        'community-resource-allocation',
        'request-allocation',
        [
          types.uint(1), // community-id
          types.uint(1), // resource-id
          types.uint(1), // amount
          types.uint(50), // requested-start
          types.some(types.uint(10)), // requested-duration
          types.utf8("Need equipment"), // justification
        ],
        wallet1.address
      ),
      // Process request
      Tx.contractCall(
        'community-resource-allocation',
        'process-allocation-request',
        [
          types.uint(1), // request-id
        ],
        wallet1.address
      ),
    ]);
    
    // Raise dispute about the allocation
    let disputeBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'raise-dispute',
        [
          types.uint(1), // community-id
          types.uint(1), // resource-id
          types.some(types.uint(1)), // allocation-id
          types.some(types.uint(2)), // against-member-id (wallet1)
          types.utf8("overuse"), // dispute-type
          types.utf8("Equipment not being used efficiently"), // description
        ],
        wallet2.address
      )
    ]);
    
    assertEquals(disputeBlock.receipts.length, 1);
    assertEquals(disputeBlock.receipts[0].result, '(ok u1)'); // First dispute ID is 1
    
    // Start voting on dispute
    let votingBlock = chain.mineBlock([
      // Start voting (function not shown in original contract, but assumed to exist)
      Tx.contractCall(
        'community-resource-allocation',
        'resolve-dispute',
        [
          types.uint(1), // dispute-id
          types.utf8("User must return equipment within 5 blocks"), // resolution
        ],
        deployer.address
      )
    ]);
    
    assertEquals(votingBlock.receipts.length, 1);
    assertEquals(votingBlock.receipts[0].result, '(ok true)');
    
    // Verify dispute status
    let disputeCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-dispute',
      [types.uint(1)],
      deployer.address
    );
    
    let dispute = disputeCall.result.expectTuple();
    assertEquals(dispute.status, types.uint(3)); // RESOLVED
    assertEquals(dispute.resolution, types.some(types.utf8("User must return equipment within 5 blocks")));
  },
});

Clarinet.test({
  name: "Can propose and implement expansions",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Setup: Create community with resource
    let setup = chain.mineBlock([
      // Create community
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Expanding Community"),
          types.utf8("Testing resource expansion"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      ),
      // Add resource
      Tx.contractCall(
        'community-resource-allocation',
        'add-resource',
        [
          types.uint(1), // community-id
          types.utf8("Storage Space"), // name
          types.utf8("Shared storage"), // description
          types.uint(1), // resource-type (DIVISIBLE)
          types.uint(1000), // total-supply
          types.uint(100), // minimum-contribution
          types.uint(100), // max-per-allocation
          types.uint(20), // cooldown-period
        ],
        deployer.address
      ),
      // Add member
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(200), // initial-contribution
        ],
        wallet1.address
      ),
    ]);
    
    // Propose expansion of existing resource
    let proposeBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'propose-expansion',
        [
          types.uint(1), // community-id
          types.some(types.uint(1)), // resource-id
          types.utf8("Storage Expansion"), // name
          types.utf8("Increase storage capacity"), // description
          types.uint(1), // resource-type (DIVISIBLE)
          types.uint(500), // proposed-supply (additional)
          types.uint(300), // estimated-cost
          types.utf8("Community Fund"), // funding-source
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(proposeBlock.receipts.length, 1);
    assertEquals(proposeBlock.receipts[0].result, '(ok u1)'); // First expansion ID is 1
    
    // Start voting
    let votingBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'start-expansion-voting',
        [
          types.uint(1), // expansion-id
        ],
        deployer.address // Admin
      )
    ]);
    
    assertEquals(votingBlock.receipts.length, 1);
    assertEquals(votingBlock.receipts[0].result, '(ok true)');
    
    // Vote on expansion
    let voteBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'vote-on-expansion',
        [
          types.uint(1), // expansion-id
          types.bool(true), // vote in favor
        ],
        deployer.address
      ),
      Tx.contractCall(
        'community-resource-allocation',
        'vote-on-expansion',
        [
          types.uint(1), // expansion-id
          types.bool(true), // vote in favor
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(voteBlock.receipts.length, 2);
    assertEquals(voteBlock.receipts[0].result, '(ok true)');
    assertEquals(voteBlock.receipts[1].result, '(ok true)');
    
    // Mine blocks to end voting period
    for (let i = 0; i < 1440; i++) {
      chain.mineBlock([]);
    }
    
    // Finalize voting
    let finalizeBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'finalize-expansion-voting',
        [
          types.uint(1), // expansion-id
        ],
        deployer.address
      )
    ]);
    
    assertEquals(finalizeBlock.receipts.length, 1);
    assertEquals(finalizeBlock.receipts[0].result, '(ok u3)'); // EXPANSION-STATUS-APPROVED = 3
    
    // Implement expansion
    let implementBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'implement-expansion',
        [
          types.uint(1), // expansion-id
        ],
        deployer.address
      )
    ]);
    
    assertEquals(implementBlock.receipts.length, 1);
    assertEquals(implementBlock.receipts[0].result, '(ok true)');
    
    // Verify resource was expanded
    let resourceCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-resource',
      [types.uint(1)],
      deployer.address
    );
    
    let resource = resourceCall.result.expectTuple();
    assertEquals(resource['total-supply'], types.uint(1500)); // 1000 + 500 = 1500
    assertEquals(resource['remaining-supply'], types.uint(1500)); // All available
  },
});

Clarinet.test({
  name: "Can manage admins and update reputations",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Setup: Create community with members
    let setup = chain.mineBlock([
      // Create community
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Admin Community"),
          types.utf8("Testing admin functionality"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      ),
      // Add members
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(150), // initial-contribution
        ],
        wallet1.address
      ),
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(200), // initial-contribution
        ],
        wallet2.address
      ),
    ]);
    
    // Make wallet1 an admin
    let adminBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'make-admin',
        [
          types.uint(1), // community-id
          types.principal(wallet1.address), // user-principal
        ],
        deployer.address
      )
    ]);
    
    assertEquals(adminBlock.receipts.length, 1);
    assertEquals(adminBlock.receipts[0].result, '(ok true)');
    
    // Verify wallet1 can perform admin functions (update user reputation)
    let reputationBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'update-reputation',
        [
          types.uint(1), // community-id
          types.uint(3), // member-id (wallet2)
          types.int(10), // score-change (+10)
        ],
        wallet1.address
      )
    ]);
    
    assertEquals(reputationBlock.receipts.length, 1);
    assertEquals(reputationBlock.receipts[0].result, '(ok u60)'); // Default 50 + 10 = 60
    
    // Verify member reputation was updated
    let memberCall = chain.callReadOnlyFn(
      'community-resource-allocation',
      'get-member',
      [types.uint(1), types.uint(3)], // community-id, member-id
      deployer.address
    );
    
    let member = memberCall.result.expectTuple();
    assertEquals(member['reputation-score'], types.uint(60)); // Updated from 50 to 60
    
    // Non-admin cannot update reputation
    let failedBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'update-reputation',
        [
          types.uint(1), // community-id
          types.uint(2), // member-id (wallet1)
          types.int(10), // score-change
        ],
        wallet2.address
      )
    ]);
    
    assertEquals(failedBlock.receipts.length, 1);
    assertEquals(failedBlock.receipts[0].result, `(err u${ERR_NOT_AUTHORIZED})`);
  },
});

Clarinet.test({
  name: "Checks resource allocation limits and entitlements",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Setup: Create community with varying member contributions and add resource
    let setup = chain.mineBlock([
      // Create community
      Tx.contractCall(
        'community-resource-allocation',
        'create-community',
        [
          types.utf8("Fair Share Community"),
          types.utf8("Testing allocation entitlements"),
          types.utf8("open"),
          types.uint(100),
        ],
        deployer.address
      ),
      // Add members with different contributions
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(300), // higher contribution
        ],
        wallet1.address
      ),
      Tx.contractCall(
        'community-resource-allocation',
        'join-community',
        [
          types.uint(1), // community-id
          types.uint(100), // minimum contribution
        ],
        wallet2.address
      ),
      // Add resource
      Tx.contractCall(
        'community-resource-allocation',
        'add-resource',
        [
          types.uint(1), // community-id
          types.utf8("Shared Resource"), // name
          types.utf8("Resource with proportional allocation"), // description
          types.uint(1), // resource-type (DIVISIBLE)
          types.uint(1000), // total-supply
          types.uint(100), // minimum-contribution (wallet2 is at minimum)
          types.uint(500), // max-per-allocation
          types.uint(20), // cooldown-period
        ],
        deployer.address
      ),
    ]);
    
    // Check allocation entitlement for wallet1 (higher contribution)
    let entitlementWallet1 = chain.callReadOnlyFn(
      'community-resource-allocation',
      'calculate-allocation-entitlement',
      [types.uint(1), types.uint(1), types.uint(2)], // community-id, resource-id, member-id
      deployer.address
    );
    
    let wallet1Entitlement = entitlementWallet1.result.expectTuple();
    
    // Check allocation entitlement for wallet2 (minimum contribution)
    let entitlementWallet2 = chain.callReadOnlyFn(
      'community-resource-allocation',
      'calculate-allocation-entitlement',
      [types.uint(1), types.uint(1), types.uint(3)], // community-id, resource-id, member-id
      deployer.address
    );
    
    let wallet2Entitlement = entitlementWallet2.result.expectTuple();
    
    // Wallet1 (higher contribution) should have higher entitlement than wallet2
    assertEquals(
      parseInt(wallet1Entitlement['max-allocation'].substring(1)) > 
      parseInt(wallet2Entitlement['max-allocation'].substring(1)), 
      true
    );
    
    // Try to allocate more than entitled (wallet2 tries to get too much)
    let overRequestBlock = chain.mineBlock([
      Tx.contractCall(
        'community-resource-allocation',
        'request-allocation',
        [
          types.uint(1), // community-id
          types.uint(1), // resource-id
          types.uint(400), // amount (likely more than wallet2's entitlement)
          types.uint(50), // requested-start
          types.none(), // no specific duration for divisible resource
          types.utf8("Need a large amount"), // justification
        ],
        wallet2.address
      ),
      // Try to process this request (should fail during processing)
      Tx.contractCall(
        'community-resource-allocation',
        'process-allocation-request',
        [
          types.uint(1), // request-id
        ],
        wallet2.address
      ),
    ]);
    
    // Request itself might succeed, but processing should fail due to allocation limit
    assertEquals(overRequestBlock.receipts.length, 2);
    assertEquals(overRequestBlock.receipts[0].result.startsWith('(ok'), true); // Request created
    // Processing should fail with allocation limit error
    assertEquals(overRequestBlock.receipts[1].result.includes('ERR-ALLOCATION-LIMIT'), true);
  },
});
    