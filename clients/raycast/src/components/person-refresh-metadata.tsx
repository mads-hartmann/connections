import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { useState } from "react";
import * as Person from "../api/person";
import * as Feed from "../api/feed";

interface PersonRefreshMetadataProps {
  person: Person.Person;
  revalidate: () => void;
}

export function PersonRefreshMetadata({ person, revalidate }: PersonRefreshMetadataProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { isLoading, data: preview, error } = usePromise(() => Person.fetchRefreshMetadataPreview(person.id));

  if (error) {
    return (
      <Form>
        <Form.Description
          title="Error"
          text={error instanceof Error ? error.message : "Failed to fetch metadata preview"}
        />
      </Form>
    );
  }

  async function handleSubmit(values: Record<string, unknown>) {
    if (!preview) return;

    setIsSubmitting(true);
    try {
      const updates: Promise<unknown>[] = [];

      // Update name if selected and different
      const updateName = values.update_name as boolean;
      const updatePhoto = values.update_photo as boolean;

      if (updateName && preview.proposed_name && preview.proposed_name !== preview.current_name) {
        updates.push(
          Person.updatePerson(
            person.id,
            preview.proposed_name,
            updatePhoto && preview.proposed_photo ? preview.proposed_photo : person.photo,
          ),
        );
      } else if (updatePhoto && preview.proposed_photo && preview.proposed_photo !== preview.current_photo) {
        updates.push(Person.updatePerson(person.id, person.name, preview.proposed_photo));
      }

      // Add selected feeds
      for (const feed of preview.proposed_feeds) {
        const key = `feed_${feed.url}`;
        if (values[key] === true) {
          updates.push(Feed.createFeed(person.id, feed.url, feed.title || ""));
        }
      }

      // Add selected profiles as metadata
      const existingUrls = new Set(preview.current_metadata.map((m) => m.value));
      for (const profile of preview.proposed_profiles) {
        const key = `profile_${profile.url}`;
        if (values[key] === true && !existingUrls.has(profile.url)) {
          updates.push(Person.createMetadata(person.id, profile.field_type.id, profile.url));
        }
      }

      await Promise.all(updates);

      const count = updates.length;
      showToast({
        style: Toast.Style.Success,
        title: "Metadata refreshed",
        message: count > 0 ? `Applied ${count} update(s)` : "No changes applied",
      });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to apply updates",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  // Check which profiles are new (not in current metadata)
  const existingUrls = new Set(preview?.current_metadata.map((m) => m.value) ?? []);

  return (
    <Form
      isLoading={isLoading || isSubmitting}
      navigationTitle={`Refresh Metadata: ${person.name}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Apply Selected Changes" icon={Icon.Check} onSubmit={handleSubmit} />
          {preview && <Action.OpenInBrowser title="Open Source URL" url={preview.source_url} />}
        </ActionPanel>
      }
    >
      {preview && (
        <>
          <Form.Description title="Source" text={preview.source_url} />

          {/* Name update */}
          {preview.proposed_name && preview.proposed_name !== preview.current_name && (
            <Form.Checkbox
              id="update_name"
              title="Name"
              label={`Update from "${preview.current_name}" to "${preview.proposed_name}"`}
              defaultValue={true}
            />
          )}

          {/* Photo update */}
          {preview.proposed_photo && preview.proposed_photo !== preview.current_photo && (
            <Form.Checkbox
              id="update_photo"
              title="Photo"
              label={preview.current_photo ? `Update photo URL` : `Add photo: ${preview.proposed_photo}`}
              defaultValue={true}
              info={preview.proposed_photo}
            />
          )}

          {/* Feeds section */}
          {preview.proposed_feeds.length > 0 && (
            <>
              <Form.Separator />
              <Form.Description title="Discovered Feeds" text="Select feeds to add" />
              {preview.proposed_feeds.map((feed, index) => (
                <Form.Checkbox
                  key={feed.url}
                  id={`feed_${feed.url}`}
                  title={index === 0 ? "Feeds" : ""}
                  label={`${feed.title || "Untitled"} (${feed.format})`}
                  defaultValue={true}
                  info={feed.url}
                />
              ))}
            </>
          )}

          {/* Profiles section */}
          {preview.proposed_profiles.length > 0 && (
            <>
              <Form.Separator />
              <Form.Description title="Discovered Profiles" text="Select profiles to add as metadata" />
              {preview.proposed_profiles.map((profile, index) => {
                const isNew = !existingUrls.has(profile.url);
                return (
                  <Form.Checkbox
                    key={profile.url}
                    id={`profile_${profile.url}`}
                    title={index === 0 ? "Profiles" : ""}
                    label={`${profile.field_type.name}: ${profile.url}${isNew ? "" : " (already exists)"}`}
                    defaultValue={isNew}
                    info={isNew ? undefined : "This profile already exists in metadata"}
                  />
                );
              })}
            </>
          )}

          {/* Show message if nothing to update */}
          {!preview.proposed_name &&
            !preview.proposed_photo &&
            preview.proposed_feeds.length === 0 &&
            preview.proposed_profiles.length === 0 && (
              <Form.Description title="No Updates" text="No new metadata was discovered from the website." />
            )}
        </>
      )}
    </Form>
  );
}
