# pingm - multiple ping tool

   Sends continuous pings to computers, and draws an in-console view of the results

    [[https://github.com/HumanEquivalentUnit/pingm/blob/master/example.gif|alt=Animated example run of pingm tool]]
    
## Example
   Ping a local gateway, an internet host, and a remote machine over a VPN
   so that when you reboot the router, you can confirm it, WAN links and VPNs
   all come online.
   
   `PS D:\> pingm.ps1 192.168.0.1, google.com, 10.200.50.50`

## Example
   Use it as a rudimentary ping sweep to ping the first 10 IPs in 192.168.1.0/24:

   `1..10 | foreach { "192.168.1.$_" } | .\pingm.ps1`

## Example
   Keep lots of results, it wraps around the screen:

   `PS D:\> .\pingm.ps1 google.com, example.org -ResultCount 400`

## Notes
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
