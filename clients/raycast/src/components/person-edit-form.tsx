import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useEffect, useState } from "react";
import * as Person from "../api/person";
import * as Tag from "../api/tag";

interface PersonEditFormProps {
  person: Person.Person;
  revalidate: () => void;
}

export function PersonEditForm({ person, revalidate }: PersonEditFormProps) {
  const { pop } = useNavigation();
  const [isLoading, setIsLoading] = useState(true);
  const [allTags, setAllTags] = useState<Tag.Tag[]>([]);
  const [currentTagIds, setCurrentTagIds] = useState<string[]>([]);

  useEffect(() => {
    async function loadData() {
      try {
        const [tags, personTags] = await Promise.all([Tag.listAll(), Tag.listByPerson(person.id)]);
        setAllTags(tags);
        setCurrentTagIds(personTags.map((t) => String(t.id)));
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
  }, [person.id]);

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

    setIsLoading(true);
    try {
      // Update person name
      await Person.updatePerson(person.id, name);

      // Update tags
      const selectedTagIds = new Set(values.tags.map((id) => parseInt(id, 10)));
      const currentIds = new Set(currentTagIds.map((id) => parseInt(id, 10)));

      const tagsToAdd = [...selectedTagIds].filter((id) => !currentIds.has(id));
      const tagsToRemove = [...currentIds].filter((id) => !selectedTagIds.has(id));

      await Promise.all([
        ...tagsToAdd.map((tagId) => Tag.addToPerson(person.id, tagId)),
        ...tagsToRemove.map((tagId) => Tag.removeFromPerson(person.id, tagId)),
      ]);

      showToast({ style: Toast.Style.Success, title: "Person updated" });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update person",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsLoading(false);
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
      <Form.TagPicker id="tags" title="Tags" value={currentTagIds} onChange={setCurrentTagIds}>
        {allTags.map((tag) => (
          <Form.TagPicker.Item key={tag.id} value={String(tag.id)} title={tag.name} icon={Icon.Tag} />
        ))}
      </Form.TagPicker>
    </Form>
  );
}
