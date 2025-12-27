import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import * as Tag from "../api/tag";
import { ArticleList } from "./article-list";
import { CreateTagForm } from "./create-tag-form";
import { EditTagForm } from "./edit-tag-form";

interface TagItemProps {
  tag: Tag.Tag;
  revalidate: () => void;
}

export function TagItem({ tag, revalidate }: TagItemProps) {
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
          <Action.Push title="View Articles" icon={Icon.List} target={<ArticleList tag={tag} />} />
          <Action.Push
            title="Edit Tag"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<EditTagForm tag={tag} revalidate={revalidate} />}
          />
          <Action.Push
            title="Create Tag"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<CreateTagForm revalidate={revalidate} />}
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
