"""
Gateway package for the Z3Gateway-native bridge runtime.
"""

__all__ = ["main"]
__version__ = "2.0.0"


def main() -> None:
    """Run the gateway CLI without importing runtime dependencies at package import time."""

    from .src.service import main as service_main

    service_main()
