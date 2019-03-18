<#
    SFTP Log Search
    Author: Abby Horner
    Date: 3/12/2019

    Change Log:

    # TODO: break information out into a more readable format
    # TODO: option to input a direct path, just in case the file locations are different
    # TODO: validate that we only read .txt files to be safe
    # TODO: option to print output to file
#>

<#
    Function to search through files in a directory for a specific keyword
    Searches line by line for any sequential set of characters
    At least very simple regex will work here, but haven't tested it very extensively (wildcards work)
#>
Function SearchLogFilesForKeyword($keyword,$logpath,$verb)
{
    # Pulling all filenames from the path
    $files = Get-ChildItem -Path $logpath
    
    # For every file at that path
    foreach ($file in $files)
    {
        # Setting up variables
        $occurrences = 0    # Number of times the keyword appears
        $lines = @()        # Array to hold the lines the keyword appears in
        $lineNumber = 0     # Line number counter to keep track of where the lines are

        # Output stuff
       Write-Host "`nSearching file" $file.FullName

        # For every line in the current file
        foreach ($line in Get-Content $file.FullName) {

            # Keeping track of line number
            $lineNumber++

            # If the keyword is found anywhere in the line
            if ($line -match $keyword)
            {
                # Increment the number of occurrences and add the linenumber + line to the lines array
                $occurrences++
                $lines += "$lineNumber ..." + ' ' * (10 - $lineNumber.ToString().Length) + "$line"
            }
        }
        # If nothing found, say so
        if ($occurrences -eq 0) 
        {
            Write-Host "Keyword not found in file $file"
        }
        # Otherwise, print what we found (including line numbers)
        else 
        {
            ParseInput $lines $verb
            # Write-Host "Found $occurrences occurrences of keyword $keyword :"
            # foreach ($line in $lines) 
            # {
            #     Write-Host $line
            # }
        }
        
    }
    return;
}

<#
    Function to find the location of the Log folder in the HuronFileTransfer folder
    The setup is the same at every client, however there is a folder that uses the client's name, so had to get tricksy
    Returns:
        $testpath = the path to the Log folder
#>
Function FindLogFilePath($serverName)
{
    # Build the first iteration using the server name and the already-known file structure
    $path = '\\'+$servername+'\i$\HuronFileTransfer\'

    # Checking that the path generated above is valid
    if (-Not(Test-Path $path))
    {
        Write-Error "That is not a valid server name or I cannot find the path to the HuronFileTransfer folder. Please check the server name and try again.`n"
        Read-Host "Press enter to exit"
        BREAK;
    }

    # Retrieve all the folders in the above path
    $folders = Get-ChildItem -Path $path -Directory

    # For every folder in that path
    foreach ($folder in $folders) {
        # Add \Log to the end
        $testpath = $folder.FullName + "\Log"
        # And check if that's itself a valid path
        if (Test-Path $testpath) {
            # If it is, return that
            return $testpath;
        }
    }
    # We didn't find a Log folder, error out
    Write-Error "HuronFileTransfer Log folder not found on this server"
    Read-Host "Press enter to exit"
    BREAK;
}

Function ParseInput($lines,$verb)
{
    $newLines = @()
    $dates = @()
    if ($verb -eq "")
    {
        # We are looking at all of them, so recursion is our friend 
        ParseInput($lines,": Download")
        ParseInput($lines,": Upload")
        ParseInput($lines,": Archive")
        ParseInput($lines,": Copy")
    }
    else 
    {
        foreach ($line in $lines) 
        {
            if ($line -match $verb) 
            {
                $newLines += $line
                $dates += $line.Substring(14,10)
            }
        }
        $dates = $dates | Sort -Unique
        foreach ($date in $dates) 
        {
            Write-Host "DATE: $date"
            Write-Host "==========================="
            Write-Host ""
            foreach ($line in $newLines) 
            {
                
                if ($line -match $date)
                {   
                    Write-Host $line.Substring(25,5) : $line.Substring(34)
                }
            }
            Write-Host ""
        }
    }
    
}

#######################################
#                                     #
#                MAIN                 #
#                                     #
#######################################

# Create empty variables
$serverName = ""
$keyword = ""

# Prompt for variables
$serverName = Read-Host -Prompt "Server name"
$keyword = Read-Host -Prompt "Keyword to search for"
$verb = ""
Switch (Read-Host -Prompt "Which action are you looking for (type number)?`n1: Downloading`n2: Copying`n3: Archiving`n4: Uploading`n5: Any of these`n") 
{
    '1' {$verb = ": Download"}
    '2' {$verb = ": Copy"}
    '3' {$verb = ": Archived"}
    '4' {$verb = ": Upload"}
    '5' {$verb = ""}
    default {
        }
}
Write-Host ""

# Check that variables are not empt
if ([string]::IsNullOrEmpty($serverName) -or [string]::IsNullOrEmpty($keyword)) 
{
    Write-Error "Variables cannot be empty; Please try again."
    Read-Host "Press enter to exit"
    BREAK;
}

# Get filepath for Log folder (error handling for invalid server names is in the function)
$logPath = FindLogFilePath $serverName
$logPath = $logPath + "\*.txt"

# Perform the search
 SearchLogFilesForKeyword $keyword $logPath $verb

 # Hang so we can look at our results...
 Read-Host "Press the enter key to exit"