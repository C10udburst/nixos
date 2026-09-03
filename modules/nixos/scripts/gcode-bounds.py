import math
import re
import sys


class GCodeSimulator:

    def __init__(self):
        # Current position for X, Y, Z
        self.current_pos = {"X": None, "Y": None, "Z": None}

        # Bounding box limits
        self.min_bounds = {"X": None, "Y": None, "Z": None}
        self.max_bounds = {"X": None, "Y": None, "Z": None}

        # Interpreter modes
        self.pos_mode = "ABSOLUTE"  # 'ABSOLUTE' (G90) or 'RELATIVE' (G91)
        self.arc_mode = "RELATIVE"  # 'RELATIVE' (G91.1) or 'ABSOLUTE' (G90.1)
        self.plane = "XY"  # 'XY' (G17), 'XZ' (G18), 'YZ' (G19)
        self.unit_scale = 1.0  # 1.0 for mm (G21), 25.4 for inches (G20)
        self.active_motion = None  # 0 (G0), 1 (G1), 2 (G2), 3 (G3)

        self.word_regex = re.compile(
            r"([A-Z])\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)"
        )

    def _update_bound(self, axis, val):
        if val is None:
            return
        if self.min_bounds[axis] is None or val < self.min_bounds[axis]:
            self.min_bounds[axis] = val
        if self.max_bounds[axis] is None or val > self.max_bounds[axis]:
            self.max_bounds[axis] = val

    def _clean_line(self, line):
        # Remove semicolon comments
        line = line.split(";")[0]
        # Remove parenthesized comments (...)
        line = re.sub(r"\(.*?\)", "", line)
        # Strip whitespace and convert to upper
        line = line.strip().upper()
        # Remove leading block delete character '/'
        if line.startswith("/"):
            line = line[1:].strip()
        return line

    def parse_file(self, file_path):
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                self.parse_line(line)

    def parse_line(self, raw_line):
        line = self._clean_line(raw_line)
        if not line:
            return

        matches = self.word_regex.findall(line)
        if not matches:
            return

        words = {}
        g_codes = []

        for letter, num_str in matches:
            val = float(num_str)
            if letter == "G":
                g_codes.append(val)
            else:
                words[letter] = val

        line_motion = None
        is_g92 = False
        is_g28 = False

        for g in g_codes:
            g_int = int(round(g)) if abs(g - round(g)) < 1e-5 else None

            if g_int == 90 and abs(g - 90.0) < 1e-5:
                self.pos_mode = "ABSOLUTE"
            elif g_int == 91 and abs(g - 91.0) < 1e-5:
                self.pos_mode = "RELATIVE"
            elif abs(g - 90.1) < 1e-5:
                self.arc_mode = "ABSOLUTE"
            elif abs(g - 91.1) < 1e-5:
                self.arc_mode = "RELATIVE"
            elif g_int == 17:
                self.plane = "XY"
            elif g_int == 18:
                self.plane = "XZ"
            elif g_int == 19:
                self.plane = "YZ"
            elif g_int == 20:
                self.unit_scale = 25.4
            elif g_int == 21:
                self.unit_scale = 1.0
            elif g_int == 0:
                line_motion = 0
                self.active_motion = 0
            elif g_int == 1:
                line_motion = 1
                self.active_motion = 1
            elif g_int == 2:
                line_motion = 2
                self.active_motion = 2
            elif g_int == 3:
                line_motion = 3
                self.active_motion = 3
            elif g_int == 92:
                is_g92 = True
            elif g_int == 28:
                is_g28 = True

        # G92: Coordinate position override
        if is_g92:
            for axis in ("X", "Y", "Z"):
                if axis in words:
                    self.current_pos[axis] = words[axis] * self.unit_scale
            return

        # G28: Return to home
        if is_g28:
            axes_to_home = [a for a in ("X", "Y", "Z") if a in words]
            if not axes_to_home:
                axes_to_home = ["X", "Y", "Z"]
            for axis in axes_to_home:
                self.current_pos[axis] = 0.0
                self._update_bound(axis, 0.0)
            return

        # Infer modal motion if axis words exist without explicit G motion
        # command
        if line_motion is None:
            if any(axis in words for axis in ("X", "Y", "Z")):
                line_motion = (
                    self.active_motion
                    if self.active_motion is not None
                    else 1
                )

        if line_motion is None:
            return

        if line_motion in (0, 1):
            self._do_linear_move(words)
        elif line_motion in (2, 3):
            self._do_arc_move(line_motion, words)

    def _do_linear_move(self, words):
        has_axis_param = False
        target = {}

        for axis in ("X", "Y", "Z"):
            if axis in words:
                has_axis_param = True
                val = words[axis] * self.unit_scale
                if self.pos_mode == "ABSOLUTE":
                    target[axis] = val
                else:
                    start_val = (
                        self.current_pos[axis]
                        if self.current_pos[axis] is not None
                        else 0.0
                    )
                    target[axis] = start_val + val
            else:
                target[axis] = self.current_pos[axis]

        if not has_axis_param:
            return

        for axis in ("X", "Y", "Z"):
            if target[axis] is not None:
                if self.current_pos[axis] is not None:
                    self._update_bound(axis, self.current_pos[axis])
                self.current_pos[axis] = target[axis]
                self._update_bound(axis, target[axis])

    def _do_arc_move(self, motion_type, words):
        if self.plane == "XY":
            u_name, v_name, w_name = "X", "Y", "Z"
            u_off_name, v_off_name = "I", "J"
        elif self.plane == "XZ":
            u_name, v_name, w_name = "Z", "X", "Y"
            u_off_name, v_off_name = "K", "I"
        else:  # YZ
            u_name, v_name, w_name = "Y", "Z", "X"
            u_off_name, v_off_name = "J", "K"

        u_has = (self.current_pos[u_name] is not None) or (u_name in words)
        v_has = (self.current_pos[v_name] is not None) or (v_name in words)
        w_has = (self.current_pos[w_name] is not None) or (w_name in words)

        u0 = (
            self.current_pos[u_name]
            if self.current_pos[u_name] is not None
            else 0.0
        )
        v0 = (
            self.current_pos[v_name]
            if self.current_pos[v_name] is not None
            else 0.0
        )
        w0 = (
            self.current_pos[w_name]
            if self.current_pos[w_name] is not None
            else 0.0
        )

        if u_name in words:
            val = words[u_name] * self.unit_scale
            u1 = val if self.pos_mode == "ABSOLUTE" else u0 + val
        else:
            u1 = u0

        if v_name in words:
            val = words[v_name] * self.unit_scale
            v1 = val if self.pos_mode == "ABSOLUTE" else v0 + val
        else:
            v1 = v0

        if w_name in words:
            val = words[w_name] * self.unit_scale
            w1 = val if self.pos_mode == "ABSOLUTE" else w0 + val
        else:
            w1 = w0

        has_offsets = (u_off_name in words) or (v_off_name in words)

        if has_offsets:
            off_u = words.get(u_off_name, 0.0) * self.unit_scale
            off_v = words.get(v_off_name, 0.0) * self.unit_scale
            if self.arc_mode == "ABSOLUTE":
                Cu = off_u
                Cv = off_v
            else:
                Cu = u0 + off_u
                Cv = v0 + off_v
            R = math.hypot(u0 - Cu, v0 - Cv)
        elif "R" in words:
            r_val = words["R"] * self.unit_scale
            r_abs = abs(r_val)
            du = u1 - u0
            dv = v1 - v0
            d = math.hypot(du, dv)
            if d < 1e-9:
                Cu, Cv, R = u0, v0, 0.0
            else:
                if r_abs < d / 2.0:
                    r_abs = d / 2.0
                h = math.sqrt(max(0.0, r_abs**2 - (d / 2.0) ** 2))
                Mu = (u0 + u1) / 2.0
                Mv = (v0 + v1) / 2.0
                u_dir = du / d
                v_dir = dv / d

                if motion_type == 2:  # G2 CW
                    if r_val > 0:
                        Cu = Mu + v_dir * h
                        Cv = Mv - u_dir * h
                    else:
                        Cu = Mu - v_dir * h
                        Cv = Mv + u_dir * h
                else:  # G3 CCW
                    if r_val > 0:
                        Cu = Mu - v_dir * h
                        Cv = Mv + u_dir * h
                    else:
                        Cu = Mu + v_dir * h
                        Cv = Mv - u_dir * h
                R = r_abs
        else:
            self._do_linear_move(words)
            return

        if u_has:
            self._update_bound(u_name, u0)
            self._update_bound(u_name, u1)
            self.current_pos[u_name] = u1

        if v_has:
            self._update_bound(v_name, v0)
            self._update_bound(v_name, v1)
            self.current_pos[v_name] = v1

        if w_has:
            self._update_bound(w_name, w0)
            self._update_bound(w_name, w1)
            self.current_pos[w_name] = w1

        if R > 1e-9:
            has_uv_params = (u_name in words) or (v_name in words)
            dist_uv = math.hypot(u1 - u0, v1 - v0)
            is_full_circle = has_offsets and (
                not has_uv_params or dist_uv < 1e-6
            )

            tau = 2 * math.pi
            theta0 = math.atan2(v0 - Cv, u0 - Cu) % tau
            theta1 = math.atan2(v1 - Cv, u1 - Cu) % tau

            if is_full_circle:
                sweep = tau
            else:
                if motion_type == 3:  # G3 CCW
                    sweep = (theta1 - theta0) % tau
                else:  # G2 CW
                    sweep = (theta0 - theta1) % tau
                if sweep < 1e-12:
                    sweep = 0.0

            cardinals = [
                0.0,
                math.pi / 2.0,
                math.pi,
                3.0 * math.pi / 2.0,
            ]
            for phi in cardinals:
                if is_full_circle:
                    in_arc = True
                else:
                    if motion_type == 3:  # G3 CCW
                        delta = (phi - theta0) % tau
                    else:  # G2 CW
                        delta = (theta0 - phi) % tau
                    in_arc = delta <= sweep + 1e-9

                if in_arc:
                    card_u = Cu + R * math.cos(phi)
                    card_v = Cv + R * math.sin(phi)
                    if u_has:
                        self._update_bound(u_name, card_u)
                    if v_has:
                        self._update_bound(v_name, card_v)


def parse_gcode_bounds(file_path):
    sim = GCodeSimulator()
    sim.parse_file(file_path)

    if (
        sim.min_bounds["X"] is None
        and sim.min_bounds["Y"] is None
        and sim.min_bounds["Z"] is None
    ):
        print("Error: No XYZ coordinates found in the file.")
        return

    print(f"File: {file_path}")
    for axis in ("X", "Y", "Z"):
        min_v = sim.min_bounds[axis]
        max_v = sim.max_bounds[axis]
        if min_v is None or max_v is None:
            print(f"{axis} Range: Min = N/A, Max = N/A")
        else:
            min_str = round(min_v, 4)
            max_str = round(max_v, 4)
            print(f"{axis} Range: Min = {min_str}, Max = {max_str}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: gcode-bounds <path_to_file.gcode> [file2.gcode ...]")
        sys.exit(1)

    for gcode_file in sys.argv[1:]:
        try:
            parse_gcode_bounds(gcode_file)
        except FileNotFoundError:
            print(f"Error: File '{gcode_file}' not found. Check the path.")
            sys.exit(1)
