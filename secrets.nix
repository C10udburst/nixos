let
  # User public keys
  cloudburst = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKWkollg2qYQxZFUWbZcILvisWJYlAb7Y/9uAKZDl1Gu 18114966+C10udburst@users.noreply.github.com";
  users = [cloudburst];

  # Host public keys
  cloudburst-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP6nZFxrEKbYZ4zTRT1f6G5K/yOgCSEdutpfrGKd+AuW root@nixos";
  cloudburst-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXN+rc6QVRB54swk7dsXfbzHNIHNm4RjuSLueUzDi2H";
  cloudburst-tablet = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINn+GfTMQYqlUdiFhsTwoko21NzwL9CkEhiXigHTLFSL";
  cache = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGaxH0iycuhAYW9eAumBaMViCUvVU7Fl1gobsT19HLcr"; # brix0 / cache

  allHosts = [
    cloudburst-desktop
    cloudburst-laptop
    cloudburst-tablet
    cache
  ];

  serverHosts = [
    cloudburst-desktop
    cache
  ];
in {
  "secrets/smb-secrets.age".publicKeys = users ++ allHosts;
  "secrets/cloudflare-api-token.age".publicKeys = users ++ serverHosts;
  "secrets/golink-tailscale-auth-key.age".publicKeys = users ++ serverHosts;
  "secrets/vaultwarden-env.age".publicKeys = users ++ serverHosts;
  "secrets/karakeep-meilisearch-master-key.age".publicKeys = users ++ serverHosts;
  "secrets/manyfold-env.age".publicKeys = users ++ serverHosts;
  "secrets/wealthfolio-env.age".publicKeys = users ++ serverHosts;
}
