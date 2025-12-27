import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useEffect, useRef, useState } from "react";
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
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const initialTagIds = useRef<Set<number>>(new Set());

  useEffect(() => {
    async function loadTags() {
      try {
        const tags = await Tag.listAll();
        setAllTags(tags);
        // Set initial selection from article tags, now that allTags is loaded
        const articleTagIds = article.tags.map((t) => String(t.id));
        setSelectedTagIds(articleTagIds);
        initialTagIds.current = new Set(article.tags.map((t) => t.id));
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
  }, [article.id, article.tags]);

  async function handleSubmit(values: { tags: string[] }) {
    setIsLoading(true);
    try {
      const newTagIds = new Set(values.tags.map((id) => parseInt(id, 10)));

      const tagsToAdd = [...newTagIds].filter((id) => !initialTagIds.current.has(id));
      const tagsToRemove = [...initialTagIds.current].filter((id) => !newTagIds.has(id));

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
      <Form.TagPicker id="tags" title="Tags" value={selectedTagIds} onChange={setSelectedTagIds}>
        {allTags.map((tag) => (
          <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
        ))}
      </Form.TagPicker>
    </Form>
  );
}
