import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useEffect, useRef, useState } from "react";
import * as Feed from "../api/feed";
import * as Tag from "../api/tag";

interface EditFeedFormProps {
  feed: Feed.Feed;
  revalidate: () => void;
}

export function EditFeedForm({ feed, revalidate }: EditFeedFormProps) {
  const { pop } = useNavigation();
  const [isLoading, setIsLoading] = useState(true);
  const [allTags, setAllTags] = useState<Tag.Tag[]>([]);
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const initialTagIds = useRef<Set<number>>(new Set());

  useEffect(() => {
    async function loadData() {
      try {
        const [tags, feedTags] = await Promise.all([Tag.listAll(), Tag.listByFeed(feed.id)]);
        setAllTags(tags);
        const tagIds = feedTags.map((t) => String(t.id));
        setSelectedTagIds(tagIds);
        initialTagIds.current = new Set(feedTags.map((t) => t.id));
      } catch (error) {
        showToast({
          style: Toast.Style.Failure,
          title: "Failed to load data",
          message: error instanceof Error ? error.message : "Unknown error",
        });
      } finally {
        setIsLoading(false);
      }
    }
    loadData();
  }, [feed.id]);

  async function handleSubmit(values: { url: string; title: string; tags: string[] }) {
    setIsLoading(true);
    try {
      // Update feed
      await Feed.updateFeed(feed.id, values.url, values.title);

      // Update tags
      const newTagIds = new Set(values.tags.map((id) => parseInt(id, 10)));

      const tagsToAdd = [...newTagIds].filter((id) => !initialTagIds.current.has(id));
      const tagsToRemove = [...initialTagIds.current].filter((id) => !newTagIds.has(id));

      await Promise.all([
        ...tagsToAdd.map((tagId) => Tag.addToFeed(feed.id, tagId)),
        ...tagsToRemove.map((tagId) => Tag.removeFromFeed(feed.id, tagId)),
      ]);

      showToast({ style: Toast.Style.Success, title: "Feed updated" });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update feed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsLoading(false);
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
      <Form.TagPicker id="tags" title="Tags" value={selectedTagIds} onChange={setSelectedTagIds}>
        {allTags.map((tag) => (
          <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
        ))}
      </Form.TagPicker>
    </Form>
  );
}
