import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.

  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).

  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

// To simplify the testing process and the specificity of the messages being sent, we decided to add clear default values in this transaction
message(0xf8a7ea5) TokenTransfer {
     queryId: Int as uint64; // should be 0
     amount: Int as coins; // should be amount of jettons to send
     destination: Address; // should be user address / TokenNotification.from
     responseDestination: Address?; // should be myAddress()
     customPayload: Cell?; // should be null
     forwardTonAmount: Int as coins; // should be ton("0.01")
     forwardPayload: Slice as remaining; // should be emptySlice()
}

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int;
  bAmount: Int;
  jettonAddressA: Address;
  jettonAddressB: Address;

  init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address) {
    self.owner = admin;
    self.jettonAddressA = newJettonAddressA;
    self.jettonAddressB = newJettonAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
  }

  receive(msg: TokenNotification) {
    require((sender() == self.jettonAddressA) || (sender() == self.jettonAddressB), "Invalid Jetton");
    if (sender() == self.jettonAddressA) {
        if (msg.from == self.owner) {
            self.aAmount = self.aAmount + msg.amount;
            return;
        }
        let b_Amount: Int = (self.bAmount * 1000000000 / self.aAmount) * msg.amount / 1000000000;
        if (self.bAmount < b_Amount) {
            // return tokens to user
            nativeSendMessage(beginCell()
                                .storeInt(0x18, 2+1+3) // internal_message + ihd_disabled
                                //.storeBool(true) // bounce
                                //.storeInt(0, 3) // bounced + from
                                .storeAddress(self.jettonAddressA) // To
                                .storeCoins(0) // Value
                                .storeInt(0+0+1, 1+4+4+64+32+1+1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                                //.storeBool(false) // No state init (code and data null)
                                //.storeBool(true) // Body not null
                                .storeRef(TokenTransfer{
                                                    queryId: 0,
                                                    amount: msg.amount,
                                                    destination: msg.from,
                                                    responseDestination: myAddress(),
                                                    customPayload: null,
                                                    forwardTonAmount: 10000000,
                                                    forwardPayload: emptySlice()
                                                }.toCell()) // Save not null body
                                .endCell(), SendIgnoreErrors + SendRemainingValue);
            return;
        }
        // valid swap
        nativeSendMessage(beginCell()
                            .storeInt(0x18, 2+1+3) // internal_message + ihd_disabled
                            //.storeBool(true) // bounce
                            //.storeInt(0, 3) // bounced + from
                            .storeAddress(self.jettonAddressB) // To
                            .storeCoins(0) // Value
                            .storeInt(0+0+1, 1+4+4+64+32+1+1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                            //.storeBool(false) // No state init (code and data null)
                            //.storeBool(true) // Body not null
                            .storeRef(TokenTransfer{
                                                queryId: 0,
                                                amount: b_Amount,
                                                destination: msg.from,
                                                responseDestination: myAddress(),
                                                customPayload: null,
                                                forwardTonAmount: 10000000,
                                                forwardPayload: emptySlice()
                                            }.toCell()) // Save not null body
                            .endCell(), SendIgnoreErrors + SendRemainingValue);
        self.bAmount = self.bAmount - b_Amount;
        self.aAmount = self.aAmount + msg.amount;
        return;
    }
    if (msg.from == self.owner) {
        self.bAmount = self.bAmount + msg.amount;
        return;
    }
    let a_Amount: Int = (self.aAmount * 1000000000 / self.bAmount) * msg.amount / 1000000000;
    if (self.aAmount < a_Amount) {
        // return tokens to user
        nativeSendMessage(beginCell()
                            .storeInt(0x18, 2+1+3) // internal_message + ihd_disabled
                            //.storeBool(true) // bounce
                            //.storeInt(0, 3) // bounced + from
                            .storeAddress(self.jettonAddressB) // To
                            .storeCoins(0) // Value
                            .storeInt(0+0+1, 1+4+4+64+32+1+1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                            //.storeBool(false) // No state init (code and data null)
                            //.storeBool(true) // Body not null
                            .storeRef(TokenTransfer{
                                                queryId: 0,
                                                amount: msg.amount,
                                                destination: msg.from,
                                                responseDestination: myAddress(),
                                                customPayload: null,
                                                forwardTonAmount: 10000000,
                                                forwardPayload: emptySlice()
                                            }.toCell()) // Save not null body
                            .endCell(), SendIgnoreErrors + SendRemainingValue);
        return;
    }
    // valid swap
    nativeSendMessage(beginCell()
                            .storeInt(0x18, 2+1+3) // internal_message + ihd_disabled
                            //.storeBool(true) // bounce
                            //.storeInt(0, 3) // bounced + from
                            .storeAddress(self.jettonAddressA) // To
                            .storeCoins(0) // Value
                            .storeInt(0+0+1, 1+4+4+64+32+1+1) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                            //.storeBool(false) // No state init (code and data null)
                            //.storeBool(true) // Body not null
                            .storeRef(TokenTransfer{
                                                queryId: 0,
                                                amount: a_Amount,
                                                destination: msg.from,
                                                responseDestination: myAddress(),
                                                customPayload: null,
                                                forwardTonAmount: 10000000,
                                                forwardPayload: emptySlice()
                                            }.toCell()) // Save not null body
                            .endCell(), SendIgnoreErrors + SendRemainingValue);
    self.aAmount = self.aAmount - a_Amount;
    self.bAmount = self.bAmount + msg.amount;
    return;
  }

  get fun price(jetton: Address): Int {
    if (jetton == self.jettonAddressB && self.bAmount > 0) {
        return self.aAmount * 1000000000 / self.bAmount;
    }
    else if (jetton == self.jettonAddressA && self.aAmount > 0) {
        return self.bAmount * 1000000000 / self.aAmount;
    }
    return 0;
  }

  get fun balance(jetton: Address): Int {
    if (jetton == self.jettonAddressA) {
        return self.aAmount;
    }
    return self.bAmount;
  }
}