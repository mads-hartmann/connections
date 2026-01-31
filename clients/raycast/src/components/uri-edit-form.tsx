import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { useState } from "react";
import * as Uri from "../api/uri";
import * as Tag from "../api/tag";

interface UriEditFormProps {
  uri: Uri.Uri;
  revalidate: () => void;
}

export function UriEditForm({ uri, revalidate }: UriEditFormProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>(uri.tags.map((t) => String(t.id)));

  const { isLoading: isLoadingAllTags, data: allTags } = usePromise(Tag.listAll);

  const isLoading = isLoadingAllTags || isSubmitting;

  // Use uri.tags as the source of truth for initial state
  const initialTagIds = new Set(uri.tags.map((t) => t.id));

  async function handleSubmit(values: { tags: string[] }) {
    setIsSubmitting(true);
    try {
      const newTagIds = new Set(values.tags.map((id) => parseInt(id, 10)));

      const tagsToAdd = [...newTagIds].filter((id) => !initialTagIds.has(id));
      const tagsToRemove = [...initialTagIds].filter((id) => !newTagIds.has(id));

      await Promise.all([
        ...tagsToAdd.map((tagId) => Tag.addToUri(uri.id, tagId)),
        ...tagsToRemove.map((tagId) => Tag.removeFromUri(uri.id, tagId)),
      ]);

      const changes = tagsToAdd.length + tagsToRemove.length;
      if (changes > 0) {
        showToast({
          style: Toast.Style.Success,
          title: "Tags updated",
          message: `${tagsToAdd.length} added, ${tagsToRemove.length} removed`,
        });
      } else {
        showToast({ style: Toast.Style.Success, title: "No changes" });
      }

      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update tags",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      navigationTitle={`Edit ${uri.title || "URI"}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Update URI" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.Description title="Title" text={uri.title || "Untitled"} />
      <Form.Description title="URL" text={uri.url} />
      <Form.Separator />
      <Form.TagPicker id="tags" title="Tags" value={selectedTagIds} onChange={setSelectedTagIds}>
        {allTags?.map((tag) => (
          <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
        ))}
      </Form.TagPicker>
    </Form>
  );
}
