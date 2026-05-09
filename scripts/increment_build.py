#!/usr/bin/env python3
import re
import os
import subprocess

def get_flutter_path():
    # Attempt to find FLUTTER_ROOT from Generated.xcconfig
    xcconfig_path = 'ios/Flutter/Generated.xcconfig'
    if os.path.exists(xcconfig_path):
        with open(xcconfig_path, 'r') as f:
            for line in f:
                if line.startswith('FLUTTER_ROOT='):
                    return os.path.join(line.split('=')[1].strip(), 'bin')
    # Fallback to current PATH
    return None

def increment_version():
    # Make sure we are in the project root
    if not os.path.exists('pubspec.yaml'):
        print("Error: pubspec.yaml not found. Please run this script from the project root.")
        return

    with open('pubspec.yaml', 'r') as f:
        lines = f.readlines()

    new_lines = []
    found = False
    for line in lines:
        if line.startswith('version: ') and not found:
            match = re.search(r'version: (\d+\.\d+\.\d+)\+(\d+)', line)
            if match:
                base_version = match.group(1)
                build_number = int(match.group(2))
                new_build_number = build_number + 1
                new_version = f"{base_version}+{new_build_number}"
                line = f"version: {new_version}\n"
                print(f"✅ Incremented build number in pubspec.yaml: {build_number} -> {new_build_number}")
                found = True
        new_lines.append(line)

    if found:
        with open('pubspec.yaml', 'w') as f:
            f.writelines(new_lines)
        
        # After updating pubspec.yaml, we must run flutter pub get to update Generated.xcconfig
        print("⏳ Running 'flutter pub get' to sync with Xcode...")
        
        # Prepare environment with Flutter in PATH
        env = os.environ.copy()
        flutter_bin = get_flutter_path()
        if flutter_bin:
            env['PATH'] = f"{flutter_bin}:{env.get('PATH', '')}"
            
        try:
            subprocess.run(['flutter', 'pub', 'get'], check=True, capture_output=True, env=env)
            print("🚀 Switched Xcode build number successfully.")
        except subprocess.CalledProcessError as e:
            print(f"⚠️ Warning: 'flutter pub get' failed: {e.stderr.decode()}")
        except FileNotFoundError:
             print("❌ Error: 'flutter' command not found. Please ensure Flutter is installed and in your PATH.")
    else:
        print("❌ Could not find version line in pubspec.yaml.")

if __name__ == "__main__":
    increment_version()
