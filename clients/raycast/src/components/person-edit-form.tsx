import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import * as Person from "../api/person";
import * as Tag from "../api/tag";

interface PersonEditFormProps {
  person: Person.Person;
  revalidate: () => void;
}

export function PersonEditForm({ person, revalidate }: PersonEditFormProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);

  const { isLoading: isLoadingAllTags, data: allTags } = useFetch<Tag.Tag[]>(Tag.listAllUrl(), {
    mapResult: (result: Tag.TagsResponse) => ({ data: result.data }),
  });

  const { isLoading: isLoadingPersonTags, data: personTags, revalidate: revalidatePersonTags } = useFetch<Tag.Tag[]>(
    Tag.listByPersonUrl(person.id),
    {
      onData: (tags) => setSelectedTagIds(tags.map((t) => String(t.id))),
    },
  );

  const isLoading = isLoadingAllTags || isLoadingPersonTags || isSubmitting;

  async function handleSubmit(values: { name: string; tags: string[] }) {
    const name = values.name.trim();
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
      await Person.updatePerson(person.id, name);

      const newTagIds = new Set(values.tags.map((id) => parseInt(id, 10)));
      const currentTagIds = new Set(personTags?.map((t) => t.id) ?? []);

      const tagsToAdd = [...newTagIds].filter((id) => !currentTagIds.has(id));
      const tagsToRemove = [...currentTagIds].filter((id) => !newTagIds.has(id));

      await Promise.all([
        ...tagsToAdd.map((tagId) => Tag.addToPerson(person.id, tagId)),
        ...tagsToRemove.map((tagId) => Tag.removeFromPerson(person.id, tagId)),
      ]);

      showToast({ style: Toast.Style.Success, title: "Person updated" });
      revalidatePersonTags();
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update person",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      navigationTitle={`Edit ${person.name}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Update Person" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="name" title="Name" defaultValue={person.name} placeholder="Person name" />
      <Form.TagPicker id="tags" title="Tags" value={selectedTagIds} onChange={setSelectedTagIds}>
        {allTags?.map((tag) => (
          <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
        ))}
      </Form.TagPicker>
    </Form>
  );
}
