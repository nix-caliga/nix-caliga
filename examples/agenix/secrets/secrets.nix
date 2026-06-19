let
  # the public key that exists on your host, path defined in the myimage/default.nix file with `age.identityPaths`
  myHost = "ssh-ed25519 ...";
in
{
  "example.age".publicKeys = [ myHost ];
}
