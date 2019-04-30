select
br.csiteno      [Site]
,br.cfileno   [File Number]
,br.cappfname [Applicant First Name]
,br.capplname [Applicant Last Name]
,br.ddatereq  [File Request Date]
,br.dcompdate[File Completed Date]
,case when b.crptdesc is null or b.crptdesc='' then b.crpttype
         else b.crptdesc end [Component]

,b.dcompdate [Component Completion Date]
,b.yunitprice [Component Price]  
,case when b.ctype ='P' then 'Package'
when b.ctype like 'F%' then 'Fee' else 'a la carte' end [Component Type] 
,case when b.CCountry is null or b.CCountry =' ' then 'USA'else b.CCountry end  [Component Country]
from bgdrequest br 
join(select  distinct bd.cfileno,bd.clineno,yunitprice,dcompdate,bd.crptdesc,bd.crpttype,bd.ctype
,case when bd.crptdesc is null or bd.crptdesc='' then bd.crpttype
         else bd.crptdesc end [Component]
,bi.CCountry
,bd.dcompdate [Component Completion Date]
,bd.yunitprice [Component Price]  
from  bgdreqdetail bd 
left join BgdReqDetailInternational bi on bi.CFileNo= bd.cfileno and bi.CLineNo= bd.clineno
where  bd.cstatus <>'NOTREQ'
and bd.cstatus <>'SUSPENDED'	
)b on b.cfileno =br.cfileno
where br.cstatus ='closed'
and br.csiteno like 'APPL416%'
--and br.csiteno like 'BCVD001%'
and br.dcompdate>='01/01/2017'
and br.dcompdate<='04/01/2019'
--and br.dcompdate>='01/01/2014'
--and br.dcompdate<='01/01/2017'
--and br.cfileno ='AF01832286'
order by br.cfileno

--//another way may dplicate //
select 
br.csiteno      [Site]
,br.cfileno   [File Number]
,br.cappfname [Applicant First Name]
,br.capplname [Applicant Last Name]
,br.ddatereq  [File Request Date]
,br.dcompdate[File Completed Date]
,case when bd.crptdesc is null or bd.crptdesc='' then bd.crpttype
         else bd.crptdesc end [Component]
,bd.dcompdate [Component Completion Date]
,bd.yunitprice [Component Price]  
,case when bd.ctype ='P' then 'Package'
when bd.ctype like 'F%' then 'Fee' else 'a la carte' end [Component Type] 
,case when cc.cdesc is null or cc.cdesc =' ' then 'United States' ELSE cc.cdesc END  [Component Country]
from bgdrequest br 
join bgdreqdetail bd on br.cfileno =bd.cfileno
left  join BgdReqDetailInternational bi on bi.CFileNo= bd.cfileno and bi.CLineNo= bd.clineno	
left  join countrycode cc on cc.clongcode=bi.CCountry or cc.cshortcode=bi.CCountry
where br.cstatus ='closed'
and bd.cstatus <>'NOTREQ'
and bd.cstatus <>'SUSPENDED'
--and br.csiteno like 'APPL416%'
and br.csiteno like 'BCVD001%'
and br.dcompdate>='01/01/2017'
and br.dcompdate<='03/31/2019'
--and br.dcompdate>='01/01/2014'
--and br.dcompdate<='01/01/2017'
--and br.cfileno ='AF01832286'
order by br.cfileno

select * from bgdreqdetail  where cfileno ='AF01832286'
select  * from BgdReqDetailInternational where cfileno ='AF01832286'


