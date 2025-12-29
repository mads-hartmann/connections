import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import { getServerUrl } from "../api/config";
import * as Metadata from "../api/metadata";

interface CreatePersonFormProps {
  revalidate: () => void;
}

export function PersonCreateForm({ revalidate }: CreatePersonFormProps) {
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
        push(<PersonPreviewForm metadata={metadata} initialName={values.name.trim()} revalidate={revalidate} />);
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

async function createPerson(
  name: string,
  feeds?: Array<{ url: string; title: string | null }>,
  profiles?: Array<Metadata.ClassifiedProfile>
) {
  const response = await fetch(`${getServerUrl()}/persons`, {
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
      await fetch(`${getServerUrl()}/persons/${person.id}/feeds`, {
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

  // Create metadata entries for profiles if provided
  if (profiles && profiles.length > 0) {
    for (const profile of profiles) {
      await fetch(`${getServerUrl()}/persons/${person.id}/metadata`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          field_type_id: profile.field_type.id,
          value: profile.url,
        }),
      });
    }
  }

  return person;
}

interface PersonPreviewFormProps {
  metadata: Metadata.MetadataResponse;
  initialName: string;
  revalidate: () => void;
}

function PersonPreviewForm({ metadata, initialName, revalidate }: PersonPreviewFormProps) {
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

  const author = metadata.merged.author;
  const site = metadata.merged.site;
  const classifiedProfiles = author?.classified_profiles ?? [];

  async function handleSubmit(values: Record<string, unknown>) {
    const name = values.name as string;
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
      // Collect selected feeds from checkbox values
      const feedsToCreate = metadata.merged.feeds.filter((f) => values[`feed_${f.url}`] === true);
      // Collect selected metadata profiles from checkbox values
      const profilesToCreate = classifiedProfiles.filter((p) => values[`profile_${p.url}`] === true);

      const person = await createPerson(name.trim(), feedsToCreate, profilesToCreate);

      const parts: string[] = [];
      if (feedsToCreate.length > 0) parts.push(`${feedsToCreate.length} feed(s)`);
      if (profilesToCreate.length > 0) parts.push(`${profilesToCreate.length} profile(s)`);

      showToast({
        style: Toast.Style.Success,
        title: "Person created",
        message: parts.length > 0 ? `Created with ${parts.join(" and ")}` : undefined,
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
  }

  // Build info strings for display
  const detailParts: string[] = [];
  if (author?.location) detailParts.push(`📍 ${author.location}`);

  return (
    <Form
      isLoading={isCreating}
      navigationTitle="Create Person"
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Create Person" icon={Icon.Plus} onSubmit={handleSubmit} />
          <Action.OpenInBrowser title="Open URL" url={metadata.merged.url} />
        </ActionPanel>
      }
    >
      {/* Source URL */}
      <Form.Description title="Source" text={metadata.merged.url} />

      {/* Name field with favicon/photo as visual context */}
      <Form.TextField
        id="name"
        title="Name"
        defaultValue={suggestedName || ""}
        placeholder="Enter person's name"
        info={author?.bio || undefined}
      />

      {/* Show extracted metadata as read-only info */}
      {detailParts.length > 0 && <Form.Description text={detailParts.join("  •  ")} />}

      <Form.Separator />

      {/* Feeds Section with Checkboxes */}
      {metadata.merged.feeds.length > 0 ? (
        metadata.merged.feeds.map((feed, index) => (
          <Form.Checkbox
            key={feed.url}
            id={`feed_${feed.url}`}
            title={index === 0 ? "Feeds" : ""}
            label={`${feed.title || "Untitled"} (${feed.format})`}
            defaultValue={true}
            info={feed.url}
          />
        ))
      ) : (
        <Form.Description title="Feeds" text="No RSS/Atom feeds discovered at this URL." />
      )}

      <Form.Separator />

      {/* Social Profiles Section with Checkboxes */}
      {classifiedProfiles.length > 0 ? (
        classifiedProfiles.map((profile, index) => (
          <Form.Checkbox
            key={profile.url}
            id={`profile_${profile.url}`}
            title={index === 0 ? "Profiles" : ""}
            label={`${profile.field_type.name}: ${profile.url}`}
            defaultValue={true}
          />
        ))
      ) : (
        <Form.Description title="Profiles" text="No social profiles discovered at this URL." />
      )}

      {/* Site info if different from name */}
      {site?.name && site.name !== suggestedName && <Form.Description title="Site" text={site.name} />}
    </Form>
  );
}
