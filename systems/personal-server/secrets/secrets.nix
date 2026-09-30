let
  personal-server = "age107c8ttyc8yxye3jyyqvs7gkfksavz8mf4ppfxhzv6p7hj2d69yqqwlhsgu";
  server-desktop  = "age18z0p6m7rhcsuxal7vjmrysvwrnsrk2kymjfc7c9ha6d5c7975e7skcuhzv";
in
{
  "wg0-private-key.age".publicKeys    = [ personal-server server-desktop ];
  "traefik-acme-email.age".publicKeys = [ personal-server server-desktop ];
  "zwave-keys.age".publicKeys         = [ personal-server server-desktop ];
}
