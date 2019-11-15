![CLEVER DATA GIT REPO](https://raw.githubusercontent.com/LiCongMingDeShujuku/git-resources/master/0-clever-data-github.png "李聪明的数据库")

# 比较本地SQL帐户与Active Directory
#### Compare Local SQL Accounts To Active Directory
**发布-日期: 2018年03月21日 (评论)**

![#](images/compare-domain-accounts-added-to-sql-to-active-domain-accounts-in-active-directory.png?raw=true "#")

## Contents

- [中文](#中文)
- [English](#English)
- [SQL Logic](#Logic)
- [Build Info](#Build-Info)
- [Author](#Author)
- [License](#License) 


## 中文
在大多数环境中，DBA需要知道网络上哪些帐户已被禁用，由此可以作为考虑标准安全性的一个因素将其从SQL Server中依次删除。
此脚本将帮助构建以下对象：
- 创建链接服务器ADSI_LINK
- 查询Active Directory
- 使用Active Directory结果创建临时表格
- 获取临时表格的大小
- 将本地帐户与Active Directory进行比较
- 查找已禁用（或已取消配置）的帐户

这将创建一个有关已添加到SQL Server的已知禁用帐户的列表。

## English
In most environment DBA’ will need to know what accounts have been disabled on the network so they can in-turn be removed from SQL Server as a matter of standard security.
This script will help build the following objects…
- Create Linked Server ADSI_LINK
- Query Active Directory
- Create Temp Table With Active Directory Results
- Get Size of Temp Table
- Compare Local Domain Accounts to Active Directory
- Find Disabled (or deprovisioned accounts)

This will create alist of known Disabled accounts that were added to SQL Server.


---
## Logic
```SQL

use master;
set nocount on
 
--	Create ADSI Linked Server for Active Directory queries (if does not exist)
--	为Active Directory queries 创建ADSI链接服务器（如果没有的话）
if (select [srvname] from master..sysservers where [srvname] = 'ADSI_LINK') is null
    begin
        exec master.dbo.sp_addlinkedserver 
            @server         = N'ADSI_LINK'
        ,   @srvproduct     = N'Active Directory Services Interfaces'
        ,   @provider       = N'ADSDSOObject'
        ,   @datasrc        = N'MyDomainController.domain.com';
     
        exec master.dbo.sp_addlinkedsrvlogin 
            @rmtsrvname     = N'ADSI_LINK'
        ,   @useself        = N'False'
        ,   @locallogin     = NULL
        ,   @rmtuser        = N'MyDomain\MyAdminAccount'
        ,   @rmtpassword    = 'MyPassword';
    end
 
--	build variables for Active Directory query
--	为Active Directory query构建变量
declare @characters varchar(255); 
declare @query      varchar(max); 
declare @attributes varchar(max);
set @characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
set @attributes = 
    '   cn
    ,   sAMAccountName
    ,   accountExpires
    ,   pwdLastSet
    ,   userAccountControl
    ,   ADsPath
    ,   lockouttime
    ,   mail
    ,   createTimeStamp
    ,   employeeID
    ,   lastLogon
    ,   co
    ,   l';
set @query = 'SELECT * INTO ##ADRESULTS FROM (';
  
--	build Active Direcotry query
--	创建Active Direcotry 查询
--	
with numbertable as (select top (len(@characters)) rownumb = row_number() over (order by [object_id]) from sys.all_objects order by rownumb)
select @query = @query + 
    'SELECT top 901 * FROM OPENQUERY(ADSI_LINK, ''SELECT ' + @attributes + 
    ' FROM ''''LDAP://DC=MyDomain,DC=com'''' WHERE objectCategory=''''Person'''' AND (cn = ''''' + 
    substring(@characters, numbertable.rownumb, 1) + '*'''') AND (objectClass = ''''user'''' OR objectClass = ''''contact'''')'')
    UNION
    '
from numbertable;
  
--	create final query
--	创建最终查询
select @query = left(@query, len(@query) - charindex(reverse('union'), reverse(@query)) - 4) + ') as query'
  
--	remove if already exists (before first run)
--	如果已存在则删除（在首次运行之前）
if object_id('tempdb.dbo.##adresults', 'u') is null
    begin
        execute(@query)
    end
 
-- get size of temp table ##adresults_table_created'    = st.name
--获取临时表格的大小## adresults_table_created'= st.name
,   'row_count'     = sddps.row_count
,   'used_size_kb'  = sddps.used_page_count * 8
,   'reserved_kb'   = sddps.reserved_page_count * 8
from 
    tempdb.sys.partitions sp inner join tempdb.sys.dm_db_partition_stats sddps
    on sp.partition_id      = sddps.partition_id 
    and sp.partition_number = sddps.partition_number 
    inner join tempdb.sys.tables as st 
    on sddps.object_id      = st.object_id 
where
    st.[name] = '##adresults'
 
--	get install date to avoid default logins
获取安装日期以避免默认登录
declare @install_date       datetime = (select [createdate] from syslogins where [sid] = 0x010100000000000512000000)
declare @default_accounts   datetime = (select dateadd(minute, 1, @install_date))
 
--	create table for local logins
为本地登录创建表格
if object_id('tempdb..##logins') is not null
    drop table  ##logins
create table    ##logins ([local_logins] varchar(255))
insert into     ##logins select [name] from syslogins where [createdate] > @default_accounts and [name] like '%\%'
 
--	find deprovisioned accounts
找到被取消配置的帐户
select
    'Deprovisioned_Accounts' = 'MyDomain\' + [samaccountname]
from
    [##adresults]
where
    'MyDomain\' + [samaccountname] in (select [local_logins] from ##logins)
    and [userAccountControl] = '514'
 
 
/*
 drop table ##adresults;
 drop table ##logins;
*/

```



[![WorksEveryTime](https://forthebadge.com/images/badges/60-percent-of-the-time-works-every-time.svg)](https://shitday.de/)

## Build-Info

| Build Quality | Build History |
|--|--|
|<table><tr><td>[![Build-Status](https://ci.appveyor.com/api/projects/status/pjxh5g91jpbh7t84?svg?style=flat-square)](#)</td></tr><tr><td>[![Coverage](https://coveralls.io/repos/github/tygerbytes/ResourceFitness/badge.svg?style=flat-square)](#)</td></tr><tr><td>[![Nuget](https://img.shields.io/nuget/v/TW.Resfit.Core.svg?style=flat-square)](#)</td></tr></table>|<table><tr><td>[![Build history](https://buildstats.info/appveyor/chart/tygerbytes/resourcefitness)](#)</td></tr></table>|

## Author

- **李聪明的数据库 Lee's Clever Data**
- **Mike的数据库宝典 Mikes Database Collection**
- **李聪明的数据库** "Lee Songming"

[![Gist](https://img.shields.io/badge/Gist-李聪明的数据库-<COLOR>.svg)](https://gist.github.com/congmingshuju)
[![Twitter](https://img.shields.io/badge/Twitter-mike的数据库宝典-<COLOR>.svg)](https://twitter.com/mikesdatawork?lang=en)
[![Wordpress](https://img.shields.io/badge/Wordpress-mike的数据库宝典-<COLOR>.svg)](https://mikesdatawork.wordpress.com/)

---
## License
[![LicenseCCSA](https://img.shields.io/badge/License-CreativeCommonsSA-<COLOR>.svg)](https://creativecommons.org/share-your-work/licensing-types-examples/)

![Lee Songming](https://raw.githubusercontent.com/LiCongMingDeShujuku/git-resources/master/1-clever-data-github.png "李聪明的数据库")

