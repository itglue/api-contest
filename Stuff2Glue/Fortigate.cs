using Stuff2Glue;
using System;
using System.Collections.Generic;


[Serializable]
public class Fortigate
{
    [Serializable]
    public class Interface
{   
        public string Name;
        public string IP;
        public string subnetMask;
        public string vlanID;
        public string glueID;
        public bool sshEnabled;
        public bool telnetEnabled;

        public Interface()
        {

        }
        public Interface(string name,string ip, string subnetMask, string vlan, bool ssh, bool telnet)
        {
            this.Name = name;
            this.IP = ip;
            this.subnetMask = subnetMask;
            this.vlanID = vlan;
            this.sshEnabled = ssh;
            this.telnetEnabled = telnet;
        }
}
    public string hostname;
    public string serial;
    public List<Interface> interfaces;
    public string manufacturer;
    public string model;
    public string version;
    public string glueID;
    public string sshPort;
    public static readonly string GlueConfigurationTypeID = "124979";
    public bool updated = false;
    public string GlueConfigurationID;
    public static int configTypeID = 124979;
    public string expires = "";
  public string configFileLocation;
   

    public Fortigate()
    {

    }

    public Fortigate((string,string)info)
    {


        this.hostname = info.Item1;
        Fortigate.Interface inter = new Fortigate.Interface();
        inter.IP = info.Item2;
        this.interfaces = new List<Interface>();
        inter.sshEnabled = true;
        this.interfaces.Add(inter);
    }


    public Fortigate(string[] configSplit, string config)
	{
        interfaces = new List<Interface>();


        //first we try and find the interfaces
        int location = Array.IndexOf(configSplit, "config system interface");
        int location2 = Array.IndexOf(configSplit, "end",location);
        string[] InterfacesConfig = new List<String>(configSplit).GetRange(location,location2-location).ToArray() ;


       for (int i = 0; i < InterfacesConfig.Length; i++)
        {
            Console.WriteLine(InterfacesConfig[i].ToString());
        }
        int index = 1;
        while (HelperFunctions.FindIndexOf(InterfacesConfig,"next",index) != -1 )
        {
            location = index;
            location2 = HelperFunctions.FindIndexOf(InterfacesConfig, "next", index);
            string[] InterfaceConfig = new List<String>(InterfacesConfig).GetRange(location, location2 - location).ToArray();

            if (HelperFunctions.FindIndexOf(InterfaceConfig, "set ip", 0) != -1)
            {
                Console.WriteLine("Found interface: " + InterfaceConfig[0]);
                string Name = InterfaceConfig[0].Split("\"")[1];
                string IP = InterfaceConfig[HelperFunctions.FindIndexOf(InterfaceConfig, "set ip", 0)].Split(" ")[10];
                string subnetMask = InterfaceConfig[HelperFunctions.FindIndexOf(InterfaceConfig, "set ip", 0)].Split(" ")[11];
                //set vlanid 
               string vlan = string.Empty;
                if (HelperFunctions.FindIndexOf(InterfaceConfig, "set vlanid ", 0) != -1)
                {
                    
                    vlan = InterfaceConfig[HelperFunctions.FindIndexOf(InterfaceConfig, "set vlanid ", 0)].Split(" ")[10];
                }
                
                if (HelperFunctions.FindIndexOf(InterfaceConfig, "set alias ", 0) != -1)
                {

                    string alias = InterfaceConfig[HelperFunctions.FindIndexOf(InterfaceConfig, "set alias ", 0)].Split("\"")[1];
                    Name = Name + "(" + alias + ")";
                }
                bool ssh = false;
                bool telnet = false;
                if(HelperFunctions.FindIndexOf(InterfaceConfig, "ssh", 0) != -1)
                {
                    ssh = true;
                }
                if (HelperFunctions.FindIndexOf(InterfaceConfig, "telnet", 0) != -1)
                {
                    telnet = true;
                }
                Console.WriteLine("New Interface found Name: " + Name + " IP:" + IP + " SubnetMask: " + subnetMask + " Vlan: " + vlan + " SSH: " + ssh);
                //alias toevoegen name(alias)

                interfaces.Add(new Interface(Name, IP, subnetMask, vlan, ssh, telnet));
            }

            
            index = location2 +1 ;
        }

        //ending processing of interfaces

        //lets set the rest of the required fortigate settings:
        //hostname

        if (HelperFunctions.FindIndexOf(configSplit, "set hostname ", 0) != -1)
        {

            this.hostname = configSplit[HelperFunctions.FindIndexOf(configSplit, "set hostname ", 0)].Split("\"")[1];

            if ((this.hostname[this.hostname.Length - 1] == 'A') || (this.hostname[this.hostname.Length - 1] == 'B'))
            {
                this.hostname = this.hostname.Remove(this.hostname.Length - 1);
            }


        }
        //serial number
        if (HelperFunctions.FindIndexOf(configSplit, "set alias ", 0) != -1)
        {

            this.serial = configSplit[HelperFunctions.FindIndexOf(configSplit, "set alias ", 0)].Split("\"")[1];

        }
        //manufacturer
        this.manufacturer = "Fortinet";
        //type  config-version
        if (HelperFunctions.FindIndexOf(configSplit, "config-version", 0) != -1)
        {

            this.model = configSplit[HelperFunctions.FindIndexOf(configSplit, "config-version", 0)].Split("=")[1].Split("-")[0];
            string firmversion = configSplit[HelperFunctions.FindIndexOf(configSplit, "config-version", 0)].Split("-")[2];
            string build = configSplit[HelperFunctions.FindIndexOf(configSplit, "config-version", 0)].Split("build")[1].Split("-")[0];
            this.version = firmversion + " build:" + build;
        }

        //serial number
        if (HelperFunctions.FindIndexOf(configSplit, "set admin-ssh-port ", 0) != -1)
        {

            this.sshPort = configSplit[HelperFunctions.FindIndexOf(configSplit, "set admin-ssh-port ", 0)].Split("port ")[1];

        }
        else
        {
            this.sshPort = "22";
        }
        

        Console.WriteLine("Other settings: Hostname: " + this.hostname + " serial: " + this.serial + " firmware: " + this.version + " Manufacturer: " + this.manufacturer + " Model: " + this.model + " SSH Port: " + this.sshPort);
        //end rest fortigate settings


    }


    public List<ConfigurationInterface> GetInterfaces()
    {
        //TODO: add physical interfaces
        List<ConfigurationInterface> Interfaces = new List<ConfigurationInterface>();

        foreach (Interface currentInt in this.interfaces)
        {
            ConfigurationInterface currentInterface = new ConfigurationInterface();
            currentInterface.name = currentInt.Name;
            currentInterface.ip = currentInt.IP;
            
            Interfaces.Add(currentInterface);
        }

        return Interfaces;
    }


}
