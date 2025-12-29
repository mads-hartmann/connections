-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Persons table
CREATE TABLE IF NOT EXISTS persons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  profile_image_url TEXT,
  metadata_updated_at TEXT
);

-- Tags table
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);

-- Person-Tag junction table
CREATE TABLE IF NOT EXISTS person_tags (
  person_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (person_id, tag_id),
  FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- RSS feeds table
CREATE TABLE IF NOT EXISTS rss_feeds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id INTEGER NOT NULL,
  url TEXT NOT NULL,
  title TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_fetched_at TEXT,
  FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE RESTRICT,
  UNIQUE(person_id, url)
);

-- Feed-Tag junction table
CREATE TABLE IF NOT EXISTS feed_tags (
  feed_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (feed_id, tag_id),
  FOREIGN KEY (feed_id) REFERENCES rss_feeds(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Articles table
CREATE TABLE IF NOT EXISTS articles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  feed_id INTEGER NOT NULL,
  title TEXT,
  url TEXT NOT NULL,
  published_at TEXT,
  content TEXT,
  author TEXT,
  image_url TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  read_at TEXT,
  og_title TEXT,
  og_description TEXT,
  og_image TEXT,
  og_site_name TEXT,
  og_fetched_at TEXT,
  og_fetch_error TEXT,
  FOREIGN KEY (feed_id) REFERENCES rss_feeds(id) ON DELETE CASCADE,
  UNIQUE(feed_id, url)
);

-- Article-Tag junction table
CREATE TABLE IF NOT EXISTS article_tags (
  article_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (article_id, tag_id),
  FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Indexes for articles table
CREATE INDEX IF NOT EXISTS idx_articles_feed_id ON articles(feed_id);
CREATE INDEX IF NOT EXISTS idx_articles_read_at ON articles(read_at);
CREATE INDEX IF NOT EXISTS idx_articles_og_fetched_at ON articles(og_fetched_at);

-- Indexes for tag lookups
CREATE INDEX IF NOT EXISTS idx_person_tags_person_id ON person_tags(person_id);
CREATE INDEX IF NOT EXISTS idx_person_tags_tag_id ON person_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_feed_tags_feed_id ON feed_tags(feed_id);
CREATE INDEX IF NOT EXISTS idx_feed_tags_tag_id ON feed_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_article_tags_article_id ON article_tags(article_id);
CREATE INDEX IF NOT EXISTS idx_article_tags_tag_id ON article_tags(tag_id);

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

-- Person metadata
CREATE TABLE IF NOT EXISTS person_metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id INTEGER NOT NULL,
  field_type_id INTEGER NOT NULL,
  value TEXT NOT NULL,
  FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
  FOREIGN KEY (field_type_id) REFERENCES metadata_field_types(id)
);

CREATE INDEX IF NOT EXISTS idx_person_metadata_person_id ON person_metadata(person_id);
