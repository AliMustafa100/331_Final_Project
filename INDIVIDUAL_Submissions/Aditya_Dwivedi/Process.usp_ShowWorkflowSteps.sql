USE QueensClassSchedule;
GO

CREATE OR ALTER PROCEDURE Process.usp_ShowWorkflowSteps
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          WorkFlowStepKey
        , WorkFlowStepDescription
        , WorkFlowStepTableRowCount
        , WorkFlowStepTable
        , StartingDateTime
        , EndingDateTime
        , DATEDIFF(SECOND, StartingDateTime, EndingDateTime) AS DurationSeconds
        , UserAuthorizationKey
        , DateAdded
        , DateOfLastUpdate
    FROM Process.WorkflowSteps
    ORDER BY WorkFlowStepKey;
END;
GO
