import sys
import os
import re
import json
import subprocess
import tempfile
import zipfile
import hashlib
import shutil
import argparse
from PyQt6.QtWidgets import (
    QApplication,
    QMainWindow,
    QListView,
    QVBoxLayout,
    QWidget,
    QLineEdit,
    QLabel,
    QStackedWidget,
)
from PyQt6.QtCore import QSize, Qt, QThread, pyqtSignal, QSortFilterProxyModel
from PyQt6.QtGui import (
    QStandardItemModel,
    QStandardItem,
    QIcon,
    QPainter,
    QColor,
    QPixmap,
)

# Cache directory
CACHE_DIR = "/tmp/scrcpy-app-cache"


def find_aapt_binary():
    import shutil
    import glob

    # 1. Check PATH
    for name in ["aapt2", "aapt"]:
        path = shutil.which(name)
        if path:
            return path

    # 2. Check current system bin
    for path in [
        "/run/current-system/sw/bin/aapt2",
        "/run/current-system/sw/bin/aapt",
    ]:
        if os.path.exists(path):
            return path

    # 3. Check Nix store via globbing
    for pattern in [
        "/nix/store/*-aapt-*/bin/aapt2",
        "/nix/store/*-aapt-*/bin/aapt",
    ]:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]

    # 4. Check Android SDK build tools in Nix store
    sdk_matches = glob.glob(
        "/nix/store/*-android-sdk-*/share/android-sdk/"
        "build-tools/*/aapt2"
    )
    if sdk_matches:
        return sdk_matches[0]

    sdk_matches_aapt = glob.glob(
        "/nix/store/*-android-sdk-*/share/android-sdk/"
        "build-tools/*/aapt"
    )
    if sdk_matches_aapt:
        return sdk_matches_aapt[0]

    return "aapt2"  # Fallback to name


def extract_best_icon(zip_file_path, icon_path_in_apk, output_png_path):
    try:
        with zipfile.ZipFile(zip_file_path) as z:
            namelist = z.namelist()

            # 1. If we have a specific icon path from badging
            if icon_path_in_apk:
                is_xml = icon_path_in_apk.endswith(".xml")
                if not is_xml and icon_path_in_apk in namelist:
                    try:
                        with open(output_png_path, "wb") as f:
                            f.write(z.read(icon_path_in_apk))
                        return True
                    except Exception:
                        pass

                # If XML or not found, try to find a raster counterpart
                base_name = os.path.basename(icon_path_in_apk).rsplit(
                    ".", 1
                )[0]

                # List of target directory qualifiers (descending resolution)
                resolutions = [
                    "xxxhdpi",
                    "xxhdpi",
                    "xhdpi",
                    "hdpi",
                    "mdpi",
                    "ldpi",
                    "anydpi",
                    "nodpi",
                    "drawable",
                ]

                # First try: Find an exact filename match in resolution dirs
                for res in resolutions:
                    for ext in [".png", ".webp", ".jpg"]:
                        for name in namelist:
                            if (
                                res in name
                                and name.endswith(f"/{base_name}{ext}")
                                and "background" not in name.lower()
                                and "foreground" not in name.lower()
                            ):
                                try:
                                    with open(output_png_path, "wb") as f:
                                        f.write(z.read(name))
                                    return True
                                except Exception:
                                    pass

                # Second try: Look for any raster file with base_name
                for res in resolutions:
                    for ext in [".png", ".webp", ".jpg"]:
                        for name in namelist:
                            if (
                                res in name
                                and base_name in os.path.basename(name)
                                and name.endswith(ext)
                                and "background" not in name.lower()
                                and "foreground" not in name.lower()
                            ):
                                try:
                                    with open(output_png_path, "wb") as f:
                                        f.write(z.read(name))
                                    return True
                                except Exception:
                                    pass

            # 2. General Fallback: Search for any launcher icon
            resolutions_simple = [
                "xxxhdpi",
                "xxhdpi",
                "xhdpi",
                "hdpi",
                "mdpi",
                "ldpi",
            ]
            for res in resolutions_simple:
                for keyword in ["ic_launcher", "launcher", "icon", "logo"]:
                    for ext in [".png", ".webp"]:
                        for name in namelist:
                            if (
                                res in name
                                and keyword in os.path.basename(name).lower()
                                and name.endswith(ext)
                                and "background" not in name.lower()
                                and "foreground" not in name.lower()
                            ):
                                try:
                                    with open(output_png_path, "wb") as f:
                                        f.write(z.read(name))
                                    return True
                                except Exception:
                                    pass

            # Last resort: just find any png in mipmap/drawable
            for name in namelist:
                is_img = name.endswith(".png")
                is_res = "mipmap" in name or "drawable" in name
                is_bg = "background" in name.lower()
                is_fg = "foreground" in name.lower()
                if is_img and is_res and not is_bg and not is_fg:
                    try:
                        with open(output_png_path, "wb") as f:
                            f.write(z.read(name))
                        return True
                    except Exception:
                        pass
    except Exception as e:
        print(f"Error extracting icon: {e}")

    return False


def get_launcher_icon(icon_path, label):
    if icon_path and os.path.exists(icon_path):
        return QIcon(icon_path)

    # Fallback: create a colorful square with the first letter of the label
    h = hashlib.md5(label.encode("utf-8")).hexdigest()
    color_hex = f"#{h[:6]}"

    icon_size = 64
    pixmap = QPixmap(icon_size, icon_size)
    pixmap.fill(QColor(color_hex))

    painter = QPainter(pixmap)
    painter.setPen(QColor("#2c3e50"))
    painter.drawRect(0, 0, icon_size - 1, icon_size - 1)

    painter.setPen(QColor("#ffffff"))
    font = painter.font()
    font.setPointSize(24)
    font.setBold(True)
    painter.setFont(font)

    letter = label[0].upper() if label else "?"
    painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, letter)
    painter.end()

    icon = QIcon()
    icon.addPixmap(pixmap)
    return icon


class DeviceMonitorThread(QThread):
    device_status_changed = pyqtSignal(
        bool, str
    )  # (is_connected, device_serial)
    apps_loaded = pyqtSignal(
        list
    )  # [{'package': ..., 'label': ..., 'icon_path': ...}]
    app_resolved = pyqtSignal(
        dict
    )  # {'package': ..., 'label': ..., 'icon_path': ...}

    def __init__(self):
        super().__init__()
        self.running = True
        self.connected = False

    def run(self):
        while self.running:
            try:
                res = subprocess.run(
                    ["adb", "get-state"],
                    capture_output=True,
                    text=True,
                    timeout=2,
                )
                state = res.stdout.strip()
                connected = state == "device"
            except Exception:
                connected = False

            if connected != self.connected:
                self.connected = connected
                serial = ""
                if connected:
                    try:
                        serial = subprocess.run(
                            ["adb", "get-serialno"],
                            capture_output=True,
                            text=True,
                        ).stdout.strip()
                    except Exception:
                        pass
                self.device_status_changed.emit(connected, serial)

                if connected:
                    self.load_apps(serial)

            self.msleep(2000)

    def load_apps(self, serial):
        try:
            # Query launchable activities
            cmd = [
                "adb",
                "shell",
                "cmd",
                "package",
                "query-activities",
                "-a",
                "android.intent.action.MAIN",
                "-c",
                "android.intent.category.LAUNCHER",
            ]
            res = subprocess.run(
                cmd, capture_output=True, text=True, timeout=5
            )
            output = res.stdout
        except Exception as e:
            print(f"Error querying activities: {e}")
            return

        packages = []
        for block in output.split("Activity #")[1:]:
            pkg_match = re.search(r"packageName=([a-zA-Z0-9_.]+)", block)
            if not pkg_match:
                pkg_match = re.search(
                    r"packageName:\s*([a-zA-Z0-9_.]+)", block
                )
            if pkg_match:
                packages.append(pkg_match.group(1))

        packages = list(dict.fromkeys(packages))
        if not packages:
            return

        # Scope cache per device
        safe_serial = "".join(
            c for c in serial if c.isalnum() or c in ("-", "_")
        )
        if not safe_serial:
            safe_serial = "default"

        device_cache_dir = os.path.join(CACHE_DIR, safe_serial)
        os.makedirs(device_cache_dir, exist_ok=True)
        cache_file = os.path.join(device_cache_dir, "apps.json")

        cache = {}
        if os.path.exists(cache_file):
            try:
                with open(cache_file, "r") as f:
                    cache = json.load(f)
            except Exception:
                pass

        new_cache = {}
        cached_active_apps = []
        packages_to_fetch = []

        for pkg in packages:
            if pkg in cache:
                cached_info = cache[pkg]
                icon_path = cached_info.get("icon")
                if (
                    not icon_path
                    or os.path.exists(icon_path)
                    or icon_path == ""
                ):
                    cached_active_apps.append(
                        {
                            "package": pkg,
                            "label": cached_info.get("label", pkg),
                            "icon_path": icon_path,
                        }
                    )
                    new_cache[pkg] = cached_info
                    continue
            packages_to_fetch.append(pkg)

        if cached_active_apps:
            self.apps_loaded.emit(cached_active_apps)

        # For remaining packages, fetch dynamically
        for pkg in packages_to_fetch:
            if not self.connected or not self.running:
                break

            info = self.fetch_app_details(pkg, device_cache_dir)
            if info:
                new_cache[pkg] = info
                self.app_resolved.emit(
                    {
                        "package": pkg,
                        "label": info["label"],
                        "icon_path": info["icon"],
                    }
                )
            else:
                # Fallback: deduce name from package
                label_parts = pkg.split(".")
                label = label_parts[-1].capitalize()
                is_generic = label.lower() in (
                    "android",
                    "google",
                    "app",
                    "application",
                )
                if is_generic and len(label_parts) > 1:
                    label = label_parts[-2].capitalize()

                fallback_info = {
                    "label": label,
                    "icon": "",
                    "apk_path": "",
                }
                new_cache[pkg] = fallback_info
                self.app_resolved.emit(
                    {
                        "package": pkg,
                        "label": fallback_info["label"],
                        "icon_path": "",
                    }
                )

        # Write updated cache
        try:
            with open(cache_file, "w") as f:
                json.dump(new_cache, f, indent=2)
        except Exception as e:
            print(f"Error saving cache: {e}")

    def fetch_app_details(self, package_name, device_cache_dir):
        try:
            # 1. Get APK path on the device
            path_cmd = ["adb", "shell", "pm", "path", package_name]
            res = subprocess.run(
                path_cmd, capture_output=True, text=True, timeout=3
            )
            path_output = res.stdout.strip()
            if not path_output.startswith("package:"):
                return None
            apk_path = path_output.replace("package:", "").strip()

            # 2. Pull the APK to a temp file
            with tempfile.NamedTemporaryFile(
                suffix=".apk", delete=False
            ) as temp_file:
                temp_apk_path = temp_file.name

            try:
                pull_cmd = ["adb", "pull", apk_path, temp_apk_path]
                pull_res = subprocess.run(
                    pull_cmd, capture_output=True, timeout=15
                )
                if pull_res.returncode != 0:
                    return None

                # 3. Dump badging using aapt/aapt2
                aapt_bin = find_aapt_binary()
                badging_cmd = [aapt_bin, "dump", "badging", temp_apk_path]
                badging_res = subprocess.run(
                    badging_cmd, capture_output=True, text=True, timeout=5
                )
                badging = badging_res.stdout

                # Parse app label
                label_match = re.search(
                    r"application-label[:=]'([^']*)'", badging
                )
                if not label_match:
                    label_match = re.search(
                        r"application-label-\w+[:=]'([^']*)'", badging
                    )
                label = (
                    label_match.group(1)
                    if label_match
                    else package_name.split(".")[-1].capitalize()
                )

                # Parse app icon
                icon_matches = re.findall(
                    r"application-icon-\d+[:=]'([^']*)'", badging
                )
                if not icon_matches:
                    icon_matches = re.findall(
                        r"application-icon[:=]'([^']*)'", badging
                    )

                icon_path_in_apk = icon_matches[-1] if icon_matches else None
                cached_icon_path = os.path.join(
                    device_cache_dir, f"{package_name}.png"
                )

                # Extract best icon using robust logic
                success = extract_best_icon(
                    temp_apk_path, icon_path_in_apk, cached_icon_path
                )
                if not success:
                    cached_icon_path = ""

                return {
                    "label": label,
                    "icon": cached_icon_path,
                    "apk_path": apk_path,
                }
            finally:
                if os.path.exists(temp_apk_path):
                    os.remove(temp_apk_path)
        except Exception as e:
            print(f"Error fetching app details for {package_name}: {e}")
            return None


class LauncherApp(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("Scrcpy App Launcher")
        self.resize(720, 520)
        self.setMinimumWidth(650)

        self.stacked_widget = QStackedWidget()
        self.setCentralWidget(self.stacked_widget)

        # 1. Connection Waiting Screen
        self.conn_widget = QWidget()
        conn_layout = QVBoxLayout(self.conn_widget)
        conn_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.conn_title = QLabel("🔌 Waiting for Android Device...")
        self.conn_title.setStyleSheet(
            "font-size: 20px; font-weight: bold;"
        )
        self.conn_title.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.conn_subtitle = QLabel(
            "Connect your device via USB or network, and make sure "
            "USB debugging is enabled."
        )
        self.conn_subtitle.setStyleSheet(
            "font-size: 13px; margin-top: 10px;"
        )
        self.conn_subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)

        conn_layout.addWidget(self.conn_title)
        conn_layout.addWidget(self.conn_subtitle)
        self.stacked_widget.addWidget(self.conn_widget)

        # 2. Main Launcher Screen
        self.launcher_widget = QWidget()
        launcher_layout = QVBoxLayout(self.launcher_widget)
        launcher_layout.setContentsMargins(15, 15, 15, 15)
        launcher_layout.setSpacing(10)

        self.search_bar = QLineEdit()
        self.search_bar.setPlaceholderText(
            "🔍 Search apps by name or package..."
        )
        self.search_bar.setStyleSheet(
            """
            QLineEdit {
                border-radius: 6px;
                padding: 8px 14px;
                font-size: 14px;
            }
        """
        )
        launcher_layout.addWidget(self.search_bar)

        self.list_view = QListView()
        self.list_view.setViewMode(QListView.ViewMode.IconMode)
        self.list_view.setResizeMode(QListView.ResizeMode.Adjust)
        self.list_view.setMovement(QListView.Movement.Static)
        self.list_view.setSpacing(15)
        self.list_view.setIconSize(QSize(64, 64))
        self.list_view.setGridSize(QSize(100, 110))
        launcher_layout.addWidget(self.list_view)

        self.status_bar = QLabel("Disconnected")
        self.status_bar.setStyleSheet(
            "color: #7f8c8d; font-size: 11px; padding: 4px;"
        )
        launcher_layout.addWidget(self.status_bar)

        self.stacked_widget.addWidget(self.launcher_widget)

        # Data Model and Proxy Model
        self.model = QStandardItemModel()
        self.proxy_model = QSortFilterProxyModel()
        self.proxy_model.setSourceModel(self.model)
        self.proxy_model.setSortCaseSensitivity(
            Qt.CaseSensitivity.CaseInsensitive
        )
        self.proxy_model.setFilterCaseSensitivity(
            Qt.CaseSensitivity.CaseInsensitive
        )
        self.proxy_model.setFilterKeyColumn(0)

        # Search filter mapping
        self.search_bar.textChanged.connect(
            self.proxy_model.setFilterFixedString
        )

        self.list_view.setModel(self.proxy_model)
        self.list_view.clicked.connect(self.on_item_clicked)

        # Track existing packages in UI
        self.displayed_packages = {}

        # Start background monitor thread
        self.monitor_thread = DeviceMonitorThread()
        self.monitor_thread.device_status_changed.connect(
            self.on_device_status_changed
        )
        self.monitor_thread.apps_loaded.connect(self.on_apps_loaded)
        self.monitor_thread.app_resolved.connect(self.on_app_resolved)
        self.monitor_thread.start()

    def on_device_status_changed(self, connected, serial):
        if connected:
            self.stacked_widget.setCurrentIndex(1)
            self.status_bar.setText(
                f"Connected: Device ({serial})"
                if serial
                else "Connected: Device"
            )
        else:
            self.stacked_widget.setCurrentIndex(0)
            self.status_bar.setText("Disconnected")
            self.model.clear()
            self.displayed_packages.clear()

    def add_or_update_app_item(self, package, label, icon_path):
        icon = get_launcher_icon(icon_path, label)

        if package in self.displayed_packages:
            # Update existing item
            item = self.displayed_packages[package]
            item.setText(label)
            item.setIcon(icon)
        else:
            # Create new item
            item = QStandardItem(icon, label)
            item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            item.setFlags(
                Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsSelectable
            )
            item.setData(package, Qt.ItemDataRole.UserRole)
            self.model.appendRow(item)
            self.displayed_packages[package] = item

        # Keep sorted alphabetically
        self.proxy_model.sort(0, Qt.SortOrder.AscendingOrder)

    def on_apps_loaded(self, apps_list):
        for app in apps_list:
            self.add_or_update_app_item(
                app["package"], app["label"], app["icon_path"]
            )

    def on_app_resolved(self, app):
        self.add_or_update_app_item(
            app["package"], app["label"], app["icon_path"]
        )

    def on_item_clicked(self, index):
        source_index = self.proxy_model.mapToSource(index)
        item = self.model.itemFromIndex(source_index)
        package_name = item.data(Qt.ItemDataRole.UserRole)

        print(f"Launching {package_name} via scrcpy...")
        cmd = [
            "scrcpy",
            "--new-display",
            "--flex-display",
            "--no-vd-system-decorations",
            f"--start-app={package_name}",
            "--keep-active",
        ]
        try:
            subprocess.Popen(cmd)
        except Exception as e:
            print(f"Error launching scrcpy: {e}")

    def closeEvent(self, event):
        self.monitor_thread.running = False
        self.monitor_thread.wait()
        super().closeEvent(event)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scrcpy App Launcher")
    parser.add_argument(
        "--clean-cache",
        "-c",
        action="store_true",
        help="Clean the cache for the connected device",
    )
    cli_args, _ = parser.parse_known_args()

    if cli_args.clean_cache:
        try:
            res = subprocess.run(
                ["adb", "get-state"],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if res.stdout.strip() == "device":
                serial = subprocess.run(
                    ["adb", "get-serialno"],
                    capture_output=True,
                    text=True,
                ).stdout.strip()
                safe_serial = "".join(
                    c for c in serial if c.isalnum() or c in ("-", "_")
                )
                if safe_serial:
                    device_dir = os.path.join(CACHE_DIR, safe_serial)
                    if os.path.exists(device_dir):
                        shutil.rmtree(device_dir)
                        print(f"Cleared cache directory: {device_dir}")
                    else:
                        print(f"No cache found for device: {serial}")
            else:
                print("No active ADB device detected. Cannot clear cache.")
        except Exception as e:
            print(f"Error cleaning cache: {e}")

    app = QApplication(sys.argv)

    if "breeze" in QIcon.themeSearchPaths():
        QIcon.setThemeName("breeze")

    window = LauncherApp()
    window.show()
    sys.exit(app.exec())
