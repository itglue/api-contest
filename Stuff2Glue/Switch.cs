using Stuff2Glue;
using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.Text;
using System.Xml.Serialization;

public enum SwitchTypes
{
    HP1910,HP1920,HP1920S,HP1950,HP2910,HP2920,HP2930,HP2530,SSHImport
}



   public class Switch
    {
        public string HostName;
        public SwitchTypes Type;
        public bool isStack;
        public int stackSize = 0;
        public int commander;
        public bool spanningTree = false;
        public bool GVRP = false;
        public bool L3enabled = false;
        public SerializableDictionary<string, List<(int stackMember, int switchInterface)>> trunks = new SerializableDictionary<string, List<(int stackMember, int switchInterface)>>();


        public SerializableDictionary<int, VLAN> vlans = new SerializableDictionary<int,VLAN>();
        public string Manufacturer = "HP";
        public bool updated = false;
        public static readonly string GlueConfigurationTypeID = "131054";
         public static int configTypeID = 131054;
    public SerializableDictionary<(int stackMember, int switchInterface), string> comments = new SerializableDictionary<(int, int), string>();
    public SerializableDictionary<(int stackMember, string switchInterface), string> flowcontrol = new SerializableDictionary<(int, string), string>();
    public SerializableDictionary<(int stackMember, string switchInterface), string> lacp = new SerializableDictionary<(int, string), string>();
    public string GlueConfigurationID;
    public string configFileLocation;

    public string IP
    {
        get
        {
            return PrimaryIP();
        }
    }

    public Switch()
        {
        }

    public Switch((string,string) info)
    {
        this.HostName = info.Item1;
        VLAN temp = new VLAN();
        temp.IPs.Add(new IP(info.Item2));
        vlans.Add(1,temp);
        this.Type = SwitchTypes.SSHImport;
    }


    public Switch (string[]configsplit,string config, ConfigTypes configType) {
        Console.WriteLine("Starting new switch of type: " + configType);
        //lets do the 29xx type switches first
        if (configType == ConfigTypes.Switch29xx)
        {
            Manufacturer = "HP";
            //check for hostname
            if (HelperFunctions.FindIndexOf(configsplit, "hostname", 0) != -1)
            {
                HostName = configsplit[HelperFunctions.FindIndexOf(configsplit, "hostname", 0)].Split(" ")[1];

                if (HostName.Contains("\""))
                {
                    HostName = HostName.Split("\"")[1];
                }


                Console.WriteLine("Found a new switch with hostname: " + HostName);
            }
            //determine type of switch
            if ((HelperFunctions.FindIndexOf(configsplit, "J9773A", 0) != -1) || (HelperFunctions.FindIndexOf(configsplit, "J9727A", 0) != -1) || (HelperFunctions.FindIndexOf(configsplit, "j9727a", 0) != -1) || (HelperFunctions.FindIndexOf(configsplit, "J9726A", 0) != -1))
            {
                Type = SwitchTypes.HP2920;

            }
            if ((HelperFunctions.FindIndexOf(configsplit, "J9415a", 0) != -1) || (HelperFunctions.FindIndexOf(configsplit, "j9145A", 0) != -1))
            {
                Type = SwitchTypes.HP2910;
            }
            if ((HelperFunctions.FindIndexOf(configsplit, "J9772A", 0) != -1) || (HelperFunctions.FindIndexOf(configsplit, "j9772A", 0) != -1) || (HelperFunctions.FindIndexOf(configsplit, "J9773A", 0) != -1) || (HelperFunctions.FindIndexOf(configsplit, "j9773A", 0) != -1))
            {
                Type = SwitchTypes.HP2530;
            }


            //Determine of it's a stack
            if (HelperFunctions.FindIndexOf(configsplit, "stacking", 0) != -1)
            {
                isStack = true;
                //if it's a stack we want to know what size 
                commander = 1;
                int start = HelperFunctions.FindIndexOf(configsplit, "stacking", 0);
                int end = HelperFunctions.FindIndexOf(configsplit, "exit", start);
                int members = 1;
                int.TryParse(configsplit[end - 1].Split(" ")[4], out members);
                Console.WriteLine("Stack with " + members + " members");
                this.stackSize = members;
            }
            else
            {
                this.isStack = false;
                this.stackSize = 1;
            }

            //check for spanning tree
            if (HelperFunctions.FindIndexOf(configsplit, "spanning-tree", 0) != -1)
            {
                spanningTree = true;
            }

            //check for gvrp
            if (HelperFunctions.FindIndexOf(configsplit, "gvrp", 0) != -1)
            {
                GVRP = true;
            }
            //check for Layer3
            if (HelperFunctions.FindIndexOf(configsplit, "ip-routing", 0) != -1)
            {
                L3enabled = true;
            }



            //we need to find the trunk lines
            //TODO: Update for stacked switches
            int t = 0;
            if (HelperFunctions.FindIndexOf(configsplit, "trunk", 0) != -1)
            {
                while (HelperFunctions.FindIndexOf(configsplit, "trunk", t) != -1)
                {
                    t = HelperFunctions.FindIndexOf(configsplit, "trunk", t);
                    List<(int stackMember, int switchInterface)> portnumbers = new List<(int stackMember, int switchInterface)>();
                    string ports = configsplit[t].Split(" ")[1];


                    List<StackInterface> portNumbers = HelperFunctions.GetStackInterfaces(ports,trunks);

                    foreach (StackInterface portnumber in portNumbers)
                    {
                        int temp = 0;
                        if (int.TryParse(portnumber.switchInterface, out temp))
                        {
                            portnumbers.Add((portnumber.stackMember, temp));
                        }
                          
                    }

                    if (portnumbers.Count > 0)
                    {
                        string trunkname = configsplit[t].Split(" ")[2];
                        if (trunks.ContainsKey(trunkname))
                        {
                            trunks.Remove(trunkname);
                        }
                        trunks.Add(trunkname, portnumbers);
                    }

                    t++;
                }
            }


            //find flow control
            t = 0;
            while (HelperFunctions.FindIndexOf(configsplit, "interface", t) != -1)
            {
                t = HelperFunctions.FindIndexOf(configsplit, "interface", t);

                int end = HelperFunctions.FindIndexOf(configsplit, "exit", t);

                int flow = HelperFunctions.FindIndexOf(configsplit, "flow-control", t);
                if ((flow > t) && (flow < end))
                {
                    StackInterface stackint = HelperFunctions.GetStackInterface(configsplit[t].Split(" ")[1], trunks);
                    this.flowcontrol.Add((stackint.stackMember,stackint.switchInterface), "X");
                }
                int lacp = HelperFunctions.FindIndexOf(configsplit, "flow-control", t);
                if ((lacp> t) && (lacp < end))
                {
                    StackInterface stackint = HelperFunctions.GetStackInterface(configsplit[t].Split(" ")[1], trunks);
                    this.lacp.Add((stackint.stackMember, stackint.switchInterface), "passive");
                }
                t = end;

            }

                t = 0;
            while (HelperFunctions.FindIndexOf(configsplit, "vlan", t) != -1)
            {
                int vlanlocation = HelperFunctions.FindIndexOf(configsplit, "vlan", t);
                if (HelperFunctions.FindIndexOf(configsplit, "exit", vlanlocation) != -1)
                {
                    int exitlocation = HelperFunctions.FindIndexOf(configsplit, "exit", vlanlocation);
                    string[] vlanConfig = new List<String>(configsplit).GetRange(vlanlocation, exitlocation - vlanlocation).ToArray();


                    VLAN newVlan = new VLAN(vlanConfig, this.stackSize,trunks);
                    if (!newVlan.failed)
                    {
                        if (vlans.ContainsKey(newVlan.ID))
                        {
                            vlans.Remove(newVlan.ID);
                        }
                        vlans.Add(newVlan.ID, newVlan);
                    }
                    t = exitlocation;

                }



            }

            //now we need the lldp information

            if ((HelperFunctions.FindIndexOf(configsplit, "LLDP Remote Devices Information", 0) != -1))
            {
                if (HelperFunctions.FindIndexOf(configsplit, "LocalPort", (HelperFunctions.FindIndexOf(configsplit, "LLDP Remote Devices Information", 0))) != -1)
                {
                    int start = HelperFunctions.FindIndexOf(configsplit, "LocalPort", (HelperFunctions.FindIndexOf(configsplit, "LLDP Remote Devices Information", 0))) + 2;
                    int end = start;
                    bool found = false;
                    while ((end < configsplit.Length) && !found)
                    {
                        if ((configsplit[end] == "") || (configsplit[end] == " "))
                        {
                            found = true;
                        }
                        else
                        {
                            end++;
                        }

                        
                    }


                    for (int y = start; y < end; y++)
                    {
                        try
                        {
                            string[] linesplit = configsplit[y].Split(new[] { ' ', '|' });
                            linesplit = HelperFunctions.CleanUpStrings(linesplit);
                            int localPort = -1;
                            int localStack = -1;
                            if (linesplit[0].Contains("/"))
                            {
                                string[] stacksplit = linesplit[0].Split("/");
                                int.TryParse(stacksplit[0], out localStack);
                                int.TryParse(stacksplit[1], out localPort);
                            }
                            else
                            {
                                int.TryParse(linesplit[0], out localPort);
                                localStack = 1;
                            }
                            string on = "";
                            if (linesplit[linesplit.Length - 2] == linesplit[linesplit.Length - 3])
                            {
                                on = linesplit[linesplit.Length - 2];
                            }
                            else
                            {
                                on = linesplit[linesplit.Length - 2] + " " + linesplit[linesplit.Length - 3];
                            }
                            this.comments.Add((localStack, localPort), linesplit[linesplit.Length - 1] + " on " + on);

                        }
                        catch
                        {
                            Console.WriteLine("Failed parsing lldp data");
                        }
                        

                       
                    }

                    

                }
            }


        } //else if ()
        else if (configType == ConfigTypes.Switch19xx)
        {
            Console.WriteLine("Parsing 19xx switch");

            //start by looking for stack
            if (HelperFunctions.FindIndexOf(configsplit, "irf member", 0) != -1)
            {
                this.isStack = true;
                int x = HelperFunctions.FindLastIndexOf(configsplit, "irf member", configsplit.Length - 1);
                int members = -1;
                if (int.TryParse(configsplit[x].Split(" ")[3], out members))
                {
                    Console.WriteLine("Found " + members + " stack members");
                    stackSize = members;
                }
                else if (int.TryParse(configsplit[x].Split(" ")[2], out members))
                {
                    Console.WriteLine("Found " + members + " stack members");
                    stackSize = members;
                }
                else
                {
                    Console.WriteLine("No stack members found");
                    stackSize = 1;
                }

                this.Type = SwitchTypes.HP1950;

            }
            else
            {
                Console.WriteLine("No stack found");
                this.isStack = false;
                stackSize = 1;
            }

            //next lets find the hostname
            if (HelperFunctions.FindIndexOf(configsplit, "sysname", 0) != -1)
            {
                string currentline = configsplit[HelperFunctions.FindIndexOf(configsplit, "sysname", 0)];
                string[] currentlinesplit = currentline.Split("sysname");


                this.HostName = currentlinesplit[currentlinesplit.Length - 1].Replace(" ", string.Empty);//.Split(" ")[2];

                Console.WriteLine("Hostname: " + this.HostName);
            }

            //discover the vlans
            int t = 0;
            while (HelperFunctions.FindIndexOf(configsplit, "vlan", t, new string[] { "port", "hybrid", "trunk", "access","voice" }) != -1)
            {
                t = HelperFunctions.FindIndexOf(configsplit, "vlan", t, new string[] { "port", "hybrid", "trunk", "access", "voice" });

                int vlanid = 0;

                if (configsplit[t].Contains("to"))
                {
                    int vlanidstop = 0;
                    if (int.TryParse(configsplit[t].Split(" ")[1], out vlanid) && int.TryParse(configsplit[t].Split(" ")[3], out vlanidstop))
                    {
                        Console.WriteLine("Start is : " + vlanid);

                        Console.WriteLine("Stop is: " + vlanidstop);

                        for (int tt = vlanid; tt <= vlanidstop; tt++)
                        {
                            VLAN vlan = new VLAN(tt, this.stackSize, false, "");
                            if (vlanid == 1)
                            {
                                vlan.defaultVlan = true;
                            }

                            vlans.Add(tt, vlan);
                        }

                    }



                }
                else
                {
                    if (int.TryParse(configsplit[t].Split(" ")[1], out vlanid))
                    {


                        VLAN vlan = new VLAN(vlanid, this.stackSize, false, configsplit[t + 1].Split(" ")[configsplit[t + 1].Split(" ").Length - 1]);
                        if (vlan.VlanName == "")
                        {
                            string[] nextline = configsplit[t + 1].Split(" ");
                            if (nextline.Length > 1)
                            {
                                vlan.VlanName = nextline[1];
                            }
                        }
                        if (vlanid == 1)
                        {
                            vlan.defaultVlan = true;
                            if (vlan.VlanName == "#")
                            {
                                vlan.VlanName = "Default";
                            }
                        }




                        vlans.Add(vlanid, vlan);
                    }
                }



                t++;
            }

            //check we have vlan 1
            if (!vlans.ContainsKey(1))
            {
                VLAN defaultVlan = new VLAN(1, 1, true, "Default");
                vlans.Add(1, defaultVlan);
            }

            t = 0;
            //handle interfaces
            while (HelperFunctions.FindIndexOf(configsplit, "interface", t, new string[] { "NULL", "ntp", "snmp" }) != -1)
            {
                t = HelperFunctions.FindIndexOf(configsplit, "interface", t, new string[] { "NULL", "ntp", "snmp" });
                string currentline = configsplit[t];
                if (currentline.Contains("Vlan-interface"))
                {
                    //vlan interfaces
                    int vlanid = 0;
                    if (int.TryParse(currentline.Split("Vlan-interface")[1], out vlanid))
                    {

                        string nextline = configsplit[t + 1];
                        if (nextline.Contains("ipv6"))
                        {
                            nextline = configsplit[t + 2];

                        }
                        if (nextline.Contains("ip address"))
                        {
                            string[] temp = nextline.Split("ip address")[1].Remove(0, 1).Split(" ");
                            string ip = temp[0] + " " + temp[1];

                            vlans[vlanid].IPs.Add(new IP(ip));
                        }
                        

                    }

                }
                else
                {
                    //normal interfaces
                    int endInterface = HelperFunctions.FindIndexOf(configsplit, "#", t);
                    string[] currentsplit = currentline.Split("/");
                    int interfaceid = 0;
                    if (int.TryParse(currentsplit[currentsplit.Length - 1], out interfaceid))
                    {
                        int stackid = 1;
                        if (this.isStack)
                        {
                            //we only need to find the stackid if it's actually a stack, otherwise we can just use 1
                            if (int.TryParse(currentsplit[currentsplit.Length - 3][currentsplit[currentsplit.Length - 3].Length - 1].ToString(), out stackid))
                            {

                            }
                        }

                        //we now have interface & stack id
                        //now we need to figure out all vlans and the single untagged vlan
                        //fortunately, any number in the rest of the interface config is a vlan id, so that gives us the complete list
                        //then figure out the untagged trough the pvid and we're golden
                        List<int> vlanids = new List<int>();
                        for (int i = t + 1; i < endInterface; i++)
                        {
                            string[] line = configsplit[i].Split(" ");
                            int tempid = 0;
                            for (int j = 0; j < line.Length; j++)
                            {
                                if (int.TryParse(line[j], out tempid))
                                {
                                    vlanids.Add(tempid);

                                }
                                else if (line[j] == "to")
                                {
                                    int start = 0;
                                    int end = 0;
                                    if ((int.TryParse(line[j - 1], out start) && (int.TryParse(line[j + 1], out end))))
                                    {
                                        for (int k = start; k <= end; k++)
                                        {
                                            vlanids.Add(k);
                                        }
                                    }

                                }
                            }

                        }
                        int pvid = 1;
                        //we now have a list with all vlans this interface belongs to
                        if (HelperFunctions.FindIndexOf(configsplit, "pvid vlan", t) != -1)
                        {
                            int line = HelperFunctions.FindIndexOf(configsplit, "pvid vlan", t);
                            if (line <= endInterface)
                            {
                                string pvidline = configsplit[line];
                                if (int.TryParse(pvidline.Split("pvid vlan")[1].Split(" ")[1], out pvid))
                                {

                                }
                            }
                        }

                        if (vlanids.Count == 0)
                        {
                            Console.WriteLine("No VLAN found for interface, defaulting");
                            vlanids.Add(1);
                        }

                        foreach (int vlanid in vlanids)
                        {
                            if (vlans.ContainsKey(vlanid))
                            {
                                vlans[vlanid].increaseStackSize(stackid, interfaceid);
                            }

                            if (vlanid == pvid)
                            {
                                VLAN vlan;
                                if (vlans.TryGetValue(vlanid, out vlan))
                                {
                                    vlans[vlanid].SetVLANInterface(stackid, interfaceid, 'U');

                                }
                            }
                            else
                            {

                                VLAN vlan;
                                if (vlans.TryGetValue(vlanid, out vlan))
                                {
                                    vlans[vlanid].SetVLANInterface(stackid, interfaceid, 'T');
                                    Console.WriteLine("Adding stackid: " + stackid + " interfaceid: " + interfaceid + " vlanid: " + vlanid);
                                }
                            }
                        }
                        int flow = HelperFunctions.FindIndexOf(configsplit, "flow-control", t);

                        if ((flow > t) && (flow < endInterface) && (flow != -1))
                        {
                            this.flowcontrol.Add((stackid,interfaceid.ToString()), "X");
                        }
                    }

                    




                        t = endInterface;

                    

                }
                t++;
            }

            //look for spanning tree

            if ((HostName == null) || (HostName == "HP") || (HostName == " HP"))
            {
                string ip;
                if (vlans[1].IPs[0] != null)
                {
                    HostName = vlans[1].IPs[0].ip;
                }

            }



            //lets look for LLDP information

            if (HelperFunctions.FindIndexOf(configsplit, "display lldp neighbor-information list", 0) != -1)
            {
                int start = HelperFunctions.FindIndexOf(configsplit, "display lldp neighbor-information list", 0);
                if (HelperFunctions.FindIndexOf(configsplit, "System Name", start) != -1)
                {
                    start = HelperFunctions.FindIndexOf(configsplit, "System Name", start) + 1;
                    int end = HelperFunctions.FindIndexOf(configsplit, "<", start);
                    for (int y = start; y < end; y++)
                    {
                        string line = configsplit[y];
                        string[] linesplit = HelperFunctions.CleanUpStrings(line.Split(" "));
                        string[] interfacesplit = linesplit[1].Split("/");
                        int switchid = -1;
                        int interfaceid = -1;
                        if (interfacesplit.Length > 2)
                        {
                            if (int.TryParse(interfacesplit[0].Substring(interfacesplit[0].Length - 1, 1), out switchid) && (int.TryParse(interfacesplit[2], out interfaceid)) && (linesplit[0] != "-"))
                            {
                                if (this.comments.ContainsKey((switchid, interfaceid)))
                                {
                                    this.comments.Remove((switchid,interfaceid));
                                }

                                string extra = "";

                                if (linesplit[3].Contains("/"))
                                {
                                    string[] extrasplit = linesplit[3].Split("/");
                                    extra += " on " + extrasplit[0].Substring(extrasplit[0].Length - 1, 1) + "/" + extrasplit[2];
                                }

                                Console.WriteLine("Adding comment for " + switchid + "/" + interfaceid + " : " + linesplit[0] + " " + extra);
                                this.comments.Add((switchid, interfaceid), linesplit[0] + extra);
                            }

                            Console.WriteLine("split: " + linesplit[1]);
                        }
                        
                    }
                }
            }






            //end 19xx





        }
        else if (configType == ConfigTypes.Switch1920S)
        {
            this.isStack = false;
            this.stackSize = 1;

            Console.WriteLine("Parsing a 1920s switch");
            if (HelperFunctions.FindIndexOf(configsplit, "JL385A", 0) != -1)
            {
                Type = SwitchTypes.HP1920S;
            }

            



            if (HelperFunctions.FindIndexOf(configsplit, "vlan name ", 0) != -1)
            {
                Console.WriteLine("parsing vlans");
                int t = HelperFunctions.FindIndexOf(configsplit, "vlan name ", 0);
                //int last = HelperFunctions.FindLastIndexOf(configsplit, "vlan name ", configsplit.Length);
                VLAN defaultVlan = new VLAN(1, 1, true, "Default");
                vlans.Add(1, defaultVlan);
                //Console.WriteLine("Begin: " + begin + "end: " + last + " splitlenght: " + configsplit.Length);
                while (configsplit[t].Contains("vlan name "))
                {
                    string[] currentline = configsplit[t].Split(" ");
                    string name = currentline[3];
                    int id = -1;
                    int.TryParse(currentline[2], out id);
                    name = name.Split("\"")[1];
                    Console.WriteLine("Found vlan: " + id + " name: " + name);
                    VLAN currentVlan = new VLAN(id, 1, false, name);
                    vlans.Add(id, currentVlan);
                    t++;
                }

            }
            else
            {
                Console.WriteLine("can't parse vlans");
                VLAN defaultVlan = new VLAN(1, 1, true, "Default");
                vlans.Add(1, defaultVlan);
            }
            if (HelperFunctions.FindIndexOf(configsplit, "interface ", 0, new string[] { "TRK" }) != -1)
            {
                int t = 0;
                while (HelperFunctions.FindIndexOf(configsplit, "interface ", t, new string[] { "TRK" }) != -1)
                {
                    int start = HelperFunctions.FindIndexOf(configsplit, "interface ", t, new string[] { "TRK" });
                    int end = HelperFunctions.FindIndexOf(configsplit, "exit", start);

                    int interfaceID = 0;
                    string[] line = configsplit[start].Split(" ");
                    if (int.TryParse(line[1], out interfaceID))
                    {
                        int vidid = 1;
                        if ((HelperFunctions.FindIndexOf(configsplit, "pvid", start) != -1) && (HelperFunctions.FindIndexOf(configsplit, "pvid", start) < end))
                        {
                            string[] currentine = configsplit[HelperFunctions.FindIndexOf(configsplit, "pvid", start)].Split(" ");
                            int.TryParse(currentine[2], out vidid);
                        }
                        Console.WriteLine("Adding vlan untagged, vlan id: " + vidid + "interface: " + interfaceID);
                        vlans[vidid].SetVLANInterface(1, interfaceID, 'U');

                        if ((HelperFunctions.FindIndexOf(configsplit, "tagging", start) != -1) && (HelperFunctions.FindIndexOf(configsplit, "tagging", start) < end))
                        {
                            string[] taggedLine = configsplit[HelperFunctions.FindIndexOf(configsplit, "tagging", start)].Split(" ");
                            string[] tagged = taggedLine[2].Split(",");
                            foreach (string tag in tagged)
                            {
                                int id = 0;
                                if (int.TryParse(tag, out id))
                                {
                                    Console.WriteLine("Adding vlan tagged, vlan id: " + id + "interface: " + interfaceID);
                                    vlans[id].SetVLANInterface(1, interfaceID, 'T');
                                }

                            }
                        }



                    }

                    if (start > t)
                    {
                        t = start;
                    }
                    else
                    {
                        t++;
                    }

                }

            }

            if (HelperFunctions.FindIndexOf(configsplit, "network parms", 0) != -1)
            {
                string[] currentline = configsplit[HelperFunctions.FindIndexOf(configsplit, "network parms", 0)].Split(" ");
                vlans[1].IPs.Add(new IP(currentline[2] + " " + currentline[3]));
                this.HostName = currentline[2];
            }

            if (HelperFunctions.FindIndexOf(configsplit, "snmp-server sysname ", 0) != -1)
            {
                int nameloc = HelperFunctions.FindIndexOf(configsplit, "snmp-server sysname ", 0);
                string[] namesplit = configsplit[nameloc].Split("\"");
                this.HostName = namesplit[1];
            }
        }
        else if (configType == ConfigTypes.CiscoSG200)
        {
            Console.WriteLine("Parsing cisco SG200");
            this.isStack = false;
            this.stackSize = 1;
            if (HelperFunctions.FindIndexOf(configsplit, "vlan database", 0) != -1)
            {
                Console.WriteLine("Parsing vlans");
               // VLAN defaultVLAN = new VLAN(1, 1, true, "Default");
              //  vlans.Add(1, defaultVLAN);
                string[] vlaninfo = configsplit[HelperFunctions.FindIndexOf(configsplit, "vlan database", 0)+1].Split(" ")[1].Split(",");
                List<string> vlanlist = new List<string>(vlaninfo);
                vlanlist.Insert(0,"1");

                List<string> vlanlist2 = new List<string>(vlanlist);

                foreach (string vlannumber in vlanlist2)
                {
                      if (vlannumber.Contains("-"))
                    {
                        string[] vlannumbers = vlannumber.Split("-");
                        int start = 0, end = 0;
                        if (int.TryParse(vlannumbers[0], out start) && int.TryParse(vlannumbers[1], out end))
                        {
                            for (int t = start; t <= end; t++)
                            {
                                vlanlist.Add(t.ToString());

                            }
                            vlanlist.Remove(vlannumber);
                        }
                        
                    }
                }


                    foreach (string vlannumber in vlanlist)
                {
                    Console.WriteLine("Found vlan: " + vlannumber);
                    int vlanid = 0;
                    if (int.TryParse(vlannumber, out vlanid))
                    {
                        string vlanname = "Unnamed vlan";
                        string vlanip = "0.0.0.0";
                        if (HelperFunctions.FindIndexOf(configsplit, "interface vlan " + vlanid,0) != -1)
                        {
                            int start = HelperFunctions.FindIndexOf(configsplit, "interface vlan " + vlanid, 0);
                            int end = HelperFunctions.FindIndexOf(configsplit, "!", start);
                            if ((HelperFunctions.FindIndexOf(configsplit, "name", start) != -1) && (HelperFunctions.FindIndexOf(configsplit, "name", start) < end))
                            {
                                if (configsplit[HelperFunctions.FindIndexOf(configsplit, "name", start)].Contains("\""))
                                {
                                    vlanname = configsplit[HelperFunctions.FindIndexOf(configsplit, "name", start)].Split("\"")[1];
                                }
                                else
                                {
                                    vlanname = configsplit[HelperFunctions.FindIndexOf(configsplit, "name", start)].Split(" ")[2];

                                }
                                
                            }
                            if ((HelperFunctions.FindIndexOf(configsplit, "ip address", start) != -1) && (HelperFunctions.FindIndexOf(configsplit, "ip address", start) < end))
                            {
                                vlanip = configsplit[HelperFunctions.FindIndexOf(configsplit, "ip address", start)].Split(" ")[3];
                            }

                        }
                        Console.WriteLine("Adding vlan: " + vlanid + " name: " + vlanname + " ip: " + vlanip);
                        VLAN current = new VLAN(vlanid, 1, false, vlanname);
                        current.IPs.Add(new IP(vlanip));
                        if (!vlans.ContainsKey(vlanid))
                        {
                            vlans.Add(vlanid, current);
                        }
                        

                    }
                }

                vlans[1].defaultVlan = true;  
            }

            int currentintline = 0;
            int highestint = 0;
            while (HelperFunctions.FindIndexOf(configsplit, "gigabitethernet", currentintline) != -1)
            {
                currentintline = HelperFunctions.FindIndexOf(configsplit, "gigabitethernet", currentintline);

                int currentint = -1;

                string tempint = configsplit[currentintline].Split("ethernet")[1];
                int.TryParse(tempint, out currentint);

                if (currentint > highestint) {
                    highestint = currentint;

                }
                int end = HelperFunctions.FindIndexOf(configsplit, "!", currentintline);
                
                int currentvlanline = currentintline;
                while ((HelperFunctions.FindIndexOf(configsplit, "vlan", currentvlanline) != -1) && (HelperFunctions.FindIndexOf(configsplit, "vlan", currentvlanline) < end))
                {
                    currentvlanline = HelperFunctions.FindIndexOf(configsplit, "vlan", currentvlanline);
                    if (configsplit[currentvlanline].Contains("trunk")) {
                        string[] linesplit = configsplit[currentvlanline].Split(' ',',');
                        foreach (string split in linesplit)
                        {
                           // Console.WriteLine("Searching for vlan id in: " + split);
                            int splitid = 0;
                            if (int.TryParse(split, out splitid))
                            {
                                this.vlans[splitid].SetVLANInterface(1, currentint, 'T');
                            }
                        }
                    }
                    currentvlanline++;
                }

                currentintline++;
                }
            this.vlans[1].increaseStackSize(1, highestint);
            for (int t = 0; t <= highestint; t++)
            {
                if (this.vlans[1].interfaces.ContainsKey((1, t.ToString())))
                {
                    Console.WriteLine("Found");
                }
                else
                {
                    this.vlans[1].SetVLANInterface(1, t, 'U');
                }
            }
            this.HostName = configsplit[1];
            

        }

    }


    public string GetOutputHTML()
    {
        String output = string.Empty;

        output += "<style type=\"text/css\">";
        output += ".rotate {";

        /* Safari */
        output += "-webkit-transform: rotate(-90deg);";

        /* Firefox */
        output += "-moz-transform: rotate(-90deg);";

        /* IE */
        output += "-ms-transform: rotate(-90deg);";

        /* Opera */
        output += "-o-transform: rotate(-90deg);";

        output += "float: left;";

        output += "}";

        output += "</style>";

        VLANColour kleurtjes = new VLANColour();
        Console.WriteLine("Writing switch " + this.HostName);
        output += "<div class=\"text-section scrollable\"><table style=\"border-color: black; width: 100%; \" border=\"2\">\n"; ;
        output += "<caption><h1>" + this.HostName;
        output += "</h1></caption>\n";
        int switchSize = 0;
        bool addmtu = false;
        List<String> FoundInterface = new List<string>();
        int highest = 0;
        foreach (VLAN vlan in vlans.Values)
        {
            if (vlan.mtu != 1500)
            {
                addmtu = true;
            }
            foreach ((int stackMember, string switchInterface) values in vlan.interfaces.Keys)
            {
                if (!FoundInterface.Contains(values.switchInterface))
                {
                    FoundInterface.Add(values.switchInterface);
                    int testhighest = -1;
                    if (int.TryParse(values.switchInterface, out testhighest))
                    {
                        if (testhighest > highest)
                        {
                            highest = testhighest;
                        }
                    }
                }
            }
        }

        
        switchSize = 0;
        foreach (string interfacenumber in FoundInterface)
        {
            int interfacenumberint = 0;
            if (int.TryParse(interfacenumber,out interfacenumberint))
            {
                if (interfacenumberint > switchSize)
                {
                    switchSize = interfacenumberint;
                }

            }
        }


        FoundInterface.Sort();

        Dictionary<string, string> InterfaceTranslation = new Dictionary<string, string>();
        for (int t = 0; t <= highest; t++)
        {
            InterfaceTranslation.Add(t.ToString(), t.ToString());

        }
        for (int t = highest + 1; t <= FoundInterface.Count - 1; t++)
        {
            InterfaceTranslation.Add(t.ToString(), FoundInterface[t]);
        }
        Console.WriteLine("Translation matrix initialised");

        


        for (int stackmember = 1; stackmember <= stackSize; stackmember++)
        {
            //int rowwidth = 150 / switchSize;
            //create titles
            if (this.isStack)
            {
                output += "<thead><tr><td align=\"center\" colspan="+(switchSize+3)+"> <b>Stackmember: "+stackmember+ (stackmember==1?" Commander":"")+ "</b></thead></tr>";
            }
            output += "<thead style=\"white-space:nowrap; \"><tr><td align=\"center\" width=60 ><b>VLAN</b></td><td align=\"center\"width=30><b>ID</b></td>" + (addmtu? "<td><b><center>MTU</center></b></td>":"") +"<td align=\"center\"width=60><b>IP</b></td>\n";
            for (int t = 1; t <= switchSize; t++)
            {
                if (InterfaceTranslation.ContainsKey(t.ToString()))
                {
                    output += "<td align=\"center\" width=30><b>" + InterfaceTranslation[t.ToString()] + "</b></td>";
                }
                else
                {
                    output += "<td align=\"center\" width=30><b></b></td>";
                }
                
            }

            if (this.comments.Count>0)
            {
                output += "</tr><tr><td>Connected to: </td><td></td><td></td>" + (addmtu ? "<td></td>" : "") ;
                for (int t = 1; t <= switchSize; t++)
                {
                    if (this.comments.ContainsKey((stackmember, t)))
                    {
                        output += "<td align=\"center\"><b style=\"writing-mode: vertical-lr; white-space: nowrap;\"> " + this.comments[(stackmember, t)] + " </b></td>";
                    }
                    else
                    {
                        output += "<td></td>";
                    }

                }

            }

            


            //output for trunk lines
            Dictionary<(int stackMember, int switchInterface), string> trunkInterfaces = new Dictionary<(int stackMember, int switchInterface), string>();

            foreach(KeyValuePair<string,List<(int stackMember, int switchInterface)>> entry in trunks) {
                foreach ((int stackMember, int switchInterface) stackint in entry.Value)
                {
                    trunkInterfaces.Add(stackint, entry.Key);
                }
            }

            if (trunkInterfaces.Count > 0)
            {
                output += "</tr><tr><td>Link aggregation:</td><td></td><td></td>"+(addmtu ? "<td></td>" : "");
                for (int t = 1; t <= switchSize; t++)
                {

                    if (trunkInterfaces.ContainsKey((stackmember, t)))
                    {
                        output += "<td align=\"center\"><b style=\"writing-mode: vertical-lr; white-space: nowrap;\"> " + trunkInterfaces[(stackmember, t)] + " </b></td>";
                    }
                    else
                    {
                        output += "<td></td>";
                    }

                }
            }

            if (lacp.Count > 0)
            {
                output += "</tr><tr><td>LACP:</td><td></td><td></td>" + (addmtu ? "<td></td>" : "");
                for (int t = 1; t <= switchSize; t++)
                {
                    if (InterfaceTranslation.ContainsKey(t.ToString()))
                    {
                        string temp = InterfaceTranslation[t.ToString()];
                        if (lacp.ContainsKey((stackmember, temp)))
                        {
                            output += "<td align=\"center\"><b  style=\"writing-mode: vertical-lr; white-space: nowrap;\"> " + lacp[(stackmember, InterfaceTranslation[t.ToString()])] + " </b></td>";
                        }
                        else
                        {
                            output += "<td></td>";
                        }
                    } else
                    {
                        output += "<td></td>";
                    }

                    

                }
            }


            if (flowcontrol.Count > 0)
            {
                output += "</tr><tr><td>Flow Control:</td><td></td><td></td>" + (addmtu ? "<td></td>" : "");
                for (int t = 1; t <= switchSize; t++)
                {
                    if (InterfaceTranslation.ContainsKey(t.ToString()))
                    {
                        string temp = InterfaceTranslation[t.ToString()];
                        if (flowcontrol.ContainsKey((stackmember, temp)))
                        {
                            output += "<td align=\"center\"><b> X </b></td>";
                        }
                        else
                        {
                            output += "<td></td>";
                        }
                    }
                    else
                    {
                        output += "<td></td>";
                    }


                        

                }
            }

            foreach (VLAN vlan in vlans.Values)
            {
                String back = kleurtjes.GetColour(vlan.ID, false);
                String fore = kleurtjes.GetColour(vlan.ID, true);
                output += "</thead></tr><tr style=\"background-color: " + back + ";\"><td align=\"center\"><font color=\"" + fore + "\">" + vlan.VlanName + "</font></td>\n<td align=\"center\">" + vlan.ID + "</td>\n";
                if (addmtu)
                {
                    string value = "";
                    if (vlan.mtu == 1500)
                    {

                    }
                    else if (vlan.mtu == 9000)
                    {
                        value = "Jumbo";
                    }

                    else
                    {
                        value = vlan.mtu.ToString();
                    }
                    output += "<td><center>" + value + "</center></td>";
                }
                bool addbr = false;
                output += "<td align=\"center\">";
                foreach (IP myip in vlan.IPs)
                {
                    String ip = myip.ip;
                    if (addbr)
                    {
                        addbr = false;
                        output += "<br>";

                    }
                    output += ip;
                    addbr = true;
                }
                output += "</td>\n";
                for (int t = 1; t <= switchSize; t++)
                {
                    char value = ' ';

                    if (InterfaceTranslation.ContainsKey(t.ToString()))
                    {
                        if (vlan.interfaces.TryGetValue((stackmember, InterfaceTranslation[t.ToString()]), out value))
                        {
                            output += "<td align=\"center\">" + value + "</td>";
                        }
                        else
                        {
                            output += "<td></td>";
                        }
                    }
                    else
                    {
                        output += "<td></td>";
                    }


                        

                }
            }
        }





        output += "</table></div>";


        return output;
    }


    public List<ConfigurationInterface> GetInterfaces()
    {
        //TODO: add physical interfaces
        List<ConfigurationInterface> Interfaces = new List<ConfigurationInterface>();

        foreach (VLAN currentVlan in vlans.Values)
        {

            if (currentVlan.IPs.Count > 0)
            {

                foreach (IP myip in currentVlan.IPs)
                {
                    string ip = myip.ip;
                    ConfigurationInterface currentInterface = new ConfigurationInterface();
                    currentInterface.name = "VLAN " + currentVlan.ID + " " + currentVlan.VlanName;
                    if (ip != "")
                    {
                        currentInterface.ip = ip;
                    }
                    else
                    {
                        currentInterface.ip = "0.0.0.0";
                    }
                    
                    Interfaces.Add(currentInterface);
                }
            }
            else
            {
                ConfigurationInterface currentInterface = new ConfigurationInterface();
                currentInterface.name = "VLAN " + currentVlan.ID + " " + currentVlan.VlanName;
                currentInterface.ip = "0.0.0.0";
                Interfaces.Add(currentInterface);
            }
            

            
        }

        foreach (KeyValuePair<(int,int), string> entry in this.comments)
        {
            ConfigurationInterface currentInterface = new ConfigurationInterface();
            currentInterface.comment = entry.Value;
            currentInterface.name = entry.Key.Item1 + "/" + entry.Key.Item2;
            currentInterface.ip = "0.0.0.0";
            Interfaces.Add(currentInterface);
        }

            return Interfaces;
    }



    public List<string> GetIPs()
    {
        List<string> IPs = new List<String>();

        foreach (VLAN currentVLAN in vlans.Values)
        {
            foreach (IP myip in currentVLAN.IPs)
            {
                string ip = myip.ip;
                if ((ip != "") && (ip != "0.0.0.0"))
                {
                    IPs.Add(ip);
                }
               
            }
        }


        return IPs;
    }


    public string PrimaryIP()
    {
        List<string> IPs = this.GetIPs();
        if (IPs.Count <= 0)
        {
            return "0.0.0.0";
        }
        else {
            return IPs[0];
        }

    }

}

