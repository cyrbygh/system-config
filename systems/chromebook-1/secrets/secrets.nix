let
  chromebook-1 = "age1vt2mer30sudtl5aesjcdhd3uq5dnu8x5g6shel4mzyhenljmye2qyussdf";
in
{
  "ssh-key.age".publicKeys  = [ chromebook-1 ];
  "wg0-conf.age".publicKeys = [ chromebook-1 ];
}
