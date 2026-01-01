import { MenuBarExtra, open, launchCommand, LaunchType } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Article from "./api/article";

const REFRESH_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes

export default function Command() {
  const {
    isLoading,
    data,
    error,
    revalidate,
  } = useFetch<Article.ArticlesResponse>(
    Article.listAllUrl({ page: 1, unread: true }),
    {
      keepPreviousData: true,
    }
  );

  const unreadCount = data?.total ?? 0;
  const recentArticles = data?.data.slice(0, 5) ?? [];

  // Set up periodic refresh
  useFetch(Article.listAllUrl({ page: 1, unread: true }), {
    execute: false,
    onData: () => revalidate(),
  });

  // Manual interval for background refresh
  if (typeof window !== "undefined") {
    setInterval(() => revalidate(), REFRESH_INTERVAL_MS);
  }

  const title = error ? undefined : String(unreadCount);

  return (
    <MenuBarExtra
      icon="extension-icon.png"
      title={title}
      isLoading={isLoading}
    >
      {error ? (
        <MenuBarExtra.Item
          title={`Error: ${error.message}`}
          onAction={() => revalidate()}
        />
      ) : (
        <>
          <MenuBarExtra.Section title="Recent Unread">
            {recentArticles.length === 0 ? (
              <MenuBarExtra.Item title="No unread articles" />
            ) : (
              recentArticles.map((article) => (
                <MenuBarExtra.Item
                  key={article.id}
                  title={article.title ?? article.url}
                  subtitle={article.author ?? undefined}
                  onAction={() => open(article.url)}
                />
              ))
            )}
          </MenuBarExtra.Section>

          <MenuBarExtra.Section>
            <MenuBarExtra.Item
              title="Open Connections"
              shortcut={{ modifiers: ["cmd"], key: "o" }}
              onAction={() =>
                launchCommand({ name: "connections", type: LaunchType.UserInitiated })
              }
            />
            <MenuBarExtra.Item
              title="Refresh"
              shortcut={{ modifiers: ["cmd"], key: "r" }}
              onAction={() => revalidate()}
            />
          </MenuBarExtra.Section>
        </>
      )}
    </MenuBarExtra>
  );
}
