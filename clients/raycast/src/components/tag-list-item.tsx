import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import * as Tag from "../api/tag";
import { UriList } from "./uri-list";
import { TagCreateForm } from "./tag-create-form";
import { TagEditForm } from "./tag-edit-form";

interface TagListItemProps {
  tag: Tag.Tag;
  revalidate: () => void;
}

export function TagListItem({ tag, revalidate }: TagListItemProps) {
  const deleteTag = async () => {
    const deleted = await Tag.deleteTag(tag);
    if (deleted) {
      revalidate();
    }
  };

  return (
    <List.Item
      key={String(tag.id)}
      title={tag.name}
      icon={Icon.Tag}
      actions={
        <ActionPanel>
          <Action.Push title="View URIs" icon={Icon.List} target={<UriList tag={tag} />} />
          <Action.Push
            title="Edit Tag"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<TagEditForm tag={tag} revalidate={revalidate} />}
          />
          <Action.Push
            title="Create Tag"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<TagCreateForm revalidate={revalidate} />}
          />
          <Action
            title="Delete"
            icon={Icon.Trash}
            style={Action.Style.Destructive}
            onAction={deleteTag}
            shortcut={Keyboard.Shortcut.Common.Remove}
          />
        </ActionPanel>
      }
    />
  );
}
