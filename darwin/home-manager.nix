{ config, pkgs, lib, ... }:

let
  common-files = import ../common/files.nix { inherit config pkgs; };
  user = "dustin"; in
{
  imports = [
    <home-manager/nix-darwin>
   ./dock
  ];

  # It me
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  # Fully declarative dock using the latest from Nix Store
  local.dock.enable = true;
  local.dock.entries = [
    { path = "/Applications/Slack.app/"; }
    { path = "/System/Applications/Messages.app/"; }
    { path = "/System/Applications/Facetime.app/"; }
    { path = "/Applications/Telegram.app/"; }
    { path = "${pkgs.alacritty}/Applications/Alacritty.app/"; }
    { path = "/Applications/Discord.app/"; }
    { path = "/System/Applications/Music.app/"; }
    { path = "/System/Applications/News.app/"; }
    { path = "/System/Applications/Photos.app/"; }
    { path = "/System/Applications/Photo Booth.app/"; }
    { path = "/Applications/Drafts.app/"; }
    { path = "/System/Applications/Home.app/"; }
    {
      path = "${config.users.users.${user}.home}/.local/share/bin/emacs-launcher.command";
      section = "others";
    }
    {
      path = "${config.users.users.${user}.home}/.local/share/";
      section = "others";
      options = "--sort name --view grid --display folder";
    }
    {
      path = "${config.users.users.${user}.home}/.local/share/downloads";
      section = "others";
      options = "--sort name --view grid --display stack";
    }
  ];

  # We use Homebrew to install impure software only (Mac Apps)
  homebrew.enable = true;
  homebrew.onActivation = {
    autoUpdate = true;
    cleanup = "zap";
    upgrade = true;
  };
  homebrew.brewPrefix = "/opt/homebrew/bin";

  # These app IDs are from using the mas CLI app
  # mas = mac app store
  # https://github.com/mas-cli/mas
  #
  # $ mas search <app name>
  #
  homebrew.casks = pkgs.callPackage ./casks.nix {};
  homebrew.masApps = {
    "1password" = 1333542190;
    "drafts" = 1435957248;
    "hidden-bar" = 1452453066;
    "wireguard" = 1451685025;
    "yoink" = 457622435;
  };

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    users.${user} = { pkgs, config, lib, ... }:{
      home.enableNixpkgsReleaseCheck = false;
      home.packages = pkgs.callPackage ./packages.nix {};
      home.file = common-files // import ./files.nix { inherit config pkgs; };
      home.activation = {
        gpgImportKeys =
          let
            gpgKeys = [
              "/Users/${user}/.ssh/pgp_github.key"
              "/Users/${user}/.ssh/pgp_github.pub"
            ];
            gpgScript = pkgs.writeScript "gpg-import-keys" ''
              #! ${pkgs.runtimeShell} -el
              ${lib.optionalString (gpgKeys != []) ''
                ${pkgs.gnupg}/bin/gpg --import ${lib.concatStringsSep " " gpgKeys}
              ''}
            '';
            plistPath = "$HOME/Library/LaunchAgents/gpg-import-keys.plist";
          in
            # Prior to the write boundary: no side effects. After writeBoundary, side effects.
            # We're creating a new plist file, so we need to run this after the writeBoundary
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              mkdir -p "$HOME/Library/LaunchAgents"
              cat >${plistPath} <<EOF
              <?xml version="1.0" encoding="UTF-8"?>
              <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
              <plist version="1.0">
              <dict>
                <key>Label</key>
                <string>gpg-import-keys</string>
                <key>ProgramArguments</key>
                <array>
                  <string>${gpgScript}</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
              </dict>
              </plist>
              EOF

              launchctl load ${plistPath}
            '';

      programs = {} // import ../common/home-manager.nix { inherit config pkgs lib; };
      # https://github.com/nix-community/home-manager/issues/3344
      # Marked broken Oct 20, 2022 check later to remove this
      # Confirmed still broken, Mar 5, 2023
      manual.manpages.enable = false;
      };
    };
  };
}
