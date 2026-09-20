let
  # User public keys
  cloudburst = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKWkollg2qYQxZFUWbZcILvisWJYlAb7Y/9uAKZDl1Gu 18114966+C10udburst@users.noreply.github.com";
  users = [cloudburst];

  # Host public keys
  cloudburst-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP6nZFxrEKbYZ4zTRT1f6G5K/yOgCSEdutpfrGKd+AuW";
  cloudburst-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXN+rc6QVRB54swk7dsXfbzHNIHNm4RjuSLueUzDi2H";
  cloudburst-tablet = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINn+GfTMQYqlUdiFhsTwoko21NzwL9CkEhiXigHTLFSL";
  brix0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFr0VqygSJ/VcNgkyDsyO2UCVis8iAvNKnK0TC4AdY7K";

  allHosts = [
    cloudburst-desktop
    cloudburst-laptop
    cloudburst-tablet
    brix0
  ];

  serverHosts = [
    cloudburst-desktop
    brix0
  ];
in {
  "secrets/cloudflare-api-token.age".publicKeys = users ++ serverHosts;
  "secrets/copyparty-accounts.age".publicKeys = users ++ serverHosts;
  "secrets/duplicati-pass.age".publicKeys = users ++ serverHosts;
  "secrets/gitea-env.age".publicKeys = users ++ serverHosts;
  "secrets/golink-tailscale-auth-key.age".publicKeys = users ++ serverHosts;
  "secrets/homarr-env.age".publicKeys = users ++ serverHosts;
  "secrets/karakeep-env.age".publicKeys = users ++ serverHosts;
  "secrets/litellm.age".publicKeys = users ++ serverHosts;
  "secrets/manyfold-env.age".publicKeys = users ++ serverHosts;
  "secrets/resume-env.age".publicKeys = users ++ serverHosts;
  "secrets/siyuan-env.age".publicKeys = users ++ serverHosts;
  "secrets/smb-secrets.age".publicKeys = users ++ allHosts;
  "secrets/vaultwarden-env.age".publicKeys = users ++ serverHosts;
  "secrets/wealthfolio-env.age".publicKeys = users ++ serverHosts;
}
