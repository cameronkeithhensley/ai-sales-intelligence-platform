"""Data-source adapters.

The production harvester ships with a set of adapters that fetch signal
data from external APIs (property, person, OSINT, reviews, ...). Those
implementations and the provider registry they populate are proprietary
and live in the private repo. This public repository ships only the
protocol interface and an empty registry so reviewers can see the
extension shape.
"""

from __future__ import annotations

from typing import Any, Protocol, runtime_checkable


@runtime_checkable
class DataAdapter(Protocol):
    """Contract every adapter implements."""

    name: str
    tenant_types: frozenset[str]

    def fetch(self, subject: dict[str, Any]) -> dict[str, Any]:
        """Retrieve a result for the given subject. Must be idempotent."""
        ...


# Registry is populated at runtime by the private plugin loader. The
# public repo ships it empty on purpose — registering an adapter here
# would either leak information about which providers the platform
# uses, or require shipping a placeholder implementation that wasn't
# useful to anyone. Leave empty and let resolve() raise on lookup.
REGISTRY: dict[str, DataAdapter] = {}


def register(adapter: DataAdapter) -> None:
    """Programmatic adapter registration hook. Used by the private
    plugin loader at startup; exposed on the public surface so tests
    can register mock adapters."""

    REGISTRY[adapter.name] = adapter


def unregister(name: str) -> None:
    REGISTRY.pop(name, None)


def resolve(name: str) -> DataAdapter:
    adapter = REGISTRY.get(name)
    if adapter is None:
        raise KeyError(
            f"No adapter registered under {name!r}. "
            "Adapter implementations are proprietary and not included "
            "in this repository."
        )
    return adapter
