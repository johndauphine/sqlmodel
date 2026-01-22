BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 5130d337f062

CREATE TABLE dw__stackoverflow2010__dbo.comments (
    id SERIAL NOT NULL, 
    creationdate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    postid INTEGER NOT NULL, 
    "Text" VARCHAR(700) NOT NULL, 
    score INTEGER, 
    userid INTEGER, 
    CONSTRAINT comments_pkey PRIMARY KEY (id)
);

CREATE TABLE dw__stackoverflow2010__dbo.posts (
    id SERIAL NOT NULL, 
    body TEXT NOT NULL, 
    creationdate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    lastactivitydate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    posttypeid INTEGER NOT NULL, 
    score INTEGER NOT NULL, 
    viewcount INTEGER NOT NULL, 
    acceptedanswerid INTEGER, 
    answercount INTEGER, 
    closeddate TIMESTAMP WITHOUT TIME ZONE, 
    commentcount INTEGER, 
    communityowneddate TIMESTAMP WITHOUT TIME ZONE, 
    favoritecount INTEGER, 
    lasteditdate TIMESTAMP WITHOUT TIME ZONE, 
    lasteditordisplayname VARCHAR(40), 
    lasteditoruserid INTEGER, 
    owneruserid INTEGER, 
    parentid INTEGER, 
    tags VARCHAR(150), 
    title VARCHAR(250), 
    CONSTRAINT posts_pkey PRIMARY KEY (id)
);

CREATE TABLE dw__stackoverflow2010__dbo.users (
    id SERIAL NOT NULL, 
    creationdate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    displayname VARCHAR(40) NOT NULL, 
    downvotes INTEGER NOT NULL, 
    lastaccessdate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    reputation INTEGER NOT NULL, 
    upvotes INTEGER NOT NULL, 
    views INTEGER NOT NULL, 
    aboutme TEXT, 
    age INTEGER, 
    emailhash VARCHAR(40), 
    location VARCHAR(100), 
    websiteurl VARCHAR(200), 
    accountid INTEGER, 
    CONSTRAINT users_pkey PRIMARY KEY (id)
);

INSERT INTO alembic_version (version_num) VALUES ('5130d337f062') RETURNING alembic_version.version_num;

COMMIT;

