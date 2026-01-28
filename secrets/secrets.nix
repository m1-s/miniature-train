let
  keys = import ../keys.nix;
in
{
  "wifi.age".publicKeys = keys;
}
