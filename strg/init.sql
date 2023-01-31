CREATE TABLE IF NOT EXISTS 'lang' (
    'id'      INTEGER PRIMARY KEY,
    'isocode' CHAR(2) NOT NULL DEFAULT '',
    'nick'    CHAR(3) NOT NULL DEFAULT ''
);
INSERT INTO 'lang' ('isocode','nick') VALUES ('en','');

CREATE TABLE IF NOT EXISTS 'mod' (
    'id'      INTEGER PRIMARY KEY,
    'app'     VARCHAR(255) NOT NULL DEFAULT '',
    'name'    VARCHAR(255) NOT NULL DEFAULT ''
);
INSERT INTO 'mod' ('app','name') VALUES ('admin','note');
-- ALTER TABLE 'page' ADD 'mod_id' INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS 'page' (
    'id'        INTEGER PRIMARY KEY,
    'hidden'    INT NOT NULL DEFAULT 0,
    'prio'      INT NOT NULL DEFAULT 0,
    'parent_id' INT NOT NULL DEFAULT 0,
    'mod_id'    INT NOT NULL DEFAULT 0,
    'nick'      VARCHAR(255) NOT NULL DEFAULT '',
    'name'      VARCHAR(255) NOT NULL DEFAULT '',
    'path'      VARCHAR(255) NOT NULL DEFAULT ''
);
INSERT INTO 'page' ('hidden','prio','parent_id','mod_id','nick','name','path') VALUES (0, 0, 0, 0, '', 'Home', '');
-- ALTER TABLE 'page' ADD 'hidden' INT NOT NULL DEFAULT 0;
-- ALTER TABLE 'page' ADD 'prio' INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS 'pagemark' (
    'id'      INTEGER PRIMARY KEY,
    'page_id' INT NOT NULL DEFAULT 0,
    'lang_id' INT NOT NULL DEFAULT 0,
    'name'    VARCHAR(255) NOT NULL DEFAULT '',
    'value'   TEXT NOT NULL DEFAULT ''
);
INSERT INTO 'pagemark' ('page_id','lang_id','name','value') VALUES (1,1,'page_title','Home Page');
INSERT INTO 'pagemark' ('page_id','lang_id','name','value') VALUES (1,1,'page_name','Home');
INSERT INTO 'pagemark' ('page_id','lang_id','name','value') VALUES (1,1,'page_descr','This is page meta description.');
INSERT INTO 'pagemark' ('page_id','lang_id','name','value') VALUES (1,1,'page_main','<h1>Hello</h1><p>Welcome to page text.</p>');

CREATE TABLE note (
  `id`      INTEGER PRIMARY KEY,
  `page_id` INT NOT NULL DEFAULT 0,
  `hidden`  INT NOT NULL DEFAULT 0,
  `prio`    INT NOT NULL DEFAULT 0,
  `added`   INT NOT NULL DEFAULT 0,
  `nick`    VARCHAR(255) NOT NULL DEFAULT '',
  `price`   FLOAT(12,2) NOT NULL DEFAULT 0
);
CREATE INDEX note_idx ON note(`page_id`);

CREATE TABLE note_version (
  `id`      INTEGER PRIMARY KEY,
  `note_id` INT NOT NULL DEFAULT 0,
  `lang_id` INT NOT NULL DEFAULT 0,
  `name`     VARCHAR(255) NOT NULL DEFAULT '',
  `p_title`  VARCHAR(255) NOT NULL DEFAULT '',
  `p_descr`  VARCHAR(255) NOT NULL DEFAULT '',
  `descr`    TEXT NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX noteversion_idx ON note_version(`note_id`, `lang_id`);

CREATE TABLE note_image (
  `id`      INTEGER PRIMARY KEY,
  `note_id` INT NOT NULL DEFAULT 0,
  `num`     INT NOT NULL DEFAULT 0,
  `path_sm` VARCHAR(255) NOT NULL DEFAULT '',
  `path_la` VARCHAR(255) NOT NULL DEFAULT ''
);
CREATE INDEX noteimage_idx ON note_image(`note_id`);
