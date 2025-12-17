USE QueensClassSchedule;
GO




/* ============================================================
   QUERY 1
   Proposition:
   Which departments are offering the highest number of classes?
   ============================================================ */

SELECT
      d.DepartmentCode
    , d.DepartmentName
    , COUNT(*) AS NumberOfClasses
FROM Faculty.Department d,
     Schedule.Course c,
     Schedule.Class sc
WHERE c.DepartmentId = d.DepartmentId
  AND sc.CourseID = c.CourseID
GROUP BY d.DepartmentCode, d.DepartmentName
ORDER BY NumberOfClasses DESC, d.DepartmentCode;
GO


/* ============================================================
   QUERY 2
   Proposition:
   Which classes are full or nearly full (90% or higher enrollment)?
   ============================================================ */

SELECT
      d.DepartmentCode
    , c.CourseNumber
    , sc.ClassCode
    , sc.SectionNumber
    , sc.Enrolled
    , sc.ClassLimit
    , CAST(
          (1.0 * sc.Enrolled) / NULLIF(sc.ClassLimit, 0)
          AS DECIMAL(6,3)
      ) AS FillRate
FROM Faculty.Department d,
     Schedule.Course c,
     Schedule.Class sc
WHERE c.DepartmentId = d.DepartmentId
  AND sc.CourseID = c.CourseID
  AND sc.ClassLimit > 0
  AND (1.0 * sc.Enrolled) / NULLIF(sc.ClassLimit, 0) >= 0.90
ORDER BY FillRate DESC, sc.Enrolled DESC;
GO


/* ============================================================
   QUERY 3
   Proposition:
   Which instructors teach in more than one department?
   ============================================================ */

USE QueensClassSchedule;
GO

SELECT
      i.InstructorFullName
    , COUNT(DISTINCT c.DepartmentID) AS NumberOfDepartments
FROM Faculty.Instructor i,
     Schedule.Class sc,
     Schedule.Course c
WHERE sc.InstructorID = i.InstructorID
  AND sc.CourseID     = c.CourseID
GROUP BY i.InstructorFullName
HAVING COUNT(DISTINCT c.DepartmentID) > 1
ORDER BY NumberOfDepartments DESC, i.InstructorFullName;
GO



/* ============================================================
   QUERY 4
   Proposition:
   Show the weekly class schedule including day, time,
   department, course, instructor, and location details.
   ============================================================ */

SELECT
      st.Days
    , st.SessionStart
    , st.SessionEnd
    , d.DepartmentCode
    , c.CourseNumber
    , sc.ClassCode
    , sc.SectionNumber
    , moi.ModeOfInstructionName
    , b.BuildingCode
    , r.RoomNumber
    , i.InstructorFullName
FROM Schedule.Time st,
     Schedule.Class sc,
     Schedule.Course c,
     Faculty.Department d,
     Schedule.ModeOfInstruction moi,
     Location.Room r,
     Location.Building b,
     Faculty.Instructor i
WHERE st.ClassID = sc.ClassID
  AND sc.CourseID = c.CourseID
  AND c.DepartmentId = d.DepartmentId
  AND sc.ModeOfInstructionID = moi.ModeOfInstructionID
  AND sc.RoomID = r.RoomID
  AND r.BuildingId = b.BuildingId
  AND sc.InstructorID = i.InstructorID
ORDER BY
      st.Days
    , st.SessionStart
    , d.DepartmentCode
    , c.CourseNumber
    , sc.SectionNumber;
GO
