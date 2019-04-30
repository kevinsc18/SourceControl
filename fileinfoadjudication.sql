declare @startDate datetime
declare @endDate datetime, @site varchar(20),@Batchno varchar(50)
set @startDate = '2017-05-01'
set @endDate = '2017-05-15'
set @site='SPRI001-0000'
--set @Batchno='SPRI001-0000'
SELECT DISTINCT 
     bg.csiteno AS [Site#], 
     bg.cbatchno, 
	 bg.cfileno AS [File#], 
	 bg.cappfname AS [First Name], 
	 bg.capplname AS [Last Name], 
	 bg.ddatereq AS [Date Requested], 
	 bg.dcompdate AS [Date Completed], 
	 bg.crequester AS [Requestor], 
	 bg.cstatus AS [File Status], 
	 bg.cpackselected AS [Package],
	 bg.listrouble,
	  (select sb.cvalue from sbilling sb where sb.cfileno = bg.cfileno and sb.ccode='EMPID')[Employee ID],
	 (select top 1  cemail from bgdrequestadditional ba where ba.cfileno = bg.cfileno)[Applicant Email],
	  (select sum(yunitprice) from bgdreqdetail bd where bd.cfileno = bg.cfileno and bd.ctype like 'F%')[Fee Total],
	  (select sum(yunitprice) from bgdreqdetail bd where bd.cfileno = bg.cfileno and bd.ctype not like 'F%')[Service Total],
	 (select sum(yunitprice) from bgdreqdetail bd where bd.cfileno = bg.cfileno)[Total File Cost],
     (SELECT        TOP (1) creqstatdesc
         FROM            clientreqstat cs WITH (nolock)
		 join adjudications ad on cs.creqstatus=ad.creqstatus
		 WHERE        (bg.cclientreqstat <> ad.creqstatus) AND (bg.cacctno = cacctno)
		 and bg.cfileno = ad.cfileno order by ad.dcreatedate asc) AS [Original Adj.]
,     (SELECT        TOP (1) creqstatdesc
         FROM            clientreqstat WITH (nolock)
         WHERE        (bg.cclientreqstat = creqstatus) AND (bg.cacctno = cacctno)) AS flagdescription
	,(SELECT        TOP (1) dcreatedate
         FROM            adjudications adj WITH (nolock)
         WHERE        (bg.cclientreqstat = adj.creqstatus) AND (bg.cfileno = adj.cfileno)) AS [Current Adj. Date]
into #temp
FROM            bgdrequest AS bg 
where bg.dcompdate > @startDate
and bg.dcompdate < dateadd(d, 1, @endDate)
and bg.csiteno in (@site)
and bg.cbatchno in (@Batchno)
and bg.cstatus='CLOSED'

select [Site#], cbatchno [Batchno],File#, [First Name], [Last Name], 
 [date requested][Date Requested]
, [date completed][Date Completed]
,[Requestor],[File Status], 
case when [Package]='NONE' then 'A LA CARTE' else [package] end [Package],
[Applicant Email],
[Fee Total], [Service Total],
 [Total File Cost],
case when [Original Adj.] is null then ' ' else [Original Adj.] end [Original Adj.], 
flagdescription, [Current Adj. Date]
,isnull([Employee ID], '')[Employee ID]
,case when listrouble = 1 then 'Y' else 'N' end [Troubled File?]
from #Temp

drop table #temp



/*parameter data set */
-- industry
select distinct clnofbus[Industry] , clnofbus[IndustryKey]
from client
where csiteno not like 'PSTS%'
and csiteno not like 'TEST%'
and lactive=1
and clnofbus <> ''
union all
select 'BLANK', ''
order by 1
--client
DECLARE @Group varchar(55)
SELECT @Group = CASE WHEN @Groupheader IS NULL THEN 'ALL' ELSE @Groupheader END
SELECT DISTINCT cgrpno AS [Client] , cgrpno as GroupKey
FROM [dbo].[Client] A
where (cgrpno in (@Groupheader)
or left(cgrpno, 4) in (@groupheader)
OR @Group='ALL')
AND clnofbus IN (@Industry)
ORDER BY cgrpno
--corpid
SELECT DISTINCT  cCorpID[CorpID]
FROM [dbo].[Client]
WHERE  cgrpno IN (@Client)
AND clnofbus IN (@Industry)
UNION ALL
SELECT ' All'
ORDER BY cCorpID ASC
--site
SELECT DISTINCT csiteno + ' | ' + ccompname1  AS [SiteName],csiteno[ClientKey]
FROM [dbo].[Client]
WHERE cgrpno IN (@Client)
AND clnofbus IN (@Industry)
AND (ccorpid IN (@CorpID) OR ' All' IN( @CorpID) )
ORDER BY  SiteName 