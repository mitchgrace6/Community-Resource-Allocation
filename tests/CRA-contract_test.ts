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