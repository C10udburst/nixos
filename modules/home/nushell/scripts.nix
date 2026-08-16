{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.nushell;

  plotScript = pkgs.writeText "plot.py" (builtins.readFile ./plot.py);
  pdScript = pkgs.writeText "pd.py" (builtins.readFile ./pd.py);
  gridviewScript = pkgs.writeText "gridview.py" (builtins.readFile ./gridview.py);
in {
  config = lib.mkIf cfg.enable {
    programs.nushell.extraConfig = ''
      def gridview [] {
        let input = $in
        if ($input | is-empty) { return }

        $input | to json | python3 ${gridviewScript}
      }

      def plot [
        col_x: any,
        col_y?: any
      ] {
        let data = $in
        let x_label = if ($col_x | describe) == "closure" { "x" } else { $col_x }
        let x_vals = if ($col_x | describe) == "closure" {
          $data | each { |row| $row | do $col_x }
        } else {
          $data | get $col_x
        }
        if $col_y == null {
          $x_vals | wrap $x_label | to json | python3 ${plotScript} $x_label
        } else {
          let y_label = if ($col_y | describe) == "closure" { "y" } else { $col_y }
          let y_vals = if ($col_y | describe) == "closure" {
            $data | each { |row| $row | do $col_y }
          } else {
            $data | get $col_y
          }
          $x_vals | wrap $x_label | merge ($y_vals | wrap $y_label) | to json | python3 ${plotScript} $x_label $y_label
        }
      }

      # Run a pandas transformation on the piped table.
      # `df` (DataFrame) and `pd` (pandas module) are pre-bound.
      # Mutate `df` in-place or assign to `result` for the output value.
      # Use --columns (-c) to select specific columns from the resulting DataFrame.
      #
      # Examples:
      #   ps | pd "df['mb'] = df.mem / 1024**2"
      #   open data.csv | pd "df = df.groupby('host').sum().reset_index()" --columns [host bytes]
      #   open data.csv | pd "result = df.describe()"
      def pd [
        script: string,
        --columns (-c): list<string> = []
      ] {
        let data = $in
        if ($columns | is-empty) {
          $data | to json | python3 ${pdScript} $script | from json
        } else {
          $data | to json | python3 ${pdScript} $script ...$columns | from json
        }
      }
    '';
  };
}
