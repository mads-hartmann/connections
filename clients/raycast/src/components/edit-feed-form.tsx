import { Action, ActionPanel, Form, showToast, Toast, useNavigation } from "@raycast/api";
import * as Feed from "../api/feed";

interface EditFeedFormProps {
  feed: Feed.Feed;
  revalidate: () => void;
}

export function EditFeedForm({ feed, revalidate }: EditFeedFormProps) {
  const { pop } = useNavigation();

  async function handleSubmit(values: { url: string; title: string }) {
    try {
      await Feed.updateFeed(feed.id, values.url, values.title);
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update feed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Update Feed" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="url" title="URL" defaultValue={feed.url} placeholder="https://example.com/feed.xml" />
      <Form.TextField id="title" title="Title" defaultValue={feed.title || ""} placeholder="Feed title" />
    </Form>
  );
}
