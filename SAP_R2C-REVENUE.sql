USE [PLOB]
GO
/******* Object:  StoredProcedure [dbo].[pGetIntefaceRevenueHeader_initial]    Script Date: 10/12/2568 14:40:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pGetIntefaceRevenueHeader_initial]	 
    @Date DATETIME,
    @BU NVARCHAR(20) = NULL   -- เพิ่ม parameter BU (เช่น 'KKUMD' หรือ 'QSHC')
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Initial Variable
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
        WHERE Code = 'REVH' AND BU = 'KKUMD' AND StatusFlag = 'A';

        SELECT @FileName_QSHC = REPLACE(FileName, 'YYYYMMDD', @FileDate)
        FROM InterfaceConfig
        WHERE Code = 'REVH' AND BU = 'QSHC' AND StatusFlag = 'A';

        -- Check duplication เฉพาะ BU ที่เลือก
      IF EXISTS (
		SELECT 1 
		FROM Interface_LoadControl  
		WHERE Status = 'SUCCESS' AND StatusFlag = 'A'
		  AND (
				(@BU = 'KKUMD' AND FileName = @FileName_KKUMD) OR
				(@BU = 'QSHC'  AND FileName = @FileName_QSHC) OR
				(@BU IS NULL   AND FileName IN (@FileName_KKUMD, @FileName_QSHC))
			  )
	)

        BEGIN
            RAISERROR('File already loaded successfully for BU %s on date %s.', 16, 1, @BU, @FileDate);
            RETURN;
        END

        -- Temp Table
        IF OBJECT_ID('tempdb..#Interface') IS NOT NULL DROP TABLE #Interface;

        CREATE TABLE #Interface (
            [BU] NVARCHAR(MAX),
            [InvoiceNo] NVARCHAR(MAX),
            [InvoiceDate] NVARCHAR(MAX),
            [Episode] NVARCHAR(MAX),
            [DocumentType] NVARCHAR(MAX),
            [PaymentMethod] NVARCHAR(MAX),
            [PayorOfficeCode] NVARCHAR(MAX),
            [CustomerType] NVARCHAR(MAX),
            [HN] NVARCHAR(MAX),
            [PatientName] NVARCHAR(MAX),
            [NationalityCode] NVARCHAR(MAX),
            [ContactID] NVARCHAR(MAX),
            [ContactPercent] NVARCHAR(MAX),
            [Currency] NVARCHAR(MAX),
            [TotalInvoiceByPaymentMethod] NVARCHAR(MAX),
            [Amount] NVARCHAR(MAX),
            [DiscountAmount] NVARCHAR(MAX),
            [SpecialDiscountAccount] NVARCHAR(MAX),
            [DepositReferenceNo] NVARCHAR(MAX),
            [CardType] NVARCHAR(MAX),
            [ProductID] NVARCHAR(MAX),
            [InsertedDate] DATETIME DEFAULT GETDATE(),
            [FileName] NVARCHAR(MAX),
            [SourceServer] NVARCHAR(100)
        );

        -- ========== Run สำหรับ KKUMD
IF @BU = 'KKUMD' OR @BU IS NULL
        BEGIN
            DECLARE @SQL1 NVARCHAR(MAX) = '
            INSERT INTO #Interface (
                [BU], [InvoiceNo], [InvoiceDate], [Episode], [DocumentType], [PaymentMethod], 
                [PayorOfficeCode], [CustomerType], [HN], [PatientName], [NationalityCode], 
                [ContactID], [ContactPercent], [Currency], [TotalInvoiceByPaymentMethod],
                [Amount], [DiscountAmount], [SpecialDiscountAccount], [DepositReferenceNo], 
                [CardType], [ProductID]
            )
            EXEC ' + 
                CASE WHEN @Linked1 = '' THEN '' ELSE '[' + @Linked1 + '].' END +  
                'HealthObject.dbo.[pGetCSInterfaceRevenue] ''' + @DateFrom + ''', ''' + @DateTo + '''';
            
            EXEC sp_executesql @SQL1;
        END

        -- ========== Run สำหรับ QSHC
IF @BU = 'QSHC' OR @BU IS NULL
        BEGIN
            DECLARE @SQL2 NVARCHAR(MAX) = '
            INSERT INTO #Interface (
                [BU], [InvoiceNo], [InvoiceDate], [Episode], [DocumentType], [PaymentMethod], 
                [PayorOfficeCode], [CustomerType], [HN], [PatientName], [NationalityCode], 
                [ContactID], [ContactPercent], [Currency], [TotalInvoiceByPaymentMethod],
                [Amount], [DiscountAmount], [SpecialDiscountAccount], [DepositReferenceNo], 
                [CardType], [ProductID]
            )
            EXEC (''[' + @Linked2 + '].HealthObject.dbo.[pGetCSInterfaceRevenuePLOB] ''''' + @DateFrom + ''''', ''''' + @DateTo + ''''''')';
            
            EXEC sp_executesql @SQL2;
        END

        -- Insert Real Table
        INSERT INTO Interface_RevenueHeader (
            [FileName],[BusinessUnit],[InvoiceNo],[InvoiceDate],[Episode],[DocumentType],
            [PaymentMethod],[PayorOfficeCode],[CustomerType],[HN],[PatientName],
            [NationalityCode],[ContactID],[ContactPercent],[Currency],[TotalInvoiceByPaymentMethod],
            [Amount],[DiscountAmount],[SpecialDiscountAccount],[DepositReferenceNo],[CardType],[ProductID],
            [InsertedDate],[SourceServer],[StatusFlag]
        )
        SELECT
            CASE WHEN [BU] = 'KKUMD' THEN @FileName_KKUMD ELSE @FileName_QSHC END,
            [BU], [InvoiceNo], [InvoiceDate], [Episode], [DocumentType],
            [PaymentMethod], [PayorOfficeCode], [CustomerType], [HN], [PatientName],
            [NationalityCode], [ContactID], [ContactPercent], [Currency], [TotalInvoiceByPaymentMethod],
            [Amount], [DiscountAmount], [SpecialDiscountAccount], [DepositReferenceNo], [CardType], [ProductID],
            GETDATE(),
            CASE WHEN [BU] = 'KKUMD' THEN @Linked1 ELSE @Linked2 END,
            'A'
        FROM #Interface;

		        -- Logging
        DECLARE @LoadControl TABLE (
            BU NVARCHAR(50),
            FileName NVARCHAR(255),
            LoadControlUID INT
        );
		 
       -- Logging
		IF @BU = 'KKUMD' OR @BU IS NULL
		BEGIN
			DECLARE @RowCount1 INT = (SELECT COUNT(*) FROM [dbo].[Interface_RevenueHeader] 
									  WHERE FileName = @FileName_KKUMD AND StatusFlag = 'A');
			INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
			     OUTPUT inserted.BU, inserted.FileName, inserted.LoadControlUID
            INTO @LoadControl(BU, FileName, LoadControlUID)
			VALUES ('KKUMD', @FileName_KKUMD, @RowCount1, CASE WHEN @RowCount1 > 0 THEN 'SUCCESS' ELSE 'NO_DATA' END, NULL, 'ETLService', GETDATE(), 'A');
		END

		IF @BU = 'QSHC' OR @BU IS NULL
		BEGIN
			DECLARE @RowCount2 INT = (SELECT COUNT(*) FROM [dbo].[Interface_RevenueHeader] 
									  WHERE FileName = @FileName_QSHC AND StatusFlag = 'A');
			INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
			     OUTPUT inserted.BU, inserted.FileName, inserted.LoadControlUID
            INTO @LoadControl(BU, FileName, LoadControlUID)
			VALUES ('QSHC', @FileName_QSHC, @RowCount2, CASE WHEN @RowCount2 > 0 THEN 'SUCCESS' ELSE 'NO_DATA' END, NULL, 'ETLService', GETDATE(), 'A');
		END

		  -- Update Interface
        UPDATE A
        SET A.InterfaceLogUID = L.LoadControlUID
        FROM Interface_RevenueDetail A
		INNER JOIN @LoadControl L ON A.FileName COLLATE Thai_CI_AS = L.FileName
        WHERE A.StatusFlag = 'A';

        DROP TABLE #Interface;

    END TRY
    BEGIN CATCH
          DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();

    IF @BU = 'KKUMD' OR @BU IS NULL
        INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
        VALUES ('KKUMD', @FileName_KKUMD, 0, 'ERROR', @ErrMsg, 'ETLService', GETDATE(), 'A');

    IF @BU = 'QSHC' OR @BU IS NULL
        INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
        VALUES ('QSHC', @FileName_QSHC, 0, 'ERROR', @ErrMsg, 'ETLService', GETDATE(), 'A');

    RAISERROR(@ErrMsg, 16, 1);

    END CATCH
END
