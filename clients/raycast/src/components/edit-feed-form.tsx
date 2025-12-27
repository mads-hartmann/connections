import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useFetch, usePromise } from "@raycast/utils";
import { useState } from "react";
import * as Feed from "../api/feed";
import * as Tag from "../api/tag";

interface EditFeedFormProps {
  feed: Feed.Feed;
  revalidate: () => void;
}

export function EditFeedForm({ feed, revalidate }: EditFeedFormProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);

  const { isLoading: isLoadingAllTags, data: allTags } = usePromise(Tag.listAll);

  const { isLoading: isLoadingFeedTags, data: feedTags, revalidate: revalidateFeedTags } = useFetch<Tag.Tag[]>(
    Tag.listByFeedUrl(feed.id),
    {
      onData: (tags) => setSelectedTagIds(tags.map((t) => String(t.id))),
    },
  );

  const isLoading = isLoadingAllTags || isLoadingFeedTags || isSubmitting;

  async function handleSubmit(values: { url: string; title: string; tags: string[] }) {
    setIsSubmitting(true);
    try {
      await Feed.updateFeed(feed.id, values.url, values.title);

      const newTagIds = new Set(values.tags.map((id) => parseInt(id, 10)));
      const currentTagIds = new Set(feedTags?.map((t) => t.id) ?? []);

      const tagsToAdd = [...newTagIds].filter((id) => !currentTagIds.has(id));
      const tagsToRemove = [...currentTagIds].filter((id) => !newTagIds.has(id));

      await Promise.all([
        ...tagsToAdd.map((tagId) => Tag.addToFeed(feed.id, tagId)),
        ...tagsToRemove.map((tagId) => Tag.removeFromFeed(feed.id, tagId)),
      ]);

      showToast({ style: Toast.Style.Success, title: "Feed updated" });
      revalidateFeedTags();
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update feed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      navigationTitle={`Edit ${feed.title || feed.url}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Update Feed" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="url" title="URL" defaultValue={feed.url} placeholder="https://example.com/feed.xml" />
      <Form.TextField id="title" title="Title" defaultValue={feed.title || ""} placeholder="Feed title" />
      {!isLoadingAllTags && !isLoadingFeedTags && (
        <Form.TagPicker id="tags" title="Tags" value={selectedTagIds} onChange={setSelectedTagIds}>
          {allTags?.map((tag) => (
            <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
          ))}
        </Form.TagPicker>
      )}
    </Form>
  );
}
