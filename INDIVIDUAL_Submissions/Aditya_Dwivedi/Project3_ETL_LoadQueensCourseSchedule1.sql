USE QueensClassSchedule;
GO

CREATE OR ALTER PROCEDURE Project3.LoadQueensCourseSchedule
    @UserAuthorizationKey INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------------------
    -- Ensure UserAuthorization row exists
    --------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM DbSecurity.UserAuthorization
        WHERE UserAuthorizationKey = @UserAuthorizationKey
    )
    BEGIN
        INSERT INTO DbSecurity.UserAuthorization
        (
            UserAuthorizationKey,
            ClassTime,
            IndividualProject,
            GroupMemberLastName,
            GroupMemberFirstName,
            GroupName,
            DateAdded,
            DateOfLastUpdate
        )
        VALUES
        (
            @UserAuthorizationKey,
            CONVERT(char(5), GETDATE(), 108),
            'Project 3',
            'MemberC',
            'MemberC',
            'Group',
            SYSDATETIME(),
            SYSDATETIME()
        );
    END

    --------------------------------------------------------------------
    -- Defaults
    --------------------------------------------------------------------
    DECLARE @DefaultRoomID INT = 320;

    IF NOT EXISTS (
        SELECT 1
        FROM Faculty.Instructor
        WHERE InstructorFirstName = 'TBA'
          AND InstructorLastName  = 'TBA'
    )
    BEGIN
        INSERT INTO Faculty.Instructor
            (InstructorFirstName, InstructorLastName, UserAuthorizationKey, DateAdded, DateOfLastUpdate)
        VALUES
            ('TBA', 'TBA', @UserAuthorizationKey, SYSDATETIME(), SYSDATETIME());
    END

    DECLARE @DefaultInstructorID INT =
    (
        SELECT TOP 1 InstructorID
        FROM Faculty.Instructor
        WHERE InstructorFirstName = 'TBA'
          AND InstructorLastName  = 'TBA'
        ORDER BY InstructorID
    );

    --------------------------------------------------------------------
    -- Build parsed source ONCE
    --------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#S3') IS NOT NULL DROP TABLE #S3;

    ;WITH S0 AS
    (
        SELECT
              Semester
            , Sec
            , Code
            , [Course (hr, crd)]     AS CourseHrCrd
            , [Description]          AS CourseTitle
            , [Day]                  AS DaysRaw
            , [Time]                 AS TimeRaw
            , [Instructor]           AS InstructorRaw
            , [Location]             AS LocationRaw
            , [Enrolled]             AS EnrolledRaw
            , [Limit]                AS LimitRaw
            , [Mode of Instruction]  AS ModeRaw
        FROM Uploadfile.CurrentSemesterCourseOfferings
    ),
    S1 AS
    (
        SELECT
            *
            , LTRIM(RTRIM(ModeRaw)) AS ModeTrim
            , LTRIM(RTRIM(DaysRaw)) AS DaysTrim
            , LTRIM(RTRIM(TimeRaw)) AS TimeTrim

            , LTRIM(RTRIM(
                LEFT(CourseHrCrd, NULLIF(CHARINDEX('(', CourseHrCrd + '(') - 1, -1))
              )) AS CourseCodeRaw

            , LTRIM(RTRIM(
                SUBSTRING(
                    CourseHrCrd,
                    CHARINDEX('(', CourseHrCrd + '(') + 1,
                    CHARINDEX(')', CourseHrCrd + ')') - CHARINDEX('(', CourseHrCrd + '(') - 1
                )
              )) AS CreditsHoursPair

            , CASE
                WHEN InstructorRaw IS NULL OR LTRIM(RTRIM(InstructorRaw)) = '' THEN 'TBA'
                WHEN CHARINDEX(',', InstructorRaw) > 0
                     THEN LTRIM(RTRIM(LEFT(InstructorRaw, CHARINDEX(',', InstructorRaw)-1)))
                ELSE LTRIM(RTRIM(InstructorRaw))
              END AS InstructorLast

            , CASE
                WHEN InstructorRaw IS NULL OR LTRIM(RTRIM(InstructorRaw)) = '' THEN 'TBA'
                WHEN CHARINDEX(',', InstructorRaw) > 0
                     THEN LTRIM(RTRIM(SUBSTRING(InstructorRaw, CHARINDEX(',', InstructorRaw)+1, 200)))
                ELSE 'TBA'
              END AS InstructorFirst
        FROM S0
    ),
    S2 AS
    (
        SELECT
            *
            , LEFT(CourseCodeRaw, CHARINDEX(' ', CourseCodeRaw + ' ') - 1) AS DepartmentCode
            , LEFT(CourseCodeRaw, 20) AS CourseNumberFull

            , TRY_CONVERT(int, PARSENAME(REPLACE(CreditsHoursPair, ',', '.'), 2)) AS Credits
            , TRY_CONVERT(int, PARSENAME(REPLACE(CreditsHoursPair, ',', '.'), 1)) AS Hours

            , TRY_CONVERT(int, Code) AS ClassCodeInt
            , TRY_CONVERT(smallint, Sec) AS SectionNum
            , TRY_CONVERT(int, EnrolledRaw) AS EnrolledInt
            , TRY_CONVERT(int, LimitRaw) AS LimitInt

            -- More robust time split: "3:10 PM - 4:25 PM"
            , LTRIM(RTRIM(CASE WHEN CHARINDEX('-', TimeTrim) > 0 THEN LEFT(TimeTrim, CHARINDEX('-', TimeTrim)-1) END)) AS StartTxt
            , LTRIM(RTRIM(CASE WHEN CHARINDEX('-', TimeTrim) > 0 THEN SUBSTRING(TimeTrim, CHARINDEX('-', TimeTrim)+1, 50) END)) AS EndTxt
        FROM S1
    ),
    S3 AS
    (
        SELECT
            *
            , TRY_CONVERT(time(0), StartTxt) AS StartTime
            , TRY_CONVERT(time(0), EndTxt)   AS EndTime
        FROM S2
    )
    SELECT *
    INTO #S3
    FROM S3;

    --------------------------------------------------------------------
    -- Department
    --------------------------------------------------------------------
    INSERT INTO Faculty.Department
        (DepartmentName, DepartmentCode, UserAuthorizationKey, DateAdded, DateOfLastUpdate)
    SELECT DISTINCT
          s.DepartmentCode,
          s.DepartmentCode,
          @UserAuthorizationKey,
          SYSDATETIME(),
          SYSDATETIME()
    FROM #S3 s
    WHERE s.DepartmentCode IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM Faculty.Department d
          WHERE d.DepartmentCode = s.DepartmentCode
      );

    --------------------------------------------------------------------
    -- Instructor
    --------------------------------------------------------------------
    INSERT INTO Faculty.Instructor
        (InstructorFirstName, InstructorLastName, UserAuthorizationKey, DateAdded, DateOfLastUpdate)
    SELECT DISTINCT
          s.InstructorFirst,
          s.InstructorLast,
          @UserAuthorizationKey,
          SYSDATETIME(),
          SYSDATETIME()
    FROM #S3 s
    WHERE NOT EXISTS (
        SELECT 1
        FROM Faculty.Instructor i
        WHERE i.InstructorFirstName = s.InstructorFirst
          AND i.InstructorLastName  = s.InstructorLast
    );

    --------------------------------------------------------------------
    -- Mode of Instruction
    --------------------------------------------------------------------
    INSERT INTO Schedule.ModeOfInstruction
        (ModeOfInstructionName, UserAuthorizationKey, DateAdded, DateOfLastUpdate)
    SELECT DISTINCT
          s.ModeTrim,
          @UserAuthorizationKey,
          SYSDATETIME(),
          SYSDATETIME()
    FROM #S3 s
    WHERE s.ModeTrim IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM Schedule.ModeOfInstruction m
          WHERE m.ModeOfInstructionName = s.ModeTrim
      );

    --------------------------------------------------------------------
    -- Course
    --------------------------------------------------------------------
    INSERT INTO Schedule.Course
        (DepartmentID, CourseNumber, CourseDescription, Credits, Hours,
         UserAuthorizationKey, DateAdded, DateOfLastUpdate)
    SELECT DISTINCT
          d.DepartmentID,
          s.CourseNumberFull,
          s.CourseTitle,
          ISNULL(s.Credits, 0),
          ISNULL(s.Hours, 0),
          @UserAuthorizationKey,
          SYSDATETIME(),
          SYSDATETIME()
    FROM #S3 s
    JOIN Faculty.Department d
        ON d.DepartmentCode = s.DepartmentCode
    WHERE NOT EXISTS (
        SELECT 1
        FROM Schedule.Course c
        WHERE c.CourseNumber = s.CourseNumberFull
    );

    --------------------------------------------------------------------
    -- Class (DEDUP by ClassCode + FIX Limit Positive + FIX Enrolled<=Limit)
    --------------------------------------------------------------------
    ;WITH ClassSource AS
    (
        SELECT
            s.*,
            ROW_NUMBER() OVER (
                PARTITION BY s.ClassCodeInt
                ORDER BY s.ClassCodeInt
            ) AS rn
        FROM #S3 s
        WHERE s.ClassCodeInt IS NOT NULL
          AND s.SectionNum IS NOT NULL
    )
    INSERT INTO Schedule.Class
    (
        CourseID,
        ClassCode,
        SectionNumber,
        Enrolled,
        ClassLimit,
        ModeOfInstructionID,
        RoomID,
        InstructorID,
        UserAuthorizationKey,
        DateAdded,
        DateOfLastUpdate
    )
    SELECT
          c.CourseID
        , cs.ClassCodeInt
        , cs.SectionNum
        , calc.EnrolledFixed
        , calc.LimitFixed
        , m.ModeOfInstructionID
        , @DefaultRoomID
        , @DefaultInstructorID
        , @UserAuthorizationKey
        , SYSDATETIME()
        , SYSDATETIME()
    FROM ClassSource cs
    JOIN Faculty.Department d
        ON d.DepartmentCode = cs.DepartmentCode
    JOIN Schedule.Course c
        ON c.CourseNumber = cs.CourseNumberFull
    JOIN Schedule.ModeOfInstruction m
        ON m.ModeOfInstructionName = cs.ModeTrim
    CROSS APPLY
    (
        SELECT
            CASE WHEN ISNULL(cs.EnrolledInt, 0) < 0 THEN 0 ELSE ISNULL(cs.EnrolledInt, 0) END AS Enr0,
            CASE WHEN ISNULL(cs.LimitInt,   0) < 0 THEN 0 ELSE ISNULL(cs.LimitInt,   0) END AS Lim0
    ) n
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN n.Lim0 <= 0 THEN CASE WHEN n.Enr0 > 0 THEN n.Enr0 ELSE 1 END
                WHEN n.Lim0 <  n.Enr0 THEN n.Enr0
                ELSE n.Lim0
            END AS LimitFixed,
            CASE
                WHEN n.Enr0 >
                     CASE
                        WHEN n.Lim0 <= 0 THEN CASE WHEN n.Enr0 > 0 THEN n.Enr0 ELSE 1 END
                        WHEN n.Lim0 <  n.Enr0 THEN n.Enr0
                        ELSE n.Lim0
                     END
                THEN
                     CASE
                        WHEN n.Lim0 <= 0 THEN CASE WHEN n.Enr0 > 0 THEN n.Enr0 ELSE 1 END
                        WHEN n.Lim0 <  n.Enr0 THEN n.Enr0
                        ELSE n.Lim0
                     END
                ELSE n.Enr0
            END AS EnrolledFixed
    ) calc
    WHERE cs.rn = 1
      AND NOT EXISTS (
          SELECT 1
          FROM Schedule.Class sc
          WHERE sc.ClassCode = cs.ClassCodeInt
      );

    --------------------------------------------------------------------
    -- Time (FIX CK_Time_Start_LT_End)
    --------------------------------------------------------------------
    INSERT INTO Schedule.Time
        (ClassID, Days, SessionStart, SessionEnd,
         SemesterAvailability, UserAuthorizationKey,
         DateAdded, DateOfLastUpdate)
    SELECT DISTINCT
          sc.ClassID
        , s.DaysTrim
        , s.StartTime
        , s.EndTime
        , s.Semester
        , @UserAuthorizationKey
        , SYSDATETIME()
        , SYSDATETIME()
    FROM #S3 s
    JOIN Schedule.Course c
        ON c.CourseNumber = s.CourseNumberFull
    JOIN Schedule.Class sc
        ON sc.CourseID = c.CourseID
       AND sc.ClassCode = s.ClassCodeInt
    WHERE s.StartTime IS NOT NULL
      AND s.EndTime IS NOT NULL
      AND s.StartTime < s.EndTime         -- ✅ KEY FIX FOR CK_Time_Start_LT_End
      AND NULLIF(LTRIM(RTRIM(s.DaysTrim)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM Schedule.Time t
          WHERE t.ClassID = sc.ClassID
            AND t.Days = s.DaysTrim
            AND t.SessionStart = s.StartTime
            AND t.SessionEnd = s.EndTime
      );
END;
GO
