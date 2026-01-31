import { Icon, MenuBarExtra, open, launchCommand, LaunchType, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Uri from "./api/uri";
import { markAllUrisRead } from "./actions/uri-actions";

export default function Command() {
  const { isLoading, data, error, revalidate } = useFetch<Uri.UrisResponse>(Uri.listAllUrl({ page: 1, unread: true }), {
    keepPreviousData: true,
  });

  const unreadCount = data?.total ?? 0;
  const recentUris = data?.data.slice(0, 5) ?? [];

  const handleUriClick = async (uri: Uri.Uri) => {
    try {
      await Uri.markUriRead(uri.id, true);
      revalidate();
    } catch {
      await showToast({ style: Toast.Style.Failure, title: "Failed to mark as read" });
    }
    await open(uri.url);
  };

  const title = error || unreadCount === 0 ? undefined : String(unreadCount);

  return (
    <MenuBarExtra icon={Icon.Person} title={title} isLoading={isLoading}>
      {error ? (
        <MenuBarExtra.Item title={`Error: ${error.message}`} onAction={() => revalidate()} />
      ) : (
        <>
          <MenuBarExtra.Section title="Recent Unread">
            {recentUris.length === 0 ? (
              <MenuBarExtra.Item title="No unread URIs" />
            ) : (
              recentUris.map((uri) => (
                <MenuBarExtra.Item
                  key={uri.id}
                  title={uri.title ?? uri.url}
                  subtitle={uri.author ?? undefined}
                  onAction={() => handleUriClick(uri)}
                />
              ))
            )}
          </MenuBarExtra.Section>

          <MenuBarExtra.Section>
            {unreadCount > 0 && (
              <MenuBarExtra.Item
                title="Mark All as Read"
                icon={Icon.CheckCircle}
                shortcut={{ modifiers: ["cmd", "shift"], key: "m" }}
                onAction={() => markAllUrisRead(revalidate)}
              />
            )}
            <MenuBarExtra.Item
              title="Open Connections"
              icon={Icon.AppWindow}
              shortcut={{ modifiers: ["cmd"], key: "o" }}
              onAction={() => launchCommand({ name: "connections", type: LaunchType.UserInitiated })}
            />
            <MenuBarExtra.Item
              title="Refresh"
              icon={Icon.ArrowClockwise}
              shortcut={{ modifiers: ["cmd"], key: "r" }}
              onAction={() => revalidate()}
            />
          </MenuBarExtra.Section>
        </>
      )}
    </MenuBarExtra>
  );
}
