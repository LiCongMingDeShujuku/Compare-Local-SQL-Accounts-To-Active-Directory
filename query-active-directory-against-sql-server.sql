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
