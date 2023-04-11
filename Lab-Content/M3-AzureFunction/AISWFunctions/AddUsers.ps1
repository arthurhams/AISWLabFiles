Disconnect-MgGraph 
Connect-MgGraph  -TenantId "4fb541ce-6d51-494d-a84f-312b731c1a97"  -Scopes "User.ReadWrite.all"

$adUserList = 'arthur.hallensleben' #'dean.efpatridis', 'guido.verdijck'
foreach ($user in $adUserList )
{
	$firstname = $user.split('.')[0]
	$lastname = $user.split('.')[1]

    $domain="nutrecohackathonoutlook.onmicrosoft.com"
    $password="Nutr3c0!" #| ConvertTo-SecureString -AsPlainText -Force

    $params = @{ AccountEnabled = $true 
         DisplayName ="$firstname $lastname"
	    mailNickname = "$firstname.$lastname"
	    UserPrincipalName = "$firstname.$lastname@$domain"
	    PasswordProfile = @{ 
	        ForceChangePasswordNextSignIn = $false 
	        Password = $password 
	    }
    } 

    New-MgUser -BodyParameter $params

    $location = "westeurope"
    $resourcegroupname="$firstname`_$lastname`_rg"
    Get-AzResourceGroup -Name $resourcegroupname -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent)
    {
        # ResourceGroup doesn't exist
        New-AzResourceGroup -Name $resourcegroupname -Location $location
    }

}
foreach ($user in $adUserList )
{
	$firstname = $user.split('.')[0]
	$lastname = $user.split('.')[1]
    $resourcegroupname="$firstname`_$lastname`_rg"

    New-AzRoleAssignment -SignInName "$firstname.$lastname@$domain"-Scope "/subscriptions/3fc173c5-7a9d-4cd0-ada9-4a87e3e624ae/resourceGroups/$resourcegroupname"  -RoleDefinitionName "Contributor" 
}


# LAB 2 - Logic App

$firstname = "arthur"
$lastname = "hallensleben"

$location = "westeurope"
$resourcegroupname="$firstname`_$lastname`_rg"
$intaccounappname = "IntAccountDemo"
$LogicAppName = "VETERPipeline-la"

New-AzIntegrationAccount -ResourceGroupName $resourcegroupname -Name $intaccounappname -Location $location -Sku "Free"
$IntegrationAccount = Get-AzIntegrationAccount -ResourceGroupName $resourcegroupname -Name $intaccounappname

Set-Location  '~/'
if ((Test-Path 'AISWLabFiles'))
{
    Remove-Item 'AISWLabFiles' -Recurse -Force
}
git clone https://github.com/arthurhams/AISWLabFiles

New-AzIntegrationAccountSchema -ResourceGroupName $resourcegroupname -Name $intaccounappname -SchemaName "order" -SchemaFilePath "~/AISWLabFiles/Lab-Content/M2-LogicApps/Content/Exercise1/order.xsd"
New-AzIntegrationAccountSchema -ResourceGroupName $resourcegroupname -Name $intaccounappname -SchemaName "saporder" -SchemaFilePath "~/AISWLabFiles/Lab-Content/M2-LogicApps/Content/Exercise1/saporder.xsd"
New-AzIntegrationAccountMap -ResourceGroupName $resourcegroupname -Name $intaccounappname -MapName "xsltmap" -MapFilePath "~/AISWLabFiles/Lab-Content/M2-LogicApps/Content/Exercise1/xsltmap.xslt"

New-AzLogicApp -ResourceGroupName $resourcegroupname -Location $location  -Name $LogicAppName -IntegrationAccountId $IntegrationAccount.Id -DefinitionFilePath "~/AISWLabFiles/Lab-Content/M2-LogicApps/Content/Exercise1/workflow.json"

#test logic app
$message =  Get-Content -Path "~/AISWLabFiles/Lab-Content/M2-LogicApps/Content/Exercise1/sample-order.xml"

$Headers = @{
    'Content-Type' = 'application/xml'
}

$logicappurl = Get-AzLogicAppTriggerCallbackUrl -ResourceGroupName $resourcegroupname -Name $LogicAppName -TriggerName "manual" 

Invoke-WebRequest -Uri $logicappurl.Value -Method POST -Body $message -Headers $Headers

# LAB 3 
$functionstorageaccountName = "$firstname$lastname" + "funcsa"
$functionappname = "$firstname$lastname" + "func"

    Write-Host Create Function Storage Account
    Get-AzStorageAccount -Name $functionstorageaccountName -ResourceGroupName $resourcegroupname -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent)
    {
        New-AzStorageAccount -ResourceGroupName $resourcegroupname `
           -Name $functionstorageaccountName -Location $location `
        -SkuName Standard_LRS  -Kind StorageV2 -AllowBlobPublicAccess $False
    }
      $fap = Get-AzFunctionApp -ResourceGroupName $resourcegroupname -Name $functionappname -ErrorAction SilentlyContinue
    if(-not($fap)){
    New-AzFunctionApp -Name $functionappname `
                  -ResourceGroupName $resourcegroupname `
                  -Location $location `
                  -StorageAccountName $functionstorageaccountName `
                  -Runtime DotNet -FunctionsVersion 4 -OSType Windows -RuntimeVersion 6 
    }

    $azureFunctionApp = Get-AzFunctionApp -ResourceGroupName $resourcegroupname  -Name $functionappname
    $functionurl = "https://" + $azureFunctionApp.DefaultHostName;

    dotnet publish '~/AISWLabFiles/Lab-Content/M3-AzureFunction/AISWFunctions/AzureIntegrationServicesWorkshop/LiquidMapper.csproj' --output '~/AISWLabFiles/Lab-Content/M3-AzureFunction/AISWFunctions/AzureIntegrationServicesWorkshop/bin/publish'

    Compress-Archive -Path '~/AISWLabFiles/Lab-Content/M3-AzureFunction/AISWFunctions/AzureIntegrationServicesWorkshop/bin/publish/*' -DestinationPath 'LiquidMapper.zip' -Force

    Publish-AzWebapp -ResourceGroupName $resourcegroupname -Name $functionappname -ArchivePath 'LiquidMapper.zip' -Force
