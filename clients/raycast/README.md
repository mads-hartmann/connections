# Connections Raycast Extension

Raycast extension for managing connections.

## Development

```bash
npm install
npm run dev
```

This starts the extension in development mode with hot reloading. The extension will appear at the top of Raycast's root search.

Press `Ctrl+C` to stop development mode. The extension remains installed in Raycast.

## Production Install

To install a production build:

```bash
npm install
npm run build
```

Then:

1. Update `dist/package.json` with the following (this is needed until we publish to the store)
    ```
    "name": "connections-live",
    "title": "Connections - Live",
    ```
2. In Raycast, run the "Import Extension" command and select the `clients/raycast/dist` directory.