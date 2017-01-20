add-pssnapin microsoft.sharepoint.powershell -ea 0

$outfile = Read-Host "Please enter the path and name you would like for the output file (ex. C:\temp\InfoOutput.txt)"


Function WarningCheck
        {
        Param ($warninglimit,$warningct,$warningmsg,$altmsg)
        if ($warningct -ge $warninglimit)
            {
                Write-Output "`n ### $($warningmsg) ### "
            }
        Else
            {
                if ($altmsg -ne $null)
                    {
                Write-Output "`n ### $($altmsg) ### "
				$altmsg = $null
                    }
            }
        }

Function UpperBound
        {
        Param ($gtlimit,$compinput,$warning,$unit)
        if ($gtlimit -lt $compinput)
            {
                Write-Output $($compinput,$unit,$warning)
            }

        Else
            {
                Write-Output $($compinput,$unit)
            }
        }

Function FarmBuild
        {
            $build=$(Get-SPFarm).BuildVersion
            Write-Output `n"## SharePoint Farm Build number is $($Build.Major).$($Build.Minor).$($Build.Build).$($Build.Revision)"
            Write-Output `n"## Installed SKUs"

            ForEach($sku in ($(get-spfarm).Products))
            {
            $product=$(switch ($sku)
                {     
			        default {"unknown version"}
                    "84902853-59F6-4B20-BC7C-DE4F419FEFAD" {"Project Server 2010 Trial"}
                    "ED21638F-97FF-4A65-AD9B-6889B93065E2" {"Project Server 2010"}
                    "BC4C1C97-9013-4033-A0DD-9DC9E6D6C887" {"Search Server 2010 Trial"}
                    "08460AA2-A176-442C-BDCA-26928704D80B" {"Search Server 2010"}
                    "BEED1F75-C398-4447-AEF1-E66E1F0DF91E" {"SharePoint Foundation 2010"}
                    "1328E89E-7EC8-4F7E-809E-7E945796E511" {"Search Server Express 2010"}
                    "B2C0B444-3914-4ACB-A0B8-7CF50A8F7AA0" {"SharePoint Server 2010 Standard Trial"}
                    "3FDFBCC8-B3E4-4482-91FA-122C6432805C" {"SharePoint Server 2010 Standard"}
                    "88BED06D-8C6B-4E62-AB01-546D6005FE97" {"SharePoint Server 2010 Enterprise Trial"}
                    "D5595F62-449B-4061-B0B2-0CBAD410BB51" {"SharePoint Server 2010 Enterprise"}
                    "926E4E17-087B-47D1-8BD7-91A394BC6196" {"Office Web Applications 2010"}
                    "35466B1A-B17B-4DFB-A703-F74E2A1F5F5E" {"Project Server 2013"}
                    "BC7BAF08-4D97-462C-8411-341052402E71" {"Project Server 2013 Preview"}
                    "9FF54EBC-8C12-47D7-854F-3865D4BE8118" {"SharePoint Foundation 2013"}
                    "C5D855EE-F32B-4A1C-97A8-F0A28CE02F9C" {"SharePoint Server 2013 Standard"}
                    "B7D84C2B-0754-49E4-B7BE-7EE321DCE0A9" {"SharePoint Server 2013 Enterprise"}
                    "D6B57A0D-AE69-4A3E-B031-1F993EE52EDC" {"Microsoft Office Web Apps Server 2013"}
                } )

			Write-Output "#### $($product) ($sku)"
			    If ($product -match "Project")
				    {Write-Output "<Font color=red>MS Project can complicate the migration process</font>"}
			    ElseIf ($product -match "Web Applications 2010")
				    {Write-Output "<Font color=red>SharePoint 2013 requires a separate server or farm for Office Web Applications</font>"}
            }
            
        }

Function UserID
        {       
            $scriptuser = whoami
            Write-Output `n"## InfoScript was run under account name $($scriptuser)"
        }

Function ServersInFarm
        {
            Write-Output `n"## Servers in farm"
            Write-Output "### Plus upgrade status and version number (version is just for comparison)"
            $servers=Get-SPServer  | Where-Object { $_.role -ne "invalid" }
            Write-Output `n"| Name | Server Memory | Role | Needs Upgrade? | Version |"
            Write-Output "| :----| :---- | :---- | :----: | ----:|"
            ForEach ($server in $servers)
                {
			$memInfo = Get-WmiObject -class "win32_PhysicalMemory" -computername $server.Name|Measure-Object -Property capacity -sum
			$sysMem="$($memInfo.sum/1gb)GB"
			Write-Output "| $($server.Name) | $sysMem | $($server.Role) | $($server.NeedsUpgrade) | $($server.Version) |"
                }
        }

Function ShowCurrentErrors
		{
            Write-Output `n"## Known Errors and Warnings"
            $build=$(Get-SPFarm).BuildVersion
            $keyPath = "HKLM:HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$($build.Major).$($build.Minor)\WSS\"
            $centralAdminInfo= Get-ItemProperty -Path $keyPath -Name CentralAdministrationURL
            $centralAdminURL=$centralAdminInfo.CentralAdministrationURL
            $listName = "Review Problems and Solutions"
            $centralAdmin= Get-SPWeb $centralAdminURL
            $problemList = $centralAdmin.Lists[$listName]
            $problemItems = $problemList.GetItems() | where-object {$_['Severity'] -ne "4 - Success"}
            Write-Output `n"| Severity | Error or Warning description|"
            Write-Output "| :----| :---- |"
                ForEach ($Item in $problemItems){
                    $itemXml=[xml]$Item.Xml
                    Write-Output "| $($itemXml.row.ows_HealthReportSeverity) | $($Item.Title) | "
                        } 
		}


Function WebAppsInFarm
		{
		    Write-Output `n"## Web Apps in Farm"
			Write-Output "### And if they are using claims auth or not"
			$webapps=Get-SPWebApplication -includecentraladministration
			Write-Output `n"| Name | URL (Default) | Claims Authenticated? | Databases |"
			Write-Output "| :----| :---- | :----: |:----|"
			ForEach ($webapp in $webapps)
				{
                    $contentdbs=get-spcontentdatabase -webapplication $webapp|select name
                    ForEach ($name in $contentdbs.name)
                        {
                            $namelist=$($namelist+$name+"<br>")
                        }

				    Write-Output "| $($webapp.DisplayName) | $($webapp.URL) | $($webapp.UseClaimsAuthentication) | $($namelist) |"
                    $namelist=$null
                        
				}
            $WebAppWarning = "Microsoft Recommends no more than 25 Web Applications in a Farm this farm has $($webapps.Count)"       
            WarningCheck -warninglimit 25 -warningct $webapps.Count -warningmsg $WebAppWarning
		}
		
		
Function ManagedAccountInfo
		{
            Write-Output `n"## Managed Accounts"
            $ManagedAccounts=Get-SPManagedAccount
            Write-Output `n"| Username | Password Expiration | Automatically Change? | Change Schedule |"
            Write-Output "| :----| :---- | :----: | :---- |"
            ForEach ($account in $managedaccounts)
                {
                    Write-Output "| $($account.UserName) | $($account.PasswordExpiration) | $($account.AutomaticChange) | $($account.ChangeSchedule) |"
                }
		}

Function ServiceInfo
		{
            Write-Output `n"## Services On Servers"
            $servers=Get-SPServer  | Where-Object { $_.role -ne "invalid" }
            ForEach($server in $servers){
            $services=Get-SPServiceInstance -server $server|sort-object TypeName
            Write-Output `n"|**$($Server.DisplayName)**| **Service** | **Status** |"
            Write-Output "| :----| :---- | ----: |"
                ForEach ($service in $services)
                    {
                        Write-Output "|      | $($service.TypeName) | $($service.Status) |"
                    }
                }
            }

Function AppPoolInfo
		{
            Write-Output `n"## Service Application and App Pools"
            $serviceapps=Get-SPServiceApplication
            $contentaccess= New-Object Microsoft.Office.Server.Search.Administration.content $(Get-SPEnterpriseSearchServiceApplication)
            Write-Output `n"| Name | Type | Application Pool | Process Account |"
            Write-Output "| :----| :---- | :---- | :---- |"
            ForEach ($serviceapp in $serviceapps)
                {
                    Write-Output "| $($serviceapp.DisplayName) | $($serviceapp.TypeName) | $($serviceapp.ApplicationPool.Name) | $($serviceapp.ApplicationPool.ProcessAccountName) |"
                }
            Write-Output "| Search Service Application |    | **Crawl Account** | $($contentaccess.DefaultGatheringAccount) |"
		}

Function LangPackList
		{
            Write-Output `n"## Language Packs"          
            $pathapps=Get-SPWebapplication
            Write-Output `n"| Language Name | Language Tag | LCID | "
            Write-Output "| :---- | ---- | ----:|"
            $centraladmin=Get-SPWebApplication -includecentraladministration | Where-Object {$_.IsAdministrationWebApplication} | Select-Object -ExpandProperty Url
            $site=Get-SPSite $centraladmin
            $web=$site.RootWeb
            $installedLanguages = $web.RegionalSettings.InstalledLanguages
            
            ForEach ($language in $installedLanguages)
                {
                    Write-Output  "| $($language.DisplayName) | $($language.LanguageTag) | $($language.LCID) |"
                } 
		}
		
Function ManagedPathList
		{         
            Write-Output `n"## Managed Paths"          
            $pathapps=Get-SPWebapplication
            Write-Output `n"| Web Application |        Name        |     Type     |"
            Write-Output "| :---- | :---- | :---- |"
            ForEach ($pathapp in $pathapps)
                {
                    $mangpaths=$pathapp|Get-SPManagedPath
                    ForEach ($mangpath in $mangpaths)
                        {
                            Write-Output "| $($pathapp.URL) | $($mangpath.Name) | $($mangpath.Type) |"
                        }
                }
		}

Function SolutionsInFarm
		{
            Write-Output `n"## Solutions in Farm"
            $solutions = Get-SPSolution | select Displayname, deployed, DeployedWebApplications
            Write-Output `n"| Name | Deployed? | Web Applications |"
            Write-Output "| :---- | :----: | :---- |"
            ForEach ($solution in $solutions)
                {
                    write-output "| $($solution.DisplayName) | $($solution.Deployed) | $($solution.DeployedWebApplications) |"
                }
		}
		
Function ContentDBInfo
		{
            $dbsizelimit = 199999
			$scsizlimit = 199999
			Write-Output `n"## Sizes of Databases and Site Collections by Web Application"
            Write-Output "### Site Collection sizes are very rough estimates"
            $contentdbs=get-spdatabase|Where-Object{$_.WebApplication -ne $null}
            Write-Output `n"| Web Application | DB name and Site Collection URL | Size in Megabytes |"
            Write-Output "| :---- |:---- | :---- | ----:|"
            ForEach ($contentdb in $contentdbs)
                {
                    $dbszcomp= $(UpperBound -gtlimit $dbsizelimit -compinput $($contentdb.DiskSizeRequired/1MB) -warning "(Too Large)" -unit "MB")
                    Write-Output "| **$($ContentDB.WebApplication.URL)** |  **$($contentdb.Name)**  | **$($dbszcomp)** |"
					$totalContentDB= ($totalContentDB + $($contentdb.DiskSizeRequired/1MB))
                    ForEach ($sitecollection in $contentdb.Sites)
                        {
                            $scszcomp= $(UpperBound -gtlimit $scsizlimit -compinput $("{0:N2}" -f $($sitecollection.Usage.Storage/1MB))-warning "**(Too Large)**" -unit "MB")
                            Write-Output "|  |  $($sitecollection.URL) |  ~$($scszcomp) |"
                        }
                }
			Write-Output `n"#### Total Size of Content Databases 	$($totalContentDB) MB"
		}

Function AppDBInfo
		{
            Write-Output `n"## Application Database sizes"
            $databases=Get-SPDatabase|Where-Object{$_.Type -ne "Content Database"}
            Write-Output `n"| Database Name | Datasize in Megabytes |"
            Write-Output "| :---- | ----: |"
            ForEach ($database in $databases)
                {
                    Write-Output "| $($database.Name) | $($database.DiskSizeRequired/1MB) MB |"
					$totalServAppDB= ($totalServAppDB + $($database.DiskSizeRequired/1MB))
                }
			Write-Output `n"#### Total Size of Service Application and Config Databases 	$($totalServAppDB) MB"
		}

Function LargeListList
		{
            $listwarning = 4000
			$listupperlimit = 4000
			Write-Output `n"## Lists containing $($listwarning) or more items."
            $listenum = Get-SPWebApplication | Get-SPSite -Limit all | Get-SPWeb -Limit all
            Write-Output `n"| List URL | Item Count"
            Write-Output "| :---- |----:|"
            ForEach ($list in $listenum.Lists)
                {
                    If ($list.ItemCount -gt $listwarning)
                        {
                            $listcomp= $(UpperBound -gtlimit $listupperlimit -compinput $($list.ItemCount))
							Write-Output "| $($list.ParentWeb.URL)/$($list.RootFolder.URL) | $($listcomp)|"
                        }
                }
		}
		
Function AAMInfo
		{
            Write-Output `n"## Alternate Access Mappings"
            $AAMS=Get-SPAlternateURL
            Write-Output `n"| Incoming URL | Zone | Public URL |"
            Write-Output "| :---- | :----: | :---- |"
            ForEach ($AAM in $AAMS)
                {
                    Write-Output "| $($AAM.IncomingURL) | $($AAM.Zone) | $($AAM.PublicURL) |"
                }
		}
		
Function FeaturesInFarm
		{ 
 
             Write-Output `n"## Features in Farm"
                        $features=Get-SPFeature|Sort-Object ID
                        Write-Output `n"| Display Name | Id Number | Compatibility Level | Scope ||"
                        Write-Output "| :---- | :---- | :----: | :---- | ----:|"
                        ForEach ($feature in $features)
                        {
                        $FeatureSource=$(switch ($feature.id)
				            { 
				            default {"**Custom**"}
                            "001f4bd7-746d-403b-aa09-a6cc43de7942" {""}   
							"001f4bd7-746d-403b-aa09-a6cc43de7999" {""}
							"00bfea71-1c5e-4a24-b310-ba51c3eb7a57" {""}
							"00bfea71-1e1d-4562-b56a-f05371bb0115" {""}
							"00bfea71-2062-426c-90bf-714c59600103" {""}
							"00bfea71-2d77-4a75-9fca-76516689e21a" {""}
							"00bfea71-3a1d-41d3-a0ee-651d11570120" {""}
							"00bfea71-4ea5-48d4-a4ad-305cf7030140" {""}
							"00bfea71-4ea5-48d4-a4ad-7ea5c011abe5" {""}
							"00bfea71-513d-4ca0-96c2-6a47775c0119" {""}
							"00bfea71-52d4-45b3-b544-b1c71b620109" {""}
							"00bfea71-5932-4f9c-ad71-1557e5751100" {""}
							"00bfea71-6a49-43fa-b535-d15c05500108" {""}
							"00bfea71-7e6d-4186-9ba8-c047ac750105" {""}
							"00bfea71-9549-43f8-b978-e47e54a10600" {""}
							"00bfea71-a83e-497e-9ba0-7a5c597d0107" {""}
							"00bfea71-c796-4402-9f2f-0eb9a6e71b18" {""}
							"00bfea71-d1ce-42de-9c63-a44004ce0104" {""}
							"00bfea71-d8fe-4fec-8dad-01c19a6e4053" {""}
							"00bfea71-dbd7-4f72-b8cb-da7ac0440130" {""}
							"00bfea71-de22-43b2-a848-c05709900100" {""}
							"00bfea71-e717-4e80-aa17-d0c71b360101" {""}
							"00bfea71-eb8a-40b1-80c7-506be7590102" {""}
							"00bfea71-ec85-4903-972d-ebe475780106" {""}
							"00bfea71-f381-423d-b9d1-da7a54c50110" {""}
							"00bfea71-f600-43f6-a895-40c0de7b0117" {""}
							"0125140f-7123-4657-b70a-db9aa1f209e5" {""}
							"013a0db9-1607-4c42-8f71-08d821d395c2" {""}
							"02464c6a-9d07-4f30-ba04-e9035cf54392" {""}
							"034947cc-c424-47cd-a8d1-6014f0e36925" {""}
							"03509cfb-8b2f-4f46-a4c9-8316d1e62a4b" {""}
							"03b0a3dc-93dd-4c68-943e-7ec56e65ed4d" {""}
							"04a98ac6-82d5-4e01-80ea-c0b7d9699d94" {""}
							"05891451-f0c4-4d4e-81b1-0dabd840bad4" {""}
							"063c26fa-3ccc-4180-8a84-b6f98e991df3" {""}
							"065c78be-5231-477e-a972-14177cc5b3c7" {""}
							"068bc832-4951-11dc-8314-0800200c9a66" {""}
							"068f8656-bea6-4d60-a5fa-7f077f8f5c20" {""}
							"071de60d-4b02-4076-b001-b456e93146fe" {""}
							"073232a0-1868-4323-a144-50de99c70efc" {""}
							"0806d127-06e6-447a-980e-2e90b03101b8" {""}
							"08386d3d-7cc0-486b-a730-3b4cfe1b5509" {""}
							"08585e12-4762-4cc9-842a-a8d7b074bdb7" {""}
							"0867298a-70e0-425f-85df-7f8bd9e06f15" {""}
							"08ee8de1-8135-4ef9-87cb-a4944f542ba3" {""}
							"09fe98f3-3324-4747-97e5-916a28a0c6c0" {""}
							"0a0b2e8f-e48e-4367-923b-33bb86c1b398" {""}
							"0ac11793-9c2f-4cac-8f22-33f93fac18f2" {""}
							"0af5989a-3aea-4519-8ab0-85d91abe39ff" {""}
							"0b07a7f4-8bb8-4ec0-a31b-115732b9584d" {""}
							"0be49fe9-9bc9-409d-abf9-702753bd878d" {""}
							"0c504a5c-bcea-4376-b05e-cbca5ced7b4f" {""}
							"0c8a9a47-22a9-4798-82f1-00e62a96006e" {""}
							"0d1c50f7-0309-431c-adfb-b777d5473a65" {""}
							"0ea1c3b6-6ac0-44aa-9f3f-05e8dbe6d70b" {""}
							"0ee1129f-a2f3-41a9-9e9c-c7ee619a8c33" {""}
							"0f121a23-c6bc-400f-87e4-e6bbddf6916d" {""}
							"0faf7d1b-95b1-4053-b4e2-19fd5c9bbc88" {""}
							"10bdac29-a21a-47d9-9dff-90c7cae1301e" {""}
							"10f73b29-5779-46b3-85a8-4817a6e9a6c2" {""}
							"12e4f16b-8b04-42d2-90f2-aef1cc0b65d9" {""}
							"14173c38-5e2d-4887-8134-60f9df889bad" {""}
							"14aafd3a-fcb9-4bb7-9ad7-d8e36b663bbd" {""}
							"151d22d9-95a8-4904-a0a3-22e4db85d1e0" {""}
							"15845762-4ec4-4606-8993-1c0512a98680" {""}
							"15a572c6-e545-4d32-897a-bab6f5846e18" {""}
							"1663ee19-e6ab-4d47-be1b-adeb27cfd9d2" {""}
							"17415b1d-5339-42f9-a10b-3fef756b84d1" {""}
							"184c82e7-7eb1-4384-8e8c-62720ef397a0" {""}
							"192efa95-e50c-475e-87ab-361cede5dd7f" {""}
							"19f5f68e-1b92-4a02-b04d-61810ead0409" {""}
							"1a8251a0-47ab-453d-95d4-07d7ca4f8166" {""}
							"1b811cfe-8c78-4982-aad7-e5c112e397d1" {""}
							"1c6a572c-1b58-49ab-b5db-75caf50692e6" {""}
							"1cc4b32c-299b-41aa-9770-67715ea05f25" {""}
							"1dbf6063-d809-45ea-9203-d3ba4a64f86d" {""}
							"1dfd85c5-feff-489f-a71f-9322f8b13902" {""}
							"1eb6a0c1-5f08-4672-b96f-16845c2448c6" {""}
							"1ec2c859-e9cb-4d79-9b2b-ea8df09ede22" {""}
							"1fce0577-1f58-4fc2-a996-6c4bcf59eeed" {""}
							"20477d83-8bdb-414e-964b-080637f7d99b" {""}
							"22a9ef51-737b-4ff2-9346-694633fe4416" {""}
							"23330bdb-b83e-4e09-8770-8155aa5e87fd" {""}
							"239650e3-ee0b-44a0-a22a-48292402b8d8" {""}
							"250042b9-1aad-4b56-a8a6-69d9fe1c8c2c" {""}
							"2510d73f-7109-4ccc-8a1c-314894deeb3a" {""}
							"26676156-91a0-49f7-87aa-37b1d5f0c4d0" {""}
							"28101b19-b896-44f4-9264-db028f307a62" {""}
							"29d85c25-170c-4df9-a641-12db0b9d4130" {""}
							"29ea7495-fca1-4dc6-8ac1-500c247a036e" {""}
							"2ac1da39-c101-475c-8601-122bc36e3d67" {""}
							"2b03956c-9271-4d1c-868a-07df2971ed30" {""}
							"2c63df2b-ceab-42c6-aeff-b3968162d4b1" {""}
							"2dd8788b-0e6b-4893-b4c0-73523ac261b1" {""}
							"2e030413-c4ff-41a4-8ee0-f6688950b34a" {""}
							"2ed1c45e-a73b-4779-ae81-1524e4de467a" {""}
							"2fa4db13-4109-4a1d-b47c-c7991d4cc934" {""}
							"2fbbe552-72ac-11dc-8314-0800200c9a66" {""}
							"2fcd5f8a-26b7-4a6a-9755-918566dba90a" {""}
							"306936fd-9806-4478-80d1-7e397bfa6474" {""}
							"319d8f70-eb3a-4b44-9c79-2087a87799d6" {""}
							"32ff5455-8967-469a-b486-f8eaf0d902f9" {""}
							"334dfc83-8655-48a1-b79d-68b7f6c63222" {""}
							"34339dc9-dec4-4256-b44a-b30ff2991a64" {""}
							"345ff4f9-f706-41e1-92bc-3f0ec2d9f6ea" {""}
							"35f680d4-b0de-4818-8373-ee0fca092526" {""}
							"365356ee-6c88-4cf1-92b8-fa94a8b8c118" {""}
							"372b999f-0807-4427-82dc-7756ae73cb74" {""}
							"38969baa-3590-4635-81a4-2049d982adfa" {""}
							"397942ec-14bf-490e-a983-95b87d0d29d1" {""}
							"3992d4ab-fa9e-4791-9158-5ee32178e88a" {""}
							"39d18bbf-6e0f-4321-8f16-4e3b51212393" {""}
							"39dd29fb-b6f5-4697-b526-4d38de4893e5" {""}
							"3a027b18-36e4-4005-9473-dd73e6756a73" {""}
							"3a11d8ef-641e-4c79-b4d9-be3b17f9607c" {""}
							"3a4ce811-6fe0-4e97-a6ae-675470282cf2" {""}
							"3bae86a2-776d-499d-9db8-fa4cdc7884f8" {""}
							"3bc0c1e1-b7d5-4e82-afd7-9f7e59b60409" {""}
							"3c577815-7658-4d4f-a347-cfbb370700a7" {""}
							"3cb475e7-4e87-45eb-a1f3-db96ad7cf313" {""}
							"3d25bd73-7cd4-4425-b8fb-8899977f73de" {""}
							"3d433d02-cf49-4975-81b4-aede31e16edf" {""}
							"3d4ea296-0b35-4a08-b2bf-f0a8cabd1d7f" {""}
							"3d7415e4-61ba-4669-8d78-213d374d9825" {""}
							"3d8210e9-1e89-4f12-98ef-643995339ed4" {""}
							"3f59333f-4ce1-406d-8a97-9ecb0ff0337f" {""}
							"409d2feb-3afb-4642-9462-f7f426a0f3e9" {""}
							"415780bf-f710-4e2c-b7b0-b463c7992ef0" {""}
							"41baa678-ad62-41ef-87e6-62c8917fc0ad" {""}
							"41bfb21c-0447-4c97-bc62-0b07bec262a1" {""}
							"41dfb393-9eb6-4fe4-af77-28e4afce8cdc" {""}
							"41e1d4bf-b1a2-47f7-ab80-d5d6cbba3092" {""}
							"4248e21f-a816-4c88-8cab-79d82201da7b" {""}
							"4326e7fc-f35a-4b0f-927c-36264b0a4cf0" {""}
							"43f41342-1a37-4372-8ca0-b44d881e4434" {""}
							"4446ee9b-227c-4f1a-897d-d78ecdd6a824" {""}
							"4750c984-7721-4feb-be61-c660c6190d43" {""}
							"481333e1-a246-4d89-afab-d18c6fe344ce" {""}
							"48a243cb-7b16-4b5a-b1b5-07b809b43f47" {""}
							"48ac883d-e32e-4fd6-8499-3408add91b53" {""}
							"48c33d5d-acff-4400-a684-351c2beda865" {""}
							"49571cd1-b6a1-43a3-bf75-955acc79c8d8" {""}
							"4aec7207-0d02-4f4f-aa07-b370199cd0c7" {""}
							"4bcccd62-dcaf-46dc-a7d4-e38277ef33f4" {""}
							"4c42ab64-55af-4c7c-986a-ac216a6e0c0e" {""}
							"4cc8aab8-5af0-45d7-a170-169ea583866e" {""}
							"4ddc5942-98b0-4d70-9f7f-17acfec010e5" {""}
							"4e7276bc-e7ab-4951-9c4b-a74d44205c32" {""}
							"4f56f9fa-51a0-420c-b707-63ecbb494db1" {""}
							"5025492c-dae2-4c00-8f34-cd08f7c7c294" {""}
							"502a2d54-6102-4757-aaa0-a90586106368" {""}
							"5094e988-524b-446c-b2f6-040b5be46297" {""}
							"5153156a-63af-4fac-b557-91bd8c315432" {""}
							"541f5f57-c847-4e16-b59a-b31e90e6f9ea" {""}
							"55312854-855b-4088-b09d-c5efe0fbf9d2" {""}
							"5690f1a0-22b6-4262-b1c2-74f505bc0670" {""}
							"5709886f-13cc-4ffc-bfdc-ec8ab7f77191" {""}
							"57311b7a-9afd-4ff0-866e-9393ad6647b1" {""}
							"57cc6207-aebf-426e-9ece-45946ea82e4a" {""}
							"57ff23fc-ec05-4dd8-b7ed-d93faa7c795d" {""}
							"58160a6b-4396-4d6e-867c-65381fb5fbc9" {""}
							"588b23d5-8e23-4b1b-9fe3-2f2f62965f2d" {""}
							"592ccb4a-9304-49ab-aab1-66638198bb58" {""}
							"5a020a4f-c449-4a65-b07d-f2cc2d8778dd" {""}
							"5a979115-6b71-45a5-9881-cdc872051a69" {""}
							"5b10d113-2d0d-43bd-a2fd-f8bc879f5abd" {""}
							"5b79b49a-2da6-4161-95bd-7375c1995ef9" {""}
							"5bccb9a4-b903-4fd1-8620-b795fa33c9ba" {""}
							"5d220570-df17-405e-b42d-994237d60ebf" {""}
							"5eac763d-fbf5-4d6f-a76b-eded7dd7b0a5" {""}
							"5ebe1445-5910-4c6e-ac27-da2e93b60f48" {""}
							"5ede0a86-c772-4f1d-a120-72e734b3400c" {""}
							"5f3b0127-2f1d-4cfd-8dd2-85ad1fb00bfc" {""}
							"5f68444a-0131-4bb0-b013-454d925681a2" {""}
							"5fe8e789-d1b7-44b3-b634-419c531cfdca" {""}
							"6077b605-67b9-4937-aeb6-1d41e8f5af3b" {""}
							"60c8481d-4b54-4853-ab9f-ed7e1c21d7e4" {""}
							"612d671e-f53d-4701-96da-c3a4ee00fdc5" {""}
							"61e874cd-3ac3-4531-8628-28c3acb78279" {""}
							"6301cbb8-9396-45d1-811a-757567d35e91" {""}
							"6361e2a8-3bc4-4ca4-abbb-3dfbb727acd7" {""}
							"636287a7-7f62-4a6e-9fcc-081f4672cbf8" {""}
							"65b53aaf-4754-46d7-bb5b-7ed4cf5564e1" {""}
							"65d96c6b-649a-4169-bf1d-b96505c60375" {""}
							"67ae7d04-6731-42dd-abe1-ba2a5eaa3b48" {""}
							"683df0c0-20b7-4852-87a3-378945158fab" {""}
							"6928b0e5-5707-46a1-ae16-d6e52522d52b" {""}
							"695b6570-a48b-4a8e-8ea5-26ea7fc1d162" {""}
							"69cc9662-d373-47fc-9449-f18d11ff732c" {""}
							"6adff05c-d581-4c05-a6b9-920f15ec6fd9" {""}
							"6c09612b-46af-4b2f-8dfc-59185c962a29" {""}
							"6d127338-5e7d-4391-8f62-a11e43b1d404" {""}
							"6d503bb6-027e-44ea-b54c-a53eac3dfed8" {""}
							"6e1e5426-2ebd-4871-8027-c5ca86371ead" {""}
							"6e53dd27-98f2-4ae5-85a0-e9a8ef4aa6df" {""}
							"6e8a2add-ed09-4592-978e-8fa71e6f117c" {""}
							"6e8f2b8d-d765-4e69-84ea-5702574c11d6" {""}
							"7094bd89-2cfe-490a-8c7e-fbace37b4a34" {""}
							"713a65a1-2bc7-4e62-9446-1d0b56a8bf7f" {""}
							"7201d6a4-a5d3-49a1-8c19-19c4bac6e668" {""}
							"739ec067-2b57-463e-a986-354be77bb828" {""}
							"73ef14b1-13a9-416b-a9b5-ececa2b0604c" {""}
							"742d4c0e-303b-41d7-8015-aad1dfd54cbd" {""}
							"744b5fd3-3b09-4da6-9bd1-de18315b045d" {""}
							"750b8e49-5213-4816-9fa2-082900c0201a" {""}
							"756d8a58-4e24-4288-b981-65dc93f9c4e5" {""}
							"76d688ad-c16e-4cec-9b71-7b7f0d79b9cd" {""}
							"77fc9e13-e99a-4bd3-9438-a3f69670ed97" {""}
							"7877bbf6-30f5-4f58-99d9-a0cc787c1300" {""}
							"7890e045-6c96-48d8-96e7-6a1d63737d71" {""}
							"7ac8cc56-d28e-41f5-ad04-d95109eb987a" {""}
							"7acfcb9d-8e8f-4979-af7e-8aed7e95245e" {""}
							"7ad5272a-2694-4349-953e-ea5ef290e97c" {""}
							"7c637b23-06c4-472d-9a9a-7c175762c5c4" {""}
							"7cd95467-1777-4b6b-903e-89e253edc1f7" {""}
							"7d12c4c3-2321-42e8-8fb6-5295a849ed08" {""}
							"7de489aa-2e4a-46ff-88f0-d1b5a9d43709" {""}
							"7e0aabee-b92b-4368-8742-21ab16453d00" {""}
							"7e0aabee-b92b-4368-8742-21ab16453d01" {""}
							"7e0aabee-b92b-4368-8742-21ab16453d02" {""}
							"7f52c29e-736d-11e0-80b8-9edd4724019b" {""}
							"7ffd6d57-4b10-4edb-ac26-c2cfbf8173ab" {""}
							"81ebc0d6-8fb2-4e3f-b2f8-062640037398" {""}
							"824a259f-2cce-4006-96cd-20c806ee9cfd" {""}
							"82e2ea42-39e2-4b27-8631-ed54c1cfc491" {""}
							"8472208f-5a01-4683-8119-3cea50bea072" {""}
							"8581a8a7-cf16-4770-ac54-260265ddb0b2" {""}
							"863da2ac-3873-4930-8498-752886210911" {""}
							"87294c72-f260-42f3-a41b-981a2ffce37a" {""}
							"875d1044-c0cf-4244-8865-d2a0039c2a49" {""}
							"87866a72-efcf-4993-b5b0-769776b5283f" {""}
							"89d1184c-8191-4303-a430-7a24291531c9" {""}
							"89e0306d-453b-4ec5-8d68-42067cdbf98e" {""}
							"8a4b8de2-6fd8-41e9-923c-c7c3c00f8295" {""}
							"8a663fe0-9d9c-45c7-8297-66365ad50427" {""}
							"8b2c6bcb-c47f-4f17-8127-f8eae47a44dd" {""}
							"8b82e40f-2001-4f0e-9ce3-0b27d1866dff" {""}
							"8c34f59f-8dfb-4a39-9a08-7497237e3dc4" {""}
							"8c54e5d3-4635-4dff-a533-19fe999435dc" {""}
							"8c6a6980-c3d9-440e-944c-77f93bc65a7e" {""}
							"8c6f9096-388d-4eed-96ff-698b3ec46fc4" {""}
							"8d75610e-5ff9-4cd1-aefc-8b926f2af771" {""}
							"8e947bf0-fe40-4dff-be3d-a8b88112ade6" {""}
							"8f15b342-80b1-4508-8641-0751e2b55ca6" {""}
							"8fb893d6-93ee-4763-a046-54f9e640368d" {""}
							"90c6c1e5-3719-4c52-9f36-34a97df596f7" {""}
							"915c240e-a6cc-49b8-8b2c-0bff8b553ed3" {""}
							"922ed989-6eb4-4f5e-a32e-27f31f93abfa" {""}
							"932f5bb1-e815-4c14-8917-c2bae32f70fe" {""}
							"937f97e9-d7b4-473d-af17-b03951b2c66b" {""}
							"947afd14-0ea1-46c6-be97-dea1bf6f5bae" {""}
							"94c94ca6-b32f-4da9-a9e3-1f3d343d7ecb" {""}
							"961d6a9c-4388-4cf2-9733-38ee8c89afd4" {""}
							"978513c0-1e6c-4efb-b12e-7698963bfd05" {""}
							"97a2485f-ef4b-401f-9167-fa4fe177c6f6" {""}
							"98311581-29c5-40e8-9347-bd5732f0cb3e" {""}
							"983521d7-9c04-4db0-abdc-f7078fc0b040" {""}
							"98d11606-9a9b-4f44-b4c2-72d72f867da9" {""}
							"99f380b4-e1aa-4db0-92a4-32b15e35b317" {""}
							"99fe402e-89a0-45aa-9163-85342e865dc8" {""}
							"9a447926-5937-44cb-857a-d3829301c73b" {""}
							"9ad4c2d4-443b-4a94-8534-49a23f20ba3c" {""}
							"9b0293a7-8942-46b0-8b78-49d29a9edd53" {""}
							"9c03e124-eef7-4dc6-b5eb-86ccd207cb87" {""}
							"9c0834e1-ba47-4d49-812b-7d4fb6fea211" {""}
							"9c2ef9dc-f733-432e-be1c-2e79957ea27b" {""}
							"9e56487c-795a-4077-9425-54a1ecb84282" {""}
							"9e99f7d7-08e9-455c-b3aa-fc71b9210027" {""}
							"9fb35ca8-824b-49e6-a6c5-cba4366444ab" {""}
							"9fec40ea-a949-407d-be09-6cba26470a0c" {""}
							"a0e5a010-1329-49d4-9e09-f280cdbed37d" {""}
							"a0f12ee4-9b60-4ba4-81f6-75724f4ca973" {""}
							"a10b6aa4-135d-4598-88d1-8d4ff5691d13" {""}
							"a140a1ac-e757-465d-94d4-2ca25ab2c662" {""}
							"a16e895c-e61a-11df-8f6e-103edfd72085" {""}
							"a1cb5b7f-e5e9-421b-915f-bf519b0760ef" {""}
							"a311bf68-c990-4da3-89b3-88989a3d7721" {""}
							"a34e5458-8d20-4c0d-b137-e1390f5824a1" {""}
							"a354e6b3-6015-4744-bdc2-2fc1e4769e65" {""}
							"a392da98-270b-4e85-9769-04c0fde267aa" {""}
							"a42f749f-8633-48b7-9b22-403b40190409" {""}
							"a44d2aa3-affc-4d58-8db4-f4a3af053188" {""}
							"a46935c3-545f-4c15-a2fd-3a19b62d8a02" {""}
							"a4c654e4-a8da-4db3-897c-a386048f7157" {""}
							"a4d4ee2c-a6cb-4191-ab0a-21bb5bde92fb" {""}
							"a568770a-50ba-4052-ab48-37d8029b3f47" {""}
							"a573867a-37ca-49dc-86b0-7d033a7ed2c8" {""}
							"a5aedf1a-12e5-46b4-8348-544386d5312d" {""}
							"a64c4402-7037-4476-a290-84cfd56ca01d" {""}
							"a7a2793e-67cd-4dc1-9fd0-43f61581207a" {""}
							"a942a218-fa43-4d11-9d85-c01e3e3a37cb" {""}
							"abf1a85c-e91a-11df-bf2e-f7acdfd72085" {""}
							"abf42bbb-cd9b-4313-803b-6f4a7bd4898f" {""}
							"acb15743-f07b-4c83-8af3-ffcfdf354965" {""}
							"ae31cd14-a866-4834-891a-97c9d37662a2" {""}
							"ae3a1339-61f5-4f8f-81a7-abd2da956a7d" {""}
							"aebc918d-b20f-4a11-a1db-9ed84d79c87e" {""}
							"aeef8777-70c0-429f-8a13-f12db47a6d47" {""}
							"af847aa9-beb6-41d4-8306-78e41af9ce25" {""}
							"b1f70691-6170-4cae-bc2e-4f7011a74faa" {""}
							"b21b090c-c796-4b0f-ac0f-7ef1659c20ae" {""}
							"b21c5a20-095f-4de2-8935-5efde5110ab3" {""}
							"b2741073-a92b-4836-b1d8-d5e9d73679bb" {""}
							"b3da33d0-5e51-4694-99ce-705a3ac80dc5" {""}
							"b435069a-e096-46e0-ae30-899daca4b304" {""}
							"b50e3104-6812-424f-a011-cc90e6327318" {""}
							"b5934f65-a844-4e67-82e5-92f66aafe912" {""}
							"b5d169c9-12db-4084-b68d-eef9273bd898" {""}
							"b5ef96cb-d714-41da-b66c-ce3517034c21" {""}
							"b63ef52c-1e99-455f-8511-6a706567740f" {""}
							"b738400a-f08a-443d-96fa-a852d0356bba" {""}
							"b8f36433-367d-49f3-ae11-f7d76b51d251" {""}
							"b9455243-e547-41f0-80c1-d5f6ce6a19e5" {""}
							"bc29e863-ae07-4674-bd83-2c6d0aa5623f" {""}
							"bcf89eb7-bca1-4468-bdb4-ca27f61a2292" {""}
							"bd012a1f-c69b-4a13-b6a4-f8bc3e59760e" {""}
							"bf76fc2c-e6c9-11df-b52f-cb00e0d72085" {""}
							"bfc789aa-87ba-4d79-afc7-0c7e45dae01a" {""}
							"c1b78fe6-9110-42e8-87cb-5bd1c8ab278a" {""}
							"c43a587e-195b-4d29-aba8-ebb22b48eb1a" {""}
							"c4773de6-ba70-4583-b751-2a7b1dc67e3a" {""}
							"c59dbaa9-fa01-495d-aaa3-3c02cc2ee8ff" {""}
							"c5d947d6-b0a2-4e07-9929-8e54f5a9fff9" {""}
							"c6561405-ea03-40a9-a57f-f25472942a22" {""}
							"c65861fa-b025-4634-ab26-22a23e49808f" {""}
							"c6a92dbf-6441-4b8b-882f-8d97cb12c83a" {""}
							"c6ac73de-1936-47a4-bdff-19a6fc3ba490" {""}
							"c845ed8d-9ce5-448c-bd3e-ea71350ce45b" {""}
							"c85e5759-f323-4efb-b548-443d2216efb5" {""}
							"c88c4ff1-dbf5-4649-ad9f-c6c426ebcbf5" {""}
							"c922c106-7d0a-4377-a668-7f13d52cb80f" {""}
							"c9c9515d-e4e2-4001-9050-74f980f93160" {""}
							"ca2543e6-29a1-40c1-bba9-bd8510a4c17b" {""}
							"ca7bd552-10b1-4563-85b9-5ed1d39c962a" {""}
							"cb869762-c694-439e-8d05-cf5ca066f271" {""}
							"cd1a49b0-c067-4fdd-adfe-69e6f5022c1a" {""}
							"cdfa39c6-6413-4508-bccf-bf30368472b3" {""}
							"d085b8dc-9205-48a4-96ea-b40782abba02" {""}
							"d250636f-0a26-4019-8425-a5232d592c01" {""}
							"d250636f-0a26-4019-8425-a5232d592c09" {""}
							"d2b9ec23-526b-42c5-87b6-852bd83e0364" {""}
							"d2d98dc8-c7e9-46ec-80a5-b38f039c16be" {""}
							"d32700c7-9ec5-45e6-9c89-ea703efca1df" {""}
							"d3f51be2-38a8-4e44-ba84-940d35be1566" {""}
							"d44a1358-e800-47e8-8180-adf2d0f77543" {""}
							"d5191a77-fa2d-4801-9baf-9f4205c9e9d2" {""}
							"d5ff2d2c-8571-4c3c-87bc-779111979811" {""}
							"d7670c9c-1c29-4f44-8691-584001968a74" {""}
							"d95c97f3-e528-4da2-ae9f-32b3535fbb59" {""}
							"d9742165-b024-4713-8653-851573b9dfbd" {""}
							"d97ded76-7647-4b1e-b868-2af51872e1b3" {""}
							"d992aeca-3802-483a-ab40-6c9376300b61" {""}
							"da2e115b-07e4-49d9-bb2c-35e93bb9fca9" {""}
							"dd903064-c9d8-4718-b4e7-8ab9bd039fff" {""}
							"dd926489-fc66-47a6-ba00-ce0e959c9b41" {""}
							"dfa42479-9531-4baf-8873-fc65b22c9bd4" {""}
							"dffaae84-60ee-413a-9600-1cf431cf0560" {""}
							"e09cefae-2ada-4a1d-aee6-8a8398215905" {""}
							"e0a45587-1069-46bd-bf05-8c8db8620b08" {""}
							"e0a9f213-54f5-4a5a-81d5-f5f3dbe48977" {""}
							"e1580c3c-c510-453b-be15-35feb0ddb1a5" {""}
							"e2f2bb18-891d-4812-97df-c265afdba297" {""}
							"e374875e-06b6-11e0-b0fa-57f5dfd72085" {""}
							"e4639bb7-6e95-4e2f-b562-03b832dd4793" {""}
							"e47705ec-268d-4c41-aa4e-0d8727985ebc" {""}
							"e4e6a041-bc5b-45cb-beab-885a27079f74" {""}
							"e792e296-5d7f-47c7-9dfa-52eae2104c3b" {""}
							"e8734bb6-be8e-48a1-b036-5a40ff0b8a81" {""}
							"e8c02a2a-9010-4f98-af88-6668d59f91a7" {""}
							"e978b1a6-8de7-49d0-8600-09a250354e14" {""}
							"e995e28b-9ba8-4668-9933-cf5c146d7a9f" {""}
							"e9c0ff81-d821-4771-8b4c-246aa7e5e9eb" {""}
							"ea23650b-0340-4708-b465-441a41c37af7" {""}
							"eaa41f18-8e4a-4894-baee-60a87f026e42" {""}
							"eaf6a128-0482-4f71-9a2f-b1c650680e77" {""}
							"ec918931-c874-4033-bd09-4f36b2e31fef" {""}
							"ed5e77f7-c7b1-4961-a659-0de93080fa36" {""}
							"edf48246-e4ee-4638-9eed-ef3d0aee7597" {""}
							"ee21b29b-b0d0-42c6-baff-c97fd91786e6" {""}
							"ee9dbf20-1758-401e-a169-7db0a6bbccb2" {""}
							"f0deabbb-b0f6-46ba-8e16-ff3b44461aeb" {""}
							"f151bb39-7c3b-414f-bb36-6bf18872052f" {""}
							"f324259d-393d-4305-aa48-36e8d9a7a0d6" {""}
							"f41cc668-37e5-4743-b4a8-74d1db3fd8a4" {""}
							"f45834c7-54f6-48db-b7e4-a35fa470fc9b" {""}
							"f63b7696-9afc-4e51-9dfd-3111015e9a60" {""}
							"f661430e-c155-438e-a7c6-c68648f1b119" {""}
							"f6924d36-2fa8-4f0b-b16d-06b7250180fa" {""}
							"f8bea737-255e-4758-ab82-e34bb46f5828" {""}
							"f979e4dc-1852-4f26-ab92-d1b2a190afc9" {""}
							"f9c216ad-35c7-4538-abb8-8ec631a5dff7" {""}
							"f9cb1a2a-d285-465a-a160-7e3e95af1fdd" {""}
							"f9ce21f8-f437-4f7e-8bc6-946378c850f0" {""}
							"fa7cefd8-5595-4d68-84fa-fe2d9e693de7" {""}
							"fa8379c9-791a-4fb0-812e-d0cfcac809c8" {""}
							"faf00902-6bab-4583-bd02-84db191801d8" {""}
							"faf31b50-880a-4e4f-a21b-597f6b4d6478" {""}
							"fb01ca75-b306-4fc2-ab27-b4814bf823d1" {""}
							"fbbd1168-3b17-4f29-acb4-ef2d34c54cfb" {""}
							"fc33ba3b-7919-4d7e-b791-c6aeccf8f851" {""}
							"fdc6383e-3f1d-4599-8b7c-c515e99cbf18" {""}
							"fde5d850-671e-4143-950a-87b473922dc7" {""}
							"fead7313-4b9e-4632-80a2-98a2a2d83297" {""}
							"fead7313-4b9e-4632-80a2-ff00a2d83297" {""}
							"fead7313-ae6d-45dd-8260-13b563cb4c71" {""}
							"ff13819a-a9ac-46fb-8163-9d53357ef98d" {""}
							"ff48f7e6-2fa1-428d-9a15-ab154762043d" {""}
							"e15ed6d2-4af1-4361-89d3-2acf8cd485de" {"SP2010"}
							"3ce24023-95a1-4778-85b0-8e9b2bcacc80" {"SP2010"}
							"786eaa5b-85d7-4ea0-8998-0b62c8befd94" {"SP2010"}
							"af6d9aec-7c38-4dda-997f-cc1ddbb87c92" {"SP2010"}
							"c0c2628d-0f59-4873-9cba-100dad2313cb" {"SP2010"}
							"9d46d0d4-af7b-4f2e-8f84-9466ab25766c" {"SP2010"}
							"c04234f4-13b8-4462-9108-b4f5159beae6" {"SP2010"}
							"2acf27a5-f703-4277-9f5d-24d70110b18b" {"SP2010"}
							"30a6403b-b04f-42cc-805a-bc4d77826253" {"SP2010"}
							"412c7903-14f8-480a-8e98-3c5817906f70" {"SP2010"}
							"5709298b-1876-4686-b257-f101a923f58d" {"SP2010"}
							"08570f0f-6163-4255-9826-f8c41dad74bd" {"SP2010"}
							"ab2b7011-492c-4487-beb7-42d7a7f33cd1" {"SP2010"}
							"7c939ea0-196e-4759-ad06-8bc2a64ed4e5" {"SP2010"}
							"095f7b90-f808-40a8-8e41-1483906e8fae" {"SP2010"}
							"6f88b617-b0ed-484d-80fc-df6f6f2b1a11" {"SP2010"}
							"893627d9-b5ef-482d-a3bf-2a605175ac36" {"SP2010"}
							"8dfaf93d-e23c-4471-9347-07368668ddaf" {"SP2010"}
							"3aac9d1a-ebcb-412d-92e5-b394acfc8ca9" {"SP2010"}
							"93eeb8e3-a860-479b-835c-80f11005013e" {"SP2010"}
							"841a0715-b009-468e-af78-62ec0ad2231e" {"SP2010"}
							"fb67f269-fd1d-4f9a-af0b-50f5755e19d7" {"SP2010"}
							"cfc6eb4f-b5a9-4c11-b214-00dd22c7e7b5" {"SP2010"}
							"738250ba-9327-4dc0-813a-a76928ba1842" {"SP2010"}
							"e8389ec7-70fd-4179-a1c4-6fcb4342d7a0" {"SP2010-SSRS"}
							"5f2e3537-91b5-4341-86ff-90c6a2f99aae" {"SP2010-SSRS"}
							"c769801e-2387-47ef-a810-2d292d4cb05d" {"SP2010-SSRS"}
							"6bcbccc3-ff47-47d3-9468-572bf2ab9657" {"SP2010-SSRS"}
							"00057002-c978-11da-ba52-00042350e42e" {"SP2010"}
							"00057005-c978-11da-ba52-00042350e42e" {"SP2010"}
							"fcef4757-bc3f-42c0-8a37-a09e010fcd57" {"SP2010"}
							"eba21329-10fb-411c-9a28-62ec10a95446" {"SP2010"}
							"47c03bc9-aac7-447d-aac4-33c495c96eea" {"SP2010"}
							"e744cdf1-146e-4136-ad37-cc6a4fa16c6b" {"SP2010"}
							"ae3d9093-2103-4155-a582-b7d6a566ecf3" {"SP2010"}
							"9bf095db-11a4-4568-b92e-e23db80a8777" {"SP2010"}

				            })
                                Write-Output "| $($feature.DisplayName) | $($feature.ID) | $($feature.CompatibilityLevel) | $($feature.Scope) | $FeatureSource |"
                                    If ($feature.ID -match "75a0fea7")
                                         {$fabcount=$fabcount+1}
                     }
                        $Fab40Warning="There are $($fabcount) feature(s) installed that are part of a template collection known as the 'Fab 40'. These may cause upgrade/migration issues."
                        WarningCheck -warninglimit 1 -warningct $fabcount -warningmsg $Fab40Warning
        }
		
Function TemplatesInFarm
		{
            Write-Output `n"## Templates in Farm"
            $templates=Get-SPWebTemplate
            Write-Output `n"| Name |        Title        |            Id                  | Compatibility Level | Custom |"
            Write-Output "| :---- | :---- | :---- | :----: | :---- |"
            ForEach ($template in $templates)
                {
                    Write-Output "| $($template.Name) | $($template.Title) | $($template.LocaleId) | $($template.CompatibilityLevel) | `t $($template.Custom)"
                }
		}
		
Function TemplatesUsedInFarm
		{
            Write-Output `n"## Templates USED in farm by web"
            Write-Host -foregroundcolor yellow "The next step in this script will list every web (site or subsite)
in your farm along with the template used by that web.
If you have a large number of sites it might take some time to complete
and may slow farm performance temporarily.

Answering No to this question only skips this section."
            $continue = Read-Host "Would you like to continue? (y/N)"
            if($continue -eq "Y")
                {
                    $webs=Get-Spsite -limit all | Get-SPWeb -limit all
                    Write-Output `n"| URL | Template ID | Template |"
                    Write-Output "| :---- | :----: | :---- |"
                    ForEach ($web in $webs)
                        {
                            Write-Output "| $($web.URL) | $($web.WebTemplateID) | `t $($web.WebTemplate)"
                        }
                }
		}

Function ConvertFrom-Markdown
        {
            <#
                .SYNOPSIS
                    Converts Markdown formatted text to HTML.

                .DESCRIPTION
                    Converts Markdown formatted text to HTML using the Github API. Output is "flavored" depending on
                    the chosen mode. The default output flavor is 'Markdown' and includes Syntax highlighting and
                    Github stylesheets.

                    Based on the Ruby version by Brett Terpstra:
                    http://brettterpstra.com/easy-command-line-github-flavored-markdown/

                    About Markdown: http://daringfireball.net/projects/markdown/

                .EXAMPLE
                    ConvertFrom-Markdown -InputObject (Get-Content .\README.md -Raw)

                .EXAMPLE
                    Get-Content .\README.md -Raw | ConvertFrom-Markdown | clip.exe

                .EXAMPLE
                    dir *.md | % {gc $_ -Raw | ConvertFrom-Markdown | Out-File -FilePath "$($_.Name.TrimEnd(".md")).html"}
             #>
            [CmdletBinding()]
                Param
                    (
                        [Parameter(
                                    Mandatory=$true,
                                    ValueFromPipeline=$true,
                                    Position=0)]
                        [PSObject[]]$InputObject
                    )
                Begin
                    {
                        $URL = "https://api.github.com/markdown"
                    }
                Process
                    {

                Foreach ($item in $InputObject)
                                                                                                                                {

                    $object = New-Object -TypeName psobject
                    $object | Add-Member -MemberType NoteProperty -Name 'text' -Value ($item | Out-String)
                    $object | Add-Member -MemberType NoteProperty -Name 'mode' -Value 'markdown'

                    $response = Invoke-WebRequest -Method Post -Uri $url -Body ($object | ConvertTo-Json)

                    if ($response.StatusCode -eq "200")
                        {

                            $HtmlOutput = @"
                            <!DOCTYPE HTML>
                            <html lang="en-US">
                            <head>
                            <meta charset="UTF-8">
                            <title></title>
                            <style>
								body {
								   font-family: 'Open Sans', 'Segoe UI',  sans-serif;
								   font-size: 14px;
								   line-height: 1.6;
								   padding-top: 10px;
								   padding-bottom: 10px;
								   background-color: white;
								   padding: 30px; }

								body > *:first-child {
								   margin-top: 0 !important; }
								body > *:last-child {
								   margin-bottom: 0 !important; }

								a {
								   color: #4183C4; }
								a.absent {
								   color: #cc0000; }
								a.anchor {
								   display: block;
								   padding-left: 30px;
								   margin-left: -30px;
								   cursor: pointer;
								   position: absolute;
								   top: 0;
								   left: 0;
								   bottom: 0; }

								h1, h2, h3, h4, h5, h6 {
								   margin: 20px 0 10px;
								   padding: 0;
								   font-weight: bold;
								   -webkit-font-smoothing: antialiased;
								   cursor: text;
								   position: relative; }

								h1:hover a.anchor, h2:hover a.anchor, h3:hover a.anchor, h4:hover a.anchor, h5:hover a.anchor, h6:hover a.anchor {
								   text-decoration: none; }

								h1 tt, h1 code {
								   font-size: inherit; }

								h2 tt, h2 code {
								   font-size: inherit; }

								h3 tt, h3 code {
								   font-size: inherit; }

								h4 tt, h4 code {
								   font-size: inherit; }

								h5 tt, h5 code {
								   font-size: inherit; }

								h6 tt, h6 code {
								   font-size: inherit; }

								h1 {
								   font-size: 28px;
								   color: black; }

								h2 {
								   font-size: 24px;
								   border-bottom: 1px solid #cccccc;
								   color: black; }

								h3 {
								   font-size: 18px; }

								h4 {
								   font-size: 16px; }

								h5 {
								   font-size: 14px; }

								h6 {
								   color: #777777;
								   font-size: 14px; }

								p, blockquote, ul, ol, dl, li, table, pre {
								   margin: 15px 0; }

								hr {
								   border: 0 none;
								   color: #cccccc;
								   height: 4px;
								   padding: 0;
								}

								body > h2:first-child {
								   margin-top: 0;
								   padding-top: 0; }
								body > h1:first-child {
								   margin-top: 0;
								   padding-top: 0; }
								body > h1:first-child + h2 {
								   margin-top: 0;
								   padding-top: 0; }
								body > h3:first-child, body > h4:first-child, body > h5:first-child, body > h6:first-child {
								   margin-top: 0;
								   padding-top: 0; }

								a:first-child h1, a:first-child h2, a:first-child h3, a:first-child h4, a:first-child h5, a:first-child h6 {
								   margin-top: 0;
								   padding-top: 0; }

								h1 p, h2 p, h3 p, h4 p, h5 p, h6 p {
								   margin-top: 0; }

								li p.first {
								   display: inline-block; }
								li {
								   margin: 0; }
								ul, ol {
								   padding-left: 30px; }

								ul :first-child, ol :first-child {
								   margin-top: 0; }

								dl {
								   padding: 0; }
								dl dt {
								   font-size: 14px;
								   font-weight: bold;
								   font-style: italic;
								   padding: 0;
								   margin: 15px 0 5px; }
								dl dt:first-child {
								   padding: 0; }
								dl dt > :first-child {
								   margin-top: 0; }
								dl dt > :last-child {
								   margin-bottom: 0; }
								dl dd {
								   margin: 0 0 15px;
								   padding: 0 15px; }
								dl dd > :first-child {
								   margin-top: 0; }
								dl dd > :last-child {
								   margin-bottom: 0; }

								blockquote {
								   border-left: 4px solid #dddddd;
								   padding: 0 15px;
								   color: #777777; }
								blockquote > :first-child {
								   margin-top: 0; }
								blockquote > :last-child {
								   margin-bottom: 0; }

								table {
								   padding: 0;border-collapse: collapse; }
								table tr {
								   border-top: 1px solid #cccccc;
								   background-color: white;
								   margin: 0;
								   padding: 0; }
								table tr:nth-child(2n) {
								   background-color: #e5e5e5; }
								table tr th {
								   font-weight: bold;
								   border: 1px solid #cccccc;
								   margin: 0;
								   padding: 6px 13px; }
								table tr td {
								   border: 1px solid #cccccc;
								   margin: 0;
								   padding: 6px 13px; }
								table tr th :first-child, table tr td :first-child {
								   margin-top: 0; }
								table tr th :last-child, table tr td :last-child {
								   margin-bottom: 0; }

								img {
								   max-width: 100%; }

								span.frame {
								   display: block;
								   overflow: hidden; }
								span.frame > span {
								   border: 1px solid #dddddd;
								   display: block;
								   float: left;
								   overflow: hidden;
								   margin: 13px 0 0;
								   padding: 7px;
								   width: auto; }
								span.frame span img {
								   display: block;
								   float: left; }
								span.frame span span {
								   clear: both;
								   color: #333333;
								   display: block;
								   padding: 5px 0 0; }
								span.align-center {
								   display: block;
								   overflow: hidden;
								   clear: both; }
								span.align-center > span {
								   display: block;
								   overflow: hidden;
								   margin: 13px auto 0;
								   text-align: center; }
								span.align-center span img {
								   margin: 0 auto;
								   text-align: center; }
								span.align-right {
								   display: block;
								   overflow: hidden;
								   clear: both; }
								span.align-right > span {
								   display: block;
								   overflow: hidden;
								   margin: 13px 0 0;
								   text-align: right; }
								span.align-right span img {
								   margin: 0;
								   text-align: right; }
								span.float-left {
								   display: block;
								   margin-right: 13px;
								   overflow: hidden;
								   float: left; }
								span.float-left span {
								   margin: 13px 0 0; }
								span.float-right {
								   display: block;
								   margin-left: 13px;
								   overflow: hidden;
								   float: right; }
								span.float-right > span {
								   display: block;
								   overflow: hidden;
								   margin: 13px auto 0;
								   text-align: right; }

								code, tt {
								   margin: 0 2px;
								   padding: 0 5px;
								   white-space: nowrap;
								   border: 1px solid #eaeaea;
								   background-color: #f8f8f8;
								   border-radius: 3px; }

								pre code {
								   margin: 0;
								   padding: 0;
								   white-space: pre;
								   border: none;
								   background: transparent; }

								.highlight pre {
								   background-color: #f8f8f8;
								   border: 1px solid #cccccc;
								   font-size: 13px;
								   line-height: 19px;
								   overflow: auto;
								   padding: 6px 10px;
								   border-radius: 3px; }

								pre {
								   background-color: #f8f8f8;
								   border: 1px solid #cccccc;
								   font-size: 13px;
								   line-height: 19px;
								   overflow: auto;
								   padding: 6px 10px;
								   border-radius: 3px; }
								pre code, pre tt {
								   background-color: transparent;
								   border: none; }

								sup {
								   font-size: 0.83em;
								   vertical-align: super;
								   line-height: 0;
								}
								* {
									 -webkit-print-color-adjust: exact;
								}
								@media screen and (min-width: 914px) {
								   body {
									  width: 854px;
									  margin:0 auto;
								   }
								}
								@media print {
									 table, pre {
										  page-break-inside: avoid;
									 }
									 pre {
										  word-wrap: break-word;
									 }
								}

                            </style>
                            </head>
                            <body>
                            <div id="wrapper">
                            $($response.Content)
                            </div>
                            </body>
                            </html>
"@
                            Write-Output $HtmlOutput

                        }

                    else { "Error: $($response.StatusCode)" }
                }
                     }
                      End
                        {
                            #$objects.count
                        }
         }
		
Function OutputRedirect
		{
			FarmBuild
			UserID
			ServersInFarm
			LangPackList
            		ShowCurrentErrors
			ServiceInfo
			WebAppsInFarm
			ManagedPathList
			ManagedAccountInfo
			AppPoolInfo			
			SolutionsInFarm
			ContentDBInfo
			AppDBInfo
			LargeListList
			AAMInfo
			FeaturesInFarm
			TemplatesInFarm
			TemplatesUsedInFarm
		}



OutputRedirect|Out-File -width 200 $OutFile

If ([INT]$(Get-Host).Version.major -gt 2)
	{
		Write-Host -foregroundcolor yellow `n"The default output file is a text file that uses the Markdown format
(http://daringfireball.net/projects/markdown/).
This next step will convert it to a nicely readable HTML file, but it will send
your data to an online API for processing. If you don't need the formatted
document, your server does not have access to the internet, or if you consider
this a security risk answer with anything besides a Y and no data will be sent.
If you answer with a Y the html document will be generated in the same folder
you specified for the text output."

$continue = Read-Host "Would you like to continue with generating the HTML version of the document? (y/N)"
if($continue -eq "Y")
        {
            $outother=Get-Item $outfile|ForEach-Object { $_.FullName -replace $_.Extension }
            Get-Content $outfile -RAW |ConvertFrom-Markdown | Out-File -FilePath "$outother.html"
        }
	}
	