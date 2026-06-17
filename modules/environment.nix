# originally copied from numtide/system-manager nix/modules/environment.nix
{
  lib,
  config,
  options,
  pkgs,
  ...
}:

{
  options.environment = {
    systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages to be installed in the system profile, available to all users at /usr/local/bin/.";
    };

    corePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Packages that are considered essential for the system to function.
        These are automatically included in `environment.systemPackages`.
        NixOS modules use this to register packages they depend on.
      '';
    };

    pathsToLink = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    extraOutputsToInstall = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional package outputs to symlink
        into per-user profiles at `/etc/profiles/per-user/<name>/`
        alongside the default "out" output.
      '';
    };

    extraInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell script code which should be called before any shell session through the host /etc/profile.";
    };

    extraSetup = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell fragments to be run after the system environment has been created. This should only be used for things that need to modify the internals of the environment, e.g. generating MIME caches. The environment being built can be accessed at $out.";
    };

    variables = lib.mkOption {
      default = { };
      example = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
      description = ''
        A set of environment variables used in the global environment.
        These variables will be set on shell initialisation (e.g. in /etc/profile).

        The value of each variable can be either a string or a list of
        strings.  The latter is concatenated, interspersed with colon
        characters.

        Setting a variable to `null` does nothing. You can override a
        variable set by another module to `null` to unset it.
      '';
      type =
        with lib.types;
        attrsOf (
          nullOr (oneOf [
            (listOf (oneOf [
              int
              str
              path
            ]))
            int
            str
            path
          ])
        );
      apply =
        let
          toStr = v: if lib.isPath v then "${v}" else toString v;
        in
        attrs:
        lib.mapAttrs (_: v: if lib.isList v then lib.concatMapStringsSep ":" toStr v else toStr v) (
          lib.filterAttrs (_: v: v != null) attrs
        );
    };

    sessionVariables = lib.mkOption {
      default = { };
      description = ''
        A set of environment variables used in the global environment.
        These variables will be set by PAM early in the login process.

        The value of each session variable can be either a string or a
        list of strings. The latter is concatenated, interspersed with
        colon characters.

        Setting a variable to `null` does nothing. You can override a
        variable set by another module to `null` to unset it.

        Note: unlike NixOS, nix-caliga does not manage PAM on the
        host, so these variables are not injected by pam_env into
        non-shell sessions (e.g. graphical logins).
      '';
      inherit (options.environment.variables) type apply;
    };
  };

  options.system.path = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = ''
      The top-level system environment derivation, combining
      `environment.systemPackages` into a single buildEnv. Exposed so
      that modules copied verbatim from NixOS (e.g. `users-groups.nix`)
      can reference `config.system.path.{ignoreCollisions,postBuild}`.
    '';
  };

  config = {
    environment = {
      systemPackages = config.environment.corePackages;

      pathsToLink = [
        "/bin"
      ];

      variables = config.environment.sessionVariables;

      etc = {
        "profile.d/caliga-path.sh".source = pkgs.writeText "caliga-path.sh" ''
          ${lib.concatLines (lib.mapAttrsToList (k: v: ''export ${k}="${v}"'') config.environment.variables)}
          export PATH="/etc/profiles/per-user/$USER/bin:/usr/local/bin:$PATH"
          ${config.environment.extraInit}
        '';
      };
    };

    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink extraOutputsToInstall;
      ignoreCollisions = true;
      postBuild = config.environment.extraSetup;
    };

    systemd.tmpfiles.rules = lib.mkIf config.caliga.core.environment.linkCurrentSystem [
      "d /run/current-system     0755 root root -"
      "L /run/current-system/sw  -    -    -    - ${config.system.path}"
    ];

    # symlink each binary under $out/usr/local/bin so streamLayeredImage places it at /usr/local/bin
    # TODO
    # not sure if this is the best option
    # I want to make nix packages built into the bootc image available to sudo
    # Trying to avoid needing to control secure_path
    layeredImage.contents = lib.mkIf (config.environment.systemPackages != [ ]) [
      (pkgs.runCommand "system-packages"
        {
          preferLocalBuild = true;
          allowSubstitutes = false;
        }
        ''
          mkdir -p $out/usr/local/bin
          for bin in ${config.system.path}/bin/*; do
            ln -sf "$bin" $out/usr/local/bin/
          done
        ''
      )
    ];
  };
}
