/*==============================================================
  File: 03_CreateTables.sql
  Purpose:
    - Create core production tables using DDL
    - Uses UDTs from 01_UDTs.sql
==============================================================*/

USE QueensClassSchedule;
GO

/*==============================================================
  0) Ensure schemas exist
==============================================================*/
IF SCHEMA_ID('DbSecurity') IS NULL EXEC('CREATE SCHEMA DbSecurity');
IF SCHEMA_ID('Faculty')   IS NULL EXEC('CREATE SCHEMA Faculty');
IF SCHEMA_ID('Location')  IS NULL EXEC('CREATE SCHEMA Location');
IF SCHEMA_ID('Schedule')  IS NULL EXEC('CREATE SCHEMA Schedule');
IF SCHEMA_ID('Process')   IS NULL EXEC('CREATE SCHEMA Process');
GO

/*==============================================================
  1) Drop tables (drop child first then parents)
==============================================================*/
IF OBJECT_ID('Schedule.Time', 'U') IS NOT NULL DROP TABLE Schedule.Time;
IF OBJECT_ID('Schedule.Class', 'U') IS NOT NULL DROP TABLE Schedule.Class;
IF OBJECT_ID('Schedule.ModeOfInstruction', 'U') IS NOT NULL DROP TABLE Schedule.ModeOfInstruction;
IF OBJECT_ID('Schedule.Course', 'U') IS NOT NULL DROP TABLE Schedule.Course;

IF OBJECT_ID('Location.Room', 'U') IS NOT NULL DROP TABLE Location.Room;
IF OBJECT_ID('Location.Building', 'U') IS NOT NULL DROP TABLE Location.Building;

IF OBJECT_ID('Faculty.MultiDepartmentInstructors', 'U') IS NOT NULL DROP TABLE Faculty.MultiDepartmentInstructors;
IF OBJECT_ID('Faculty.Instructor', 'U') IS NOT NULL DROP TABLE Faculty.Instructor;
IF OBJECT_ID('Faculty.Department', 'U') IS NOT NULL DROP TABLE Faculty.Department;

IF OBJECT_ID('Process.WorkflowSteps', 'U') IS NOT NULL DROP TABLE Process.WorkflowSteps;
IF OBJECT_ID('DbSecurity.UserAuthorization', 'U') IS NOT NULL DROP TABLE DbSecurity.UserAuthorization;
GO

/*==============================================================
  2) DbSecurity.UserAuthorization
==============================================================*/
CREATE TABLE DbSecurity.UserAuthorization
(
    UserAuthorizationKey     INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_UserAuthorization PRIMARY KEY,

    ClassTime                Udt.WorkflowClassTime NULL
        CONSTRAINT DF_UserAuthorization_ClassTime DEFAULT ('10:45'),

    IndividualProject        NVARCHAR(60) NULL
        CONSTRAINT DF_UserAuthorization_IndividualProject DEFAULT ('PROJECT 3'),

    GroupMemberLastName      Udt.LastName NOT NULL,
    GroupMemberFirstName     Udt.FirstName NOT NULL,

    GroupName                NVARCHAR(20) NOT NULL
        CONSTRAINT DF_UserAuthorization_GroupName DEFAULT ('Group 2'),

    DateAdded                Udt.DateAdded NOT NULL
        CONSTRAINT DF_UserAuthorization_DateAdded DEFAULT (SYSDATETIME()),

    DateOfLastUpdate         Udt.DateOfLastUpdate NOT NULL
        CONSTRAINT DF_UserAuthorization_DateOfLastUpdate DEFAULT (SYSDATETIME())
);
GO

/*==============================================================
  3) Faculty.Department
==============================================================*/
CREATE TABLE Faculty.Department
(
    DepartmentId           INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Department PRIMARY KEY,

    DepartmentName         NVARCHAR(50) NOT NULL,
    DepartmentCode         NVARCHAR(50) NOT NULL,

    UserAuthorizationKey   INT NOT NULL,
    DateAdded              Udt.DateAdded NOT NULL CONSTRAINT DF_Department_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate       Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_Department_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT UQ_Department_DepartmentCode UNIQUE (DepartmentCode),
    CONSTRAINT FK_Department_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO

/*==============================================================
  4) Faculty.Instructor  (FullName must be computed & persisted)
==============================================================*/
CREATE TABLE Faculty.Instructor
(
    InstructorID         INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Instructor PRIMARY KEY,

    InstructorFirstName  Udt.FirstName NOT NULL,
    InstructorLastName   Udt.LastName NOT NULL,

    -- Spec: derived column, persisted
    InstructorFullName AS (
        CONVERT(NVARCHAR(80),
            CONCAT(InstructorLastName, ', ', InstructorFirstName)
        )
    ) PERSISTED,

    UserAuthorizationKey INT NOT NULL,
    DateAdded            Udt.DateAdded NOT NULL CONSTRAINT DF_Instructor_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate     Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_Instructor_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT FK_Instructor_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO

/*==============================================================
  5) Faculty.MultiDepartmentInstructors  (bridge table)
==============================================================*/
CREATE TABLE Faculty.MultiDepartmentInstructors
(
    InstructorID         INT NOT NULL,
    DepartmentId         INT NOT NULL,

    UserAuthorizationKey INT NOT NULL,
    DateAdded            Udt.DateAdded NOT NULL CONSTRAINT DF_MDI_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate     Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_MDI_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_MultiDepartmentInstructors PRIMARY KEY (InstructorID, DepartmentId),

    CONSTRAINT FK_MDI_Instructor FOREIGN KEY (InstructorID)
        REFERENCES Faculty.Instructor(InstructorID),

    CONSTRAINT FK_MDI_Department FOREIGN KEY (DepartmentId)
        REFERENCES Faculty.Department(DepartmentId),

    CONSTRAINT FK_MDI_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO

/*==============================================================
  6) Location.Building
==============================================================*/
CREATE TABLE Location.Building
(
    BuildingId           INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Building PRIMARY KEY,

    BuildingName         NVARCHAR(50) NOT NULL,
    BuildingCode         Udt.BuildingCode NOT NULL,

    UserAuthorizationKey INT NOT NULL,
    DateAdded            Udt.DateAdded NOT NULL CONSTRAINT DF_Building_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate     Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_Building_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT UQ_Building_BuildingCode UNIQUE (BuildingCode),

    CONSTRAINT FK_Building_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO

/*==============================================================
  7) Location.Room
==============================================================*/
CREATE TABLE Location.Room
(
    RoomID               INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Room PRIMARY KEY,

    BuildingId           INT NOT NULL,
    RoomNumber           Udt.RoomCode NOT NULL,

    UserAuthorizationKey INT NOT NULL,
    DateAdded            Udt.DateAdded NOT NULL CONSTRAINT DF_Room_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate     Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_Room_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    -- unique room within a building
    CONSTRAINT UQ_Room_Building_RoomNumber UNIQUE (BuildingId, RoomNumber),

    CONSTRAINT FK_Room_Building FOREIGN KEY (BuildingId)
        REFERENCES Location.Building(BuildingId),

    CONSTRAINT FK_Room_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO

/*==============================================================
  8) Schedule.ModeOfInstruction
==============================================================*/
CREATE TABLE Schedule.ModeOfInstruction
(
    ModeOfInstructionID     INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_ModeOfInstruction PRIMARY KEY,

    ModeOfInstructionName   Udt.ModeName NOT NULL,

    UserAuthorizationKey    INT NOT NULL,
    DateAdded               Udt.DateAdded NOT NULL CONSTRAINT DF_MOI_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate        Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_MOI_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT UQ_ModeOfInstruction_Name UNIQUE (ModeOfInstructionName),

    CONSTRAINT FK_MOI_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO

/*==============================================================
  9) Schedule.Course  (Course is a parent of Class)
==============================================================*/
CREATE TABLE Schedule.Course
(
    CourseID             INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Course PRIMARY KEY,

    DepartmentId         INT NOT NULL,

    CourseNumber         Udt.CourseCode NOT NULL,
    CourseDescription    Udt.CourseTitle NOT NULL,

    Credits              Udt.CreditValue NOT NULL,
    Hours                Udt.ContactHours NOT NULL,

    UserAuthorizationKey INT NOT NULL,
    DateAdded            Udt.DateAdded NOT NULL CONSTRAINT DF_Course_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate     Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_Course_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT UQ_Course_CourseNumber UNIQUE (CourseNumber),

    CONSTRAINT FK_Course_Department FOREIGN KEY (DepartmentId)
        REFERENCES Faculty.Department(DepartmentId),

    CONSTRAINT FK_Course_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey),

    -- basic domain checks (safe, high-value)
    CONSTRAINT CK_Course_Credits_Range CHECK (Credits BETWEEN 0 AND 10),
    CONSTRAINT CK_Course_Hours_Range CHECK (Hours BETWEEN 0 AND 30)
);
GO

/*==============================================================
  10) Schedule.Class
==============================================================*/
CREATE TABLE Schedule.Class
(
    ClassID              INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Class PRIMARY KEY,

    CourseID             INT NOT NULL,
    ClassCode            Udt.ClassCode NOT NULL,
    SectionNumber        Udt.SectionNumber NOT NULL,

    Enrolled             Udt.EnrollmentCount NOT NULL,
    ClassLimit           Udt.ClassLimit NOT NULL,

    ModeOfInstructionID  INT NOT NULL,
    RoomID               INT NOT NULL,
    InstructorID         INT NOT NULL,

    UserAuthorizationKey INT NOT NULL,
    DateAdded            Udt.DateAdded NOT NULL CONSTRAINT DF_Class_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate     Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_Class_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT UQ_Class_ClassCode UNIQUE (ClassCode),

    CONSTRAINT FK_Class_Course FOREIGN KEY (CourseID)
        REFERENCES Schedule.Course(CourseID),

    CONSTRAINT FK_Class_ModeOfInstruction FOREIGN KEY (ModeOfInstructionID)
        REFERENCES Schedule.ModeOfInstruction(ModeOfInstructionID),

    CONSTRAINT FK_Class_Room FOREIGN KEY (RoomID)
        REFERENCES Location.Room(RoomID),

    CONSTRAINT FK_Class_Instructor FOREIGN KEY (InstructorID)
        REFERENCES Faculty.Instructor(InstructorID),

    CONSTRAINT FK_Class_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey),

    -- business rules (core)
    CONSTRAINT CK_Class_Enrolled_NonNegative CHECK (Enrolled >= 0),
    CONSTRAINT CK_Class_Limit_Positive CHECK (ClassLimit > 0),
    CONSTRAINT CK_Class_Enrolled_LTE_Limit CHECK (Enrolled <= ClassLimit)
);
GO

/*==============================================================
  11) Schedule.Time  (meeting instances for a class)
==============================================================*/
CREATE TABLE Schedule.Time
(
    ScheduleID           INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_ScheduleTime PRIMARY KEY,

    ClassID              INT NOT NULL,

    Days                 Udt.DayPattern NOT NULL,
    SessionStart         Udt.ClassStartTime NOT NULL,
    SessionEnd           Udt.ClassEndTime NOT NULL,

    SemesterAvailability Udt.SemesterName NOT NULL,

    UserAuthorizationKey INT NOT NULL,
    DateAdded            Udt.DateAdded NOT NULL CONSTRAINT DF_Time_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate     Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_Time_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT FK_Time_Class FOREIGN KEY (ClassID)
        REFERENCES Schedule.Class(ClassID),

    CONSTRAINT FK_Time_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey),

    CONSTRAINT CK_Time_Start_LT_End CHECK (SessionStart < SessionEnd)
);
GO

/*==============================================================
  12) Process.WorkflowSteps (workflow logging)
==============================================================*/
CREATE TABLE Process.WorkflowSteps
(
    WorkFlowStepKey           INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_WorkflowSteps PRIMARY KEY,

    WorkFlowStepDescription   NVARCHAR(100) NOT NULL,
    WorkFlowStepTableRowCount INT NULL CONSTRAINT DF_WorkflowSteps_RowCount DEFAULT (0),

    StartingDateTime          DATETIME2(0) NULL CONSTRAINT DF_WorkflowSteps_Start DEFAULT (SYSDATETIME()),
    EndingDateTime            DATETIME2(0) NULL CONSTRAINT DF_WorkflowSteps_End DEFAULT (SYSDATETIME()),

    ClassTime                 Udt.WorkflowClassTime NULL CONSTRAINT DF_WorkflowSteps_ClassTime DEFAULT ('10:45'),

    UserAuthorizationKey      INT NOT NULL,

    DateAdded                 Udt.DateAdded NOT NULL CONSTRAINT DF_WorkflowSteps_DateAdded DEFAULT (SYSDATETIME()),
    DateOfLastUpdate          Udt.DateOfLastUpdate NOT NULL CONSTRAINT DF_WorkflowSteps_DateOfLastUpdate DEFAULT (SYSDATETIME()),

    CONSTRAINT FK_WorkflowSteps_UserAuthorization FOREIGN KEY (UserAuthorizationKey)
        REFERENCES DbSecurity.UserAuthorization(UserAuthorizationKey)
);
GO
