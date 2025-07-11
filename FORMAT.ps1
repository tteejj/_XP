# ===CONFIGURATION===
#GET-DISK
# !! CHANGE THIS TO YOUR USB DISK NUMBER FROM STEP 1 !!
$DiskNumber = 2 

# Choose your file system: NTFS, FAT32, or exFAT (recommended for USBs)
$FileSystem = "exFAT" 

# Choose a name for your drive
$DriveLabel = "MyUSB"

# ===EXECUTION===
# This single line executes all the steps. Confirm any prompts.
Get-Disk -Number $DiskNumber | Clear-Disk -RemoveData -RemoveOEM | Initialize-Disk -PartitionStyle GPT -Passthru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $DriveLabel

Write-Host "Process complete. Your USB drive should now be visible in File Explorer."