using Stuff2Glue;
using System;
using System.Collections.Generic;
using System.Text;



    public class Configuration
    {
    public string mode;
    public string GlueOrganisationID;
         public string SettingsFile;
        public Configuration(string organisationID, string SettingsFile)
        {
            this.GlueOrganisationID = organisationID;
        this.SettingsFile = SettingsFile;
        }
    public string PickupFolder;
    public string password;
    public string AlternativePath;
    public string ZipLocation;
    public bool nodelete = false;
    public bool noglue = false;
    public bool debug = false;
    public bool html = false;
    

    public Configuration(string orgid)
    {
        mode = "NORMAL";
        this.GlueOrganisationID = orgid;
        nodelete = true;
        noglue = true;
        debug = true;
        html = false;
    }



    public Configuration(string[] args)
    {

        try
        {
            this.mode = args[0];


            if (HelperFunctions.FindIndexOf(args, "-OrgID", 0) != -1)
            {
                this.GlueOrganisationID = args[HelperFunctions.FindIndexOf(args, "-OrgID", 0) + 1];
            }
            if (HelperFunctions.FindIndexOf(args, "-PathToSettings", 0) != -1)
            {
                this.SettingsFile = args[HelperFunctions.FindIndexOf(args, "-PathToSettings", 0) + 1];


                
            }

            if (HelperFunctions.FindIndexOf(args, "-PathToPickup", 0) != -1)
            {
                this.PickupFolder = args[HelperFunctions.FindIndexOf(args, "-PathToPickup", 0) + 1];
            }
            if (HelperFunctions.FindIndexOf(args, "-Password", 0) != -1)
            {
               
                


                this.password = args[HelperFunctions.FindIndexOf(args, "-Password", 0) + 1];


            }
            if (HelperFunctions.FindIndexOf(args, "-OrgId", 0) != -1)
            {
                this.GlueOrganisationID = args[HelperFunctions.FindIndexOf(args, "-OrgId", 0) + 1];
            }
            if (HelperFunctions.FindIndexOf(args, "-AlternativePath", 0) != -1)
            {
                this.AlternativePath = args[HelperFunctions.FindIndexOf(args, "-AlternativePath", 0) + 1];
                this.ZipLocation = this.AlternativePath + "\\ConfigurationBackup.zip";
            }
            if (HelperFunctions.FindIndexOf(args, "-NoDelete", 0) != -1)
            {
                this.nodelete = true;
            }
            if (HelperFunctions.FindIndexOf(args, "-NoGlue", 0) != -1)
            {
                this.noglue = true;
            }
            if (HelperFunctions.FindIndexOf(args, "-Debug", 0) != -1)
            {
                this.debug = true;
            }
            if (HelperFunctions.FindIndexOf(args, "-WriteHTML", 0) != -1)
            {
                this.html = true;
            }
           
        }
        catch (Exception e)
        {
            Console.WriteLine("Error while reading parameters");
            Console.WriteLine(e);
        }
       
            
    }


    }
