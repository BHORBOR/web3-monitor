import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure web3-activity-tracker contract initializes entities",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall(
                "web3-activity-tracker", 
                "register-entity", 
                [
                    types.ascii("Web3 Researcher"),
                    types.uint(2)  // Developer role
                ],
                deployer.address
            )
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Validate activity creation in web3-activity-tracker",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall(
                "web3-activity-tracker", 
                "create-activity", 
                [
                    types.ascii("Web3 Protocol Research"),
                    types.ascii("Research advanced web3 protocol implementations"),
                    types.ascii("Research"),
                    types.uint(3),  // Medium complexity
                    types.uint(1),  // First namespace
                    types.none()    // No parent activity
                ],
                deployer.address
            )
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
    }
});