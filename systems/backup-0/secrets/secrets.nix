let
  backup-0      = "age1xqddru0skp5lk23n8a4m7ej9waxxhnvezmtqex2dqcgrq6gpmemsm08ftp";
  server-desktop = "age18z0p6m7rhcsuxal7vjmrysvwrnsrk2kymjfc7c9ha6d5c7975e7skcuhzv";
in
{
  "wg0-conf.age".publicKeys = [ backup-0 server-desktop ];
}
