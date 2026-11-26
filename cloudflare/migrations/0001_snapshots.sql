CREATE TABLE snapshots (
  space TEXT NOT NULL,
  device TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  data TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (space, device)
);
