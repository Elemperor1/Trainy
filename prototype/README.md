# Browser prototype

A dependency-free browser sketch of the Japan-first Shinkansen flow. It is **not
part of the shipped product**: the iOS app in `TrainyIOS/` and `Sources/` is the
product. Nothing here is deployed, built by CI beyond a syntax check, or covered
by the privacy manifest or the archive audit.

Everything on screen is invented sample data (trains, seats, platform numbers,
"signal" scores). It does not reflect any operator's timetable or any real trip.

## Run it

```bash
python3 -m http.server 4173 --directory prototype
```

Then open <http://localhost:4173>.

## What still checks it

- `node --check prototype/app.js` and `node --check prototype/components.js`
  (Swift CI).
- `scripts/check-design-system-bypass.sh` keeps `app.js` routing dynamic markup
  through `components.js` and keeps color literals in `styles.css` inside CSS
  custom-property declarations.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | Page shell |
| `app.js` | Sample trips and page behavior |
| `components.js` | Component factories (`TrainyUI.*`) that build all dynamic markup |
| `styles.css` | Design tokens and component styles |
