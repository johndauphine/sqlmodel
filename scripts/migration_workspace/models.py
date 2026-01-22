from typing import Optional
import datetime

from sqlalchemy import DateTime, Identity, Integer, PrimaryKeyConstraint, Unicode
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass


class Comments(Base):
    __tablename__ = 'Comments'
    __table_args__ = (
        PrimaryKeyConstraint('Id', name='PK_Comments__Id'),
        {'schema': 'dbo'}
    )

    Id: Mapped[int] = mapped_column(Integer, Identity(start=1, increment=1), primary_key=True)
    CreationDate: Mapped[datetime.datetime] = mapped_column(DateTime, nullable=False)
    PostId: Mapped[int] = mapped_column(Integer, nullable=False)
    Text: Mapped[str] = mapped_column(Unicode(700, 'SQL_Latin1_General_CP1_CI_AS'), nullable=False)
    Score: Mapped[Optional[int]] = mapped_column(Integer)
    UserId: Mapped[Optional[int]] = mapped_column(Integer)


class Posts(Base):
    __tablename__ = 'Posts'
    __table_args__ = (
        PrimaryKeyConstraint('Id', name='PK_Posts__Id'),
        {'schema': 'dbo'}
    )

    Id: Mapped[int] = mapped_column(Integer, Identity(start=1, increment=1), primary_key=True)
    Body: Mapped[str] = mapped_column(Unicode(collation='SQL_Latin1_General_CP1_CI_AS'), nullable=False)
    CreationDate: Mapped[datetime.datetime] = mapped_column(DateTime, nullable=False)
    LastActivityDate: Mapped[datetime.datetime] = mapped_column(DateTime, nullable=False)
    PostTypeId: Mapped[int] = mapped_column(Integer, nullable=False)
    Score: Mapped[int] = mapped_column(Integer, nullable=False)
    ViewCount: Mapped[int] = mapped_column(Integer, nullable=False)
    AcceptedAnswerId: Mapped[Optional[int]] = mapped_column(Integer)
    AnswerCount: Mapped[Optional[int]] = mapped_column(Integer)
    ClosedDate: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime)
    CommentCount: Mapped[Optional[int]] = mapped_column(Integer)
    CommunityOwnedDate: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime)
    FavoriteCount: Mapped[Optional[int]] = mapped_column(Integer)
    LastEditDate: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime)
    LastEditorDisplayName: Mapped[Optional[str]] = mapped_column(Unicode(40, 'SQL_Latin1_General_CP1_CI_AS'))
    LastEditorUserId: Mapped[Optional[int]] = mapped_column(Integer)
    OwnerUserId: Mapped[Optional[int]] = mapped_column(Integer)
    ParentId: Mapped[Optional[int]] = mapped_column(Integer)
    Tags: Mapped[Optional[str]] = mapped_column(Unicode(150, 'SQL_Latin1_General_CP1_CI_AS'))
    Title: Mapped[Optional[str]] = mapped_column(Unicode(250, 'SQL_Latin1_General_CP1_CI_AS'))


class Users(Base):
    __tablename__ = 'Users'
    __table_args__ = (
        PrimaryKeyConstraint('Id', name='PK_Users_Id'),
        {'schema': 'dbo'}
    )

    Id: Mapped[int] = mapped_column(Integer, Identity(start=1, increment=1), primary_key=True)
    CreationDate: Mapped[datetime.datetime] = mapped_column(DateTime, nullable=False)
    DisplayName: Mapped[str] = mapped_column(Unicode(40, 'SQL_Latin1_General_CP1_CI_AS'), nullable=False)
    DownVotes: Mapped[int] = mapped_column(Integer, nullable=False)
    LastAccessDate: Mapped[datetime.datetime] = mapped_column(DateTime, nullable=False)
    Reputation: Mapped[int] = mapped_column(Integer, nullable=False)
    UpVotes: Mapped[int] = mapped_column(Integer, nullable=False)
    Views: Mapped[int] = mapped_column(Integer, nullable=False)
    AboutMe: Mapped[Optional[str]] = mapped_column(Unicode(collation='SQL_Latin1_General_CP1_CI_AS'))
    Age: Mapped[Optional[int]] = mapped_column(Integer)
    EmailHash: Mapped[Optional[str]] = mapped_column(Unicode(40, 'SQL_Latin1_General_CP1_CI_AS'))
    Location: Mapped[Optional[str]] = mapped_column(Unicode(100, 'SQL_Latin1_General_CP1_CI_AS'))
    WebsiteUrl: Mapped[Optional[str]] = mapped_column(Unicode(200, 'SQL_Latin1_General_CP1_CI_AS'))
    AccountId: Mapped[Optional[int]] = mapped_column(Integer)
