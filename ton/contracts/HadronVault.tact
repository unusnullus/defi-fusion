// Hadron Vault for TON (scaffold)
// This is a minimal scaffold mirroring ERC4626-style operations.

contract HadronVault {
  // Config
  owner: address;
  usdt_root: address;         // Jetton root for USDT on TON
  usdt_vault_wallet: address; // Vault's Jetton wallet holding USDT

  // Simple share accounting (1:1 with USDT for scaffold)
  total_supply: int;
  balances: map[address] -> int;

  init(owner: address, usdt_root: address, usdt_vault_wallet: address) {
    self.owner = owner;
    self.usdt_root = usdt_root;
    self.usdt_vault_wallet = usdt_vault_wallet;
    self.total_supply = 0;
  }

  inline fun onlyOwner() {
    require(msg.sender == self.owner, "NOT_OWNER");
  }

  // Owner can update vault USDT wallet if rotated
  fun setUsdtVaultWallet(addr: address) {
    onlyOwner();
    self.usdt_vault_wallet = addr;
  }

  // Deposit path: Users transfer USDT Jetton to the vault; the vault receives a transfer notification.
  // For scaffold purposes we expose an explicit credit function that can be called by the vault's USDT wallet.
  // In production, wire this to Jetton transfer notification handler.
  fun creditDeposit(from: address, amount: int) {
    require(amount > 0, "ZERO_AMOUNT");
    require(msg.sender == self.usdt_vault_wallet, "ONLY_VAULT_WALLET");
    let prev = self.balances.get(from).getOrElse(0);
    self.balances.set(from, prev + amount);
    self.total_supply = self.total_supply + amount;
  }

  // Withdraw: burn shares and instruct vault USDT wallet to transfer tokens to receiver
  fun withdraw(shares: int, receiver: address) {
    require(shares > 0, "ZERO_AMOUNT");
    let bal = self.balances.get(msg.sender).getOrElse(0);
    require(bal >= shares, "INSUFFICIENT_SHARES");
    self.balances.set(msg.sender, bal - shares);
    self.total_supply = self.total_supply - shares;

    // Build Jetton transfer to receiver via vault wallet (opaque payload placeholder)
    // NOTE: Replace with proper Jetton wallet transfer message per standard.
    let body = beginCell().storeUint(0, 32).endCell();
    sendInternal(self.usdt_vault_wallet, 0, body, 1);
  }

  // Execute gluon actions (placeholder)
  fun execute(actions: slice[]) {
    // run pre-hooks
    // iterate gluon actions and call adapters
  }
}
