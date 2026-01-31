import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import { markAllUrisReadByConnection } from "../actions/connection-actions";
import * as Connection from "../api/connection";
import { AddMetadataForm } from "./add-metadata-form";
import { UriList } from "./uri-list";
import { ConnectionCreateForm } from "./connection-create-form";
import { FeedList } from "./feed-list";
import { ImportOpml } from "./import-opml";
import { ConnectionDetailMetadata } from "./connection-detail-metadata";
import { ConnectionEditForm } from "./connection-edit-form";
import { ConnectionRefreshMetadata } from "./connection-refresh-metadata";

interface ConnectionItemProps {
  connection: Connection.Connection;
  revalidate: () => void;
  showDetail: boolean;
  onToggleDetail: () => void;
}

export function ConnectionListItem({ connection, revalidate, showDetail, onToggleDetail }: ConnectionItemProps) {
  const deleteConnection = async () => {
    await Connection.deleteConnection(connection);
    revalidate();
  };

  const accessories: List.Item.Accessory[] = [];
  if (connection.unread_uri_count > 0) {
    accessories.push({ text: `${connection.unread_uri_count} unread` });
  }

  return (
    <List.Item
      key={String(connection.id)}
      title={connection.name}
      icon={connection.photo ? { source: connection.photo } : undefined}
      accessories={accessories}
      detail={<ConnectionDetailMetadata connection={connection} />}
      actions={
        <ActionPanel>
          <Action.Push
            title="View URIs"
            icon={Icon.Document}
            target={
              <UriList
                connectionId={connection.id}
                connectionName={connection.name}
                defaultFilter={connection.unread_uri_count > 0 ? "unread" : "all"}
              />
            }
          />
          <Action
            title="Mark All as Read"
            icon={Icon.CheckCircle}
            shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
            onAction={() => markAllUrisReadByConnection(connection.id, connection.name, revalidate)}
          />
          <Action.Push
            title="View Feeds"
            icon={Icon.List}
            shortcut={{ modifiers: ["cmd"], key: "f" }}
            target={<FeedList connectionId={connection.id} connectionName={connection.name} />}
          />
          <Action.Push
            title="Add Metadata"
            icon={Icon.Plus}
            shortcut={{ modifiers: ["cmd"], key: "m" }}
            target={
              <AddMetadataForm connectionId={connection.id} connectionName={connection.name} revalidate={revalidate} />
            }
          />
          <Action.Push
            title="Edit Connection"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<ConnectionEditForm connection={connection} revalidate={revalidate} />}
          />
          <Action.Push
            title="Refresh from Website"
            icon={Icon.ArrowClockwise}
            shortcut={{ modifiers: ["cmd"], key: "r" }}
            target={<ConnectionRefreshMetadata connection={connection} revalidate={revalidate} />}
          />
          <Action
            title={showDetail ? "Hide Details" : "Show Details"}
            icon={showDetail ? Icon.EyeDisabled : Icon.Eye}
            shortcut={{ modifiers: ["cmd"], key: "d" }}
            onAction={onToggleDetail}
          />
          <Action.Push
            title="Create Connection"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<ConnectionCreateForm revalidate={revalidate} />}
          />
          <Action.Push
            title="Import from OPML"
            icon={Icon.Download}
            shortcut={{ modifiers: ["cmd", "shift"], key: "i" }}
            target={<ImportOpml revalidate={revalidate} />}
          />
          <Action
            title="Delete"
            icon={Icon.Trash}
            style={Action.Style.Destructive}
            onAction={deleteConnection}
            shortcut={Keyboard.Shortcut.Common.Remove}
          />
        </ActionPanel>
      }
    />
  );
}
