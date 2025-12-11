USE [PLOB]
GO
/***** Object:  StoredProcedure [dbo].[P_PLOBInterfaceOIC_SetItem]    Script Date: 10/12/2568 18:08:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



 ALTER PROCEDURE [dbo].[P_PLOBInterfaceOIC_SetItem]
	
    @P_BusinessUnit NVARCHAR(50),  -- เพิ่ม BU
    @P_ItemCode NVARCHAR(200),
    @P_ItemName NVARCHAR(510),
    @P_StockCategory NVARCHAR(5),
    @P_StatusFlag CHAR(1),
    @P_UOMCode NVARCHAR(3),
    @P_VendorCode NVARCHAR(50),
    @P_StorageAreaCode NVARCHAR(50),
    @P_RecordStatus CHAR(1),
    @P_ItemType NVARCHAR(255),
    @P_ItemDescription NVARCHAR(510)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate
    IF @P_ItemCode IS NULL OR LTRIM(RTRIM(@P_ItemCode)) = ''
    BEGIN
        RAISERROR('Item Code is required.', 16, 1);
        RETURN;
    END

    IF @P_RecordStatus NOT IN ('A', 'I')
    BEGIN
        RAISERROR('Invalid Record Status. Must be A or I.', 16, 1);
        RETURN;
    END

    -- เตรียม Data string
    DECLARE @Data NVARCHAR(MAX) =
        LTRIM(RTRIM(@P_ItemCode)) + '|' +
        ISNULL(LTRIM(RTRIM(@P_ItemName)), '') + '|' +
        ISNULL(LTRIM(RTRIM(@P_StockCategory)), '') + '|' +
        @P_StatusFlag + '|' +
        ISNULL(LTRIM(RTRIM(@P_UOMCode)), '') + '|' +
        ISNULL(LTRIM(RTRIM(@P_VendorCode)), '') + '|' +
        ISNULL(LTRIM(RTRIM(@P_StorageAreaCode)), '') + '|' +
        @P_RecordStatus + '|' +
        ISNULL(LTRIM(RTRIM(@P_ItemType)), '') + '|' +
        ISNULL(LTRIM(RTRIM(@P_ItemDescription)), '');

    DECLARE @InterfaceType NVARCHAR(50) = 'ITM';

    -- เลือก linked server/database ตาม BU
    DECLARE @LinkedServerName NVARCHAR(100);
    DECLARE @DatabaseName NVARCHAR(100);

    IF UPPER(LTRIM(RTRIM(@P_BusinessUnit))) = 'QSHC'
    BEGIN
        SET @LinkedServerName = dbo.fGetLinkedServerNameForOICInterface_QSHC();
        SET @DatabaseName = dbo.fGetLinkedDatabaseNameForOICInterface_QSHC();
    END
    ELSE IF UPPER(LTRIM(RTRIM(@P_BusinessUnit))) = 'KKUMD'
    BEGIN
        SET @LinkedServerName = dbo.fGetLinkedServerNameForOICInterface();
        SET @DatabaseName = dbo.fGetLinkedDatabaseNameForOICInterface();
    END

    -- สร้าง SQL
    DECLARE @SQL NVARCHAR(MAX) = '
        EXEC [' + @LinkedServerName + '].[' + @DatabaseName + '].[dbo].[pGetPLOBInterfaceOIC]
            @InterfaceType = @InterfaceType,
            @Data = @Data;';

    -- Preview SQL
/*    SELECT
        '----- SQL Preview -----' AS MsgTitle,
        @SQL AS SqlPreview,
        @P_BusinessUnit AS TargetBU,
        @InterfaceType AS InterfaceType,
        @Data AS Data;
		*/
    -- Uncomment บรรทัดนี้เมื่อพร้อม execute จริง
     
    -- Uncomment บรรทัดด้านล่างเมื่อพร้อม execute จริง
		DECLARE @PPname NVARCHAR(100) = OBJECT_NAME(@@PROCID); 
		EXEC [dbo].[LogStoredProcedureExecution] @PPname, @Data;
 

    EXEC sp_executesql @SQL,
        N'@InterfaceType NVARCHAR(50), @Data NVARCHAR(MAX)',
        @InterfaceType = @InterfaceType,
        @Data = @Data;
   
END;
	 
