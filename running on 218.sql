USE [warehouse]
GO
/****** Object:  StoredProcedure [dbo].[usprptexecutivecommission]    Script Date: 4/26/2019 2:08:00 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO




ALTER PROCEDURE [dbo].[usprptexecutivecommission] (@packagekey AS INT)
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
		AccountExecutiveID Change
 -		Add New Business Bucket   11/15/2018	 Kevin Liu	         Add new rate columns to change the new business
 -		Commission rate 										     commission Rate dynamicly
 -      Add Business Start Date 				
 -	    Add SiteNumber		 
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
		,[SiteNumber]	 varchar(50) null
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
		,[BusinessStartDate] datetime null								
		,[EndDate]	         datetime	null							
		,[Yr1Rate]	         decimal(4,2) null							
		,[Yr2Rate]	         decimal(4,2) null							
		,[Yr3Rate]	         decimal(4,2) null							
		,[PerpetualRate]     decimal(4,2) null							

		
		) ON [primary]
  /* 1. SPC tpye*/
	INSERT INTO [#RptExecutiveCommission] (
	     [accountagingindays]
	    ,[ClientKey]
		,[CompanyName]
	,[SiteNumber]						
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
    ,[BusinessStartDate]	
	,[EndDate]			  
	,[Yr1Rate]	     	  
	,[Yr2Rate]	     	  
	,[Yr3Rate]	     	  
	,[PerpetualRate] 	  
	
	)						  

  	SELECT  CONVERT(VARCHAR, cs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, cs.AccountAgeMax)
		
	,AcComm.ClientKey
		,[CompanyName1] AS companyname
		 ,SiteNumber
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nactualamount, 0.00))) AS actual
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nfees, 0.00))) AS fees
		,SUM(ISNULL(MiscellaneousFees, 0.00)) AS miscfee
		,SUM(isnull(FIA.[BadDebtAmount],0.00)) AS baddebt
		,ROUND((SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0))), 2) AS comissionableamount
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), ISNULL(CommissionPercent, 0.00))) AS [amount payable percentage]
		,CONVERT(DECIMAL(18, 2), (SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0)) - SUM(ISNULL(FIA.[AdjustmentAmount], 0.0)) - SUM(ISNULL(FIA.[BadDebtAmount], 0.00))) * (ISNULL(CommissionPercent, 0.00) / 100.0)) AS [comission to be paid]
		,'Special' AS commissiontype
		,LTRIM(RTRIM(accountexecutive)) accountexecutive
		,BillingDateKey
		,SUM(isnull(FIA.[AdjustmentAmount],0.00)) AS [AdjustmentAmount]
		,AcComm.BusinessStartDate
		,AcComm.EndDate
		
		  	 ,(select top 1 	AccountPayPercent
		 from  DimCommissionSetup where commissionkey=1) 
		   ,(select top 1 	AccountPayPercent
		 from  DimCommissionSetup where commissionkey=2)
		  ,(select top 1 	AccountPayPercent
		 from  DimCommissionSetup where commissionkey=3)  
		 ,(select top 1 	AccountPayPercent
			 from  DimCommissionSetup where commissionkey=5) 	

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
			,fc.BusinessStartDate
			,fc.EndDate
			 ,fc.SiteNumber
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
			 ,dc.BusinessStartDate	  			  
			
			,dateadd(dd,1095, dc.BusinessStartDate) EndDate	 
			,dc.SiteNumber
			FROM [dbo].[FactComponent] fc WITH (NOLOCK)
			INNER JOIN [dbo].[DimComponentUsageType] DCUT ON DCUT.[ComponentUsageTypeKey] = FC.[ComponentUsageTypeKey]
				AND FC.[IsDelete] = 0
			INNER JOIN [dbo].[DimFile] DF ON DF.[FileKey] = FC.[FileKey]
				AND DF.[IsDelete] = 0
			INNER JOIN [dbo].[DimClient] dc WITH (NOLOCK) ON fc.[clientkey] = dc.[clientkey]
			INNER JOIN [dbo].[DimComponent] dct WITH (NOLOCK) ON dct.[componentkey] = fc.[componentkey]
			INNER JOIN [dbo].[DimCommissionSetup] dcs WITH (NOLOCK) ON DATEDIFF(dd, DC.BusinessStartDate, CONVERT(DATE, CONVERT(VARCHAR, FC.BillingDateKey))) BETWEEN DCS.AccountAgeMin
					AND DCS.AccountAgeMax 
			WHERE DC.[CommissionType ] = 'spc'
				AND FC.[IsBilled] = 1
			GROUP BY FC.FileKey
				,DC.CompanyName1
				,DC.ClientKey
				,DC.CommissionPercent
				,DC.[AccountExecutive]
				,FC.BillingDateKey
				,DCS.CommissionKey
				,DC.[AccountExecutiveID]
			,dc.BusinessStartDate	  
			,dc.SiteNumber
			) FC
		LEFT JOIN [dbo].[FactFile] F ON F.[FileKey] = FC.[FileKey]
		GROUP BY CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,CommissionPercent
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
			,BusinessStartDate
			,EndDate
			,SiteNumber
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
,AcComm.BusinessStartDate
,AcComm.EndDate
,SiteNumber
		

	/*2. REG type    DC.BusinessStartDate)<='03/31/2016'*/				
	INSERT INTO [#RptExecutiveCommission] (			
		[accountagingindays]
		,[ClientKey]
		,[companyname]
		,[SiteNumber]
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
		,[BusinessStartDate]	 
		,[EndDate]	        	 
		,[Yr1Rate]	        	 
		,[Yr2Rate]	        	 
		,[Yr3Rate]	        	 
		,[PerpetualRate]    	 
		)
	SELECT  CONVERT(VARCHAR, cs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, cs.AccountAgeMax)
		,Acage.[ClientKey]
		,Acage.[CompanyName1] AS CompanyName
		,SiteNumber
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(Acage.nactualamount, 0.00))) AS actual
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(Acage.nfees, 0.00))) AS fees
		,SUM(ISNULL(MiscellaneousFees, 0.00)) AS miscfee
		,SUM(ISNULL(FIA.BadDebtAmount, 0.00))
		,ROUND((SUM(ISNULL(Acage.nactualamount, 0.00)) - SUM(ISNULL(Acage.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0))), 2) AS comissionableamount
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), ISNULL(cs.AccountPayPercent, 0.00))) AS [amount payable percentage]   --use cs.Accountpaypercent
		,CONVERT(DECIMAL(18, 2), (SUM(ISNULL(Acage.nactualamount, 0.00)) - SUM(ISNULL(Acage.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0)) - SUM(ISNULL(FIA.[AdjustmentAmount], 0.00)) - SUM(ISNULL(FIA.[BadDebtAmount], 0.00))) * (ISNULL(AccountPayPercent, 0.00) / 100.0))
		,'Regular' AS commissiontype
		,LTRIM(RTRIM(accountexecutive)) accountexecutive
		,BillingDateKey
		,SUM(isnull(FIA.[AdjustmentAmount],0.00))
	   ,Acage.BusinessStartDate		 
		 ,acage.EndDate				 
	    ,(select top 1 	AccountPayPercent					 
		 from  DimCommissionSetup where commissionkey=1) 	 
		   ,(select top 1 	AccountPayPercent				 
		 from  DimCommissionSetup where commissionkey=2)	 
		  ,(select top 1 	AccountPayPercent				 
		 from  DimCommissionSetup where commissionkey=3)  	 
		 ,(select top 1 	AccountPayPercent				 
		 from  DimCommissionSetup where commissionkey=5) 	 
		
	FROM [dbo].[DimCommissionSetup] cs WITH (NOLOCK)
	LEFT JOIN (
		SELECT SUM(FC.nactualamount) nactualamount
			,CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,SiteNumber
			,SUM(nfees) AS nfees
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
			,SUM(ISNULL(f.MiscellaneousFees, 0.00)) MiscellaneousFees
			,SUM(ISNULL(BackgroundFees, 0.0)) BackgroundFees
			,fc.BusinessStartDate		 
			,fc.EndDate
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
				 ,dc.SiteNumber
				,DC.ClientKey
				,Dc.[AccountExecutiveID]
				,dc.BusinessStartDate		 
				,dateadd(dd,1095, dc.BusinessStartDate) EndDate	 

	
			FROM [dbo].[FactComponent] fc WITH (NOLOCK)
			INNER JOIN [dbo].[DimComponentUsageType] DCUT ON DCUT.[ComponentUsageTypeKey] = FC.[ComponentUsageTypeKey]
				AND FC.[IsDelete] = 0
			INNER JOIN [dbo].[DimFile] DF ON DF.[FileKey] = FC.[FileKey]
				AND DF.[IsDelete] = 0
			INNER JOIN [dbo].[DimClient] dc WITH (NOLOCK) ON fc.[clientkey] = dc.[clientkey]
			AND CONVERT(Date,DC.BusinessStartDate)<='03/31/2016'
			INNER JOIN [dbo].[DimComponent] dct WITH (NOLOCK) ON dct.[componentkey] = fc.[componentkey]
			INNER JOIN [dbo].[DimCommissionSetup] dcs WITH (NOLOCK) ON DATEDIFF(dd, DC.BusinessStartDate, 
				CONVERT(DATE, CONVERT(VARCHAR, FC.BillingDateKey))) BETWEEN DCS.AccountAgeMin
					AND DCS.AccountAgeMax AND dcs.IsDelete =0
			WHERE DC.[CommissionType ] = 'REG'
				AND FC.[IsBilled] = 1
			GROUP BY FC.FileKey
				,FC.BillingDateKey
				,DCS.CommissionKey
				,DC.AccountExecutive
				,DC.CompanyName1									
				,DC.ClientKey
				,dc.SiteNumber
				,DC.AccountExecutiveID
				,dc.BusinessStartDate		 
			) FC
		LEFT JOIN [dbo].[FactFile] F ON F.FileKey = FC.FilekEy
		GROUP BY CommissionKey
			,CompanyName1
			,Fc.ClientKey
			,fc.SiteNumber
			,[AccountExecutive]
			,BillingDateKey
			,[AccountExecutiveID]
			,fc.BusinessStartDate	
			,fc.EndDate				 
		) Acage ON CS.CommissionKey = Acage.CommissionKey
	LEFT JOIN [dbo].[FactInvoiceAdjustment] FIA ON
	 --FIA.[CLientKey] = Acage.ClientKey  and
		FIA.AccountExecutiveID = Acage.AccountExecutiveID
		AND FIA.AdjustmentMonth = RIGHT(LEFT(CONVERT(VARCHAR, Acage.[BillingDateKey]), 6), 2)
		AND FIA.AdjustmentYear = LEFT(CONVERT(VARCHAR, BillingDateKey), 4)
	GROUP BY ISNULL(AccountPayPercent, 0.00)
		,CONVERT(VARCHAR, cs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, cs.AccountAgeMax)
		,LTRIM(RTRIM(AccountExecutive))
		,BillingDateKey
		,Acage.CompanyName1
		,acage.SiteNumber
		,Acage.ClientKey				 
		,Acage.BusinessStartDate		 
		,acage.EndDate					 
										  
   /* 3. New Business Buckete
   CONVERT(Date,DC.BusinessStartDate)>='04/01/2016'*/
INSERT INTO [#RptExecutiveCommission] (			
		[accountagingindays],
		[ClientKey]
		,[CompanyName]
		,[SiteNumber]
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
		,[BusinessStartDate]
        ,[EndDate]
		
		,[Yr1Rate]		
		,[Yr2Rate]		
		,[Yr3Rate]
		,PerpetualRate		
			
)

select  AgingInDays
		,AcComm.ClientKey
		,[CompanyName1] AS companyname
		
		,SiteNumber
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nactualamount, 0.00))) AS actual
		,CONVERT(DECIMAL(18, 2), SUM(ISNULL(AcComm.nfees, 0.00))) AS fees
		,SUM(ISNULL(MiscellaneousFees, 0.00)) AS miscfee
		,SUM(isnull(FIA.[BadDebtAmount],0.00)) AS baddebt
		,ROUND((SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0))), 2) AS comissionableamount
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), ISNULL(CurrCommissionRate, 0.00))) AS [amount payable percentage]
		,CONVERT(DECIMAL(18, 2), (SUM(ISNULL(AcComm.nactualamount, 0.00)) - SUM(ISNULL(AcComm.nfees, 0.00)) - 0 - SUM(ISNULL(MiscellaneousFees, 0.00)) - SUM(ISNULL(BackgroundFees, 0.0)) - SUM(ISNULL(FIA.[AdjustmentAmount], 0.0)) - SUM(ISNULL(FIA.[BadDebtAmount], 0.00))) * (ISNULL(CurrCommissionRate, 0.00) / 100.0)) AS [comission to be paid]
		,accomm.BucketName AS commissiontype				  --add 
		,LTRIM(RTRIM(accountexecutive)) accountexecutive
		,BillingDateKey
		,SUM(isnull(FIA.[AdjustmentAmount],0.00)) AS [AdjustmentAmount]
		 ,BusinessStartDate
		 ,EndDate
		
		,Yr1Rate
		,Yr2Rate
		,Yr3Rate
		,PerpetualRate
from
(     SELECT SUM(FC.nactualamount) nactualamount
			,SUM(nfees) AS nfees
		    ,CompanyName1
			,fc.BucketName
			,SiteNumber
			,Fc.ClientKey
			,fc.CurrCommissionRate
			,[AccountExecutive]
			,[AccountExecutiveID]
			,BillingDateKey
			,SUM(ISNULL(f.MiscellaneousFees, 0.00)) MiscellaneousFees
			,SUM(ISNULL(f.BackgroundFees, 0.0)) BackgroundFees									
			,isnull(FC.Yr1Rate ,0)	Yr1Rate
			,isnull(FC.Yr2Rate ,0)	Yr2Rate
			,isnull(FC.Yr3Rate,0)	Yr3Rate
			,isnull(FC.PerpetualRate,0)	PerpetualRate
			,FC.[month]
			,FC.BusinessStartDate
			,FC.EndDate
			,FC.AgingInDays
		

from (
		select 
		dc.sitenumber ,
		SUM(FC.Quantity * FC.UnitPrice) AS nactualamount
		,FC.FileKey
	    ,SUM((
		CASE 
				WHEN (
						DCUT.[ComponentUsageTypeName] LIKE 'f%'
						OR DCT.[ChargeasFee] = 1
							)
					THEN (FC.Quantity * FC.UnitPrice)
							ELSE 0.00
									END	 )) AS nfees
			,DC.CompanyName1
			,DC.ClientKey
		    ,DC.[AccountExecutive] AS [AccountExecutive]
			,FC.BillingDateKey
			,DC.[AccountExecutiveID]
			,dc.BusinessStartDate
			,dateadd(dd,1095,DC.BusinessStartDate)  EndDate
			,	case when datediff(dd, dc.BusinessStartDate,BillingDate) between 1 and 365	then sbb.Yr1Rate
					when datediff(dd, dc.BusinessStartDate,BillingDate) between 366 and 730   then sbb.Yr2Rate
					when datediff(dd, dc.BusinessStartDate,BillingDate) between 731 and 1095	then sbb.Yr3Rate	
					else  sbb.PerpetualRate								
			end     CurrCommissionRate	
					,sbb.BucketName
					,sbb.Yr1Rate
					,sbb.Yr2Rate
					,sbb.Yr3Rate
					,sbb.PerpetualRate
					,sbb.Month
					,datediff(dd, BusinessStartDate,BillingDate)	 AgingInDays1
					,CONVERT(VARCHAR, dcs.StartRange) + ' - ' + CONVERT(VARCHAR, dcs.EndRange) AgingInDays
  FROM [dbo].[FactComponent] fc WITH (NOLOCK)
  	INNER JOIN [dbo].[DimComponentUsageType] DCUT ON DCUT.[ComponentUsageTypeKey] = FC.[ComponentUsageTypeKey]
				AND FC.[IsDelete] = 0
   	INNER JOIN [dbo].[DimFile] DF ON DF.[FileKey] = FC.[FileKey]
				AND DF.[IsDelete] = 0
		INNER JOIN [dbo].[DimClient] dc WITH (NOLOCK) ON fc.[clientkey] = dc.[clientkey]
			AND CONVERT(Date,DC.BusinessStartDate)>='04/01/2016'
		INNER JOIN [dbo].[DimComponent] dct WITH (NOLOCK) ON dct.[componentkey] = fc.[componentkey]
		INNER JOIN LkpBusinessBucket SBB ON SBB.SiteNumber = dc.SiteNumber
		--AND LEFT(FC.BillingDateKey,6)=LEFT(CONVERT(Varchar,CONVERT(Date,SBB.MONTH),112),6)
		INNER JOIN dbo.DimNewBusinessIncentive dcs WITH (NOLOCK)	
				ON DATEDIFF(dd, DC.BusinessStartDate, CONVERT(DATE, CONVERT(VARCHAR, FC.BillingDateKey))) BETWEEN 
			DCS.StartRange AND DCS.EndRange
WHERE 
 FC.[IsBilled] = 1
GROUP BY FC.FileKey
,DC.CompanyName1
,DC.ClientKey
,DC.[AccountExecutive]
,FC.BillingDateKey
,DC.[AccountExecutiveID]
,dc.BusinessStartDate		
,sbb.BucketName				
,sbb.Yr1Rate			
,sbb.Yr2Rate			
,sbb.Yr3Rate				
,sbb.PerpetualRate			
,datediff(dd, BusinessStartDate,BillingDate) 
,CONVERT(VARCHAR, dcs.StartRange) + ' - ' + CONVERT(VARCHAR, dcs.EndRange)	
,sbb.[Month]
,dc.sitenumber 
 )FC
		LEFT JOIN [dbo].[FactFile] F ON F.[FileKey] = FC.[FileKey]
		GROUP BY CompanyName1
			,fc.BucketName				
			,fc.SiteNumber
			,Fc.ClientKey
			,fc.CurrCommissionRate		 
			,[AccountExecutive]
			,fc.AccountExecutiveID	     
			,BillingDateKey
			,FC.Yr1Rate					 
			,FC.Yr2Rate					 
			,FC.Yr3Rate					
			,FC.PerpetualRate			
			,FC.[month]					 
			,FC.BusinessStartDate		 
			,FC.EndDate					 
			,FC.AgingInDays				 
			
		
		) AcComm 
LEFT JOIN [dbo].[FactInvoiceAdjustment] FIA ON FIA.[CLientKey] = AcComm.ClientKey
		   	AND FIA.AdjustmentMonth = RIGHT(LEFT(CONVERT(VARCHAR, AcComm.[BillingDateKey]), 6), 2)
		AND FIA.AdjustmentYear = LEFT(CONVERT(VARCHAR, BillingDateKey), 4)
GROUP BY AgingInDays 
,ISNULL(CurrCommissionRate , 0.00)
,[CompanyName1]
,AcComm.ClientKey
,LTRIM(RTRIM([AccountExecutive]))
,BillingDateKey
,BucketName
,SiteNumber
,BusinessStartDate
,EndDate
,CurrCommissionRate
,Yr1Rate
,Yr2Rate
,Yr3Rate
,PerpetualRate



/*4 over 730 days */
	SELECT  @sourcecount = COUNT(1)
	FROM [#Rptexecutivecommission]
TRUNCATE TABLE dbo.[RptExecutiveCommission]
	INSERT INTO [dbo].[RptExecutiveCommission] (
		[ClientKey]
		,[CompanyName]	
		,[SiteNumber]					
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
	,[BusinessStartDate]			
	,EndDate						
	,[AuditInsertedPackageKey]		
	,[Yr1Rate]						
	,[Yr2Rate]						
	,[Yr3Rate]						
	,[PerpetualRate]				
		
		)
	SELECT [ClientKey]
		,[CompanyName]													
		,[SiteNumber]													  	
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
	,[BusinessStartDate]
	,EndDate
,@packagekey
	,[Yr1Rate]		
	,[Yr2Rate]		
	,[Yr3Rate]		
	,[PerpetualRate]
	FROM [#RptExecutiveCommission]

	/*5   [dbo].[FactInvoiceAdjustment] */
	INSERT INTO [dbo].[RptExecutiveCommission] (
		[CompanyName]
		,[SiteNumber]
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
		,[BusinessStartDate] 		
		,EndDate					
		 ,[Yr1Rate]					
		  ,[Yr2Rate]				
		  ,[Yr3Rate]				
		  ,[PerpetualRate]			
		,[AuditInsertedPackageKey]	
		
		)
SELECT DC.CompanyName1
	,dc.SiteNumber
		,DC.ClientKey
		,NULL
		,NULL
		,NULL
		,FI.BadDebtAmount
		,ISNULL(FI.Amount, 0.00) - ISNULL(FI.Fee, 0.00) - ISNULL(FI.BadDebtAmount, 0.00)		   --Adjustamount
		,- (ISNULL(FI.BadDebtAmount, 0.00) + (ISNULL(FI.Amount, 0.00) - ISNULL(FI.Fee, 0.00)))	   --commissionable
		,CONVERT(VARCHAR, CONVERT(DECIMAL(5, 2), CASE 											  
					WHEN DC.[CommissionType ]= 'REG'
						THEN DCs.AccountPayPercent
					WHEN DC.[CommissionType ]= 'spc'
						THEN DC.CommissionPercent
					END))
		,- (																	--	[AmountPayablePercentage]
			(ISNULL(FI.BadDebtAmount, 0.00) + ISNULL(FI.Amount, 0.00) - ISNULL(FI.Fee, 0.00)) * ISNULL(CASE 
					WHEN DC.[CommissionType ]= 'REG'
						THEN DCs.AccountPayPercent
					WHEN DC.[CommissionType ]= 'spc'
						THEN DC.CommissionPercent
					END, 0.00)
			) / 100.00
		,CASE 
			WHEN DC.[CommissionType ]= 'REG'
				THEN 'REGULAR'
			WHEN DC.[CommissionType ]= 'spc'
				THEN 'Special'
			END
		,DC.AccountExecutive
		,CONVERT(VARCHAR, CONVERT(DATE, FI.AdjustmentYear + '-' + FI.AdjustmentMonth + '-01'), 112)
		,CASE 
			WHEN DC.[CommissionType ]= 'REG'
				THEN CONVERT(VARCHAR, dcs.AccountAgeMin) + ' - ' + CONVERT(VARCHAR, dcs.AccountAgeMax)
			END
		   ,dc.BusinessStartDate
		   ,Dateadd(dd,1095,dc.BusinessStartDate)
		   ,FC.Yr1Rate
		   ,FC.Yr2Rate
		   ,FC.Yr3Rate
		   ,Fc.PerpetualRate


	   ,@packagekey
	FROM [dbo].[FactInvoiceAdjustment] FI
	INNER JOIN [dbo].[DimClient] DC ON FI.CLientKEy = DC.ClientKey
	INNER JOIN [dbo].[DimCommissionSetup] dcs WITH (NOLOCK) ON DATEDIFF(dd, DC.BusinessStartDate, CONVERT(DATE, CONVERT(VARCHAR, FI.AdjustmentYear + '-' + FI.AdjustmentMonth + '-01'))) BETWEEN DCS.AccountAgeMin
			AND DCS.AccountAgeMax
	LEFT JOIN [dbo].[RptExecutiveCommission] FC ON FC.[CLientKey] = DC.ClientKey
		AND FI.AdjustmentMonth = RIGHT(LEFT(CONVERT(VARCHAR, FC.[BillingDateKey]), 6), 2)
		AND FI.AdjustmentYear = LEFT(CONVERT(VARCHAR, BillingDateKey), 4)
	WHERE FC.ClientKey IS NULL
	
	/*6 Audit info to log tables*/
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
