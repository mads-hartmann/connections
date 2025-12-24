import { Action, ActionPanel, Detail, Form, Icon, List, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import * as Metadata from "../api/metadata";

interface CreatePersonFormProps {
  revalidate: () => void;
}

export function CreatePersonForm({ revalidate }: CreatePersonFormProps) {
  const { pop, push } = useNavigation();
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(values: { name: string; url: string }) {
    const hasName = values.name.trim() !== "";
    const hasUrl = values.url.trim() !== "";

    // If URL provided, fetch metadata and show preview
    if (hasUrl) {
      setIsLoading(true);
      try {
        const metadata = await Metadata.fetchMetadata(values.url.trim());
        push(<PersonPreview metadata={metadata} initialName={values.name.trim()} revalidate={revalidate} />);
      } catch (error) {
        showToast({
          style: Toast.Style.Failure,
          title: "Failed to fetch URL",
          message: error instanceof Error ? error.message : "Unknown error",
        });
      } finally {
        setIsLoading(false);
      }
      return;
    }

    // If only name provided, create directly
    if (hasName) {
      setIsLoading(true);
      try {
        await createPerson(values.name.trim());
        revalidate();
        pop();
      } catch (error) {
        showToast({
          style: Toast.Style.Failure,
          title: "Failed to create person",
          message: error instanceof Error ? error.message : "Unknown error",
        });
      } finally {
        setIsLoading(false);
      }
      return;
    }

    showToast({
      style: Toast.Style.Failure,
      title: "Missing input",
      message: "Please enter a name or URL",
    });
  }

  return (
    <Form
      isLoading={isLoading}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Create Person" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="name" title="Name" placeholder="Enter person's name" />
      <Form.Separator />
      <Form.TextField id="url" title="URL" placeholder="https://example.com (optional)" />
      <Form.Description text="Enter a URL to automatically extract the person's name and discover their RSS feeds." />
    </Form>
  );
}

async function createPerson(name: string, feeds?: Array<{ url: string; title: string | null }>) {
  const response = await fetch("http://localhost:8080/persons", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to create person");
  }
  const person = await response.json();

  // Create feeds if provided
  if (feeds && feeds.length > 0) {
    for (const feed of feeds) {
      await fetch(`http://localhost:8080/persons/${person.id}/feeds`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          person_id: person.id,
          url: feed.url,
          title: feed.title,
        }),
      });
    }
  }

  return person;
}

interface PersonPreviewProps {
  metadata: Metadata.MetadataResponse;
  initialName: string;
  revalidate: () => void;
}

function PersonPreview({ metadata, initialName, revalidate }: PersonPreviewProps) {
  const { pop } = useNavigation();
  const [isCreating, setIsCreating] = useState(false);

  // Determine the best name to use
  const suggestedName =
    initialName ||
    metadata.merged.author?.name ||
    metadata.merged.content.author?.name ||
    metadata.merged.site.name ||
    metadata.merged.content.title ||
    new URL(metadata.merged.url).hostname;

  const [name, setName] = useState(suggestedName || "");
  const [selectedFeeds, setSelectedFeeds] = useState<Set<string>>(new Set(metadata.merged.feeds.map((f) => f.url)));

  const toggleFeed = (url: string) => {
    const newSelected = new Set(selectedFeeds);
    if (newSelected.has(url)) {
      newSelected.delete(url);
    } else {
      newSelected.add(url);
    }
    setSelectedFeeds(newSelected);
  };

  const handleCreate = async () => {
    if (!name.trim()) {
      showToast({
        style: Toast.Style.Failure,
        title: "Name required",
        message: "Please enter a name for the person",
      });
      return;
    }

    setIsCreating(true);
    try {
      const feedsToCreate = metadata.merged.feeds.filter((f) => selectedFeeds.has(f.url));
      await createPerson(name.trim(), feedsToCreate);
      showToast({
        style: Toast.Style.Success,
        title: "Person created",
        message: feedsToCreate.length > 0 ? `Created with ${feedsToCreate.length} feed(s)` : undefined,
      });
      revalidate();
      pop();
      pop(); // Go back to main list
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to create person",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsCreating(false);
    }
  };

  const author = metadata.merged.author;
  const site = metadata.merged.site;

  // Build markdown preview
  let markdown = `# Preview: ${name || "New Person"}\n\n`;

  if (author?.photo) {
    markdown += `![Photo](${author.photo})\n\n`;
  }

  if (author?.bio) {
    markdown += `> ${author.bio}\n\n`;
  }

  markdown += `## Details\n\n`;
  markdown += `| Field | Value |\n|-------|-------|\n`;
  markdown += `| **URL** | ${metadata.merged.url} |\n`;

  if (author?.name) markdown += `| **Author** | ${author.name} |\n`;
  if (author?.email) markdown += `| **Email** | ${author.email} |\n`;
  if (author?.location) markdown += `| **Location** | ${author.location} |\n`;
  if (site?.name) markdown += `| **Site** | ${site.name} |\n`;

  if (author?.social_profiles && author.social_profiles.length > 0) {
    markdown += `\n## Social Profiles\n\n`;
    for (const profile of author.social_profiles) {
      markdown += `- ${profile}\n`;
    }
  }

  if (metadata.merged.feeds.length > 0) {
    markdown += `\n## Discovered Feeds (${selectedFeeds.size}/${metadata.merged.feeds.length} selected)\n\n`;
    for (const feed of metadata.merged.feeds) {
      const selected = selectedFeeds.has(feed.url) ? "✓" : "○";
      markdown += `- ${selected} **${feed.title || "Untitled"}** (${feed.format})\n`;
      markdown += `  ${feed.url}\n`;
    }
  }

  return (
    <Detail
      isLoading={isCreating}
      markdown={markdown}
      navigationTitle="Preview Person"
      metadata={
        <Detail.Metadata>
          <Detail.Metadata.Label title="Name" text={name} />
          {author?.url && <Detail.Metadata.Link title="Website" target={author.url} text={author.url} />}
          {site?.favicon && <Detail.Metadata.Label title="Favicon" icon={site.favicon} text="" />}
          <Detail.Metadata.Separator />
          <Detail.Metadata.Label title="Feeds" text={`${selectedFeeds.size} selected`} />
          {metadata.merged.feeds.map((feed) => (
            <Detail.Metadata.TagList key={feed.url} title={feed.title || feed.url}>
              <Detail.Metadata.TagList.Item
                text={feed.format}
                color={selectedFeeds.has(feed.url) ? "#00ff00" : "#888888"}
              />
            </Detail.Metadata.TagList>
          ))}
        </Detail.Metadata>
      }
      actions={
        <ActionPanel>
          <Action title="Create Person" icon={Icon.Plus} onAction={handleCreate} />
          <Action.Push
            title="Edit Name & Feeds"
            icon={Icon.Pencil}
            target={
              <EditPersonPreview
                metadata={metadata}
                name={name}
                setName={setName}
                selectedFeeds={selectedFeeds}
                toggleFeed={toggleFeed}
              />
            }
          />
          <Action.OpenInBrowser title="Open URL" url={metadata.merged.url} />
        </ActionPanel>
      }
    />
  );
}

interface EditPersonPreviewProps {
  metadata: Metadata.MetadataResponse;
  name: string;
  setName: (name: string) => void;
  selectedFeeds: Set<string>;
  toggleFeed: (url: string) => void;
}

function EditPersonPreview({ metadata, name, setName, selectedFeeds, toggleFeed }: EditPersonPreviewProps) {
  const { pop } = useNavigation();

  return (
    <List navigationTitle="Edit Person Details">
      <List.Section title="Name">
        <List.Item
          title={name || "No name set"}
          subtitle="Click to edit"
          icon={Icon.Person}
          actions={
            <ActionPanel>
              <Action.Push
                title="Edit Name"
                icon={Icon.Pencil}
                target={<EditNameForm currentName={name} onSave={setName} />}
              />
              <Action title="Done" icon={Icon.Check} onAction={pop} />
            </ActionPanel>
          }
        />
      </List.Section>

      <List.Section title="Feeds" subtitle={`${selectedFeeds.size} of ${metadata.merged.feeds.length} selected`}>
        {metadata.merged.feeds.map((feed) => (
          <List.Item
            key={feed.url}
            title={feed.title || "Untitled"}
            subtitle={feed.url}
            icon={selectedFeeds.has(feed.url) ? Icon.CheckCircle : Icon.Circle}
            accessories={[{ tag: feed.format }]}
            actions={
              <ActionPanel>
                <Action
                  title={selectedFeeds.has(feed.url) ? "Deselect Feed" : "Select Feed"}
                  icon={selectedFeeds.has(feed.url) ? Icon.Circle : Icon.CheckCircle}
                  onAction={() => toggleFeed(feed.url)}
                />
                <Action title="Done" icon={Icon.Check} onAction={pop} />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>

      {metadata.merged.feeds.length === 0 && (
        <List.EmptyView title="No feeds discovered" description="No RSS/Atom feeds were found at this URL" />
      )}
    </List>
  );
}

interface EditNameFormProps {
  currentName: string;
  onSave: (name: string) => void;
}

function EditNameForm({ currentName, onSave }: EditNameFormProps) {
  const { pop } = useNavigation();

  function handleSubmit(values: { name: string }) {
    onSave(values.name);
    pop();
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Name" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="name" title="Name" defaultValue={currentName} placeholder="Enter person's name" />
    </Form>
  );
}
