# Chrome Web Store Update/Submit Script

Use `scripts/cws-update-submit.mjs` for a narrow Chrome Web Store maintenance path:

- update an already known CWS field, currently the privacy policy URL
- save the existing draft
- optionally submit the saved draft for review

This script intentionally does **not** build the extension, deploy the website, generate store assets, upload a zip, or edit Firefox/Edge listings.

## When to Use

- Chrome Web Store rejected an item because a metadata field is wrong, such as a privacy policy URL
- the corrected target URL or value already exists and is reachable
- the user has explicitly authorized saving or submitting the CWS draft
- normal browser automation lacks the user's Google login cookies or is blocked by Google security checks

Do not use it for first-time store setup, asset preparation, version packaging, or multi-platform release orchestration.

## Dry Run

```bash
node scripts/cws-update-submit.mjs \
  --publisher <publisher-id> \
  --item <extension-id>
```

The script opens the CWS privacy page through a temporary Chrome profile copied from the user's real Chrome profile, then prints the current privacy URL and visible status. No field is changed without `--save`.

## Save and Submit

```bash
node scripts/cws-update-submit.mjs \
  --publisher <publisher-id> \
  --item <extension-id> \
  --privacy-url https://example.com/privacy/ \
  --save --submit
```

`--submit` requires `--save` so the submitted draft matches the requested update.

Use `--no-auto-publish` when the final review dialog should not keep auto-publish enabled.

## Hold On Example

```bash
node scripts/cws-update-submit.mjs \
  --publisher b94d7c34-ac9c-4853-80c7-a109eda5c998 \
  --item ggofobggmeflfhplmmabcodbcgpaceee \
  --privacy-url https://hold-on.pages.dev/privacy/ \
  --save --submit
```

## Login Model

The script follows the `cdp-browser-control` pattern:

1. copy selected Chrome profile data into `/tmp/chrome-debug-profile-cws`
2. launch a separate Chrome instance with `--remote-debugging-port`
3. connect `playwriter --direct` to that CDP endpoint
4. delete the playwriter session and close only the temporary Chrome when done

It does not close or mutate the user's existing Chrome windows.

## Operational Notes

- The source profile defaults to `Default`; override with `--profile "Profile 1"` if needed.
- The CDP port defaults to `9223`; use `--port` if occupied.
- If an existing CDP browser is already listening, the script fails unless `--reuse-cdp` is passed.
- If Chrome Web Store redirects to Google login, the source profile lacks a usable CWS login; stop and let the user log in to that Chrome profile.
- CWS DOM labels can change. After a Chrome Web Store UI update, run the dry-run command before using `--save --submit`.
