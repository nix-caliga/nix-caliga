# Home-manager

Home-manager on Nix-caliga is configured identically to how home-manager is configured on NixOS. See the [home-manager documentation](https://nix-community.github.io/home-manager/).

Home-manager requires the nix daemon to be enabled. See [Nix Package and Daemon](nix.md).  
See the examples in the project: [examples/home-manager/](https://github.com/nix-caliga/nix-caliga/tree/main/examples/home-manager).

## Known Limitations

- `home-manager.startAsUserService` is set to false by default in hm. Hm will not work activate in Nix-caliga if set to true.
