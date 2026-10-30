/// Checks if you are awesome. Spoiler: you are.
class Awesome() {
  /// Creates it.
  this;

  /// Whether you are awesome.
  bool get isAwesome => true;

  // Its own test still uses it, which ci.yml's Analyze has to let through.
  /// Whether you were awesome.
  @Deprecated('Use isAwesome.')
  bool get wasAwesome => isAwesome;
}
