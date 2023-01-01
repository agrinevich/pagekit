CREATE TABLE IF NOT EXISTS 'lang' (
    'id'      INTEGER PRIMARY KEY,
    'isocode' TEXT NOT NULL,
    'nick'    TEXT NOT NULL
);
INSERT INTO 'lang' ('isocode','nick') VALUES ('en','');

CREATE TABLE IF NOT EXISTS 'page' (
    'id'        INTEGER PRIMARY KEY,
    'parent_id' INT NOT NULL,
    'nick'      TEXT NOT NULL,
    'name'      TEXT NOT NULL,
    'path'      TEXT NOT NULL
);
INSERT INTO 'page' ('parent_id','nick','name','path') VALUES (0,'','Home','');

CREATE TABLE IF NOT EXISTS 'pagemark' (
    'id'      INTEGER PRIMARY KEY,
    'page_id' INT NOT NULL,
    'lang_id' INT NOT NULL,
    'name'    TEXT NOT NULL,
    'value'   TEXT NOT NULL
);
INSERT INTO 'pagemark' ('page_id','lang_id','name','value') VALUES (1,1,'page_title','Home Page');
INSERT INTO 'pagemark' ('page_id','lang_id','name','value') VALUES (1,1,'page_descr','This is my site - welcome!');
INSERT INTO 'pagemark' ('page_id','lang_id','name','value') VALUES (1,1,'page_main','<h1>Hello</h1><p>Welcome.</p>');
