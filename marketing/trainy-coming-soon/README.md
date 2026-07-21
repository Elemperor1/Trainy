# Trainy coming-soon site

A responsive launch preview for Trainy. The page intentionally communicates a
coming-soon state and does not claim an App Store release date or download.

## Run locally

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Build

```bash
npm run build
npm run sites:build
```

Both commands produce a self-contained ChatGPT Sites Worker package in `dist/`.
The generated worker embeds the static page and its image assets so deployment
does not depend on an undeclared runtime asset binding.

To preview the generated static export instead of the development server, run
`npm run build`, then serve the `out/` directory with any static file server,
for example `python3 -m http.server 4173 --directory out`.

The ChatGPT Sites project identifier is recorded in `.openai/hosting.json`.
