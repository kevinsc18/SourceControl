USE [warehouse]
GO

/****** Object:  StoredProcedure [dbo].[usprptexecutivecommission]    Script Date: 4/25/2019 1:10:57 PM ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO


CREATE PROCEDURE [dbo].[usprptexecutivecommission] (@packagekey AS INT)
AS
/*

***************************************************************************************************************
author: infomagnus
***************************************************************************************************************


***************************************************************************************************************
description: this procedure is used for loading reporting table executive commission
***************************************************************************************************************

change history
***************************************************************************************************************
taskid	taskname				date			owner					desciRption					versionno
***************************************************************************************************************
 -	    create reporting	  07/01/2015	   naveen kirane			stored procedure to laod		   v1.0
		table Rptexecutivecommission									Rptexecutivecommission table
 -		Populate New Business 06/28/2016	   Naveen Kirane			Added logic to populate new Business Incentive
		Incentive
 -		Added				  07/09/2016		Syam V					Update adjustment calcaultion logic using AccountExecutiveID
		AccountExecutiveID
*/
DECLARE @sourcecount INT = NULL
	,@insertcount INT = NULL
	,@updatecount INT = NULL
	,@deletecount INT = NULL
	,@destinationrowcount INT = NULL
	,@destinationfinalrowcount INT = NULL

BEGIN
	DECLARE @rowcounts TABLE (mergeaction NVARCHAR(10));
	DECLARE @duplicaterecordsfr INT

	SET NOCOUNT ON;-- supress messages back to client
	SET NOCOUNT ON;-- supress messages back to client


	IF OBJECT_ID('tempdb..#RptExecutiveCommission') IS NOT NULL
		DROP TABLE tempdb..#RptExecutiveCommission

	CREATE TABLE [#RptExecutiveCommission] (
		[ClientKey] [int] NULL
		,[CompanyName] [varchar](255) NULL
		,[ActualAmount] [decimal](18, 2) NULL
		,[FeesAmount] [decimal](18, 2) NULL
		,[MiscellaneousFee] [decimal](18, 2) NULL
		,[BadDebtAmount] [decimal](18, 2) NULL
		,[AdjustmentAmount] [decimal](18, 2) NULL
		,[CommissionableAmount] [float] NULL
		,[AmountPayablePercentage] [varchar](31) NULL
		,[CommissionToBePaid] [decimal](18, 2) NULL
		,[CommissionType] [varchar](55) NOT NULL
		,[AccountExecutive] [varchar](61) NULL
		,[BillingDateKey] [int] NULL
		,[AccountAgingInDays] [varchar](55) NULL
		) ON [primary]

	INSERT INTO [#RptExecutiveCommission] (
	[accountagingindays]
		,
		[ClientKey]
		,[CompanyName]
		,[ActualAmount]
		,[FeesAmount]
		,[MiscellaneousFee]
		,[BadDebtAmount]
		,[CommissionableAmount]
		,[AmountPayablePercentage]
		,[CommissionTobePaid]
		,[CommissionType]
		,[AccountExecutive]
		,[BillingDateKey]
		,[AdjustmentAmount]
		)
	SELECT  CONVERT(VARCHAR, cs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, cs.AccountAgeMax)
		
	,AcComm.ClientKey
		,[CompanyName1] AS companyname
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nactualamount, 0.00))) AS actual
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nfees, 0.00))) AS fees
		,SUM(ISNULL(MiscellaneousFees, 0.00)) AS miscfee
		,SUM(FIA.[BadDebtAmount]) AS baddebt
		,ROUND((SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0))), 2) AS comissionableamount
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), ISNULL(CommissionPercent, 0.00))) AS [amount payable percentage]
		,CONVERT(DECIMAL(18, 2), (SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0)) - SUM(ISNULL(FIA.[AdjustmentAmount], 0.0)) - SUM(ISNULL(FIA.[BadDebtAmount], 0.00))) * (ISNULL(CommissionPercent, 0.00) / 100.0)) AS [comission to be paid]
		,'Special' AS commissiontype
		,LTRIM(RTRIM(accountexecutive)) accountexecutive
		,BillingDateKey
		,SUM(FIA.[AdjustmentAmount]) AS [AdjustmentAmount]
	FROM [dbo].[DimCommissionSetup] cs WITH (NOLOCK)
	LEFT JOIN (
		SELECT SUM(FC.nactualamount) nactualamount
			,SUM(nfees) AS nfees
			,CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,CommissionPercent
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
			,SUM(ISNULL(f.MiscellaneousFees, 0.00)) MiscellaneousFees
			,SUM(ISNULL(BackgroundFees, 0.0)) BackgroundFees
		FROM (
			SELECT SUM(FC.Quantity * FC.UnitPrice) AS nactualamount
				,FC.FileKey
				,DCS.CommissionKey
				,SUM((
						CASE 
							WHEN (
									DCUT.[ComponentUsageTypeName] LIKE 'f%'
									OR DCT.[ChargeasFee] = 1
									)
								THEN (FC.Quantity * FC.UnitPrice)
							ELSE 0.00
							END
						)) AS nfees
				,DC.CompanyName1
				,DC.ClientKey
				,DC.CommissionPercent
				,DC.[AccountExecutive] AS [AccountExecutive]
				,FC.BillingDateKey
				,DC.AccountExecutiveID
			FROM [dbo].[FactComponent] fc WITH (NOLOCK)
			INNER JOIN [dbo].[DimComponentUsageType] DCUT ON DCUT.[ComponentUsageTypeKey] = FC.[ComponentUsageTypeKey]
				AND FC.[IsDelete] = 0
			INNER JOIN [dbo].[DimFile] DF ON DF.[FileKey] = FC.[FileKey]
				AND DF.[IsDelete] = 0
			INNER JOIN [dbo].[DimClient] dc WITH (NOLOCK) ON fc.[clientkey] = dc.[clientkey]
			INNER JOIN [dbo].[DimComponent] dct WITH (NOLOCK) ON dct.[componentkey] = fc.[componentkey]
			INNER JOIN [dbo].[DimCommissionSetup] dcs WITH (NOLOCK) ON DATEDIFF(dd, DC.BusinessStartDate, CONVERT(DATE, CONVERT(VARCHAR, FC.BillingDateKey))) BETWEEN DCS.AccountAgeMin
					AND DCS.AccountAgeMax 
			WHERE DC.CommissionType = 'spc'
				AND FC.[IsBilled] = 1
			GROUP BY FC.FileKey
				,DC.CompanyName1
				,DC.ClientKey
				,DC.CommissionPercent
				,DC.[AccountExecutive]
				,FC.BillingDateKey
				,DCS.CommissionKey
				,DC.[AccountExecutiveID]
			) FC
		LEFT JOIN [dbo].[FactFile] F ON F.[FileKey] = FC.[FileKey]
		GROUP BY CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,CommissionPercent
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
		) AcComm ON CS.CommissionKey = AcComm.CommissionKey
		
	LEFT JOIN [dbo].[FactInvoiceAdjustment] FIA ON --FIA.[CLientKey] = AcComm.ClientKey
		FIA.[AccountExecutiveID] = AcComm.AccountExecutiveID
		AND FIA.AdjustmentMonth = RIGHT(LEFT(CONVERT(VARCHAR, AcComm.[BillingDateKey]), 6), 2)
		AND FIA.AdjustmentYear = LEFT(CONVERT(VARCHAR, BillingDateKey), 4)
	GROUP BY ISNULL([CommissionPercent], 0.00)
		,[CompanyName1]
		,AcComm.ClientKey
		,LTRIM(RTRIM([AccountExecutive]))
		,BillingDateKey
, CONVERT(VARCHAR, cs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, cs.AccountAgeMax)
		
	INSERT INTO [#RptExecutiveCommission] (
		[accountagingindays]
		,[ClientKey]
		,[companyname]
		,[ActualAmount]
		,[FeesAmount]
		,[MiscellaneousFee]
		,[BadDebtAmount]
		,[CommissionableAmount]
		,[AmountPayablePercentage]
		,[CommissionTobePaid]
		,[CommissionType]
		,[AccountExecutive]
		,[BillingDateKey]
		,[AdjustmentAmount]
		)
	SELECT CONVERT(VARCHAR, cs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, cs.AccountAgeMax)
		,Acage.[ClientKey]
		,Acage.[CompanyName1] AS CompanyName
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(Acage.nactualamount, 0.00))) AS actual
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(Acage.nfees, 0.00))) AS fees
		,SUM(ISNULL(MiscellaneousFees, 0.00)) AS miscfee
		,SUM(ISNULL(FIA.BadDebtAmount, 0.00))
		,ROUND((SUM(ISNULL(Acage.nactualamount, 0.00)) - SUM(ISNULL(Acage.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0))), 2) AS comissionableamount
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), ISNULL(cs.AccountPayPercent, 0.00))) AS [amount payable percentage]
		,CONVERT(DECIMAL(18, 2), (SUM(ISNULL(Acage.nactualamount, 0.00)) - SUM(ISNULL(Acage.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0)) - SUM(ISNULL(FIA.[AdjustmentAmount], 0.00)) - SUM(ISNULL(FIA.[BadDebtAmount], 0.00))) * (ISNULL(AccountPayPercent, 0.00) / 100.0))
		,'Regular' AS commissiontype
		,LTRIM(RTRIM(accountexecutive)) accountexecutive
		,BillingDateKey
		,SUM(FIA.[AdjustmentAmount])
	FROM [dbo].[DimCommissionSetup] cs WITH (NOLOCK)
	LEFT JOIN (
		SELECT SUM(FC.nactualamount) nactualamount
			,CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,SUM(nfees) AS nfees
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
			,SUM(ISNULL(f.MiscellaneousFees, 0.00)) MiscellaneousFees
			,SUM(ISNULL(BackgroundFees, 0.0)) BackgroundFees
		FROM (
			SELECT SUM(FC.Quantity * FC.UnitPrice) AS nactualamount
				,FC.FileKey
				,DCS.CommissionKey
				,SUM((
						CASE 
							WHEN (
									DCUT.[ComponentUsageTypeName] LIKE 'f%'
									OR DCT.[ChargeasFee] = 1
									)
								THEN (FC.Quantity * FC.UnitPrice)
							ELSE 0.00
							END
						)) AS nfees
				,DC.AccountExecutive
				,FC.BillingDateKey
				,DC.CompanyName1
				,DC.ClientKey
				,Dc.[AccountExecutiveID]
			FROM [dbo].[FactComponent] fc WITH (NOLOCK)
			INNER JOIN [dbo].[DimComponentUsageType] DCUT ON DCUT.[ComponentUsageTypeKey] = FC.[ComponentUsageTypeKey]
				AND FC.[IsDelete] = 0
			INNER JOIN [dbo].[DimFile] DF ON DF.[FileKey] = FC.[FileKey]
				AND DF.[IsDelete] = 0
			INNER JOIN [dbo].[DimClient] dc WITH (NOLOCK) ON fc.[clientkey] = dc.[clientkey]
			AND CONVERT(Date,DC.BusinessStartDate)<='03/31/2016'
			INNER JOIN [dbo].[DimComponent] dct WITH (NOLOCK) ON dct.[componentkey] = fc.[componentkey]
			INNER JOIN [dbo].[DimCommissionSetup] dcs WITH (NOLOCK) ON DATEDIFF(dd, DC.BusinessStartDate, CONVERT(DATE, CONVERT(VARCHAR, FC.BillingDateKey))) BETWEEN DCS.AccountAgeMin
					AND DCS.AccountAgeMax AND dcs.IsDelete =0
			WHERE DC.CommissionType = 'REG'
				AND FC.[IsBilled] = 1
			GROUP BY FC.FileKey
				,FC.BillingDateKey
				,DCS.CommissionKey
				,DC.AccountExecutive
				,DC.CompanyName1
				,DC.ClientKey
				,DC.AccountExecutiveID
			) FC
		LEFT JOIN [dbo].[FactFile] F ON F.FileKey = FC.FilekEy
		GROUP BY CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
		) Acage ON CS.CommissionKey = Acage.CommissionKey
	LEFT JOIN [dbo].[FactInvoiceAdjustment] FIA ON --FIA.[CLientKey] = Acage.ClientKey
		FIA.AccountExecutiveID = Acage.AccountExecutiveID
		AND FIA.AdjustmentMonth = RIGHT(LEFT(CONVERT(VARCHAR, Acage.[BillingDateKey]), 6), 2)
		AND FIA.AdjustmentYear = LEFT(CONVERT(VARCHAR, BillingDateKey), 4)
	GROUP BY ISNULL(AccountPayPercent, 0.00)
		,CONVERT(VARCHAR, cs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, cs.AccountAgeMax)
		,LTRIM(RTRIM(AccountExecutive))
		,BillingDateKey
		,Acage.CompanyName1
		,Acage.ClientKey
INSERT INTO [#RptExecutiveCommission] (
[accountagingindays]
		,
		[ClientKey]
		,[CompanyName]
		,[ActualAmount]
		,[FeesAmount]
		,[MiscellaneousFee]
		,[BadDebtAmount]
		,[CommissionableAmount]
		,[AmountPayablePercentage]
		,[CommissionTobePaid]
		,[CommissionType]
		,[AccountExecutive]
		,[BillingDateKey]
		,[AdjustmentAmount]
		)
SELECT CONVERT(VARCHAR, cs.StartRange) + ' - ' + CONVERT(VARCHAR, cs.EndRange)
		,AcComm.ClientKey
		,[CompanyName1] AS companyname
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nactualamount, 0.00))) AS actual
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nfees, 0.00))) AS fees
		,SUM(ISNULL(MiscellaneousFees, 0.00)) AS miscfee
		,SUM(FIA.[BadDebtAmount]) AS baddebt
		,ROUND((SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0))), 2) AS comissionableamount
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), ISNULL(IncentivePercentage, 0.00))) AS [amount payable percentage]
		,CONVERT(DECIMAL(18, 2), (SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0)) - SUM(ISNULL(FIA.[AdjustmentAmount], 0.0)) - SUM(ISNULL(FIA.[BadDebtAmount], 0.00))) * (ISNULL(IncentivePercentage, 0.00) / 100.0)) AS [comission to be paid]
		,CS.BucketName AS commissiontype
		,LTRIM(RTRIM(accountexecutive)) accountexecutive
		,BillingDateKey
		,SUM(FIA.[AdjustmentAmount]) AS [AdjustmentAmount]
	FROM dbo.DimNewBusinessIncentive  cs WITH (NOLOCK)
	INNER JOIN (
		SELECT SUM(FC.nactualamount) nactualamount
			,SUM(nfees) AS nfees
			,CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,CommissionPercent
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
			,SUM(ISNULL(f.MiscellaneousFees, 0.00)) MiscellaneousFees
			,SUM(ISNULL(BackgroundFees, 0.0)) BackgroundFees
		FROM (
			SELECT SUM(FC.Quantity * FC.UnitPrice) AS nactualamount
				,FC.FileKey
				,DCS.NewBusinessIncentiveKey AS CommissionKey
				,SUM((
						CASE 
							WHEN (
									DCUT.[ComponentUsageTypeName] LIKE 'f%'
									OR DCT.[ChargeasFee] = 1
									)
								THEN (FC.Quantity * FC.UnitPrice)
							ELSE 0.00
							END
						)) AS nfees
				,DC.CompanyName1
				,DC.ClientKey
				,DCS.IncentivePercentage CommissionPercent
				,DC.[AccountExecutive] AS [AccountExecutive]
				,FC.BillingDateKey
				,DC.[AccountExecutiveID]
			FROM [dbo].[FactComponent] fc WITH (NOLOCK)
			INNER JOIN [dbo].[DimComponentUsageType] DCUT ON DCUT.[ComponentUsageTypeKey] = FC.[ComponentUsageTypeKey]
				AND FC.[IsDelete] = 0
			INNER JOIN [dbo].[DimFile] DF ON DF.[FileKey] = FC.[FileKey]
				AND DF.[IsDelete] = 0
			INNER JOIN [dbo].[DimClient] dc WITH (NOLOCK) ON fc.[clientkey] = dc.[clientkey]
		AND CONVERT(Date,DC.BusinessStartDate)>='04/01/2016'
			INNER JOIN LKPBusinessBucket SBB ON SBB.SiteNumber = dc.SiteNumber
			--AND LEFT(FC.BillingDateKey,6)=LEFT(CONVERT(Varchar,CONVERT(Date,SBB.MONTH),112),6)
			INNER JOIN [dbo].[DimComponent] dct WITH (NOLOCK) ON dct.[componentkey] = fc.[componentkey]
			INNER JOIN dbo.DimNewBusinessIncentive dcs WITH (NOLOCK)
			 ON DATEDIFF(dd, DC.BusinessStartDate, CONVERT(DATE, CONVERT(VARCHAR, FC.BillingDateKey))) BETWEEN 
			DCS.StartRange 
					AND DCS.EndRange
					AND DCS.BucketName = SBB.BucketName
			WHERE  FC.[IsBilled] = 1
			GROUP BY FC.FileKey
				,DC.CompanyName1
				,DC.ClientKey
				,DCS.IncentivePercentage
				,DC.[AccountExecutive]
				,FC.BillingDateKey
				,DCS.NewBusinessIncentiveKey
				,DC.[AccountExecutiveID]
			) FC
		LEFT JOIN [dbo].[FactFile] F ON F.[FileKey] = FC.[FileKey]
		GROUP BY CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,CommissionPercent
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
		) AcComm ON CS.NewBusinessIncentiveKey = AcComm.CommissionKey
		
	LEFT JOIN [dbo].[FactInvoiceAdjustment] FIA ON --FIA.[CLientKey] = AcComm.ClientKey
		FIA.AccountExecutiveID = AcComm.AccountExecutiveID
		AND FIA.AdjustmentMonth = RIGHT(LEFT(CONVERT(VARCHAR, AcComm.[BillingDateKey]), 6), 2)
		AND FIA.AdjustmentYear = LEFT(CONVERT(VARCHAR, BillingDateKey), 4)
	GROUP BY ISNULL(IncentivePercentage , 0.00)
		,[CompanyName1]
		,AcComm.ClientKey
		,LTRIM(RTRIM([AccountExecutive]))
		,BillingDateKey
,CONVERT(VARCHAR, cs.StartRange) + ' - ' + CONVERT(VARCHAR, cs.EndRange)
,CS.BucketName
	SELECT @sourcecount = COUNT(1)
	FROM [#Rptexecutivecommission]
TRUNCATE TABLE dbo.[RptExecutiveCommission]
	INSERT INTO [dbo].[RptExecutiveCommission] (
		[ClientKey]
		,[CompanyName]
		,[ActualAmount]
		,[FeesAmount]
		,[MiscellaneousFee]
		,[BadDebtAmount]
		,[CommissionableAmount]
		,[AdjustmentAmount]
		,[AmountPayablePercentage]
		,[CommissionToBePaid]
		,[CommissionType]
		,[AccountExecutive]
		,[BillingDateKey]
		,[AccountAgingInDays]
		,[AuditInsertedPackageKey]
		)
	SELECT [ClientKey]
		,[CompanyName]
		,[ActualAmount]
		,[FeesAmount]
		,[MiscellaneousFee]
		,[BadDebtAmount]
		,[CommissionableAmount]
		,[AdjustmentAmount]
		,[AmountPayablePercentage]
		,[CommissionToBePaid]
		,[CommissionType]
		,[AccountExecutive]
		,[BillingDateKey]
		,CASE 
			WHEN AccountAgingInDays = '731 - 1095'
				THEN '731 - 1,095'
			WHEN AccountAgingInDays = '1462 - 9999'
				THEN '1,462 - 9,999'
			WHEN AccountAgingInDays = '1096 - 1461'
				THEN '1,096 - 1,461'
			ELSE AccountAgingInDays
			END AS [AccountAgingInDays]
		,@packagekey
	FROM [#RptExecutiveCommission]

	
	INSERT INTO [dbo].[RptExecutiveCommission] (
		[CompanyName]
		,[ClientKey]
		,[ActualAmount]
		,[FeesAmount]
		,[MiscellaneousFee]
		,[BadDebtAmount]
		,[AdjustmentAmount]
		,[CommissionableAmount]
		,[AmountPayablePercentage]
		,[CommissionToBePaid]
		,[CommissionType]
		,[AccountExecutive]
		,[BillingDateKey]
		,[AccountAgingInDays]
		,[AuditInsertedPackageKey]
		)
	SELECT DC.CompanyName1
		,DC.ClientKey
		,NULL
		,NULL
		,NULL
		,FI.BadDebtAmount
		,ISNULL(FI.Amount, 0.00) - ISNULL(FI.Fee, 0.00) - ISNULL(FI.BadDebtAmount, 0.00)
		,- (ISNULL(FI.BadDebtAmount, 0.00) + (ISNULL(FI.Amount, 0.00) - ISNULL(FI.Fee, 0.00)))
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), CASE 
					WHEN DC.CommissionType = 'REG'
						THEN DCs.AccountPayPercent
					WHEN DC.CommissionType = 'spc'
						THEN DC.CommissionPercent
					END))
		,- (
			(ISNULL(FI.BadDebtAmount, 0.00) + ISNULL(FI.Amount, 0.00) - ISNULL(FI.Fee, 0.00)) * ISNULL(CASE 
					WHEN DC.CommissionType = 'REG'
						THEN DCs.AccountPayPercent
					WHEN DC.CommissionType = 'spc'
						THEN DC.CommissionPercent
					END, 0.00)
			) / 100.00
		,CASE 
			WHEN DC.CommissionType = 'REG'
				THEN 'REGULAR'
			WHEN DC.CommissionType = 'spc'
				THEN 'SPECIAL'
			END
		,DC.AccountExecutive
		,CONVERT(VARCHAR, CONVERT(DATE, FI.AdjustmentYear + '-' + FI.AdjustmentMonth + '-01'), 112)
		,CASE 
			WHEN DC.CommissionType = 'REG'
				THEN CONVERT(VARCHAR, dcs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, dcs.AccountAgeMax)
			END
		,@packagekey
	FROM [dbo].[FactInvoiceAdjustment] FI
	INNER JOIN [dbo].[DimClient] DC ON FI.CLientKEy = DC.ClientKey
	INNER JOIN [dbo].[DimCommissionSetup] dcs WITH (NOLOCK) ON DATEDIFF(dd, DC.BusinessStartDate, CONVERT(DATE, CONVERT(VARCHAR, FI.AdjustmentYear + '-' + FI.AdjustmentMonth + '-01'))) BETWEEN DCS.AccountAgeMin
			AND DCS.AccountAgeMax
	LEFT JOIN [dbo].[RptExecutiveCommission] FC ON FC.[CLientKey] = DC.ClientKey
		AND FI.AdjustmentMonth = RIGHT(LEFT(CONVERT(VARCHAR, FC.[BillingDateKey]), 6), 2)
		AND FI.AdjustmentYear = LEFT(CONVERT(VARCHAR, BillingDateKey), 4)
	WHERE FC.ClientKey IS NULL

	SELECT @destinationfinalrowcount = COUNT(1)
	FROM [dbo].[Rptexecutivecommission]

	SELECT @insertcount = COUNT(1)
	FROM [dbo].[Rptexecutivecommission]
	WHERE CONVERT(DATE, auditinserteddate) = CONVERT(DATE, getdate())

	SELECT @sourcecount AS sourcecount
		,@insertcount AS insertcount
		,@updatecount AS updatecount
		,@deletecount AS deletecount
		,@destinationrowcount AS destinationrowcount
		,@destinationfinalrowcount AS destinationfinalrowcount
		,CASE 
			WHEN @destinationrowcount = 0
				THEN 0
			ELSE @sourcecount - (@updatecount + @deletecount)
			END AS nochangerowcount
		,@sourcecount AS extractrowcount
		,@duplicaterecordsfr AS duplicaterecordsfr

	IF OBJECT_ID('tempdb..#RptExecutiveCommission') IS NOT NULL
		DROP TABLE tempdb..#RptExecutiveCommission
END
GO


