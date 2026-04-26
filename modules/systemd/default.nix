# builds /usr/lib/systemd/system for layeredImage.contents.
# follows NixOS generateUnits; adds: systemd.defaultUnit option, unit masking
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.systemd;

  enabledUnits = lib.filterAttrs (_: unit: unit.enable) cfg.units;

  mkDepLinks =
    attr: suffix:
    lib.concatStrings (
      lib.mapAttrsToList (
        name: unit:
        lib.concatMapStrings (target: ''
          mkdir -p "$dir"/'${target}.${suffix}'
          ln -sfn '../${name}' "$dir"/'${target}.${suffix}'/
        '') (unit.${attr} or [ ])
      ) enabledUnits
    );

  systemdUnits =
    # copying the files here instead of linking them fixes issues with selinux, by making it clear what selinux needs to label
    # copying doesnt result in a image size increase that matters so we go with this for now
    # TODO figure out if theres a better way to label systemd services in selinux
    pkgs.runCommand "systemd-units"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        dir=$out/usr/lib/systemd/system
        mkdir -p "$dir"

        # Copy units from systemd.packages
        for package in ${lib.escapeShellArgs (lib.unique cfg.packages)}; do
          for basedir in $package/etc/systemd/system $package/lib/systemd/system; do
            [ -e "$basedir" ] || continue
            cp -rL "$basedir"/. "$dir"/
          done
        done

        # Link unit files, handling conflicts with drop-in overrides
        for i in ${toString (lib.mapAttrsToList (n: v: v.unit) (lib.filterAttrs (n: v: v.overrideStrategy == "asDropinIfExists") enabledUnits))}; do
          fn=$(basename $i/*)
          if [ -e "$dir"/$fn ]; then
            if [ "$(readlink -f $i/$fn)" = /dev/null ]; then
              ln -sfn /dev/null "$dir"/$fn
            else
              mkdir -p "$dir"/$fn.d
              cp -L $i/$fn "$dir"/$fn.d/overrides.conf
            fi
          else
            cp -L $i/$fn "$dir"/
          fi
        done

        for i in ${toString (lib.mapAttrsToList (n: v: v.unit) (lib.filterAttrs (n: v: v.overrideStrategy == "asDropin") enabledUnits))}; do
          fn=$(basename $i/*)
          mkdir -p "$dir"/$fn.d
          cp -L $i/$fn "$dir"/$fn.d/overrides.conf
        done

        # Create dependency symlinks
        ${mkDepLinks "wantedBy" "wants"}
        ${mkDepLinks "requiredBy" "requires"}
        ${mkDepLinks "upheldBy" "upholds"}

        # Create aliases
        ${lib.concatStrings (lib.mapAttrsToList (name: unit:
          lib.concatMapStrings (alias: ''
            ln -sfn '${name}' "$dir"/'${alias}'
          '') (unit.aliases or [ ])
        ) enabledUnits)}

        # Mask units
        ${lib.concatMapStrings (unit: ''
          ln -sfn /dev/null "$dir"/'${unit}'
        '') cfg.maskedUnits}

        # Set default target
        ${lib.optionalString (cfg.defaultUnit != null) ''
          ln -sfn '${cfg.defaultUnit}' "$dir"/default.target
        ''}
      '';

  hasUnits =
    enabledUnits != { } || cfg.packages != [ ] || cfg.maskedUnits != [ ] || cfg.defaultUnit != null;

in
{
  imports = [
    ./systemd.nix
  ];

  options.systemd.defaultUnit = lib.mkOption {
    default = null;
    type = lib.types.nullOr lib.types.str;
    description = "Default target unit.";
  };

  config = lib.mkIf (config.caliga.core.systemd.enable && hasUnits) {
    assertions =
      let
        enabledUnitNames = lib.attrNames enabledUnits;
        overlap = lib.intersectLists enabledUnitNames cfg.maskedUnits;
      in
      [
        {
          assertion = overlap == [ ];
          message = "units cannot be both defined and masked: ${lib.concatStringsSep ", " overlap}";
        }
      ];

    warnings = lib.optional (!config.caliga.core.selinux.enable && !config.selinux.ignoreWarnings) ''
      caliga.core.systemd.enable is active but caliga.core.selinux.enable is false.
      Systemd units may fail if selinux is enforcing.
      Enable caliga.core.selinux.enable or set selinux.ignoreWarnings = true to silence this warning.
    '';

    layeredImage.contents = [ systemdUnits ];
  };
}
