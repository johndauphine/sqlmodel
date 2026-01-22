from typing import Optional
import datetime

from sqlalchemy import DateTime, Identity, Integer, PrimaryKeyConstraint, Unicode
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass


class Comments(Base):
    __tablename__ = 'comments'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='pk_comments__id'),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )

    Id: Mapped[int] = mapped_column('id', Integer, Identity(start=1, increment=1), primary_key=True)
    CreationDate: Mapped[datetime.datetime] = mapped_column('creationdate', DateTime, nullable=False)
    PostId: Mapped[int] = mapped_column('postid', Integer, nullable=False)
    Text: Mapped[str] = mapped_column('text', Unicode(700, 'SQL_Latin1_General_CP1_CI_AS'), nullable=False)
    Score: Mapped[Optional[int]] = mapped_column('score', Integer)
    UserId: Mapped[Optional[int]] = mapped_column('userid', Integer)


class Posts(Base):
    __tablename__ = 'posts'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='pk_posts__id'),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )

    Id: Mapped[int] = mapped_column('id', Integer, Identity(start=1, increment=1), primary_key=True)
    Body: Mapped[str] = mapped_column('body', Unicode(collation='SQL_Latin1_General_CP1_CI_AS'), nullable=False)
    CreationDate: Mapped[datetime.datetime] = mapped_column('creationdate', DateTime, nullable=False)
    LastActivityDate: Mapped[datetime.datetime] = mapped_column('lastactivitydate', DateTime, nullable=False)
    PostTypeId: Mapped[int] = mapped_column('posttypeid', Integer, nullable=False)
    Score: Mapped[int] = mapped_column('score', Integer, nullable=False)
    ViewCount: Mapped[int] = mapped_column('viewcount', Integer, nullable=False)
    AcceptedAnswerId: Mapped[Optional[int]] = mapped_column('acceptedanswerid', Integer)
    AnswerCount: Mapped[Optional[int]] = mapped_column('answercount', Integer)
    ClosedDate: Mapped[Optional[datetime.datetime]] = mapped_column('closeddate', DateTime)
    CommentCount: Mapped[Optional[int]] = mapped_column('commentcount', Integer)
    CommunityOwnedDate: Mapped[Optional[datetime.datetime]] = mapped_column('communityowneddate', DateTime)
    FavoriteCount: Mapped[Optional[int]] = mapped_column('favoritecount', Integer)
    LastEditDate: Mapped[Optional[datetime.datetime]] = mapped_column('lasteditdate', DateTime)
    LastEditorDisplayName: Mapped[Optional[str]] = mapped_column('lasteditordisplayname', Unicode(40, 'SQL_Latin1_General_CP1_CI_AS'))
    LastEditorUserId: Mapped[Optional[int]] = mapped_column('lasteditoruserid', Integer)
    OwnerUserId: Mapped[Optional[int]] = mapped_column('owneruserid', Integer)
    ParentId: Mapped[Optional[int]] = mapped_column('parentid', Integer)
    Tags: Mapped[Optional[str]] = mapped_column('tags', Unicode(150, 'SQL_Latin1_General_CP1_CI_AS'))
    Title: Mapped[Optional[str]] = mapped_column('title', Unicode(250, 'SQL_Latin1_General_CP1_CI_AS'))


class Users(Base):
    __tablename__ = 'users'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='pk_users_id'),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )

    Id: Mapped[int] = mapped_column('id', Integer, Identity(start=1, increment=1), primary_key=True)
    CreationDate: Mapped[datetime.datetime] = mapped_column('creationdate', DateTime, nullable=False)
    DisplayName: Mapped[str] = mapped_column('displayname', Unicode(40, 'SQL_Latin1_General_CP1_CI_AS'), nullable=False)
    DownVotes: Mapped[int] = mapped_column('downvotes', Integer, nullable=False)
    LastAccessDate: Mapped[datetime.datetime] = mapped_column('lastaccessdate', DateTime, nullable=False)
    Reputation: Mapped[int] = mapped_column('reputation', Integer, nullable=False)
    UpVotes: Mapped[int] = mapped_column('upvotes', Integer, nullable=False)
    Views: Mapped[int] = mapped_column('views', Integer, nullable=False)
    AboutMe: Mapped[Optional[str]] = mapped_column('aboutme', Unicode(collation='SQL_Latin1_General_CP1_CI_AS'))
    Age: Mapped[Optional[int]] = mapped_column('age', Integer)
    EmailHash: Mapped[Optional[str]] = mapped_column('emailhash', Unicode(40, 'SQL_Latin1_General_CP1_CI_AS'))
    Location: Mapped[Optional[str]] = mapped_column('location', Unicode(100, 'SQL_Latin1_General_CP1_CI_AS'))
    WebsiteUrl: Mapped[Optional[str]] = mapped_column('websiteurl', Unicode(200, 'SQL_Latin1_General_CP1_CI_AS'))
    AccountId: Mapped[Optional[int]] = mapped_column('accountid', Integer)
