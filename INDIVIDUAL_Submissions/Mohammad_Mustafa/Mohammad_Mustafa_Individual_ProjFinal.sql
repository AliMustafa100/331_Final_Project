-- Mohammad Mustafa - Project 3 (QueensClassSchedule) - All Queries Used (from this chat)
-- NOTE: These queries are written against the staging table:
--   Uploadfile.CurrentSemesterCourseOfferings
-- Database: QueensClassSchedule
-- File: Mohammad_Mustafa_Individual_ProjFinal_ALL.sql

/* ============================================================================
   0) Database context
   ============================================================================ */
USE QueensClassSchedule;
GO

/* ============================================================================
   1) Raw Upload Data (Top 20)
   ============================================================================ */
SELECT TOP (20) *
FROM Uploadfile.CurrentSemesterCourseOfferings;
GO

/* ============================================================================
   2) Mode of Instruction (Domain distribution)
   ============================================================================ */
SELECT [Mode of Instruction] AS Mode, COUNT(*) AS Cnt
FROM Uploadfile.CurrentSemesterCourseOfferings
GROUP BY [Mode of Instruction]
ORDER BY Cnt DESC;
GO

/* ============================================================================
   3) Day Patterns (distribution incl. blanks)
   ============================================================================ */
SELECT
  COALESCE(NULLIF(LTRIM(RTRIM([Day])), ''), '(BLANK)') AS DayPattern,
  COUNT(*) AS Cnt
FROM Uploadfile.CurrentSemesterCourseOfferings
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM([Day])), ''), '(BLANK)')
ORDER BY Cnt DESC;
GO

/* ============================================================================
   4) Time Patterns (distribution incl. blanks / placeholders)
   ============================================================================ */
SELECT
  COALESCE(NULLIF(LTRIM(RTRIM([Time])), ''), '(BLANK)') AS TimePattern,
  COUNT(*) AS Cnt
FROM Uploadfile.CurrentSemesterCourseOfferings
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM([Time])), ''), '(BLANK)')
ORDER BY Cnt DESC;
GO

/* ============================================================================
   5) Location Patterns (top locations incl. blanks)
   ============================================================================ */
SELECT TOP (50)
  COALESCE(NULLIF(LTRIM(RTRIM([Location])), ''), '(BLANK)') AS LocationValue,
  COUNT(*) AS Cnt
FROM Uploadfile.CurrentSemesterCourseOfferings
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM([Location])), ''), '(BLANK)')
ORDER BY Cnt DESC;
GO

/* ============================================================================
   6) Location → Building Code distribution (parsed from Location)
   ============================================================================ */
SELECT TOP (50)
  LEFT([Location], CHARINDEX(' ', [Location] + ' ') - 1) AS BuildingCode,
  COUNT(*) AS Cnt
FROM Uploadfile.CurrentSemesterCourseOfferings
WHERE NULLIF(LTRIM(RTRIM([Location])), '') IS NOT NULL
GROUP BY LEFT([Location], CHARINDEX(' ', [Location] + ' ') - 1)
ORDER BY Cnt DESC;
GO

/* ============================================================================
   7) Missing/TBA summary (baseline QA)
   ============================================================================ */
SELECT
  SUM(CASE WHEN NULLIF(LTRIM(RTRIM([Day])), '') IS NULL THEN 1 ELSE 0 END) AS DayBlank,
  SUM(CASE WHEN NULLIF(LTRIM(RTRIM([Location])), '') IS NULL THEN 1 ELSE 0 END) AS LocationBlank,
  SUM(CASE WHEN NULLIF(LTRIM(RTRIM([Time])), '') IS NULL THEN 1 ELSE 0 END) AS TimeBlank,
  SUM(CASE WHEN [Time] = '-' THEN 1 ELSE 0 END) AS TimeDash,
  SUM(CASE WHEN [Time] = '12:00 AM - 12:00 AM' THEN 1 ELSE 0 END) AS TimeMidnightMidnight
FROM Uploadfile.CurrentSemesterCourseOfferings;
GO

/* ============================================================================
   8) Rows that SHOULD produce meetings (Day+Time+Location all present and real)
   ============================================================================ */
SELECT COUNT(*) AS RowsThatShouldProduceMeetings
FROM Uploadfile.CurrentSemesterCourseOfferings
WHERE NULLIF(LTRIM(RTRIM([Day])), '') IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Location])), '') IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Time])), '') IS NOT NULL
  AND [Time] NOT IN ('-', '12:00 AM - 12:00 AM');
GO

/* ============================================================================
   9) REQUIRED Proposition Query #1: Instructors teaching in multiple departments
   ============================================================================ */
WITH Parsed_InstructorDept AS (
  SELECT
    Instructor,
    LEFT([Course (hr, crd)], CHARINDEX(' ', [Course (hr, crd)] + ' ') - 1) AS DeptCode
  FROM Uploadfile.CurrentSemesterCourseOfferings
  WHERE NULLIF(LTRIM(RTRIM(Instructor)), '') IS NOT NULL
)
SELECT
  Instructor,
  COUNT(DISTINCT DeptCode) AS DeptCount
FROM Parsed_InstructorDept
GROUP BY Instructor
HAVING COUNT(DISTINCT DeptCode) > 1
ORDER BY DeptCount DESC, Instructor;
GO

/* ============================================================================
   10) REQUIRED Proposition Query #2: How many instructors per department?
   ============================================================================ */
WITH Parsed_DeptInstructor AS (
  SELECT
    LEFT([Course (hr, crd)], CHARINDEX(' ', [Course (hr, crd)] + ' ') - 1) AS DeptCode,
    Instructor
  FROM Uploadfile.CurrentSemesterCourseOfferings
  WHERE NULLIF(LTRIM(RTRIM(Instructor)), '') IS NOT NULL
)
SELECT
  DeptCode,
  COUNT(DISTINCT Instructor) AS InstructorCount
FROM Parsed_DeptInstructor
GROUP BY DeptCode
ORDER BY InstructorCount DESC, DeptCode;
GO

/* ============================================================================
   11) REQUIRED Proposition Query #3: Classes by course + totals + % enrollment
   ============================================================================ */
WITH Clean_Enroll AS (
  SELECT
    [Course (hr, crd)] AS CourseLabel,
    TRY_CONVERT(int, Enrolled) AS EnrolledInt,
    TRY_CONVERT(int, [Limit]) AS LimitInt
  FROM Uploadfile.CurrentSemesterCourseOfferings
)
SELECT
  CourseLabel,
  COUNT(*) AS ClassCount,
  SUM(EnrolledInt) AS TotalEnrolled,
  SUM(LimitInt) AS TotalLimit,
  CAST(100.0 * SUM(EnrolledInt) / NULLIF(SUM(LimitInt), 0) AS decimal(6,2)) AS PctEnrolled
FROM Clean_Enroll
GROUP BY CourseLabel
ORDER BY PctEnrolled DESC, TotalEnrolled DESC;
GO

/* ============================================================================
   12) Extra Reporting: Sections closest to full (% full)
   ============================================================================ */
SELECT TOP (25)
  [Course (hr, crd)] AS CourseLabel,
  Sec,
  Code AS CRN,
  TRY_CONVERT(int, Enrolled) AS EnrolledInt,
  TRY_CONVERT(int, [Limit]) AS LimitInt,
  CAST(100.0 * TRY_CONVERT(int, Enrolled) / NULLIF(TRY_CONVERT(int, [Limit]),0) AS decimal(6,2)) AS PctFull
FROM Uploadfile.CurrentSemesterCourseOfferings
WHERE TRY_CONVERT(int, Enrolled) IS NOT NULL
  AND TRY_CONVERT(int, [Limit]) IS NOT NULL
ORDER BY PctFull DESC;
GO

/* ============================================================================
   13) Extra Reporting: Room utilization (top rooms by section count)
   ============================================================================ */
SELECT TOP (25)
  [Location],
  COUNT(*) AS SectionCount
FROM Uploadfile.CurrentSemesterCourseOfferings
WHERE NULLIF(LTRIM(RTRIM([Location])), '') IS NOT NULL
GROUP BY [Location]
ORDER BY SectionCount DESC;
GO
