#!/usr/bin/env python3
"""Compatibility entry point; v5.453 supersedes the incomplete v5.452 race fixture."""

from pathlib import Path
import runpy


runpy.run_path(str(Path(__file__).with_name("test-home-carousel-453.py")), run_name="__main__")
