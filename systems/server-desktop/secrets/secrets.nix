let
  server-desktop = "age18z0p6m7rhcsuxal7vjmrysvwrnsrk2kymjfc7c9ha6d5c7975e7skcuhzv";
in
{
  "ssh-key.age".publicKeys = [ server-desktop ];
}
