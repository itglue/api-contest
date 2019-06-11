# IT Glue API contest entry: NPI-ResetDomainPassword

## The problem
MSPs have a perennial security problem: what happens if we ourselves are compromised?  Not only are we in trouble, but all our clients are as well.  We generally have administrative access into our clients' environments, via a single MSP account, whose password is stored in IT Glue.  Such compromise can be a disgruntled current or former employee or a more typical external compromise.  
Therefore, our internal security must be at least as strong as that of any of our clients.  One component of a good security practice is password rotation, both regularly, and upon departure of any employee who had access to IT Glue-stored passwords.  However, this rotation is an operational challenge when you have potentially hundreds of clients, each with a stored MSP credential.  There are expensive password-checkout systems out there, but they may be beyond the budget of many MSPs.

## The solution
This script will work with Active Directory and IT Glue to update the MSP's stored password on demand.  It can be deployed via any remote management tool, and when run on a domain controller (or RSAT machine) will update the MSP account's password.  It can optionally create a new password and store it in both Active Directory and IT Glue, and that password can be either fully randomized or human-readable (in the CorrectHorseBatteryStaple vein).  Randomized passwords will satisfy complexity requirements and the length can be specified, and will not include homographs 0/O or I/1/l (\[*cough, cough, IT Glue password randomization algorithm*\]).  The script could be used by an MSP after every client access, or could be run across all clients at specified intervals.  That would help the MSP to comply with security frameworks that require regular password rotation.

### Requirements
- There must be a flexible asset type that stores the Active Directory domain name, and its ID must be hard-coded into the script in the Find-MyOrganization function.  For our IT Glue tenant, that ID is 25110.
- The installed version of Powershell on which the script is run must be at least version 3
- The machine on which the script is run must have the ActiveDirectory PowerShell module installed.

### Submitter
- David Hirsch, 11 June 2019
