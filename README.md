# vcpkg-repository

A private [vcpkg](https://learn.microsoft.com/vcpkg) Git registry.

Layout (per the [git-registry tutorial](https://learn.microsoft.com/en-us/vcpkg/produce/publish-to-a-git-registry)):

- `ports/` — the registry's ports, one directory per port.
- `versions/` — the versions database (`baseline.json` + per-port version files).

## Ports

| Port | Version | Upstream |
| ---- | ------- | -------- |
| `dxvk` | 3.0 | [LibreSAGE/dxvk](https://github.com/LibreSAGE/dxvk) |

## Consuming this registry

In the project that wants to use these ports, add a `vcpkg-configuration.json`
next to your `vcpkg.json`:

```json
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "<a vcpkg builtin baseline commit>"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "https://example.com/<this-repo>.git",
      "baseline": "<latest commit SHA of this repository>",
      "packages": [ "dxvk" ]
    }
  ]
}
```

Then declare the dependency in your `vcpkg.json`:

```json
{
  "dependencies": [ "dxvk" ]
}
```

## Maintaining the registry

After adding or changing a port, regenerate the versions database and commit:

```console
vcpkg --x-builtin-ports-root=./ports --x-builtin-registry-versions-dir=./versions x-add-version --all --verbose
git add .
git commit -m "Update versions database"
```
