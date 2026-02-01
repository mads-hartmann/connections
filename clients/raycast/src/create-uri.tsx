import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import { getServerUrl } from "./api/config";
import * as Connection from "./api/connection";
import * as Uri from "./api/uri";

interface UriMetadata {
  title?: string;
  description?: string;
  image?: string;
  published_at?: string;
  author_name?: string;
  site_name?: string;
  canonical_url?: string;
  tags: string[];
  content_type?: string;
}

async function fetchUriMetadata(url: string): Promise<UriMetadata> {
  const params = new URLSearchParams({ url });
  const response = await fetch(`${getServerUrl()}/discovery/uri-metadata?${params.toString()}`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch metadata");
  }
  return response.json();
}

export default function Command() {
  const { push } = useNavigation();
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(values: { url: string }) {
    const url = values.url.trim();
    if (!url) {
      showToast({
        style: Toast.Style.Failure,
        title: "Missing URL",
        message: "Please paste a URL",
      });
      return;
    }

    setIsLoading(true);
    try {
      // Parse host from URL for connection matching
      let host: string;
      try {
        const parsed = new URL(url);
        host = parsed.host;
      } catch {
        showToast({
          style: Toast.Style.Failure,
          title: "Invalid URL",
          message: "Please enter a valid URL",
        });
        setIsLoading(false);
        return;
      }

      // Fetch metadata and matching connections in parallel
      const [metadata, matchingConnections] = await Promise.all([fetchUriMetadata(url), Connection.findByHost(host)]);

      push(<UriPreviewForm url={url} metadata={metadata} matchingConnections={matchingConnections} />);
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to fetch URL",
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
          <Action.SubmitForm title="Fetch URL" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="url" title="URL" placeholder="https://example.com/article" autoFocus />
      <Form.Description text="Paste a URL to save it. Metadata will be fetched automatically." />
    </Form>
  );
}

const URI_KINDS: { value: Uri.UriKind; title: string }[] = [
  { value: "blog", title: "Blog" },
  { value: "video", title: "Video" },
  { value: "tweet", title: "Tweet" },
  { value: "book", title: "Book" },
  { value: "site", title: "Site" },
  { value: "podcast", title: "Podcast" },
  { value: "paper", title: "Paper" },
  { value: "unknown", title: "Unknown" },
];

interface UriPreviewFormProps {
  url: string;
  metadata: UriMetadata;
  matchingConnections: Connection.Connection[];
}

function UriPreviewForm({ url, metadata, matchingConnections }: UriPreviewFormProps) {
  const { pop } = useNavigation();
  const [isCreating, setIsCreating] = useState(false);

  // Infer kind from content_type if available
  const inferredKind = (): Uri.UriKind => {
    if (metadata.content_type) {
      const type = metadata.content_type.toLowerCase();
      if (type.includes("video")) return "video";
      if (type.includes("article") || type.includes("blog")) return "blog";
    }
    return "unknown";
  };

  async function handleSubmit(values: { title: string; kind: string; connection_id: string }) {
    setIsCreating(true);
    try {
      const request: Uri.CreateUriRequest = {
        url,
        title: values.title.trim() || undefined,
        kind: values.kind as Uri.UriKind,
        connection_id: values.connection_id ? parseInt(values.connection_id, 10) : undefined,
      };

      await Uri.createUri(request);

      showToast({
        style: Toast.Style.Success,
        title: "URI created",
        message: values.title || url,
      });
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to create URI",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsCreating(false);
    }
  }

  return (
    <Form
      isLoading={isCreating}
      navigationTitle="Create URI"
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Create URI" icon={Icon.Plus} onSubmit={handleSubmit} />
          <Action.OpenInBrowser title="Open URL" url={url} />
        </ActionPanel>
      }
    >
      <Form.Description title="URL" text={url} />

      <Form.TextField id="title" title="Title" defaultValue={metadata.title || ""} placeholder="Enter title" />

      <Form.Dropdown id="kind" title="Kind" defaultValue={inferredKind()}>
        {URI_KINDS.map((kind) => (
          <Form.Dropdown.Item key={kind.value} value={kind.value} title={kind.title} />
        ))}
      </Form.Dropdown>

      <Form.Dropdown id="connection_id" title="Connection" defaultValue="">
        <Form.Dropdown.Item value="" title="None (Inbox)" icon={Icon.Tray} />
        {matchingConnections.length > 0 && (
          <Form.Dropdown.Section title="Matching Connections">
            {matchingConnections.map((connection) => (
              <Form.Dropdown.Item
                key={connection.id}
                value={String(connection.id)}
                title={connection.name}
                icon={Icon.Person}
              />
            ))}
          </Form.Dropdown.Section>
        )}
      </Form.Dropdown>

      {metadata.site_name && <Form.Description title="Site" text={metadata.site_name} />}
      {metadata.author_name && <Form.Description title="Author" text={metadata.author_name} />}
      {metadata.description && <Form.Description title="Description" text={metadata.description} />}
    </Form>
  );
}
