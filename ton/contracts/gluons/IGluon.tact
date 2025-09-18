// Gluon interface (TON scaffold)

trait IGluon {
  // Execute with opaque calldata
  fun call(data: slice);
}
