// Simple Access Control (TON scaffold)

contract AccessControl {
  owner: address;

  init(owner: address) {
    self.owner = owner;
  }

  fun transferOwnership(newOwner: address) {
    require(msg.sender == self.owner, "NOT_OWNER");
    self.owner = newOwner;
  }
}
