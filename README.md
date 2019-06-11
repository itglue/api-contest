# IT Glue API contest entry: NPI-ResetDomainPassword

## The problem
MSPs have a perennial security problem: what happens if we ourselves are compromised?  Not only are we in trouble, but all our clients are as well.  We generally have administrative access into our clients' environments, via a single MSP account, whose password is stored in IT Glue.  Such compromise can be a disgruntled current or former employee or a more typical external compromise.  Our internal security must be at least as strong as that of any of our clients.  One component of a good security practice is password rotation, both regularly, and upon departure of any employee who had access to IT Glue-stored passwords.  However, this rotation is an operational challenge when you have potentially hundreds of clients, each with a stored MSP credential.

## The solution
This script can be deployed via any remote management tool, and when run on a domain controller will update the MSP's account password.  It can optionally create a new password and store it in IT Glue, and that password can be fully randomized or human-readable (in the CorrectHorseBatteryStaple vein).  Complex passwords will satisfy complexity requirements and the length can be specified, and will not include homographs 0/O or I/1/l (\[*cough, cough, IT Glue password randomization algorithm*\]).  The script could be used by an MSP after every client access, or could be run across all clients at specified times.  It will allow the MSP to comply with security frameworks that require regular password rotation.

### Requirements
There must be a flexible asset type that stores the Active Directory domain name, and its ID must be hard-coded into the script in the Find-MyOrganization function.  For our IT Glue tenant, that ID is 25110.

### Submitter
- David Hirsch, 11 June 2019
