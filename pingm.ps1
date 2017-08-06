<#
.Synopsis
   Repeatedly sends pings to computers, and draws an in-console view of the results, e.g.

   .............x.....................x....  | google.com (18ms)
   ...................................x....  | 8.8.8.8 (15ms)
.DESCRIPTION
   Takes one or more ComputerNames as a parameter, or from the pipeline - names or IPs.
   Sets up a continuous loop of ping tests, and draws the last few ping results on screen.
   e.g. for pinging several things as you reboot them, and watching them come back online.

   Results key:
   _ represents no data, result slots start out like this before there are results for them
   . represents a ping reply
   x represents a timeout
   ? represents an exception during the ping attempt, or other failure
   
   Press Ctrl-C to break the loop and stop it running.


   NB. 'ping' requests are usually low priority for hosts to reply to, and often dropped
       if links are hitting bandwidth limits. A few blip timeouts when pinging over the 
       internet is quite common, and you can't reliably use "one failure" to indicate a
       host is offline or has network problems.
.EXAMPLE
   Ping your local network firewall, Google out on the internet, and a remote machine 
   at one of your other offices, so that when you reboot your firewall you can confirm
   it comes back online, the internet connection comes up, and the VPN comes up.
   
   PS D:\> pingm.ps1 192.168.0.1, google.com, 10.200.50.50
.EXAMPLE
   Use it as a rudimentary ping sweep to ping the first 10 IPs in 192.168.1.0/24:

   1..10 | foreach { "192.168.1.$_" } | .\pingm.ps1
.EXAMPLE
   Keep lots of results, it wraps around the screen:

   PS D:\> .\pingm.ps1 google.com, example.org -ResultCount 400
.INPUTS
   Inputs to this cmdlet:
   -ComputerName: one or more computer names or IP addresses, as a parameter or pipeline input.
   -ResultCount: how many ping results to store and draw for each host.
.OUTPUTS
   Output from this cmdlet: None, it's interactive only.
.NOTES
   General notes
#>
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                Position=0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName,


    # Number of pings to show
    [Parameter(Position=1)]
    [int]$ResultCount = 50
)



# Gather up pipeline input, if there was any
    $PipelineItems = @($input)
    if ($PipelineItems.Count)
    {
        $ComputerName = $PipelineItems
    }



# Validate computernames 
# - stop script if anything is not an IP address, and can't be resolved to one.
$ComputerName | 
    Where-Object   { -not ($_ -as [ipaddress]) } |
    ForEach-Object {
        $null = Resolve-DnsName $_ -ErrorAction Stop
    }



# Redrawing the screen with Clear-Host causes it to flicker; each line is arranged
# to be the same length, so moving the cursor back to the top can overwrite them
# but this doesn't work in PS ISE, so this tries to detect that and use the nicer
# method if supported, falling back to Clear-Host
$UseClearHostWhenRedrawing = $false
try {
    [System.Console]::SetCursorPosition(0, 0)
} catch [System.IO.IOException] {
    $UseClearHostWhenRedrawing = $true
}



# Clear host anyway, for the first run.
Clear-Host



# Setup the data store for each computer, with a pinger, and a store for previous results
[array]$PingData = foreach($Computer in $ComputerName)
{
    @{
        'Name'       = $Computer
        'Pinger'     = New-Object -TypeName System.Net.NetworkInformation.Ping
        'Results'    = New-Object -TypeName System.Collections.Queue($ResultCount)
        'LastResult' = @{}
    }
}



# Initialise the results stores for each computer with '_' entries
foreach ($Item in $PingData)
{
    for ($Filler = 0; $Filler -lt $ResultCount; $Filler++)
    {
        $Item.Results.Enqueue('_')
    }
}



# Run the main code loop - ping forever
while ($true)
{


    # Send pings to each computer in the background
        [array]$PingTasks = foreach($Item in $PingData)
        {
            $Item.Pinger.SendPingAsync($Item.Name)
                # NB. it is possible to set a timeout in ms here, 
                #     but it doesn't work reliably, reporting false
                #     TimedOut replies even when replies do come back,
                #     so I removed it and leave the default.
        }



    # Wait for all the results
        try {
            [Threading.Tasks.Task]::WaitAll($PingTasks)
        } catch [AggregateException] {
            # This happens e.g. if there's a failed DNS lookup in one of the tasks
            # Just going to let it happen, silence it, check the results later,
            # and display failed tasks differently.
        }



    # Update PingData store with results for each computer
        0..($PingTasks.Count-1) | ForEach-Object {
                
            $Task         = $PingTasks[$_]
            $ComputerData = $PingData[$_]

            if ($Task.Status -ne 'RanToCompletion')
            {
                $ComputerData.Results.Enqueue('?')
            }
            else
            {
                $ComputerData.LastResult = $Task.Result
                    
                switch ($Task.Result.Status)
                {
                    'Success'  { $ComputerData.Results.Enqueue('.') }
                    'TimedOut' { $ComputerData.Results.Enqueue('x') }
                }
                    
            }  
        }



    # Stop results store growing forever, remove old entries if they get too big.
        foreach ($Item in $PingData)
        {
            while ($Item.Results.Count -gt $ResultCount)
            {
                $null = $Item.Results.DeQueue()
            }
        }



    # ReDraw screen
        if ($UseClearHostWhenRedrawing)
        {
            Clear-Host
        }
        else
        {
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            $CursorPosition.X = 0
            $CursorPosition.Y = 0
            $Host.UI.RawUI.CursorPosition = $CursorPosition
        }



        # Draw a line of results for each computer, with color indicating ping reply or not
        foreach ($Item in $PingData)
        {
            # Draw the results array
            Write-Host (($Item.Results -join '') + ' | ') -NoNewline

            # Handle ping to make it fixed width - 
            $PingText = if ($Item.LastResult.Status -eq 'Success')
            {
                if (1000 -le $Item.LastResult.RoundTripTime)
                {
                     '(999+ms)'
                }
                else
                {
                    '({0}ms)' -f $Item.LastResult.RoundTripTime.ToString().PadLeft(4, ' ')
                }
            }
            else
            {
                '(----ms)'
            }

            # Draw ping text and computer name
            Write-Host "$PingText | " -NoNewline

            # Draw computer name with colour
            if ($Item.LastResult.Status -eq 'Success')
            {
                Write-Host ($Item.Name) -BackgroundColor DarkGreen
            }
            else
            {
                Write-Host ($Item.Name) -BackgroundColor DarkRed
            }
        }



    # Delay restarting the ping loop
    # Try to be 1 second wait, minus the time spent waiting for the slowest ping reply.
        $Delay = 1000 - ($PingData.lastresult.roundtriptime | Sort-Object | Select-Object -Last 1)
        Start-Sleep -MilliSeconds $Delay
}
