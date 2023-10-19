import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.
  Implement getter that will return NFT addresses held by the smart contract.
  Implement getter that will return the amount of admin`s profit collected.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender

  Getters
  * profit
   - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  * nfts
   - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values
     the order of NFTs in this dictionary doesn't matter
*/

message AdminWithdrawalProfit {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message AdminFetchProfit {
  queryId: Int as uint64;
}


message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining;
}

message(0x5fcc3d14) Transfer {
    queryId: Int as uint64;
    newOwner: Address;
    responseDestination: Address;
    customPayload: Cell?;
    forwardAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract Task5 with Deployable {
  seed: Int as uint128;
  owner: Address;
  id_nfts: map<Int as uint16, Address>;
  nfts_number: Int;

  init(seed: Int, owner: Address) {
    self.owner = owner;
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    self.nfts_number = 0;
    self.id_nfts = emptyMap();
  }

  receive(msg: OwnershipAssigned) {
    let ctx: Context = context();

    // if prevOwner is the owner's (admin) address, then add NFT to the collection
    if (msg.prevOwner == self.owner) {
        self.nfts_number = self.nfts_number + 1;
        self.id_nfts.set(self.nfts_number - 1, sender());
    }

    // if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
    // but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
    else if ((ctx.value < (ton("2.1"))) && (ctx.value > ctx.readForwardFee())) {
        let c: Cell = beginCell()
            .storeInt(1, 2) // internal_message + ihd_disabled
            .storeBool(true) // bounce
            .storeInt(0, 3) // bounced + from
            .storeAddress(sender()) // To
            .storeCoins(0) // Value
            .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeBool(false) // No state init (code and data null)
            .storeBool(true) // Body not null
            .storeRef(Transfer{
                            queryId: msg.queryId,
                            newOwner: msg.prevOwner,
                            responseDestination: msg.prevOwner,
                            customPayload: null,   // correct
                            forwardAmount: 0,   // correct
                            forwardPayload: emptySlice()    //correct
                            }.toCell()) // Save not null body
            .endCell();
        nativeSendMessage(c, SendRemainingValue + SendIgnoreErrors);
    }

    // randomly select NFT to send from all the NFTs that smart contract has
    else {
        let nft_address: Address = sender();
        if (self.nfts_number > 0) {
            let nft_id: Int = random(0, self.nfts_number);
            if (nft_id != self.nfts_number) {
                nft_address = self.id_nfts.get(nft_id)!!;
                self.id_nfts.set(nft_id, sender());
            }
        }

        // send the selected NFT to the sender with all remaining balance
        // (except for admin profit = fees collected from this and other swaps)
        // In other words: the contract's balance should increase by exactly 2 TON,
        // some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
        let c: Cell = beginCell()
            .storeInt(1, 2) // internal_message + ihd_disabled
            .storeBool(true) // bounce
            .storeInt(0, 3) // bounced + from
            .storeAddress(nft_address) // To
            .storeCoins(ctx.value - ton("2")) // Value
            .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeBool(false) // No state init (code and data null)
            .storeBool(true) // Body not null
            .storeRef(Transfer{
                            queryId: msg.queryId,
                            newOwner: msg.prevOwner,
                            responseDestination: msg.prevOwner,
                            customPayload: null,   // correct
                            forwardAmount: 0,   // correct
                            forwardPayload: emptySlice()    //correct
                            }.toCell()) // Save not null body
            .endCell();
        nativeSendMessage(c, SendIgnoreErrors);
    }
  }

  receive(msg: AdminWithdrawalProfit) {
    // SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
    require(sender() == self.owner, "Insufficient privelegies");
    let ctx: Context = context();

    // SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
    // In other words: after each such operation, the contract's balance should be equal to 0.1 TON
    // (which are reserved for storage) and the rest should be sent to the admin
    let c: Cell = beginCell()
        .storeInt(1, 2) // internal_message + ihd_disabled
        .storeBool(true) // bounce
        .storeInt(0, 3) // bounced + from
        .storeAddress(sender()) // To
        .storeCoins(myBalance() - ctx.value - ton("0.1")) // Value
        .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
        .storeBool(false) // No state init (code and data null)
        .storeBool(true) // Body not null
        .storeRef(AdminFetchProfit{
                        queryId: msg.queryId
                        }.toCell()) // Save not null body
        .endCell();
    nativeSendMessage(c, SendRemainingValue + SendIgnoreErrors);
  }

  receive(msg: AdminWithdrawalAllNFTs) {
    let ctx: Context = context();
    if (sender() == myAddress()) {
        repeat (160) {
            let c: Cell = beginCell()
                .storeInt(1, 2) // internal_message + ihd_disabled
                .storeBool(true) // bounce
                .storeInt(0, 3) // bounced + from
                .storeAddress(self.id_nfts.get(self.nfts_number-1)!!) // To
                .storeCoins(ton("0.08")) // Value
                .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                .storeBool(false) // No state init (code and data null)
                .storeBool(true) // Body not null
                .storeRef(Transfer{
                                queryId: msg.queryId,   // correct
                                newOwner: self.owner,   // correct
                                responseDestination: self.owner,    // correct
                                customPayload: null,    // correct
                                forwardAmount: 0,   // correct
                                forwardPayload: emptySlice() // correct
                                }.toCell()) // Save not null body
                .endCell();
            nativeSendMessage(c, SendIgnoreErrors);
            self.nfts_number = self.nfts_number - 1;
            if (self.nfts_number == 0) {
                self.id_nfts = emptyMap();
                return;
            }
        }
    }
    else {
        // SC should check that incoming tx TON value is enough for NFT withdrawal.
        // Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
        require(ctx.value >= (ton("1") + ton("0.08")*(self.nfts_number)), "Insufficent funds");

        // SC should check that sender is the admin, throw "Invalid sender" otherwise
        require(sender() == self.owner, "Invalid sender");

        // If all checks pass, SC should send NFTs one by one to the admin
        // SC should be able to withdraw all NFTs by a single message from admin
        repeat (160) {
            let c: Cell = beginCell()
                .storeInt(1, 2) // internal_message + ihd_disabled
                .storeBool(true) // bounce
                .storeInt(0, 3) // bounced + from
                .storeAddress(self.id_nfts.get(self.nfts_number-1)!!) // To
                .storeCoins(ton("0.08")) // Value
                .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                .storeBool(false) // No state init (code and data null)
                .storeBool(true) // Body not null
                .storeRef(Transfer{
                                queryId: msg.queryId,   // correct
                                newOwner: self.owner,   // correct
                                responseDestination: self.owner,    // correct
                                customPayload: null,    // correct
                                forwardAmount: 0,   // correct
                                forwardPayload: emptySlice() // correct
                                }.toCell()) // Save not null body
                .endCell();
            nativeSendMessage(c, SendIgnoreErrors);
            self.nfts_number = self.nfts_number - 1;
            if (self.nfts_number == 0) {
                self.id_nfts = emptyMap();
                return;
            }
        }
        if (self.nfts_number > 0) {
            let c2: Cell = beginCell()
                .storeInt(1, 2) // internal_message + ihd_disabled
                .storeBool(true) // bounce
                .storeInt(0, 3) // bounced + from
                .storeAddress(myAddress()) // To
                .storeCoins(ctx.value - ton("0.08")*160) // Value
                .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                .storeBool(false) // No state init (code and data null)
                .storeBool(true) // Body not null
                .storeRef(AdminWithdrawalAllNFTs{
                                queryId: msg.queryId
                                }.toCell()) // Save not null body
                .endCell();
            nativeSendMessage(c2, SendPayGasSeparately + SendIgnoreErrors);
        }
    }
  }

  get fun profit(): Int {
    // returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
    return (myBalance() - ton("0.1"));
  }

  get fun nfts(): map<Int as uint16, Address> {
    // returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values
    return self.id_nfts;
  }
}