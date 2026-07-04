# Releasing semsys (and registering with risset)

risset distributes **binaries**, not source: it downloads a per-platform binary from
a URL — here, a GitHub release asset of this repo — and reads `risset.json` from the
repo root. So a release is: build the binaries, zip them with the exact names in
`risset.json`, upload them to a `v<version>` GitHub release, then add this repo to the
risset index.

## 1. Version

`risset.json` `version` and the git tag must agree. `risset.json` release URLs use
`v${version}` (e.g. version `1.0.0` → tag `v1.0.0`).

## 2. Build the binaries

Each `risset.json` binary entry names a zip and the file inside it (`extractpath`):

| platform            | zip                                   | extractpath      |
|---------------------|---------------------------------------|------------------|
| linux-x86_64        | `semsys-csound7-linux.zip`            | `libsemsys.so`   |
| windows-x86_64      | `semsys-csound7-windows.zip`          | `semsys.dll`     |
| macos-x86_64/arm64  | `semsys-csound7-macos-universal.zip`  | `libsemsys.dylib`|

Two ways to produce them:

### Automated (GitHub Actions)

Push a `v*` tag. `.github/workflows/release.yml` builds all three platforms (cloning
the Csound source only for its headers) and uploads the zips to the release. Pin
`CSOUND_REF` in that workflow to a Csound 7 tag for reproducibility.

### Manual (per platform)

On each OS, with the Csound plugin SDK headers available:

```sh
CSOUND_INCLUDE_DIR=/path/to/csound/include ./scripts/package.sh
```

This writes `dist/semsys-csound7-<os>.zip`. On macOS it builds a universal
(arm64 + x86_64) binary. See the README **Building** section for the header/ONNX notes.

## 3. Create the GitHub release

```sh
git tag v1.0.0 && git push origin v1.0.0
gh release create v1.0.0 dist/semsys-csound7-*.zip \
  --title "semsys 1.0.0" --notes "Initial release."
```

(The Actions workflow attaches the zips automatically if the release already exists;
otherwise upload them with `gh release create`/`gh release upload`.)

## 4. Verify the manifest URLs resolve

Every `risset.json` URL must be a real, public asset — no `.git` in the path:

```sh
grep -o 'https://[^"]*' risset.json | sed 's/\${version}/1.0.0/' | \
  while read u; do echo "$u"; curl -sIL -o /dev/null -w '  %{http_code}\n' "$u"; done
```

## 5. Register with risset

Open a PR against
[`csound-plugins/risset-data`](https://github.com/csound-plugins/risset-data/blob/master/rissetindex.json)
adding this entry to the `plugins` object. No `path` — `risset.json` is at the repo root:

```json
"semsys": {
  "url": "https://github.com/PasqualeMainolfi/csound-semsys.git"
}
```

Once merged, `risset install semsys` fetches the binary for the user's platform.
