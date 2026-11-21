"""Regenerate the original STRSK app icon variants and in-app mark."""

from pathlib import Path
import subprocess
import sys


script = Path(__file__).with_name("generate_strsk_icon.py")
subprocess.run([sys.executable, str(script)], check=True)
