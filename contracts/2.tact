import "@stdlib/deploy";

/*
  TASK 2 - Proxy 
  Create a contract that forwards all received TONs
  to the admin contract (whose address is set in init_store).
  Message from this proxy contract to the admin contract should contain:
    - Address of user who sent original message (should be stored in the outcoming body's data/bits)
    - Original message that proxy smart contract received from user (should be stored in the outcoming body's first ref)
  Also, if admin contract decides to reject message (if it sends to the proxy "Refund" message with opcode=0x44),
  proxy contract needs to forward all TONs (attached to Refund message) back to the user.
  User address will be provided in Refund message body as "sender".
*/

message(0x44) Refund {
  queryId: Int as uint64;
  sender: Address;
}

contract Task2 with Deployable {
  admin: Address;

  init(admin: Address) {
    self.admin = admin;
  }
  
  receive(msg: Refund) {
    require(sender() == self.admin, "fraud");
    send(SendParameters{
        to: msg.sender,
        value: 0,
        mode: SendIgnoreErrors + SendRemainingValue,
        bounce: true,
        body: emptyCell()
    });
  }

  receive(msg: Slice) {
    let out_body: Builder = beginCell();
    out_body = out_body.storeAddress(sender());
    out_body = out_body.storeRef(msg.asCell());
    send(SendParameters{
        to: self.admin,
        value: 0,
        mode: SendIgnoreErrors + SendRemainingValue,
        bounce: true,
        body: out_body.endCell()
  });
}
}
