1. Install the PowerShell wrapper for ITGlue's API on each Hyper-V server to sync. https://github.com/itglue/powershellwrapper
2. Run `ITGlue-VMHost-CreateFlexibleAsset.ps1` once to create the flexible asset needed and add it to the side bar ("_VM Host_").
3. Create a new _VM Host_ asset for each server you want to sync. Take note of individual IDs.  
3a. subdomain.itglue.com/1234568/assets/records/**1153985665234565**  
3b. You only need to give it a name and tag a related a configuration in IT Glue when creating the assets.

From here on, there are multiple options on how to specify the script's paramaters *(i.e. in the file, as paramaters when calling, via module settings)* but these instructions will store API settings via the wrapper module and asset ID in the scheduled task.

4. Note down the subdomain of your IT Glue URL:  
4a. happyfrog.itglue.com translate to `happyfrog`.  
4b. froghappy.eu.itglue.com translates to `froghappy`.
5. Place `ITGlue-VMHost-Setup.ps1` and `ITGlue-VMHost-FeedFlexibleAssetHyperV.ps1` in a folder to house these script for the duration of their lives *(i.e. somewhere they will not be moved from)*.
  
**IMPORTANT: Do the next step as the user who will be running the script on the server**  
  
6. Run `ITGlue-VMHost-Setup.ps1`. The script will ask for IT Glue API key, data center (EU/US) (if not saved already) and **flexible_asset_id**. It will save API key and data center via the module and create a new task in TaskScheduler under \ITGlueSync\ scheduled to run daily at the time when the setup was run.
