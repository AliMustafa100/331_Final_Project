USE QueensClassSchedule;
GO

IF OBJECT_ID('Process.WorkflowSteps', 'U') IS NOT NULL
    DROP TABLE Process.WorkflowSteps;
GO

CREATE TABLE Process.WorkflowSteps (
    WorkflowStepKey INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_WorkflowSteps PRIMARY KEY,

    WorkflowStepDescription NVARCHAR(100) NOT NULL,

    WorkflowStepTableRowCount INT NULL
        CONSTRAINT DF_WorkflowSteps_RowCount DEFAULT (0),

StartingDateTime DATETIME2(0) NULL
    CONSTRAINT DF_WorkflowSteps_Start DEFAULT (SYSDATETIME()),

EndingDateTime DATETIME2(0) NULL
    CONSTRAINT DF_WorkflowSteps_End DEFAULT (SYSDATETIME()),


    WorkflowClassTime [Udt].[WorkflowClassTime] NULL
        CONSTRAINT DF_WorkflowSteps_ClassTime DEFAULT ('10:45'),

    UserAuthorizationKey INT NOT NULL,

    DateAdded [Udt].[DateAdded] NOT NULL
        CONSTRAINT DF_WorkflowSteps_DateAdded DEFAULT (SYSDATETIME()),

    DateOfLastUpdate [Udt].[DateOfLastUpdate] NOT NULL
        CONSTRAINT DF_WorkflowSteps_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT FK_WorkflowSteps_UserAuthorization
        FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO
