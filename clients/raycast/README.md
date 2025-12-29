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
npm run publish-local
```

Then in Raycast, run the "Import Extension" command and select the `clients/raycast/dist` directory.

This builds the extension and renames it to "Connections - Live" so it can coexist with the dev version.