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

Then in Raycast, run the "Import Extension" command and select the `clients/raycast` directory.

## Configuration

The extension has a configurable server URL preference (default: `http://localhost:8080`).

To change it:
1. Open Raycast Preferences (`Cmd+,`)
2. Go to Extensions > Connections
3. Update the "Server URL" field
