let
  backup-1       = "age1j9gp0w6j78dnhgd6xndtm27ljc4stdcxghxwudr6hltljg3c84sqxpvhgd";
  server-desktop = "age18z0p6m7rhcsuxal7vjmrysvwrnsrk2kymjfc7c9ha6d5c7975e7skcuhzv";
in
{
  "wg0-conf.age".publicKeys = [ backup-1 server-desktop ];
}
