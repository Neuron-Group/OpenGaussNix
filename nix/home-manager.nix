{ config, lib, pkgs, ... }:

let
  cfg = config.programs.opengauss;
  yamlFormat = pkgs.formats.yaml { };
  envType = lib.types.attrsOf (lib.types.oneOf [
    lib.types.str
    lib.types.int
    lib.types.float
    lib.types.bool
    lib.types.path
  ]);
  envText = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "${name}=${toString value}") cfg.environment
  );
in
{
  options.programs.opengauss = {
    enable = lib.mkEnableOption "Open Gauss";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.opengauss";
      description = "Open Gauss package to install.";
    };

    gaussHome = lib.mkOption {
      type = lib.types.str;
      default = ".gauss";
      description = "Path relative to the home directory for Gauss state and config.";
    };

    withClaudeCode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install `claude-code` alongside Open Gauss.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages added to the user environment for Open Gauss workflows.";
    };

    settings = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      example = {
        gauss.autoformalize.backend = "claude-code";
        gauss.autoformalize.auth_mode = "api-key";
        model = "anthropic/claude-sonnet-4";
        terminal.backend = "local";
      };
      description = ''
        Declarative content for `config.yaml`.
        This maps directly to Gauss' YAML config structure.
      '';
    };

    environment = lib.mkOption {
      type = envType;
      default = { };
      example = {
        ANTHROPIC_API_KEY = "...";
        OPENAI_BASE_URL = "http://127.0.0.1:8000/v1";
      };
      description = "Entries written to `${cfg.gaussHome}/.env`.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ]
      ++ lib.optional cfg.withClaudeCode pkgs.claude-code
      ++ cfg.extraPackages;

    home.sessionVariables.GAUSS_HOME = "${config.home.homeDirectory}/${cfg.gaussHome}";

    home.file."${cfg.gaussHome}/config.yaml" = lib.mkIf (cfg.settings != { }) {
      source = yamlFormat.generate "opengauss-config.yaml" cfg.settings;
    };

    home.file."${cfg.gaussHome}/.env" = lib.mkIf (cfg.environment != { }) {
      text = envText + "\n";
    };

    home.file."${cfg.gaussHome}/install-root".text = "${cfg.package}/share/opengauss\n";
  };
}
