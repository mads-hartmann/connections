let content =
  {|-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Persons table
CREATE TABLE IF NOT EXISTS persons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);

-- Person-Category junction table
CREATE TABLE IF NOT EXISTS person_categories (
  person_id INTEGER NOT NULL,
  category_id INTEGER NOT NULL,
  PRIMARY KEY (person_id, category_id),
  FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
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

-- Indexes for articles table
CREATE INDEX IF NOT EXISTS idx_articles_feed_id ON articles(feed_id);
CREATE INDEX IF NOT EXISTS idx_articles_read_at ON articles(read_at)|}
