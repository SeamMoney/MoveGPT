module owner::collatz_lengths {  
  /// A Collatz Length NFT. Each number is unique, as well as their numbers.
  struct CollatzLength has store, key {
    number: u64,
    length: u64 
  } 
  
  public fun mint(account: &signer, n: u64) {
    // check if $n$ is minted already

    // mint a Collatz Length NFT.
    move_to<CollatzLength>(account, CollatzLength {
      number: n,
      length: collatz_length(n)
    })
  }

  // Computes the collatz length, which is the number of iterations it takes
  // for a number to reach 1 via Collatz Functions. 
  fun collatz_length(n: u64): u64 {
    let len: u64 = 0;

    while (n != 1) {
      if (n % 2 == 0) {
        // even
        n = n << 1;
      } else {
        // odd
        n = 3*n + 1;
      };
      len = len + 1;
    };

    return len
  }
}
