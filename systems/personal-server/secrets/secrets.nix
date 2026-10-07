let
  personal-server = "age18z0p6m7rhcsuxal7vjmrysvwrnsrk2kymjfc7c9ha6d5c7975e7skcuhzv";
in
{
  "wg0-private-key.age".publicKeys           = [ personal-server ];
  "traefik-acme-email.age".publicKeys        = [ personal-server ];
  "zwave-keys.age".publicKeys                = [ personal-server ];
  "zigbee2mqtt-network-key.age".publicKeys   = [ personal-server ];
  "ssh-key.age".publicKeys                   = [ personal-server ];
  "nut-monitor-password.age".publicKeys      = [ personal-server ];
  "frigate-rtsp-credentials.age".publicKeys  = [ personal-server ];
}
