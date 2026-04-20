{ lib, ... }:

{
  name = "vars";
  meta.maintainers = with lib.maintainers; [ lassulus ];

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [
        ./options.nix
        ./backends/on-machine
      ];
      vars.settings.on-machine.enable = true;
      environment.systemPackages = [
        # expect script to drive generate-vars interactively.
        # prompts appear in attribute-name order: aamulti, hidden, line.
        (pkgs.writeScriptBin "run-generate-vars" ''
          #!${pkgs.expect}/bin/expect -f
          set timeout 30
          spawn generate-vars
          expect "press control-d to finish"
          send "multi line content1\rmulti line content2\r"
          send "\x04"
          expect "doesn't show the input"
          send "hidden prompt content\r"
          expect "a simple line prompt"
          send "simple prompt content\r"
          expect eof
        '')
      ];
      vars.generators = {
        simple = {
          files.simple = { };
          script = ''
            echo simple > "$out"/simple
          '';
        };

        a = {
          files.a = { };
          script = ''
            echo a > "$out"/a
          '';
        };
        b = {
          dependencies = [ "a" ];
          files.b = { };
          script = ''
            cat "$in"/a/a > "$out"/b
            echo b >> "$out"/b
          '';
        };

        prompts = {
          files.prompt_line = { };
          files.prompt_hidden = { };
          files.prompt_multiline = { };
          prompts.line = {
            description = ''
              a simple line prompt
            '';
          };
          prompts.hidden = {
            type = "hidden";
            description = ''
              a prompt that doesn't show the input
            '';
          };
          prompts.aamulti = {
            type = "multiline";
            description = ''
              a prompt with multiple lines
            '';
          };
          script = ''
            cp "$prompts"/line "$out"/prompt_line
            cp "$prompts"/hidden "$out"/prompt_hidden
            cp "$prompts"/aamulti "$out"/prompt_multiline
          '';
        };
      };
    };

  testScript = ''
    start_all()

    # The generate-vars service fails because prompts need interactive input.
    # Wait for it to finish, then run manually with expect.
    machine.wait_for_unit("multi-user.target")
    machine.systemctl("is-active generate-vars.service || true")

    machine.succeed("run-generate-vars")

    # Verify non-prompt generators
    machine.succeed("grep -q simple /etc/vars/secret/simple/simple")
    machine.succeed("grep -q a /etc/vars/secret/a/a")
    out = machine.succeed("cat /etc/vars/secret/b/b")
    assert "a\n" in out, f"b should contain a's output, got: {out}"
    assert "b" in out, f"b should contain 'b', got: {out}"

    # Verify prompt-based generator
    machine.succeed("grep -q 'simple prompt content' /etc/vars/secret/prompts/prompt_line")
    machine.succeed("grep -q 'hidden prompt content' /etc/vars/secret/prompts/prompt_hidden")
    machine.succeed("grep -q 'multi line content1' /etc/vars/secret/prompts/prompt_multiline")
    machine.succeed("grep -q 'multi line content2' /etc/vars/secret/prompts/prompt_multiline")
  '';
}
