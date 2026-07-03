#!/usr/bin/env python3
import os
import subprocess
import glob

# App Store Screenshot Dimensions
# 6.5" (iPhone 14 Plus, 13 Pro Max, etc.): 1284 x 2778
# 5.5" (iPhone 8 Plus, 7 Plus, etc.): 1242 x 2208

SIZES = {
    "6.5-inch": (1284, 2778),
    "5.5-inch": (1242, 2208)
}

def resize_screenshots():
    # Make sure we are in the project root
    if not os.path.exists('pubspec.yaml'):
        print("Error: Please run this script from the project root.")
        return

    raw_dir = "screenshots/raw"
    if not os.path.exists(raw_dir):
        os.makedirs(raw_dir, exist_ok=True)
        print(f"📁 Created {raw_dir}. Please place your high-res screenshots there.")
        return

    screenshots = glob.glob(os.path.join(raw_dir, "*.png"))
    if not screenshots:
        print(f"⚠️ No PNG files found in {raw_dir}. Please add some screenshots first.")
        return

    print(f"🚀 Found {len(screenshots)} screenshots in {raw_dir}. Processing...")

    for size_name, (width, height) in SIZES.items():
        output_dir = os.path.join("screenshots", size_name)
        os.makedirs(output_dir, exist_ok=True)
        
        for shot in screenshots:
            filename = os.path.basename(shot)
            dest = os.path.join(output_dir, filename)
            
            # Using macOS 'sips' (Scriptable Image Processing System)
            # sips -z <height> <width> <source> --out <destination>
            try:
                subprocess.run([
                    "sips", 
                    "-z", str(height), str(width), 
                    shot, 
                    "--out", dest
                ], check=True, capture_output=True)
                print(f"✅ Generated {size_name}: {filename}")
            except subprocess.CalledProcessError as e:
                print(f"❌ Failed to resize {filename} to {size_name}: {e.stderr.decode()}")

    print("\n✨ Done! Your resized screenshots are in the 'screenshots/' folder.")

if __name__ == "__main__":
    resize_screenshots()
