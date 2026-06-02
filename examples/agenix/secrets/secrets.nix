let
  testHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBTNxrDXYOGDA42xLonqKrgF/EmqNgq38ZSpqISmzstc";
in
{
  "example.age".publicKeys = [ testHost ];
}
