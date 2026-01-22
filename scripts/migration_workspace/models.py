from typing import Optional
import datetime

from sqlalchemy import DateTime, Integer, PrimaryKeyConstraint, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass


class Posts(Base):
    __tablename__ = 'posts'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='posts_pkey'),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )

    Id: Mapped[int] = mapped_column('id', Integer, primary_key=True)
    Body: Mapped[str] = mapped_column('body', Text, nullable=False)
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
    LastEditorDisplayName: Mapped[Optional[str]] = mapped_column('lasteditordisplayname', String(40))
    LastEditorUserId: Mapped[Optional[int]] = mapped_column('lasteditoruserid', Integer)
    OwnerUserId: Mapped[Optional[int]] = mapped_column('owneruserid', Integer)
    ParentId: Mapped[Optional[int]] = mapped_column('parentid', Integer)
    Tags: Mapped[Optional[str]] = mapped_column('tags', String(150))
    Title: Mapped[Optional[str]] = mapped_column('title', String(250))


class Users(Base):
    __tablename__ = 'users'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='users_pkey'),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )

    Id: Mapped[int] = mapped_column('id', Integer, primary_key=True)
    CreationDate: Mapped[datetime.datetime] = mapped_column('creationdate', DateTime, nullable=False)
    DisplayName: Mapped[str] = mapped_column('displayname', String(40), nullable=False)
    DownVotes: Mapped[int] = mapped_column('downvotes', Integer, nullable=False)
    LastAccessDate: Mapped[datetime.datetime] = mapped_column('lastaccessdate', DateTime, nullable=False)
    Reputation: Mapped[int] = mapped_column('reputation', Integer, nullable=False)
    UpVotes: Mapped[int] = mapped_column('upvotes', Integer, nullable=False)
    Views: Mapped[int] = mapped_column('views', Integer, nullable=False)
    AboutMe: Mapped[Optional[str]] = mapped_column('aboutme', Text)
    Age: Mapped[Optional[int]] = mapped_column('age', Integer)
    EmailHash: Mapped[Optional[str]] = mapped_column('emailhash', String(40))
    Location: Mapped[Optional[str]] = mapped_column('location', String(100))
    WebsiteUrl: Mapped[Optional[str]] = mapped_column('websiteurl', String(200))
    AccountId: Mapped[Optional[int]] = mapped_column('accountid', Integer)
