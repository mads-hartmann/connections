import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useEffect, useState } from "react";
import * as Tag from "../api/tag";

type EntityType = "person" | "feed" | "article";

interface ManageTagsFormProps {
  entityType: EntityType;
  entityId: number;
  entityName: string;
  revalidate?: () => void;
}

export function ManageTagsForm({ entityType, entityId, entityName, revalidate }: ManageTagsFormProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [currentTagIds, setCurrentTagIds] = useState<Set<number>>(new Set());

  // Fetch all available tags
  const { isLoading: isLoadingAllTags, data: allTagsData } = useFetch(
    (options) => Tag.listUrl({ page: options.page + 1 }),
    {
      mapResult(result: Tag.TagsResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
      keepPreviousData: true,
    },
  );

  // Fetch current tags for the entity
  const { isLoading: isLoadingCurrentTags, data: currentTags } = useFetch(
    () => {
      switch (entityType) {
        case "person":
          return `http://localhost:8080/persons/${entityId}/tags`;
        case "feed":
          return `http://localhost:8080/feeds/${entityId}/tags`;
        case "article":
          // Articles don't have a list endpoint, we get tags from the article itself
          return null;
      }
    },
    {
      execute: entityType !== "article",
      mapResult(result: Tag.Tag[]) {
        return { data: result };
      },
    },
  );

  // Initialize current tag IDs when data loads
  useEffect(() => {
    if (currentTags) {
      setCurrentTagIds(new Set(currentTags.map((t) => t.id)));
    }
  }, [currentTags]);

  const isLoading = isLoadingAllTags || isLoadingCurrentTags;

  async function handleSubmit(values: Record<string, boolean>) {
    setIsSubmitting(true);
    try {
      const selectedTagIds = new Set(
        Object.entries(values)
          .filter(([key, checked]) => key.startsWith("tag_") && checked)
          .map(([key]) => parseInt(key.replace("tag_", ""), 10)),
      );

      // Determine which tags to add and remove
      const tagsToAdd = [...selectedTagIds].filter((id) => !currentTagIds.has(id));
      const tagsToRemove = [...currentTagIds].filter((id) => !selectedTagIds.has(id));

      // Perform add/remove operations
      for (const tagId of tagsToAdd) {
        switch (entityType) {
          case "person":
            await Tag.addToPerson(entityId, tagId);
            break;
          case "feed":
            await Tag.addToFeed(entityId, tagId);
            break;
          case "article":
            await Tag.addToArticle(entityId, tagId);
            break;
        }
      }

      for (const tagId of tagsToRemove) {
        switch (entityType) {
          case "person":
            await Tag.removeFromPerson(entityId, tagId);
            break;
          case "feed":
            await Tag.removeFromFeed(entityId, tagId);
            break;
          case "article":
            await Tag.removeFromArticle(entityId, tagId);
            break;
        }
      }

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

      revalidate?.();
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

  const entityTypeLabel = entityType.charAt(0).toUpperCase() + entityType.slice(1);

  return (
    <Form
      isLoading={isLoading || isSubmitting}
      navigationTitle={`Manage Tags - ${entityName}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Tags" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.Description title={entityTypeLabel} text={entityName} />
      <Form.Separator />

      {allTagsData && allTagsData.length > 0 ? (
        allTagsData.map((tag, index) => (
          <Form.Checkbox
            key={tag.id}
            id={`tag_${tag.id}`}
            title={index === 0 ? "Tags" : ""}
            label={tag.name}
            defaultValue={currentTagIds.has(tag.id)}
          />
        ))
      ) : (
        <Form.Description text="No tags available. Create some tags first." />
      )}
    </Form>
  );
}
