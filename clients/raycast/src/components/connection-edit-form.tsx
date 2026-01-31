import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useFetch, usePromise } from "@raycast/utils";
import { useState } from "react";
import * as Connection from "../api/connection";
import * as Tag from "../api/tag";

interface ConnectionEditFormProps {
  connection: Connection.Connection;
  revalidate: () => void;
}

export function ConnectionEditForm({ connection, revalidate }: ConnectionEditFormProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const [deletedMetadataIds, setDeletedMetadataIds] = useState<Set<number>>(new Set());

  const { isLoading: isLoadingAllTags, data: allTags } = usePromise(Tag.listAll);

  const {
    isLoading: isLoadingConnectionTags,
    data: connectionTags,
    revalidate: revalidateConnectionTags,
  } = useFetch<Tag.Tag[]>(Tag.listByConnectionUrl(connection.id), {
    onData: (tags) => setSelectedTagIds(tags.map((t) => String(t.id))),
  });

  const isLoading = isLoadingAllTags || isLoadingConnectionTags || isSubmitting;

  // Filter out deleted metadata for display
  const visibleMetadata = connection.metadata.filter((m) => !deletedMetadataIds.has(m.id));

  async function handleSubmit(values: Record<string, unknown>) {
    const name = (values.name as string).trim();
    if (!name) {
      showToast({
        style: Toast.Style.Failure,
        title: "Name required",
        message: "Please enter a name",
      });
      return;
    }

    setIsSubmitting(true);
    try {
      // Update connection name and photo
      const photo = values.photo as string | undefined;
      await Connection.updateConnection(connection.id, name, photo || null);

      // Update tags
      const newTagIds = new Set((values.tags as string[]).map((id) => parseInt(id, 10)));
      const currentTagIds = new Set(connectionTags?.map((t) => t.id) ?? []);

      const tagsToAdd = [...newTagIds].filter((id) => !currentTagIds.has(id));
      const tagsToRemove = [...currentTagIds].filter((id) => !newTagIds.has(id));

      await Promise.all([
        ...tagsToAdd.map((tagId) => Tag.addToConnection(connection.id, tagId)),
        ...tagsToRemove.map((tagId) => Tag.removeFromConnection(connection.id, tagId)),
      ]);

      // Delete marked metadata
      await Promise.all([...deletedMetadataIds].map((id) => Connection.deleteMetadata(connection.id, id)));

      // Update metadata values
      const metadataUpdates = visibleMetadata
        .map((m) => {
          const newValue = values[`metadata_${m.id}`] as string;
          if (newValue && newValue.trim() !== m.value) {
            return Connection.updateMetadata(connection.id, m.id, newValue.trim());
          }
          return null;
        })
        .filter(Boolean);

      await Promise.all(metadataUpdates);

      showToast({ style: Toast.Style.Success, title: "Connection updated" });
      revalidateConnectionTags();
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update connection",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      navigationTitle={`Edit ${connection.name}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Changes" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="name" title="Name" defaultValue={connection.name} placeholder="Connection name" />
      <Form.TextField
        id="photo"
        title="Photo URL"
        defaultValue={connection.photo || ""}
        placeholder="https://example.com/photo.jpg"
      />

      {!isLoadingAllTags && !isLoadingConnectionTags && (
        <Form.TagPicker id="tags" title="Tags" value={selectedTagIds} onChange={setSelectedTagIds}>
          {allTags?.map((tag) => (
            <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
          ))}
        </Form.TagPicker>
      )}

      {visibleMetadata.length > 0 && <Form.Separator />}

      {visibleMetadata.map((m) => (
        <Form.TextField
          key={m.id}
          id={`metadata_${m.id}`}
          title={m.field_type.name}
          defaultValue={m.value}
          placeholder={m.value}
        />
      ))}

      {visibleMetadata.length > 0 && (
        <>
          <Form.Separator />
          <Form.Description title="Delete Metadata" text="Check the boxes below to mark metadata for deletion." />
          {visibleMetadata.map((m) => (
            <Form.Checkbox
              key={`delete_${m.id}`}
              id={`delete_${m.id}`}
              title=""
              label={`Delete ${m.field_type.name}: ${m.value}`}
              value={deletedMetadataIds.has(m.id)}
              onChange={(checked) => {
                if (checked) {
                  setDeletedMetadataIds((prev) => new Set([...prev, m.id]));
                } else {
                  setDeletedMetadataIds((prev) => {
                    const next = new Set(prev);
                    next.delete(m.id);
                    return next;
                  });
                }
              }}
            />
          ))}
        </>
      )}
    </Form>
  );
}
