{ pkgs, lib, ... }:

let
  metadataFetcher = import ./openstack-metadata-fetcher.nix {
    targetRoot = "/";
    wgetExtraOptions = "--retry-connrefused";
  };
in
{
  imports = [
    ../profiles/qemu-guest.nix
    ../profiles/headless.nix
  ];

  config = {
    # The Openstack Metadata service exposes data on an EC2 API also.
    ec2.metadata.enable = true;
    virtualisation.amazon-init.enable = true;

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    boot.growPartition = true;
    boot.kernelParams = [ "console=ttyS0" ];
    boot.loader.grub.device = "/dev/vda";
    boot.loader.timeout = 0;

    # Allow root logins
    services.openssh = {
      enable = true;
      permitRootLogin = "prohibit-password";
      passwordAuthentication = lib.mkDefault false;
    };

    # Force getting the hostname from Openstack metadata.
    networking.hostName = lib.mkDefault "";

    systemd.services.openstack-init = {
      path = [ pkgs.wget ];
      description = "Fetch Metadata on startup";
      wantedBy = [ "multi-user.target" ];
      before = [ "apply-ec2-data.service" "amazon-init.service"];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      script = metadataFetcher;
      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
