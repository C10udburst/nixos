{pkgs}: let
  homarrIcon = name: hash:
    pkgs.fetchurl {
      url = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/${name}.png";
      sha256 = hash;
    };

  googleFavicon = domain: hash:
    pkgs.fetchurl {
      url = "https://www.google.com/s2/favicons?domain=${domain}&sz=128";
      sha256 = hash;
    };
in {
  inherit homarrIcon googleFavicon;

  # Self-hosted / custom services
  wealthfolio = pkgs.fetchurl {
    url = "https://assets.wealthfolio.app/images/logo.png";
    sha256 = "sha256-zD8vc3P1ubXoq2j/hXKQaIgKCcq+COWy0tPUyzDj2+A=";
  };
  immich = homarrIcon "immich" "sha256-OrUuw7FDkvUsS/x3vwDO91awJHu1cD96RDfzrPF/LJk=";
  home-assistant = homarrIcon "home-assistant" "sha256-ZYb/8I1bW1sRHSExFFocAJ1fqTaUB4kTM4jwI0hSzb4=";
  siyuan = pkgs.fetchurl {
    url = "https://github.com/siyuan-note.png";
    sha256 = "sha256-cUd2IJfRsT/79FOT85jhVnNl+iYtOml1UyaTZ9SMyIs=";
  };
  karakeep = homarrIcon "karakeep" "sha256-uuUYA0mIV1jiM/gvnrxMlVmru6oMNzw8fJW+gZ3rRvk=";

  # Google suite & productivity
  google-docs = homarrIcon "google-docs" "sha256-xN2P2nOW4RCbHc4V6V7SnmDIvxwGGL8SmfEFkY1Z1Ew=";
  google-sheets = homarrIcon "google-sheets" "sha256-DjrmjwLQ6HCugGcGgiKspNBgTT3eQSy2OIbJ8rxOGWg=";
  google-slides = homarrIcon "google-slides" "sha256-eulmf16X/PlRDKzJn7m4tY4j2J0MjIz3BETfWKiKiv0=";
  google-forms = homarrIcon "google-forms" "sha256-/HCVpV7j4DO9zMh2g5kZ/4EY6INny9yI9pHvKZm3hGs=";
  gmail = homarrIcon "gmail" "sha256-ABl4wWJ83y83cRNIKs4fqTNmNQiWaWbGfukVNxlnGdE=";

  # Messengers & socials
  whatsapp = homarrIcon "whatsapp" "sha256-onbgRNXmys5zyMdvIGUMbIic6k5Jrc1s7/8d2c9O4Pw=";
  telegram = homarrIcon "telegram" "sha256-jGUwFMoV6/1veq00R2TW+I0U4Yt/mZUGVVVUPtW4h/M=";
  discord = homarrIcon "discord" "sha256-E64iFdxU7URnyr2ttS4g5V1bvhVK60StTK3crzNZd0w=";
  messenger = googleFavicon "messenger.com" "sha256-vKK7vKsrzLgV4dBwXvEAPky+Ez/UIbka0VmcFrnYezs=";
  fetlife = googleFavicon "fetlife.com" "sha256-tXO3bqN7mPgep/ffqT5rVb69cnFCq74WJ/J3AU7plZ4=";

  # Dev & Tools
  vscode = homarrIcon "visual-studio-code" "sha256-SUSwDA+8SJ3nIe910Ci0z5LV28y5mbsAzTBws9A7NHs=";
  gridfinity = googleFavicon "https://gridfinity-cutout.pages.dev" "sha256-7vApHTv8kb4FgUJQ4PfSt3vmvRU102rcnpQseH3yG1k=";
}
