BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> ff4179b55c6b

CREATE TABLE dw__stackoverflow2010__dbo.badges (
    id SERIAL NOT NULL, 
    userid INTEGER NOT NULL, 
    name VARCHAR(50) NOT NULL, 
    date TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    class INTEGER NOT NULL, 
    tagbased BOOLEAN NOT NULL, 
    CONSTRAINT badges_pkey PRIMARY KEY (id)
);

CREATE TABLE dw__stackoverflow2010__dbo.comments (
    id SERIAL NOT NULL, 
    creationdate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    postid INTEGER NOT NULL, 
    "Text" VARCHAR(700) NOT NULL, 
    score INTEGER, 
    userid INTEGER, 
    CONSTRAINT comments_pkey PRIMARY KEY (id)
);

CREATE TABLE dw__stackoverflow2010__dbo.linktypes (
    id SERIAL NOT NULL, 
    type VARCHAR(50) NOT NULL, 
    CONSTRAINT linktypes_pkey PRIMARY KEY (id)
);

CREATE TABLE dw__stackoverflow2010__dbo.postlinks (
    id SERIAL NOT NULL, 
    postid INTEGER NOT NULL, 
    relatedpostid INTEGER NOT NULL, 
    linktypeid INTEGER NOT NULL, 
    creationdate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    CONSTRAINT postlinks_pkey PRIMARY KEY (id)
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

CREATE TABLE dw__stackoverflow2010__dbo.posttypes (
    id SERIAL NOT NULL, 
    type VARCHAR(50) NOT NULL, 
    CONSTRAINT posttypes_pkey PRIMARY KEY (id)
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

CREATE TABLE dw__stackoverflow2010__dbo.votes (
    id SERIAL NOT NULL, 
    postid INTEGER NOT NULL, 
    votetypeid INTEGER NOT NULL, 
    creationdate TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    userid INTEGER, 
    bountyamount INTEGER, 
    CONSTRAINT votes_pkey PRIMARY KEY (id)
);

CREATE TABLE dw__stackoverflow2010__dbo.votetypes (
    id SERIAL NOT NULL, 
    name VARCHAR(50) NOT NULL, 
    CONSTRAINT votetypes_pkey PRIMARY KEY (id)
);

INSERT INTO alembic_version (version_num) VALUES ('ff4179b55c6b') RETURNING alembic_version.version_num;

COMMIT;

