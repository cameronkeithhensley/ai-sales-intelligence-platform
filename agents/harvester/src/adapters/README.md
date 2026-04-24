# agents/harvester/src/adapters

The harvester's data-source adapters are proprietary and do not ship
in this public repository. This directory exists so reviewers can see
the extension shape without the implementations: the `DataAdapter`
Protocol in [`__init__.py`](./__init__.py), an empty `REGISTRY` dict,
and `register` / `resolve` / `unregister` helpers.

In the production build, a plugin loader discovers per-provider
adapter modules at startup and populates `REGISTRY`. Each adapter
declares a stable `name`, the set of `tenant_types` it applies to,
and a `fetch(subject)` method whose result is idempotent with
respect to the subject. Everything else — the adapter list itself,
the providers, the response shapes, the normalisation rules — lives
in the private repo.

The public harvester's processor calls `resolve(name)` and gets a
`KeyError` because the registry is empty. That path is deliberate:
jobs land in `public.jobs` with `status = failed`, and the failure
reason makes it clear that adapters are proprietary. Tests register
a stub adapter to cover the success path.
