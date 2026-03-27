"""
Gateway runtime core for the Z3Gateway-native bridge.
"""

__all__ = ["main"]


def main() -> None:
    """Run the runtime entrypoint lazily."""

    from .service import main as service_main

    service_main()
