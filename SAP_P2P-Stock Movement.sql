USE [PLOB]
GO
/****** Object:  StoredProcedure [dbo].[pGetIntefaceInventoryIssue_initial]    Script Date: 10/12/2568 18:02:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pGetIntefaceInventoryIssue_initial]  
    @Date DATETIME,
    @BU NVARCHAR(10) = NULL -- เพิ่ม BU เพื่อเลือกว่าจะโหลดเฉพาะ BU ไหน
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE 
            @DateFrom NVARCHAR(20) = CONVERT(NVARCHAR(20), @Date, 120),
            @DateTo   NVARCHAR(20) = CONVERT(NVARCHAR(20), DATEADD(SECOND, 86399, @Date), 120),
            @FileDate NVARCHAR(8)  = CONVERT(CHAR(8), @Date, 112),
            @Linked1 NVARCHAR(100) = dbo.fGetLinkedServerNameForOICInterface__OUTBOUND_KKUMD(),
            @Linked2 NVARCHAR(100) = dbo.fGetLinkedServerNameForOICInterface__OUTBOUND_QSHC();

        DECLARE 
            @FileName_KKUMD NVARCHAR(MAX),
            @FileName_QSHC  NVARCHAR(MAX);

        SELECT @FileName_KKUMD = REPLACE(FileName, 'YYYYMMDD', @FileDate)
        FROM InterfaceConfig
        WHERE Code = 'INV_ISS' AND BU = 'KKUMD' AND StatusFlag = 'A';

        SELECT @FileName_QSHC = REPLACE(FileName, 'YYYYMMDD', @FileDate)
        FROM InterfaceConfig
        WHERE Code = 'INV_ISS' AND BU = 'QSHC' AND StatusFlag = 'A';

        -- Check duplication only for specified BU
        IF EXISTS (
            SELECT 1 FROM Interface_LoadControl 
            WHERE
                (
                    (@BU IS NULL AND FileName IN (@FileName_KKUMD, @FileName_QSHC)) OR
                    (@BU = 'KKUMD' AND FileName = @FileName_KKUMD) OR
                    (@BU = 'QSHC' AND FileName = @FileName_QSHC)
                )
                AND Status = 'SUCCESS' AND StatusFlag = 'A'
        )
        BEGIN
            RAISERROR('File already loaded successfully for date %s.', 16, 1, @FileDate);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#Interface') IS NOT NULL DROP TABLE #Interface;

        CREATE TABLE #Interface ( 
			  [Line] NVARCHAR(MAX),
			[TransactionGroup] NVARCHAR(MAX),
			[TransactionID] NVARCHAR(MAX),
			[BusinessUnitCode] NVARCHAR(MAX),
			[DistributionType] NVARCHAR(MAX),
			[IssueNO] NVARCHAR(MAX),
			[IssueLineNO] NVARCHAR(MAX),
			[ShippingID] NVARCHAR(MAX),
			[ShippingDate] NVARCHAR(MAX),
			[ShippingTime] NVARCHAR(MAX),
			[IssueDate] NVARCHAR(MAX),
			[CustomerName] NVARCHAR(MAX),
			[Location] NVARCHAR(MAX),
			[ItemID] NVARCHAR(MAX),
			[StorageCode] NVARCHAR(MAX),
			[Quantity] NVARCHAR(MAX),
			[UOM] NVARCHAR(MAX),
			[Comment] NVARCHAR(MAX),
			[DepartmentID] NVARCHAR(MAX),
			[FirstLocation] NVARCHAR(MAX),
			[OrderLocation] NVARCHAR(MAX),
			[OrderToLocation] NVARCHAR(MAX),
			[EpisodeID] NVARCHAR(MAX),
			[ShipToCustomer] NVARCHAR(MAX),
			[SoldToCustomer] NVARCHAR(MAX),
			[TO_SEQ_NBR] NVARCHAR(MAX),
			[AvgCost] NVARCHAR(MAX),
			[BatchID] NVARCHAR(MAX) 
        );

        -- Load per BU
        IF @BU IS NULL OR @BU = 'KKUMD'
        BEGIN
            DECLARE @SQL1 NVARCHAR(MAX) = '
                 INSERT INTO #Interface (
		       [Line]      ,[TransactionGroup]      ,[TransactionID]      ,[BusinessUnitCode]      ,[DistributionType]      ,[IssueNO]      ,[IssueLineNO]      ,[ShippingID]
			  ,[ShippingDate]      ,[ShippingTime]      ,[IssueDate]      ,[CustomerName]      ,[Location]      ,[ItemID]      ,[StorageCode]      ,[Quantity]
			  ,[UOM]      ,[Comment]      ,[DepartmentID]      ,[FirstLocation]      ,[OrderLocation]      ,[OrderToLocation]      ,[EpisodeID]      ,[ShipToCustomer]
			  ,[SoldToCustomer]      ,[TO_SEQ_NBR]      ,[AvgCost]      ,[BatchID]
      

					)
					EXEC ' + 
					CASE WHEN @Linked1 = '' THEN '' ELSE '[' + @Linked1 + '].' END + 
					'HealthObject.dbo.[pGetCSInterfaceInvenIssue] ''' + @DateFrom + ''', ''' + @DateTo + '''';

				EXEC sp_executesql @SQL1;
        END
      IF @BU IS NULL OR @BU = 'QSHC'
        BEGIN
            DECLARE @SQL2 NVARCHAR(MAX) = '
                    INSERT INTO #Interface (
					    [Line]      ,[TransactionGroup]      ,[TransactionID]      ,[BusinessUnitCode]      ,[DistributionType]      ,[IssueNO]      ,[IssueLineNO]      ,[ShippingID]
					  ,[ShippingDate]      ,[ShippingTime]      ,[IssueDate]      ,[CustomerName]      ,[Location]      ,[ItemID]      ,[StorageCode]      ,[Quantity]
					  ,[UOM]      ,[Comment]      ,[DepartmentID]      ,[FirstLocation]      ,[OrderLocation]      ,[OrderToLocation]      ,[EpisodeID]      ,[ShipToCustomer]
					  ,[SoldToCustomer]      ,[TO_SEQ_NBR]      ,[AvgCost]      ,[BatchID]

					)
					EXEC ' + 
					CASE WHEN @Linked2 = '' THEN '' ELSE '[' + @Linked2 + '].' END + 
					'HealthObject.dbo.[pGetCSInterfaceInvenIssuePLOB] ''' + @DateFrom + ''', ''' + @DateTo + '''';

            EXEC sp_executesql @SQL2;
        END

        -- Insert into real table
        INSERT INTO Interface_InventoryIssue (
            [FileName],      [Line]      ,[TransactionGroup]      ,[TransactionID]      ,[BusinessUnitCode]      ,[DistributionType]      ,[IssueNO]      ,[IssueLineNO]      ,[ShippingID]
					  ,[ShippingDate]      ,[ShippingTime]      ,[IssueDate]      ,[CustomerName]      ,[Location]      ,[ItemID]      ,[StorageCode]      ,[Quantity]
					  ,[UOM]      ,[Comment]      ,[DepartmentID]      ,[FirstLocation]      ,[OrderLocation]      ,[OrderToLocation]      ,[EpisodeID]      ,[ShipToCustomer]
					  ,[SoldToCustomer]      ,[TO_SEQ_NBR]      ,[AvgCost]      ,[BatchID]      
        ,    [InsertedDate],[SourceServer],[StatusFlag]
        )
	   
        SELECT
            CASE WHEN [BusinessUnitCode] = 'KKUMD' THEN @FileName_KKUMD ELSE @FileName_QSHC END,
		    [Line]      ,[TransactionGroup]      ,[TransactionID]      ,[BusinessUnitCode]      ,[DistributionType]      ,[IssueNO]      ,[IssueLineNO]      ,[ShippingID]
					  ,[ShippingDate]      ,[ShippingTime]      ,[IssueDate]      ,[CustomerName]      ,[Location]      ,[ItemID]      ,[StorageCode]      ,[Quantity]
					  ,[UOM]      ,[Comment]      ,[DepartmentID]      ,[FirstLocation]      ,[OrderLocation]      ,[OrderToLocation]      ,[EpisodeID]      ,[ShipToCustomer]
					  ,[SoldToCustomer]      ,[TO_SEQ_NBR]      ,[AvgCost]      ,[BatchID]

         ,   GETDATE(),
            CASE WHEN [BusinessUnitCode] = 'KKUMD' THEN CASE WHEN @Linked1 = '' THEN (SELECT   top 1  local_net_address AS CurrentIPAddress FROM     sys.dm_exec_connections WHERE     session_id = @@SPID)
			ELSE @Linked1 END  ELSE @Linked2 END,
            'A'
        FROM #Interface;

        -- Logging
        DECLARE @LoadControl TABLE (
            BU NVARCHAR(50),
            FileName NVARCHAR(255),
            LoadControlUID INT
        );

        DECLARE 
            @RowCount1 INT = (SELECT COUNT(*) FROM Interface_InventoryIssue WHERE FileName = @FileName_KKUMD AND StatusFlag = 'A'),
            @RowCount2 INT = (SELECT COUNT(*) FROM Interface_InventoryIssue WHERE FileName = @FileName_QSHC AND StatusFlag = 'A');

        IF @BU IS NULL OR @BU = 'KKUMD'
        BEGIN
            INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
            OUTPUT inserted.BU, inserted.FileName, inserted.LoadControlUID
            INTO @LoadControl(BU, FileName, LoadControlUID)
            VALUES ('KKUMD', @FileName_KKUMD, @RowCount1, CASE WHEN @RowCount1 > 0 THEN 'SUCCESS' ELSE 'NO_DATA' END, NULL, 'ETLService', GETDATE(), 'A');
        END

        IF @BU IS NULL OR @BU = 'QSHC'
        BEGIN
            INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
            OUTPUT inserted.BU, inserted.FileName, inserted.LoadControlUID
            INTO @LoadControl(BU, FileName, LoadControlUID)
            VALUES ('QSHC', @FileName_QSHC, @RowCount2, CASE WHEN @RowCount2 > 0 THEN 'SUCCESS' ELSE 'NO_DATA' END, NULL, 'ETLService', GETDATE(), 'A');
        END

        -- Update Interface
        UPDATE A
        SET A.InterfaceLogUID = L.LoadControlUID
        FROM Interface_InventoryIssue A
        INNER JOIN @LoadControl L ON A.FileName = L.FileName
        WHERE A.StatusFlag = 'A';

        DROP TABLE #Interface;

    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();

        IF @BU IS NULL OR @BU = 'KKUMD'
            INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
            VALUES ('KKUMD', @FileName_KKUMD, 0, 'ERROR', @ErrMsg, 'ETLService', GETDATE(),'A');

        IF @BU IS NULL OR @BU = 'QSHC'
            INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
            VALUES ('QSHC',  @FileName_QSHC,  0, 'ERROR', @ErrMsg, 'ETLService', GETDATE(),'A');

        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
