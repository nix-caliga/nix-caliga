# Microvm.nix

Microvm.nix is configured identically to how microvm.nix is configured on NixOS. See the [microvm.nix documentation](https://microvm-nix.github.io/microvm.nix/).

Depending on how microvms are configured, the nix daemon may be required on the host image. See [Nix Package and Daemon](nix.md).  
Also see the examples in the project: [examples/microvm/](https://github.com/nix-caliga/nix-caliga/tree/main/examples/microvm).

## Known Limitations

The following options are currently just stubs and have no effect on your system:

These are likely already handled in your base image
- `boot.kernelModules`
- `hardware.ksm.enable`

May have a few limitations when running microvms manually with the microvm command because of a lack of PAM?:
- `security.pam.loginLimits`
