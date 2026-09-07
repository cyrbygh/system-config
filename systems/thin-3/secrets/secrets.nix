let
  thin-3 = "age1u8wvgysf4y67nactyle7mvq9pckzuwzx8ahfd6yytzgu0jxksy6svp5yzn";
in
{
  "ssh-key.age".publicKeys  = [ thin-3 ];
  "wg0-conf.age".publicKeys = [ thin-3 ];
}
