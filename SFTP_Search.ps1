<#
    SFTP Log Search
    Author: Abby Horner
    Date: 3/12/2019

    # TODO: option to input a direct path, just in case the file locations are different
    # TODO: option to print output to file
    # TODO: option to specify which file (if multiple are found) to read from
#>

<#
    Function to search through files in a directory for a specific keyword
    Searches line by line for any sequential set of characters
    Regex may break it
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

<#
    Parses the information from the file and prints it out in a more readable format.
#>
Function ParseInput($lines,$verb)
{
    # Set up our arrays
    $newLines = @()
    $dates = @()

    # If $verb is empty, throw this to the other function to print a readable timeline of all actions
    if ($verb -eq "")
    {
        ParseInputAllTypes $lines 
    }
    else 
    {
        # For every line we pulled out of the file,
        foreach ($line in $lines) 
        {
            # If it uses the specified verb,
            if ($line -match $verb) 
            {
                # Save it and its date off
                $newLines += $line
                $dates += $line.Substring(14,10)
            }
        }
    }
    # Throw the selected lines to the print function
    PrintOutput $newLines $dates 
    
}

Function ParseInputAllTypes($lines)
{
    # Same variables as above
    $newLines = @()
    $dates = @()

    # For all the lines,
    foreach ($line in $lines) 
    {
        # and for all the verbs,
        foreach ($item in $verbs)
        {
            # if the line has one of the verbs, save it off into $newLines
            if ($line -match $item) 
            {
                $newLines += $line 
                $dates += $line.Substring(14,10)
            }
        }
    }
    # Throw the selected lines to the print function
    PrintOutput $newLines $dates 
    
}

Function PrintOutput($newLines,$dates)
{
     # Remove duplicate dates
     $dates = $dates | Sort-Object -Unique

     # For every unique date we grabbed,
     foreach ($date in $dates) 
     {
         # Print out a header
         Write-Host "DATE: $date"
         Write-Host "==========================="
         Write-Host ""
         # For every line,
         foreach ($line in $newLines) 
         {
             # If the line is for the current date, print it out
             if ($line -match $date)
             {   
                 # Format = HH:MM : LINE TEXT
                 Write-Host $line.Substring(25,5) : $line.Substring(34)
             }
         }
         Write-Host ""
     }
}

Function CheckExit() 
{
    while (1) 
    {
        $exit = Read-Host "Exit? Y/N"
        switch($exit) {
            'Y' {return 1}
            'N' {return 0}
            default {Write-Host "Please select Y or N"}
        }
    }
}

#######################################
#                                     #
#                MAIN                 #
#                                     #
#######################################

while (1) 
{
    # Create empty variables
    $serverName = ""
    $keyword = ""

    # Prompt for variables
    $serverName = Read-Host -Prompt "Server name"
    $keyword = Read-Host -Prompt "Keyword to search for"

    # $verb will be used to filter our results
    $verb = ""
    $verbs = @(": Download",": Copy",": Archived",": Upload")

    # Get input from the user on which verb to search for. If no input or anything other than 1-5, $verb remains empty, meaning we look at all of them
    Switch (Read-Host -Prompt "Which action are you looking for (type number)?`n1: Downloading`n2: Copying`n3: Archiving`n4: Uploading`n5: Any of these`n") 
    {
        '1' {$verb = $verbs[0]}
        '2' {$verb = $verbs[1]}
        '3' {$verb = $verbs[2]}
        '4' {$verb = $verbs[3]}
        default {
            }
    }
    Write-Host ""

    # Check that variables (except $verb) are not empty
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
    $exit = CheckExit
    if ($exit -eq 1) {BREAK}
}

