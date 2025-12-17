-- Create DbSecurity.UserAuthorization
CREATE TABLE DbSecurity.UserAuthorization (
    UserAuthorizationKey   INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_UserAuthorization PRIMARY KEY,

    WorkflowClassTime        [Udt].[WorkflowClassTime] NULL
        CONSTRAINT DF_UserAuthorization_WorkflowClassTime DEFAULT ('10:45'),

    IndividualProject        NVARCHAR(60) NULL
        CONSTRAINT DF_UserAuthorization_IndividualProject DEFAULT ('PROJECT 3'),

    GroupMemberLastName  [Udt].[LastName] NOT NULL,
    GroupMemberFirstName  [Udt].[FirstName] NOT NULL,

    GroupName                NVARCHAR(20) NOT NULL
        CONSTRAINT DF_UserAuthorization_GroupName DEFAULT ('Group 2'),

    DateAdded         [Udt].[DateAdded] NOT NULL
        CONSTRAINT DF_UserAuthorization_DateAdded DEFAULT (SYSDATETIME()),

    DateOfLastUpdate      [Udt].[DateOfLastUpdate] NOT NULL
        CONSTRAINT DF_UserAuthorization_DateOfLastUpdate DEFAULT (SYSDATETIME())
);
GO