param(
[Parameter(Mandatory)][string]$appName,
[Parameter(Mandatory)][string]$principalId
)

# Get the appId/clientId using Azure CLI

$appId = az ad sp show --id $principalId --query "appId" -o tsv

if (-not $appId) {
    Write-Error "Could not find appId for principalId: $principalId"
    exit 1
}

Write-Host "Generating SQL script for appName: $appName with appId: $appId"

$sqlFileName = "$appName-GrantPermissions.sql"
$sqlFilePath = Join-Path $PSScriptRoot $sqlFileName

$sqlContent = @"
DECLARE @AppName NVARCHAR(256) = '$appName';
DECLARE @AppId NVARCHAR(256) = '$appId';
DECLARE @SidBinary VARBINARY(16);
DECLARE @SidHex NVARCHAR(34);
DECLARE @UserExists BIT = 0;

-- Convert GUID string to binary
SET @SidBinary = CAST(@AppId AS UNIQUEIDENTIFIER);

-- Convert binary to hex string with 0x prefix
SET @SidHex = '0x' + CONVERT(NVARCHAR(32), @SidBinary, 2);

-- Find and delete the user if it already exists
SELECT @UserExists = 1
FROM sys.database_principals
WHERE name = @AppName AND type = 'E';

IF @UserExists = 1
BEGIN
    PRINT 'User already exists. Dropping existing user.';
    DROP USER [@AppName];
END

-- Create the user for the Azure AD application

DECLARE @SQL NVARCHAR(MAX);
-- SET @SQL = 'CREATE USER [' + @AppName + N'] FROM EXTERNAL
SET @SQL = 'CREATE USER [' + @AppName + N'] WITH DEFAULT_SCHEMA=[dbo], SID=' + @SidHex + ', TYPE = E;';
EXEC sp_executesql @SQL;

-- Grant necessary permissions
SET @SQL = 'ALTER ROLE [db_datareader] ADD MEMBER [' + @AppName + N'];';
EXEC sp_executesql @SQL;
SET @SQL = 'ALTER ROLE [db_datawriter] ADD MEMBER [' + @AppName + N'];';
EXEC sp_executesql @SQL;
"@

$sqlContent | Out-File -FilePath $sqlFilePath -Encoding UTF8