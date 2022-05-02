#Requires -RunAsAdministrator
#
# Copyright (c) Mainline4Lumia
#

param(
    [Parameter(Mandatory)]
    [string]$efiesp_location
)

function Get-GUID {
    param (
        $bcdeditOutput
    )

    $pattern = '(?<=\{).+?(?=\})'
    return "{$([regex]::Matches($bcdeditOutput, $pattern).Value)}"
}

Write-Output("Developer menu and bootshim installer");

$bcd_file = "$efiesp_location\EFI\Microsoft\BOOT\BCD"
$bootmgr_efis_location = "$efiesp_location\Windows\System32\BOOT"

if (-not (Test-Path -Path "$bcd_file" -PathType Leaf)) {
    Write-Output("BCD file not found")
    exit 1
}

Write-Output("Enabling bootmgr menu")
bcdedit /store "$bcd_file" /set "{bootmgr}" displaybootmenu on
bcdedit /store "$bcd_file" /set "{bootmgr}" timeout 10
bcdedit /store "$bcd_file" /displayorder "{default}"

Write-Output("Creating bootshim entry")
$bootshim_guid = bcdedit /store "$bcd_file" /create /d "Boot Shim" /application BOOTAPP
$bootshim_guid = Get-GUID($bootshim_guid)
bcdedit /store "$bcd_file" /set "$bootshim_guid" path "\Windows\System32\BOOT\bootshim.efi"
bcdedit /store "$bcd_file" /set "$bootshim_guid" device "partition=$efiesp_location"
bcdedit /store "$bcd_file" /set "$bootshim_guid" testsigning on
bcdedit /store "$bcd_file" /set "$bootshim_guid" nointegritychecks on
bcdedit /store "$bcd_file" /set "{bootmgr}" "custom:54000001" "$bootshim_guid"

Write-Output("Creating developermenu entry")
$bootentry_guid = bcdedit /store "$bcd_file" /create /d "Developer Menu" /application BOOTAPP
$bootentry_guid = Get-GUID($bootentry_guid)
bcdedit /store "$bcd_file" /set "$bootentry_guid" path "\Windows\System32\BOOT\developermenu.efi"
bcdedit /store "$bcd_file" /set "$bootentry_guid" device "partition=$efiesp_location"
bcdedit /store "$bcd_file" /set "$bootentry_guid" testsigning on
bcdedit /store "$bcd_file" /set "$bootentry_guid" nointegritychecks on
bcdedit /store "$bcd_file" /set "{bootmgr}" "custom:54000002" "$bootentry_guid"

Write-Output("Copying bootshim")
Copy-Item "$PSScriptRoot\bootshim.efi" -Destination "$bootmgr_efis_location"
Copy-Item "$PSScriptRoot\Stage2.efi" -Destination "$efiesp_location"

Write-Output("Copying developermenu")
Copy-Item -Path "$PSScriptRoot\developermenu.efi" -Destination "$bootmgr_efis_location"
New-Item -ItemType Directory -Path "$bootmgr_efis_location\ui" -Force
Copy-Item -Path "$PSScriptRoot\ui\*" -Destination "$bootmgr_efis_location\ui"

Write-Output("Done! On phone power on, you can now boot bootshim and developer menu by pressing volume up and down keys respectively, else wait 10 seconds to boot Windows Phone");
