/*==============================================================
  File: 01_UDTs.sql
  Purpose:
    - Create (or recreate) schemas and User-Defined Types (UDTs)
    - Safe to re-run during development (drops dependent tables + UDTs)

  Run Order:
    01_UDTs.sql
    02_DbSecurity_UserAuthorization.sql
    03_Process_WorkflowSteps.sql
    (then Adrain/Adi scripts for production tables + ETL)

==============================================================*/

USE QueensClassSchedule;
GO

/*==============================================================
  1) Drop dependent tables first (child then parent)

==============================================================*/

IF OBJECT_ID('Process.WorkflowSteps', 'U') IS NOT NULL
    DROP TABLE Process.WorkflowSteps;
GO

IF OBJECT_ID('DbSecurity.UserAuthorization', 'U') IS NOT NULL
    DROP TABLE DbSecurity.UserAuthorization;
GO

/*==============================================================
  2) Checking if schemas exist (we need to safely run repeatedley)
==============================================================*/

IF SCHEMA_ID('Udt') IS NULL EXEC('CREATE SCHEMA Udt');
IF SCHEMA_ID('DbSecurity') IS NULL EXEC('CREATE SCHEMA DbSecurity');
IF SCHEMA_ID('Process') IS NULL EXEC('CREATE SCHEMA Process');
GO

/*==============================================================
  3) Drop UDTs (only after dependent tables are dropped)
==============================================================*/

-- Location
IF TYPE_ID('Udt.RoomCode') IS NOT NULL DROP TYPE Udt.RoomCode;
IF TYPE_ID('Udt.BuildingCode') IS NOT NULL DROP TYPE Udt.BuildingCode;

-- Enrollment
IF TYPE_ID('Udt.ClassLimit') IS NOT NULL DROP TYPE Udt.ClassLimit;
IF TYPE_ID('Udt.EnrollmentCount') IS NOT NULL DROP TYPE Udt.EnrollmentCount;

-- Course / org
IF TYPE_ID('Udt.ModeName') IS NOT NULL DROP TYPE Udt.ModeName;
IF TYPE_ID('Udt.ClassCode') IS NOT NULL DROP TYPE Udt.ClassCode;
IF TYPE_ID('Udt.SectionNumber') IS NOT NULL DROP TYPE Udt.SectionNumber;
IF TYPE_ID('Udt.ContactHours') IS NOT NULL DROP TYPE Udt.ContactHours;
IF TYPE_ID('Udt.CreditValue') IS NOT NULL DROP TYPE Udt.CreditValue;
IF TYPE_ID('Udt.CourseTitle') IS NOT NULL DROP TYPE Udt.CourseTitle;
IF TYPE_ID('Udt.CourseCode') IS NOT NULL DROP TYPE Udt.CourseCode;
IF TYPE_ID('Udt.SemesterName') IS NOT NULL DROP TYPE Udt.SemesterName;

-- People
IF TYPE_ID('Udt.FullName') IS NOT NULL DROP TYPE Udt.FullName;
IF TYPE_ID('Udt.FirstName') IS NOT NULL DROP TYPE Udt.FirstName;
IF TYPE_ID('Udt.LastName') IS NOT NULL DROP TYPE Udt.LastName;

-- Meeting pattern / time
IF TYPE_ID('Udt.DayPattern') IS NOT NULL DROP TYPE Udt.DayPattern;
IF TYPE_ID('Udt.ClassEndTime') IS NOT NULL DROP TYPE Udt.ClassEndTime;
IF TYPE_ID('Udt.ClassStartTime') IS NOT NULL DROP TYPE Udt.ClassStartTime;

-- Workflow clock time
IF TYPE_ID('Udt.WorkflowClassTime') IS NOT NULL DROP TYPE Udt.WorkflowClassTime;

-- Standard auditing + keys
IF TYPE_ID('Udt.DateOfLastUpdate') IS NOT NULL DROP TYPE Udt.DateOfLastUpdate;
IF TYPE_ID('Udt.DateAdded') IS NOT NULL DROP TYPE Udt.DateAdded;
IF TYPE_ID('Udt.SurrogateKeyInt') IS NOT NULL DROP TYPE Udt.SurrogateKeyInt;
GO

/*==============================================================
  4) Create UDTs 
==============================================================*/

-- Standard keys + auditing (used across all tables)
CREATE TYPE [Udt].[SurrogateKeyInt]     FROM INT          NOT NULL;
GO
CREATE TYPE [Udt].[DateAdded]           FROM DATETIME2(0) NOT NULL;
GO
CREATE TYPE [Udt].[DateOfLastUpdate]    FROM DATETIME2(0) NOT NULL;
GO

-- Workflow clock time (course section metadata, NOT schedule time range)
CREATE TYPE [Udt].[WorkflowClassTime]   FROM CHAR(5)      NOT NULL;
GO

-- Appropriate meeting times (for real schedule times, if/when used)
CREATE TYPE [Udt].[ClassStartTime]      FROM TIME(0)      NOT NULL;
GO
CREATE TYPE [Udt].[ClassEndTime]        FROM TIME(0)      NOT NULL;
GO

-- Day pattern (e.g., 'M','T, TH', etc.)
CREATE TYPE [Udt].[DayPattern]          FROM NVARCHAR(20) NOT NULL;
GO

-- People info domains
CREATE TYPE [Udt].[LastName]  FROM NVARCHAR(40) NOT NULL;
GO
CREATE TYPE [Udt].[FirstName]    FROM NVARCHAR(40) NOT NULL;
GO
CREATE TYPE [Udt].[FullName]   FROM NVARCHAR(80) NOT NULL;
GO

-- Course/org domains
CREATE TYPE [Udt].[SemesterName]  FROM NVARCHAR(30)  NOT NULL;
GO
CREATE TYPE [Udt].[CourseCode]      FROM NVARCHAR(20)  NOT NULL;
GO
CREATE TYPE [Udt].[CourseTitle]     FROM NVARCHAR(100) NOT NULL;
GO
CREATE TYPE [Udt].[CreditValue]         FROM SMALLINT      NOT NULL;
GO
CREATE TYPE [Udt].[ContactHours]        FROM SMALLINT      NOT NULL;
GO
CREATE TYPE [Udt].[SectionNumber]       FROM SMALLINT      NOT NULL;
GO
CREATE TYPE [Udt].[ClassCode]           FROM INT           NOT NULL;
GO
CREATE TYPE [Udt].[ModeName]            FROM NVARCHAR(30)  NOT NULL;
GO

-- Enrollment
CREATE TYPE [Udt].[EnrollmentCount]     FROM INT NOT NULL;
GO
CREATE TYPE [Udt].[ClassLimit]          FROM INT NOT NULL;
GO

-- Location
CREATE TYPE [Udt].[BuildingCode]        FROM NVARCHAR(10) NOT NULL;
GO
CREATE TYPE [Udt].[RoomCode]            FROM NVARCHAR(10) NOT NULL;
GO

/*==============================================================
  5) Quick verification (optional)
==============================================================*/
SELECT t.name AS UdtName, bt.name AS BaseType, t.max_length
FROM sys.types t
JOIN sys.types bt ON t.system_type_id = bt.user_type_id
WHERE t.is_user_defined = 1 AND SCHEMA_NAME(t.schema_id)='Udt'
ORDER BY t.name;