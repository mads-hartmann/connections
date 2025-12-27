import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useEffect, useState } from "react";
import * as Article from "../api/article";
import * as Tag from "../api/tag";

interface ArticleEditFormProps {
  article: Article.Article;
  revalidate: () => void;
}

export function ArticleEditForm({ article, revalidate }: ArticleEditFormProps) {
  const { pop } = useNavigation();
  const [isLoading, setIsLoading] = useState(true);
  const [allTags, setAllTags] = useState<Tag.Tag[]>([]);
  const [currentTagIds, setCurrentTagIds] = useState<string[]>(article.tags.map((t) => String(t.id)));

  useEffect(() => {
    async function loadTags() {
      try {
        const tags = await Tag.listAll();
        setAllTags(tags);
      } catch (error) {
        showToast({
          style: Toast.Style.Failure,
          title: "Failed to load tags",
          message: error instanceof Error ? error.message : "Unknown error",
        });
      } finally {
        setIsLoading(false);
      }
    }
    loadTags();
  }, []);

  async function handleSubmit(values: { tags: string[] }) {
    setIsLoading(true);
    try {
      const selectedTagIds = new Set(values.tags.map((id) => parseInt(id, 10)));
      const currentIds = new Set(article.tags.map((t) => t.id));

      const tagsToAdd = [...selectedTagIds].filter((id) => !currentIds.has(id));
      const tagsToRemove = [...currentIds].filter((id) => !selectedTagIds.has(id));

      await Promise.all([
        ...tagsToAdd.map((tagId) => Tag.addToArticle(article.id, tagId)),
        ...tagsToRemove.map((tagId) => Tag.removeFromArticle(article.id, tagId)),
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
      setIsLoading(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      navigationTitle={`Edit ${article.title || "Article"}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Update Article" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.Description title="Title" text={article.title || "Untitled"} />
      <Form.Description title="URL" text={article.url} />
      <Form.Separator />
      <Form.TagPicker id="tags" title="Tags" value={currentTagIds} onChange={setCurrentTagIds}>
        {allTags.map((tag) => (
          <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
        ))}
      </Form.TagPicker>
    </Form>
  );
}
