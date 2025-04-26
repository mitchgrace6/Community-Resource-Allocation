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
      