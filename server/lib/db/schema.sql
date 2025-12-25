-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Persons table
CREATE TABLE IF NOT EXISTS persons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
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

-- Indexes for tag lookups
CREATE INDEX IF NOT EXISTS idx_person_tags_person_id ON person_tags(person_id);
CREATE INDEX IF NOT EXISTS idx_person_tags_tag_id ON person_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_feed_tags_feed_id ON feed_tags(feed_id);
CREATE INDEX IF NOT EXISTS idx_feed_tags_tag_id ON feed_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_article_tags_article_id ON article_tags(article_id);
CREATE INDEX IF NOT EXISTS idx_article_tags_tag_id ON article_tags(tag_id);
