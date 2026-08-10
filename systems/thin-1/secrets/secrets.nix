let
  thin-1 = "age14h8g2te3nw0xy3x8dzkhpzzlytcxtxcyrc9sw5efj5fdxw63qyast5efuy";
in
{
  "ssh-key.age".publicKeys  = [ thin-1 ];
  "wg0-conf.age".publicKeys = [ thin-1 ];
}
