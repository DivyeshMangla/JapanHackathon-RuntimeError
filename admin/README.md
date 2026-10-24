# Melo admin

Buildless HTML, CSS and JavaScript. No dependency installation or separate build is required.
The backend serves this directory and its API on the same origin. Run `npm run demo`
from `backend/`, then open http://127.0.0.1:8787.

Overview, patient search/filter/export, account creation, therapist approval,
assignment, account disabling, recording playback, audit history and password changes
all use the real API. Demo data is explicitly synthetic and opt-in.

Fonts are served from the existing bundled `assets/fonts` directory. The dashboard
does not load third-party scripts, fonts or analytics.

## Code style

`app.js` and `styles.css` follow Prettier with the options in `.prettierrc.json`
(embedded-language formatting is off, so markup inside templates is never
rewritten). Markup templates use the `html` tag defined at the top of `app.js`:
write them across lines freely, because `html` drops a line break and its
indentation wherever it comes before a tag or a `${…}` value. Text that should
keep a line break needs an explicit `<br>`.
