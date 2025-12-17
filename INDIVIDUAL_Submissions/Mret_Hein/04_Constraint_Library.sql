/*==============================================================
  File: 04_Constraint_Library.sql
    Add constraints to improve data quality for
    QueensClassSchedule

  IMPORTANT WORKFLOW GUIDANCE
  --------------------------------------------------------------
  - Part A (SAFE / STRUCTURAL): can be run early; usually won't
    block ETL development.

  - Part B (BUSINESS RULES): run AFTER ETL is stable (AFTER Aditya's part); may reject
    dirty rows (this is intended and useful for auditing).

  - Script is rerunnable: each constraint is only added if it does
    not already exist (by constraint name).

  Assumptions:
  - Tables and schemas already exist (run table creation scripts first).
  - Column names match the patched schema:
      Faculty.Department(DepartmentName, DepartmentCode)
      Faculty.Instructor(InstructorFirstName, InstructorLastName)
      Location.Building(BuildingName)
      Location.Room(RoomNumber)
      Schedule.Course(CourseDescription, Credits, Hours)
      Schedule.Class(Enrolled, ClassLimit)
      Schedule.Time(Days, SessionStart, SessionEnd, SemesterAvailability)
      Schedule.ModeOfInstruction(ModeOfInstructionName)
      Process.WorkflowSteps(WorkFlowStepTableRowCount)
==============================================================*/

USE QueensClassSchedule;
GO


/*==============================================================
  PART A) SAFE / STRUCTURAL CONSTRAINTS
  --------------------------------------------------------------
  Goal:
  - Improve quality without usually blocking ETL.
  - Enforce "not blank" (no whitespace-only values).
  - Encourage atomic columns (e.g., instructor names).
==============================================================*/

----------------------------------------------------------------
-- A1) DepartmentName must not be empty/whitespace
-- prevents meaningless values like '' or '   '.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Department_DepartmentName_NotBlank')
BEGIN
    ALTER TABLE Faculty.Department
    ADD CONSTRAINT CK_Department_DepartmentName_NotBlank
    CHECK (LEN(LTRIM(RTRIM(DepartmentName))) > 0);
END;
GO

----------------------------------------------------------------
-- A2) DepartmentCode must not be empty/whitespace
-- DepartmentCode is usually used as a stable identifier.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Department_DepartmentCode_NotBlank')
BEGIN
    ALTER TABLE Faculty.Department
    ADD CONSTRAINT CK_Department_DepartmentCode_NotBlank
    CHECK (LEN(LTRIM(RTRIM(DepartmentCode))) > 0);
END;
GO

----------------------------------------------------------------
-- A3) BuildingName must not be empty/whitespace
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Building_BuildingName_NotBlank')
BEGIN
    ALTER TABLE Location.Building
    ADD CONSTRAINT CK_Building_BuildingName_NotBlank
    CHECK (LEN(LTRIM(RTRIM(BuildingName))) > 0);
END;
GO

----------------------------------------------------------------
-- A4) RoomNumber must not be empty/whitespace to help avoid bad room records (e.g., blank room numbers).
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Room_RoomNumber_NotBlank')
BEGIN
    ALTER TABLE Location.Room
    ADD CONSTRAINT CK_Room_RoomNumber_NotBlank
    CHECK (LEN(LTRIM(RTRIM(RoomNumber))) > 0);
END;
GO

----------------------------------------------------------------
-- A5) InstructorFirstName must not be empty/whitespace
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Instructor_FirstName_NotBlank')
BEGIN
    ALTER TABLE Faculty.Instructor
    ADD CONSTRAINT CK_Instructor_FirstName_NotBlank
    CHECK (LEN(LTRIM(RTRIM(InstructorFirstName))) > 0);
END;
GO

----------------------------------------------------------------
-- A6) InstructorLastName must not be empty/whitespace
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Instructor_LastName_NotBlank')
BEGIN
    ALTER TABLE Faculty.Instructor
    ADD CONSTRAINT CK_Instructor_LastName_NotBlank
    CHECK (LEN(LTRIM(RTRIM(InstructorLastName))) > 0);
END;
GO

----------------------------------------------------------------
-- A7) Optional atomic-name hygiene: No commas in atomic fields
--   Source data often has Instructor = 'Last, First'
--   ETL must split this into atomic columns.
--   These checks prevent accidental loading of un-split values.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Instructor_FirstName_NoComma')
BEGIN
    ALTER TABLE Faculty.Instructor
    ADD CONSTRAINT CK_Instructor_FirstName_NoComma
    CHECK (InstructorFirstName NOT LIKE '%,%');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Instructor_LastName_NoComma')
BEGIN
    ALTER TABLE Faculty.Instructor
    ADD CONSTRAINT CK_Instructor_LastName_NoComma
    CHECK (InstructorLastName NOT LIKE '%,%');
END;
GO

----------------------------------------------------------------
-- A8) ModeOfInstructionName must not be empty/whitespace
--  Mode is a category/lookup value; blanks are invalid.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ModeOfInstruction_Name_NotBlank')
BEGIN
    ALTER TABLE Schedule.ModeOfInstruction
    ADD CONSTRAINT CK_ModeOfInstruction_Name_NotBlank
    CHECK (LEN(LTRIM(RTRIM(ModeOfInstructionName))) > 0);
END;
GO

----------------------------------------------------------------
-- A9) Days must not be empty/whitespace
-- schedule days (e.g., 'MW', 'TTh')
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ScheduleTime_Days_NotBlank')
BEGIN
    ALTER TABLE Schedule.Time
    ADD CONSTRAINT CK_ScheduleTime_Days_NotBlank
    CHECK (LEN(LTRIM(RTRIM(Days))) > 0);
END;
GO

----------------------------------------------------------------
-- A10) CourseDescription must not be empty/whitespace
--  blanks are useless.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Course_CourseDescription_NotBlank')
BEGIN
    ALTER TABLE Schedule.Course
    ADD CONSTRAINT CK_Course_CourseDescription_NotBlank
    CHECK (LEN(LTRIM(RTRIM(CourseDescription))) > 0);
END;
GO

----------------------------------------------------------------
-- A11) SemesterAvailability must not be empty/whitespace
-- You want to avoid schedule rows with no semester labeling.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Time_SemesterAvailability_NotBlank')
BEGIN
    ALTER TABLE Schedule.Time
    ADD CONSTRAINT CK_Time_SemesterAvailability_NotBlank
    CHECK (LEN(LTRIM(RTRIM(SemesterAvailability))) > 0);
END;
GO


/*==============================================================
  PART B) BUSINESS-RULE CONSTRAINTS
  --------------------------------------------------------------
  Goal:
  - Enforce business logic / real-world validity rules.
  - These are usually enabled AFTER ETL is working.
==============================================================*/

----------------------------------------------------------------
-- B1) Enrollment must be non-negative
--  Negative enrollment does not make sense
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Class_Enrolled_NonNegative')
BEGIN
    ALTER TABLE Schedule.Class
    ADD CONSTRAINT CK_Class_Enrolled_NonNegative
    CHECK (Enrolled >= 0);
END;
GO

----------------------------------------------------------------
-- B2) ClassLimit must be positive (> 0)
 -- A class should have capacity; 0 typically indicates bad data.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Class_Limit_Positive')
BEGIN
    ALTER TABLE Schedule.Class
    ADD CONSTRAINT CK_Class_Limit_Positive
    CHECK (ClassLimit > 0);
END;
GO

----------------------------------------------------------------
-- B3) No. of Enrolled cannot exceed capacity
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Class_Enrolled_LTE_Limit')
BEGIN
    ALTER TABLE Schedule.Class
    ADD CONSTRAINT CK_Class_Enrolled_LTE_Limit
    CHECK (Enrolled <= ClassLimit);
END;
GO

----------------------------------------------------------------
-- B4) Credits must be within a realistic range
-- 
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Course_Credits_Range')
BEGIN
    ALTER TABLE Schedule.Course
    ADD CONSTRAINT CK_Course_Credits_Range
    CHECK (Credits BETWEEN 0 AND 4);
END;
GO

----------------------------------------------------------------
-- B5) Contact hours must be within a realistic range
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Course_Hours_Range')
BEGIN
    ALTER TABLE Schedule.Course
    ADD CONSTRAINT CK_Course_Hours_Range
    CHECK (Hours BETWEEN 0 AND 30);
END;
GO

----------------------------------------------------------------
-- B6) SessionStart must be earlier than SessionEnd
-- Why: prevents inverted time ranges.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ScheduleTime_Start_LT_End')
BEGIN
    ALTER TABLE Schedule.Time
    ADD CONSTRAINT CK_ScheduleTime_Start_LT_End
    CHECK (SessionStart < SessionEnd);
END;
GO

----------------------------------------------------------------
-- B7) Workflow row count should not be negative
-- Why: row counts represent inserted rows; negative is impossible.
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_WorkflowSteps_RowCount_NonNegative')
BEGIN
    ALTER TABLE Process.WorkflowSteps
    ADD CONSTRAINT CK_WorkflowSteps_RowCount_NonNegative
    CHECK (WorkFlowStepTableRowCount IS NULL OR WorkFlowStepTableRowCount >= 0);
END;
GO



-- List all CHECK constraints added by this library (by naming pattern)
SELECT
    s.name  AS SchemaName,
    t.name  AS TableName,
    cc.name AS CheckConstraintName,
    cc.is_disabled,
    cc.is_not_trusted
FROM sys.check_constraints cc
JOIN sys.tables t   ON cc.parent_object_id = t.object_id
JOIN sys.schemas s  ON t.schema_id = s.schema_id
WHERE cc.name LIKE 'CK[_]%'
ORDER BY s.name, t.name, cc.name;
GO
