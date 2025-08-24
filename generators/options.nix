{
  lib,
  ...
}:
{
  options.vars = {
    unattended = lib.mkEnableOption "Whether to default to generating values unattended, rather than prompting for desired values.";
  };
}
