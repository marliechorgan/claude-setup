# Your own automation browser (CDP)

For public pages and scheduled jobs, run a separate Chrome that holds none of the user's cookies and drive it over the Chrome DevTools Protocol (Playwright, Puppeteer or raw CDP). It can run unattended at 7am; the extension on the real profile can't. Observed on macOS with Chrome 136–151, 2026.

## It can never be the user's profile by flag

Chrome 136+ silently ignores `--remote-debugging-port` when `--user-data-dir` is the default profile, and copying the real profile into a custom folder doesn't get around it. So a flag-launched automation browser is always a different, logged-out profile. That's the point: keep it identity-free. (Chrome 144+ also has a per-profile opt-in at `chrome://inspect/#remote-debugging` that allows debugging the real profile after a click-to-allow prompt. It's attended by nature, not an unattended route.)

## Launch it without touching the user's real Chrome

- **Always pass your own `--user-data-dir`,** one per port. Without it, even `chrome --help` hands its arguments to the user's running Chrome. Two instances on one profile directory abort on the lock and the debug port never opens.
- **Keep the real `HOME`, and pass `--use-mock-keychain`.** Launching Chrome with a stand-in `HOME` on macOS fills the user's screen with "Keychain Not Found" dialogs.
- **Close it when the job ends,** by matching its exact profile path, not "any Chrome".
- **On macOS, two apps now answer to `com.google.Chrome`:** `open -a "Google Chrome"` may bring your automation window forward instead of the user's. Anything that needs the user's Chrome in front (1Password autofill) must check which process came forward.
- **Scheduled jobs under launchd don't get your shell's PATH:** `node` installed via nvm isn't found at 7am even though every hand test passed. Resolve the runtime path explicitly.

## Headless vs off-screen

- **True headless gets blocked** on Akamai- and Cloudflare-class sites where the same profile in a real window gets through: measured 403 vs 200 with nothing else changed.
- **Default to a real window positioned off-screen** (`--window-position=-2400,-2400`) and make true headless an opt-in. A mode that depends on remembering a flag isn't a control: make the safe mode the default.
- **Some walls hold anyway** (a Cloudflare "Just a moment…" interstitial that survives a real window). Then use the site's own API, a first-party data endpoint, or an attended browser.
- **Bot posture is per hostname, not per domain.** Sibling subdomains of one organisation can differ completely. One `curl -sSI https://host/` and a look at `server:` and `cf-mitigated:` settles it for that host only.

## Read the page, not the shell

- WebFetch and plain HTTP see server HTML only. Client-rendered pages can hold 0 items in the source and 10 in the rendered DOM, so "unreadable" often means "unreadable to WebFetch". Try the real browser before writing a surface off.
- **Prefer embedded JSON to the DOM.** One events page gave 15 identical anchors in the DOM and 37 real events in its `__NEXT_DATA__`.
- **"Thin page" is two different faults:** a JS page (the browser fixes it) and a dead URL (the browser renders a full-looking 404 shell under a plausible title). Check the HTTP status, compare the title with what the page should say, and reconcile counts ("Displaying N of M"). Before declaring a URL dead, check the site's sitemap; the path may just have moved.
- **Prefer first-party sources to aggregators.** For job listings, the ATS boards (Greenhouse, Ashby, Lever) serve complete public JSON with no bot wall.
- **Let the agent author the scraper once,** then run the script on a schedule at zero model cost. The model comes back only when the scraper breaks.
