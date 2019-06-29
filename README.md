# api-contest

The SAMPLE CSV files are an example of what fields the each script expects, see the script comment-based help for further details on what specific headers it's expecting.

N.B. Automated workflows to generate the above using Azure Automation is already in place, but is unfortunately beyond the scope of IT Glue-related projects.

General pre-requisites are:
- IT Glue PowerShell Wrapper is already installed
- IT Glue API Key has already been created
- IT Glue organisations that you want to sync to Office 365 tenant information to, have their Azure AD Tenant ID already listed within 
the IT Glue Organisation DESCRIPTION field in the format of: AADTenantID:<Azure AD Tenant ID>, for example for the contoso.com tenant:
AADTenantID:6babcaad-604b-40ac-a9d7-9fd97c0b779f

