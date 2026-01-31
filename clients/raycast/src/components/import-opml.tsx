import { Action, ActionPanel, Form, Icon, List, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import * as Import from "../api/import";

interface ImportOpmlProps {
  revalidate: () => void;
}

// Step 1: File picker form
export function ImportOpml({ revalidate }: ImportOpmlProps) {
  const { push } = useNavigation();
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(values: { file: string[] }) {
    if (!values.file || values.file.length === 0) {
      showToast({
        style: Toast.Style.Failure,
        title: "No file selected",
        message: "Please select an OPML file",
      });
      return;
    }

    setIsLoading(true);
    try {
      // Read file content
      const fs = await import("fs").then((m) => m.promises);
      const content = await fs.readFile(values.file[0], "utf-8");

      // Get preview from API
      const preview = await Import.previewOpml(content);

      if (preview.connections.length === 0) {
        showToast({
          style: Toast.Style.Failure,
          title: "No feeds found",
          message:
            preview.errors.length > 0
              ? `${preview.errors.length} feeds failed to load`
              : "The OPML file contains no valid feeds",
        });
        return;
      }

      // Navigate to preview screen
      push(<ImportPreview preview={preview} revalidate={revalidate} />);
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to parse OPML",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Preview Import" onSubmit={handleSubmit} icon={Icon.Eye} />
        </ActionPanel>
      }
    >
      <Form.FilePicker id="file" title="OPML File" allowMultipleSelection={false} canChooseDirectories={false} />
      <Form.Description text="Select an OPML file exported from your RSS reader. The import will extract author information from each feed and group them by connection." />
    </Form>
  );
}

// Step 2: Preview and select connections to import
interface ImportPreviewProps {
  preview: Import.PreviewResponse;
  revalidate: () => void;
}

function ImportPreview({ preview, revalidate }: ImportPreviewProps) {
  const { pop } = useNavigation();
  const [selectedConnections, setSelectedConnections] = useState<Set<string>>(
    new Set(preview.connections.map((c) => c.name)),
  );
  const [isImporting, setIsImporting] = useState(false);

  const toggleConnection = (name: string) => {
    const newSelected = new Set(selectedConnections);
    if (newSelected.has(name)) {
      newSelected.delete(name);
    } else {
      newSelected.add(name);
    }
    setSelectedConnections(newSelected);
  };

  const toggleAll = () => {
    if (selectedConnections.size === preview.connections.length) {
      setSelectedConnections(new Set());
    } else {
      setSelectedConnections(new Set(preview.connections.map((c) => c.name)));
    }
  };

  const handleImport = async () => {
    const connectionsToImport = preview.connections.filter((c) => selectedConnections.has(c.name));
    if (connectionsToImport.length === 0) {
      showToast({
        style: Toast.Style.Failure,
        title: "No connections selected",
        message: "Please select at least one connection to import",
      });
      return;
    }

    setIsImporting(true);
    try {
      const result = await Import.confirmImport({ connections: connectionsToImport });
      showToast({
        style: Toast.Style.Success,
        title: "Import complete",
        message: `Created ${result.created_connections} connections, ${result.created_feeds} feeds, ${result.created_tags} tags`,
      });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Import failed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <List isLoading={isImporting} navigationTitle="Import Preview" searchBarPlaceholder="Filter connections...">
      <List.Section
        title="Connections to Import"
        subtitle={`${selectedConnections.size} of ${preview.connections.length} selected`}
      >
        {preview.connections.map((connection) => (
          <List.Item
            key={connection.name}
            title={connection.name}
            subtitle={`${connection.feeds.length} feed${connection.feeds.length !== 1 ? "s" : ""}`}
            accessories={[
              ...(connection.tags.length > 0 ? [{ tag: connection.tags.join(", ") }] : []),
              {
                icon: selectedConnections.has(connection.name) ? Icon.CheckCircle : Icon.Circle,
              },
            ]}
            actions={
              <ActionPanel>
                <Action
                  title={selectedConnections.has(connection.name) ? "Deselect" : "Select"}
                  icon={selectedConnections.has(connection.name) ? Icon.Circle : Icon.CheckCircle}
                  onAction={() => toggleConnection(connection.name)}
                />
                <Action
                  title={selectedConnections.size === preview.connections.length ? "Deselect All" : "Select All"}
                  icon={Icon.CheckCircle}
                  onAction={toggleAll}
                />
                <Action
                  title={`Import ${selectedConnections.size} Connections`}
                  icon={Icon.Download}
                  onAction={handleImport}
                />
                <Action.Push
                  title="View Feeds"
                  icon={Icon.List}
                  target={<ConnectionFeedsList connection={connection} />}
                />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
      {preview.errors.length > 0 && (
        <List.Section title="Failed Feeds" subtitle={`${preview.errors.length} errors`}>
          {preview.errors.map((error) => (
            <List.Item key={error.url} title={error.url} subtitle={error.error} icon={Icon.ExclamationMark} />
          ))}
        </List.Section>
      )}
    </List>
  );
}

// Detail view for a connection's feeds
interface ConnectionFeedsListProps {
  connection: Import.ConnectionInfo;
}

function ConnectionFeedsList({ connection }: ConnectionFeedsListProps) {
  return (
    <List navigationTitle={`${connection.name}'s Feeds`}>
      <List.Section title="Feeds" subtitle={`${connection.feeds.length} total`}>
        {connection.feeds.map((feed) => (
          <List.Item
            key={feed.url}
            title={feed.title || feed.url}
            subtitle={feed.title ? feed.url : undefined}
            icon={Icon.Link}
          />
        ))}
      </List.Section>
      {connection.tags.length > 0 && (
        <List.Section title="Tags">
          {connection.tags.map((tag) => (
            <List.Item key={tag} title={tag} icon={Icon.Tag} />
          ))}
        </List.Section>
      )}
    </List>
  );
}
