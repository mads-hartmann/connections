-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Connections table (formerly persons)
CREATE TABLE IF NOT EXISTS connections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  photo TEXT
);

-- Tags table
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);

-- Connection-Tag junction table (formerly person_tags)
CREATE TABLE IF NOT EXISTS connection_tags (
  connection_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (connection_id, tag_id),
  FOREIGN KEY (connection_id) REFERENCES connections(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- RSS feeds table
CREATE TABLE IF NOT EXISTS rss_feeds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  connection_id INTEGER NOT NULL,
  url TEXT NOT NULL,
  title TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_fetched_at TEXT,
  FOREIGN KEY (connection_id) REFERENCES connections(id) ON DELETE RESTRICT,
  UNIQUE(connection_id, url)
);

-- Feed-Tag junction table
CREATE TABLE IF NOT EXISTS feed_tags (
  feed_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (feed_id, tag_id),
  FOREIGN KEY (feed_id) REFERENCES rss_feeds(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- URI kinds enum table
CREATE TABLE IF NOT EXISTS uri_kinds (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

-- Seed URI kinds
INSERT OR IGNORE INTO uri_kinds (id, name) VALUES
  (1, 'blog'),
  (2, 'video'),
  (3, 'tweet'),
  (4, 'book'),
  (5, 'site'),
  (6, 'unknown'),
  (7, 'podcast'),
  (8, 'paper');

-- URIs table (formerly articles)
CREATE TABLE IF NOT EXISTS uris (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  feed_id INTEGER,
  connection_id INTEGER,
  kind_id INTEGER NOT NULL DEFAULT 6,
  title TEXT,
  url TEXT NOT NULL,
  published_at TEXT,
  content TEXT,
  author TEXT,
  image_url TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  read_at TEXT,
  read_later_at TEXT,
  og_title TEXT,
  og_description TEXT,
  og_image TEXT,
  og_site_name TEXT,
  og_fetched_at TEXT,
  og_fetch_error TEXT,
  FOREIGN KEY (feed_id) REFERENCES rss_feeds(id) ON DELETE CASCADE,
  FOREIGN KEY (connection_id) REFERENCES connections(id) ON DELETE SET NULL,
  FOREIGN KEY (kind_id) REFERENCES uri_kinds(id)
);

-- Unique constraint: URL must be unique per feed (for RSS-discovered URIs)
-- For manual URIs (feed_id IS NULL), URL must be globally unique
CREATE UNIQUE INDEX IF NOT EXISTS idx_uris_feed_url ON uris(feed_id, url) WHERE feed_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_uris_url_no_feed ON uris(url) WHERE feed_id IS NULL;

-- URI-Tag junction table (formerly article_tags)
CREATE TABLE IF NOT EXISTS uri_tags (
  uri_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (uri_id, tag_id),
  FOREIGN KEY (uri_id) REFERENCES uris(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Indexes for uris table
CREATE INDEX IF NOT EXISTS idx_uris_feed_id ON uris(feed_id);
CREATE INDEX IF NOT EXISTS idx_uris_connection_id ON uris(connection_id);
CREATE INDEX IF NOT EXISTS idx_uris_read_at ON uris(read_at);
CREATE INDEX IF NOT EXISTS idx_uris_read_later_at ON uris(read_later_at);
CREATE INDEX IF NOT EXISTS idx_uris_og_fetched_at ON uris(og_fetched_at);
CREATE INDEX IF NOT EXISTS idx_uris_kind_id ON uris(kind_id);

-- Indexes for tag lookups
CREATE INDEX IF NOT EXISTS idx_connection_tags_connection_id ON connection_tags(connection_id);
CREATE INDEX IF NOT EXISTS idx_connection_tags_tag_id ON connection_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_feed_tags_feed_id ON feed_tags(feed_id);
CREATE INDEX IF NOT EXISTS idx_feed_tags_tag_id ON feed_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_uri_tags_uri_id ON uri_tags(uri_id);
CREATE INDEX IF NOT EXISTS idx_uri_tags_tag_id ON uri_tags(tag_id);

-- Metadata field types (static lookup table)
CREATE TABLE IF NOT EXISTS metadata_field_types (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

-- Seed metadata field types (alphabetically ordered by name)
INSERT OR IGNORE INTO metadata_field_types (id, name) VALUES
  (1, 'Bluesky'),
  (2, 'Email'),
  (3, 'GitHub'),
  (4, 'LinkedIn'),
  (5, 'Mastodon'),
  (6, 'Website'),
  (7, 'X');

-- Connection metadata (formerly person_metadata)
CREATE TABLE IF NOT EXISTS connection_metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  connection_id INTEGER NOT NULL,
  field_type_id INTEGER NOT NULL,
  value TEXT NOT NULL,
  FOREIGN KEY (connection_id) REFERENCES connections(id) ON DELETE CASCADE,
  FOREIGN KEY (field_type_id) REFERENCES metadata_field_types(id)
);

CREATE INDEX IF NOT EXISTS idx_connection_metadata_connection_id ON connection_metadata(connection_id);

-- Unique constraint for idempotent metadata creation (case-insensitive, trimmed)
CREATE UNIQUE INDEX IF NOT EXISTS idx_connection_metadata_unique
  ON connection_metadata(connection_id, field_type_id, LOWER(TRIM(value)));

-- URI content cache (stores markdown conversion of URI HTML)
CREATE TABLE IF NOT EXISTS uri_content (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uri_id INTEGER NOT NULL UNIQUE,
  markdown TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (uri_id) REFERENCES uris(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_uri_content_uri_id ON uri_content(uri_id);
