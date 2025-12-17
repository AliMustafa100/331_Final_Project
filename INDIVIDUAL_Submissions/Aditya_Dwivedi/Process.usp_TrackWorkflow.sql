USE QueensClassSchedule;
GO

CREATE OR ALTER PROCEDURE Process.usp_TrackWorkflow
(
      @WorkFlowStepDescription NVARCHAR(100)
    , @WorkFlowStepTableRowCount INT
    , @WorkFlowStepTable NVARCHAR(100)
    , @StartingDateTime DATETIME2(0)
    , @EndingDateTime DATETIME2(0)
    , @UserAuthorizationKey INT
)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Process.WorkflowSteps
    (
          WorkFlowStepDescription
        , WorkFlowStepTableRowCount
        , WorkFlowStepTable
        , StartingDateTime
        , EndingDateTime
        , ClassTime
        , UserAuthorizationKey
        , DateAdded
        , DateOfLastUpdate
    )
    VALUES
    (
          @WorkFlowStepDescription
        , @WorkFlowStepTableRowCount
        , @WorkFlowStepTable
        , @StartingDateTime
        , @EndingDateTime
        , CONVERT(char(5), GETDATE(), 108)
        , @UserAuthorizationKey
        , SYSDATETIME()
        , SYSDATETIME()
    );
END;
GO
