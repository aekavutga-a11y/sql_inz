USE [PLOB]
GO
/***** Object:  StoredProcedure [dbo].[pGetIntefaceAR_initial]    Script Date: 10/12/2568 18:05:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pGetIntefaceAR_initial] -- [dbo].[pGetIntefaceAR_initial]  '2025-07-01'
    @Date DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Initial Variable
        DECLARE 
            @DateFrom NVARCHAR(20) = CONVERT(NVARCHAR(20), @Date, 120),
            @DateTo   NVARCHAR(20) =   CONVERT(NVARCHAR(20), DATEADD(SECOND, 86399, @Date), 120),
            @FileDate NVARCHAR(8)  = CONVERT(CHAR(8), @Date, 112),
            @Linked1 NVARCHAR(100) = dbo.fGetLinkedServerNameForOICInterface__OUTBOUND_KKUMD(),
            @Linked2 NVARCHAR(100) = dbo.fGetLinkedServerNameForOICInterface__OUTBOUND_QSHC();

        DECLARE 
            @FileName_KKUMD NVARCHAR(MAX),
            @FileName_QSHC  NVARCHAR(MAX);

        SELECT @FileName_KKUMD = REPLACE(FileName, 'YYYYMMDD', @FileDate)
        FROM InterfaceConfig
        WHERE Code = 'AR' AND BU = 'KKUMD' AND StatusFlag = 'A';

        SELECT @FileName_QSHC = REPLACE(FileName, 'YYYYMMDD', @FileDate)
        FROM InterfaceConfig
        WHERE Code = 'AR' AND BU = 'QSHC' AND StatusFlag = 'A';

        -- Check duplication
        IF EXISTS (
            SELECT 1 FROM Interface_LoadControl 
            WHERE FileName IN (@FileName_KKUMD, @FileName_QSHC) AND Status = 'SUCCESS' AND StatusFlag = 'A'
        )
        BEGIN
            RAISERROR('File already loaded successfully for date %s.', 16, 1, @FileDate);
            RETURN;
        END

        -- Temp Table
        IF OBJECT_ID('tempdb..#InterfaceAR') IS NOT NULL DROP TABLE #InterfaceAR;

        CREATE TABLE #InterfaceAR (
                 [BU] NVARCHAR(MAX), [InvoiceNo] NVARCHAR(MAX), [PayorOfficeCode] NVARCHAR(MAX), [HN] NVARCHAR(MAX),
            [PatientName] NVARCHAR(MAX), [DocumentType] NVARCHAR(MAX), [SubDocumentType] NVARCHAR(MAX),
            [NetAmount] NVARCHAR(MAX), [Discount] NVARCHAR(MAX), [Amount] NVARCHAR(MAX), [InvoicePrintDate] NVARCHAR(MAX),
            [Currency] NVARCHAR(MAX), [DocumentNo] NVARCHAR(MAX), [AdmissionDate] NVARCHAR(MAX), [DischargeDate] NVARCHAR(MAX),
            [ContactID] NVARCHAR(MAX), [National] NVARCHAR(MAX), [VN] NVARCHAR(MAX), [PatientType] NVARCHAR(MAX),
            [AgreementCode] NVARCHAR(MAX), AgreementName NVARCHAR(MAX), [InsuranceCompanyCode] NVARCHAR(MAX),
            [InsuranceCompanyName] NVARCHAR(MAX), [PID] NVARCHAR(MAX), [SubPayorOfficeCode] NVARCHAR(MAX),
            [ContractName] NVARCHAR(MAX), [AddressNo] NVARCHAR(MAX), [AddressMoo] NVARCHAR(MAX),
            [AddressRoad] NVARCHAR(MAX), [Address] NVARCHAR(MAX), [AddressCity] NVARCHAR(MAX), [AddressState] NVARCHAR(MAX),
            [AddressPostal] NVARCHAR(MAX), [ContractTelNo] NVARCHAR(MAX), [ContractDueDate] NVARCHAR(MAX),
            [ContractType] NVARCHAR(MAX), [InsertedDate] DATETIME, [FileName] NVARCHAR(MAX), [SourceServer] NVARCHAR(100)
        );

        -- ========== Linked 1: KKUMD
      	DECLARE @SQL1 NVARCHAR(MAX) = '
		INSERT INTO #InterfaceAR (
			[BU], [InvoiceNo], [PayorOfficeCode], [HN], [PatientName], [DocumentType], [SubDocumentType],
			[NetAmount], [Discount], [Amount], [InvoicePrintDate], [Currency], [DocumentNo],
			[AdmissionDate], [DischargeDate], [ContactID], [National], [VN], [PatientType],
			[AgreementCode], [AgreementName], [InsuranceCompanyCode], [InsuranceCompanyName], [PID],
			[SubPayorOfficeCode], [ContractName], [AddressNo], [AddressMoo], [AddressRoad], [Address],
			[AddressCity], [AddressState], [AddressPostal], [ContractTelNo], [ContractDueDate], [ContractType]
		) 
	EXEC ' + 
					CASE WHEN @Linked1 = '' THEN '' ELSE '[' + @Linked1 + '].' END + 
					'HealthObject.dbo.pGetCSInterfaceAR ''' + @DateFrom + ''', ''' + @DateTo + '''';

        EXEC sp_executesql @SQL1;

        -- ========== Linked 2: QSHC
        DECLARE @SQL2 NVARCHAR(MAX) = '
		INSERT INTO #InterfaceAR (
			[BU], [InvoiceNo], [PayorOfficeCode], [HN], [PatientName], [DocumentType], [SubDocumentType],
			[NetAmount], [Discount], [Amount], [InvoicePrintDate], [Currency], [DocumentNo],
			[AdmissionDate], [DischargeDate], [ContactID], [National], [VN], [PatientType],
			[AgreementCode], [AgreementName], [InsuranceCompanyCode], [InsuranceCompanyName], [PID],
			[SubPayorOfficeCode], [ContractName], [AddressNo], [AddressMoo], [AddressRoad], [Address],
			[AddressCity], [AddressState], [AddressPostal], [ContractTelNo], [ContractDueDate], [ContractType]
		)
			EXEC ' + 
					CASE WHEN @Linked2 = '' THEN '' ELSE '[' + @Linked2 + '].' END +  					
					'HealthObject.dbo.[pGetCSInterfaceARPLOB] ''' + @DateFrom + ''', ''' + @DateTo + '''';

        EXEC sp_executesql @SQL2;

        -- ========== Insert Real Table
        INSERT INTO Interface_AR (
            [FileName], [BU], [InvoiceNo], [PayorOfficeCode], [HN], [PatientName], [DocumentType], [SubDocumentType],
            [NetAmount], [Discount], [Amount], [InvoicePrintDate], [Currency], [DocumentNo],
            [AdmissionDate], [DischargeDate], [ContactID], [National], [VN], [PatientType],
            [AgreementCode], [AgreementName], [InsuranceCompanyCode], [InsuranceCompanyName], [PID],
            [SubPayorOfficeCode], [ContractName], [AddressNo], [AddressMoo], [AddressRoad], [Address],
            [AddressCity], [AddressState], [AddressPostal], [ContractTelNo], [ContractDueDate], [ContractType],
            [InsertedDate], [SourceServer],StatusFlag 
        )
        SELECT 
            CASE WHEN  [BU] ='KKUMD' THEN    @FileName_KKUMD  
			ELSE    @FileName_QSHC END , [BU],
			[InvoiceNo], [PayorOfficeCode], [HN], [PatientName], [DocumentType], [SubDocumentType],
            [NetAmount], [Discount], [Amount], [InvoicePrintDate], [Currency], [DocumentNo],
            [AdmissionDate], [DischargeDate], [ContactID], [National], [VN], [PatientType],
            [AgreementCode], [AgreementName], [InsuranceCompanyCode], [InsuranceCompanyName], [PID],
            [SubPayorOfficeCode], [ContractName], [AddressNo], [AddressMoo], [AddressRoad], [Address],
            [AddressCity], [AddressState], [AddressPostal], [ContractTelNo], [ContractDueDate], [ContractType],
            GETDATE(),      CASE WHEN  [BU] ='KKUMD' THEN    @Linked1  
			ELSE    @Linked2 END  SourceServer, 'A'
        
            
        FROM #InterfaceAR;

        -- ========== Logging
    -- ========== Logging
DECLARE @LoadControl TABLE (
    BU NVARCHAR(50),
    FileName NVARCHAR(255),
    LoadControlUID INT
);

-- Get record counts
DECLARE 
    @RowCount1 INT = (SELECT COUNT(*) FROM Interface_AR WHERE FileName = @FileName_KKUMD AND StatusFlag = 'A'),
    @RowCount2 INT = (SELECT COUNT(*) FROM Interface_AR WHERE FileName = @FileName_QSHC AND StatusFlag = 'A');

-- Insert and capture LoadControlUIDs
INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate, StatusFlag)
OUTPUT inserted.BU, inserted.FileName, inserted.LoadControlUID
INTO @LoadControl(BU, FileName, LoadControlUID)
VALUES
    ('KKUMD', @FileName_KKUMD, @RowCount1, CASE WHEN @RowCount1 > 0 THEN 'SUCCESS' ELSE 'NO_DATA' END, NULL, 'ETLService', GETDATE(), 'A'),
    ('QSHC',  @FileName_QSHC,  @RowCount2, CASE WHEN @RowCount2 > 0 THEN 'SUCCESS' ELSE 'NO_DATA' END, NULL, 'ETLService', GETDATE(), 'A');

-- Update Interface_AR with matching LoadControlUID
UPDATE A
SET A.InterfaceLogUID = L.LoadControlUID
FROM Interface_AR A
INNER JOIN @LoadControl L ON A.FileName = L.FileName
WHERE A.StatusFlag = 'A';

END TRY
BEGIN CATCH
    DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();

    INSERT INTO Interface_LoadControl (BU, FileName, RecordCount, Status, Message, LoadBy, LoadDate)
    VALUES 
        ('KKUMD', @FileName_KKUMD, 0, 'ERROR', @ErrMsg, 'ETLService', GETDATE()),
        ('QSHC',  @FileName_QSHC,  0, 'ERROR', @ErrMsg, 'ETLService', GETDATE());

    RAISERROR(@ErrMsg, 16, 1);
END CATCH

END

