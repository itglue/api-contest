using System;
using System.Collections.Generic;
using System.Text;
using System.Linq;
using System.Net;

public class IP : IComparable
    {
        UInt32 myip;
        UInt32 maskbits = 24;
    public IP()
    {

    }

    private static IPAddress GetNetworkAddress(IPAddress address, IPAddress subnetMask)
    {
        byte[] ipAdressBytes = address.GetAddressBytes();
        byte[] subnetMaskBytes = subnetMask.GetAddressBytes();

        if (ipAdressBytes.Length != subnetMaskBytes.Length)
            throw new ArgumentException("Lengths of IP address and subnet mask do not match.");

        byte[] broadcastAddress = new byte[ipAdressBytes.Length];
        for (int i = 0; i < broadcastAddress.Length; i++)
        {
            broadcastAddress[i] = (byte)(ipAdressBytes[i] & (subnetMaskBytes[i]));
        }
        return new IPAddress(broadcastAddress);
    }


    public int CompareTo(object obj)
    {
        if (obj == null) return 1;
        if (obj.GetType() == typeof(IP))
        {
            IP other = (IP)obj;
            return this.myip.CompareTo(other.myip);
        }
        else
        {
            return 1;
        }
        
        

    }

        public string IPRangeCIDR
    {
        get
        {
            uint mask = ~(0xffffffff >> (int)maskbits);
            UInt32 range = (myip & mask);
            string temp = String.Format("{0}.{1}.{2}.{3}", range >> 24, (range >> 16) & 0xff, (range >> 8) & 0xff, range & 0xff);

            return temp + "/" +maskbits;
        }
    }
    

        public IP (string value){

        if (!value.Contains(" ") && !value.Contains("/"))
        {
            Console.WriteLine("Subnet mask not found, assuming /24");
            string[] parts = value.Split('.', '/');
            myip = (Convert.ToUInt32(parts[0]) << 24) |
            (Convert.ToUInt32(parts[1]) << 16) |
            (Convert.ToUInt32(parts[2]) << 8) |
            Convert.ToUInt32(parts[3]);
        }
        else
        {
            if (value.Contains(" "))
            {
                string[] split = value.Split(" ");
                string[] parts = split[0].Split('.', '/');
                myip = (Convert.ToUInt32(parts[0]) << 24) |
                (Convert.ToUInt32(parts[1]) << 16) |
                (Convert.ToUInt32(parts[2]) << 8) |
                Convert.ToUInt32(parts[3]);
                string[] bytestring = split[1].Split(".");
                byte[] bytes = new byte[4];
                for (int t = 0; t < 4; t++)
                {
                    bytes[t] = byte.Parse(bytestring[t]);
                }
                maskbits = MaskToCIDR(bytes);
            }
            else
            {
                string[] parts = value.Split('.', '/');
                myip = (Convert.ToUInt32(parts[0]) << 24) |
                (Convert.ToUInt32(parts[1]) << 16) |
                (Convert.ToUInt32(parts[2]) << 8) |
                Convert.ToUInt32(parts[3]);
                maskbits = Convert.ToUInt32(parts[4]);
            }
        }


       

            
        }

    static uint MaskToCIDR(byte[] bytes)
    {

        return (uint)Convert.ToString(BitConverter.ToInt32(bytes, 0), 2)
         .ToCharArray()
         .Count(x => x == '1');
    }


    public string CIDR
        {
            set {
            
                string[] parts = value.Split('.', '/');
                myip = (Convert.ToUInt32(parts[0]) << 24) |
                (Convert.ToUInt32(parts[1]) << 16) |
                (Convert.ToUInt32(parts[2]) << 8) |
                Convert.ToUInt32(parts[3]);
                maskbits = Convert.ToUInt32(parts[4]);

            }

            get {
                string temp = String.Format("{0}.{1}.{2}.{3}", myip >> 24, (myip >> 16) & 0xff, (myip >> 8) & 0xff, myip & 0xff);
            if ((temp == "99.99.99.99/99") || (temp == "99.99.99.99"))
            {
                return "";
            } else
            {
                temp += "/" + maskbits;
                return temp;
            }
            
            }



        }

    public string ip
    {
        get
        {
            string temp = String.Format("{0}.{1}.{2}.{3}", myip >> 24, (myip >> 16) & 0xff, (myip >> 8) & 0xff, myip & 0xff);
            if ((temp == "99.99.99.99/99") || (temp == "99.99.99.99"))
            {
                return "";
            }
            else
            {
                return temp;
            }
        }
    }
    

    public string mask
        {
            get
            {
                return maskbits.ToString();
            }
        }

        
        

    }

   class Network
    {
        public List<String> names = new List<string>();
        public int vlanID = -1;
        public List<IP> IPs = new List<IP>();
        public bool actionReq = false;
        public List<object> ConnectedTo = new List<object>();

    public String[] ConnectedFirewalls
    {
        get
        {
            List<String> items = new List<String>();
            foreach (object obj in ConnectedTo)
            {
                if (obj.GetType() == typeof(Fortigate))
                {
                    Fortigate fw = (Fortigate)obj;
                    if ((fw.GlueConfigurationID != null) && (fw.GlueConfigurationID != ""))
                    {
                        items.Add(fw.GlueConfigurationID);
                    }
                }
            }

            return items.ToArray();
        }
    }

    public String[] ConnectedSwitches
    {
        get
        {
            List<String> items = new List<String>();
            foreach (object obj in ConnectedTo)
            {
                if (obj.GetType() == typeof(Switch))
                {
                    Switch sw = (Switch)obj;
                    if ((sw.GlueConfigurationID != null) && (sw.GlueConfigurationID != ""))
                    {
                        items.Add(sw.GlueConfigurationID);
                    }
                }
            }

            return items.ToArray();
        }
    }


    public static List<Network> networks(List<Fortigate> fortigates, List<Switch> Switches)
        {
       
            List<Network> myNetworks = new List<Network>();
            Dictionary<int,Network> tempNetworks = new Dictionary<int, Network>();
            foreach (Switch currentSwitch in Switches) {
                foreach (VLAN vlan in currentSwitch.vlans.Values)
                {
                    if (tempNetworks.ContainsKey(vlan.ID))
                    {
                    tempNetworks[vlan.ID].Add(vlan,currentSwitch);
                    }
                    else
                    {
                       tempNetworks.Add(vlan.ID,new Network(vlan,currentSwitch));
                    }
                }
            }
        myNetworks = tempNetworks.Values.ToList<Network>();
        Dictionary<string, int> stringNetworks = new Dictionary<string, int>();
        for (int t = 0; t < myNetworks.Count; t++)
        {
            foreach (string name in myNetworks[t].names)
            {
                if (!stringNetworks.ContainsKey(name))
                {
                    stringNetworks.Add(name, t);
                }
                
            }
        }

        foreach (Fortigate currentGate in fortigates)
        {
            foreach (Fortigate.Interface currentInterface in currentGate.interfaces)
            {
                if (stringNetworks.ContainsKey(currentInterface.Name))
                {
                    myNetworks[stringNetworks[currentInterface.Name]].Add(currentInterface, currentGate);
                }
                else
                {
                    int temp = myNetworks.Count;
                    myNetworks.Add(new Network(currentInterface, currentGate));
                    stringNetworks.Add(currentInterface.Name, temp);
                }
            }
        }

        foreach (Network network in myNetworks)
        {
            network.names.Sort();
            network.IPs.Sort();
        }

            return myNetworks;
        }



    public Network(Fortigate.Interface currentInterface, object connected)
    {
        this.vlanID = -1;
        Add(currentInterface, connected);
    }

    public void Add(Fortigate.Interface currentInterface, object connected) {

        string name = currentInterface.Name;
        if (name == "")
        {
            name = "Empty";
        }
        if (!names.Contains(name))
        {
            names.Add(name);
            if (names.Count > 1)
            {
                actionReq = true;

            }
        }

        IP ip = new IP(currentInterface.IP + " " + currentInterface.subnetMask);

        if (!this.IPs.Contains(ip))
        {
            this.IPs.Add(ip);
        }

        this.ConnectedTo.Add(connected);
    }


    public void Add(VLAN vlan, object connected)
    {
        if ((this.vlanID == -1) || (this.vlanID == vlan.ID) || (vlan.ID == -1))
        {
            this.vlanID = vlan.ID;
            string name = vlan.VlanName;
            if (name == "")
            {
                name = "Empty";
            }

            if (!names.Contains(name))
            {
                names.Add(name);
                if (names.Count > 1)
                {
                    actionReq = true;

                }
                
            }

            foreach (IP ip in vlan.IPs)
            {
                if (!this.IPs.Contains(ip))
                {
                    this.IPs.Add(ip);
                }
                
            }
        }
        else
        {
            Console.WriteLine("Error occured reading networks, adding vlan to existing network with wrong vlan ID");
        }
        this.ConnectedTo.Add(connected);
    }



    public Network(VLAN vlan, object connected)
    {
        Add(vlan, connected);

    }



        public Network(string name,int vlanID, List<IP> IPs)
        {
            if (name == "")
            {
                this.names.Add("Empty");
            }
            else
            {
                this.names.Add(name);
            }
            
            this.vlanID = vlanID;
            foreach (IP ip in IPs)
            {
                this.IPs.Add(new IP(ip.CIDR)); 
            } 
        }

    public string IPstring
    {
        get
        {
            if (IPs.Count == 0)
            {
                return "";
            }
            string result = "";

            List<string> UniqueIPs = new List<string>();

            foreach (IP ip in IPs)
            {
                if (!UniqueIPs.Contains(ip.IPRangeCIDR))
                {
                    UniqueIPs.Add(ip.IPRangeCIDR);
                }
            }

            foreach (string ipstring in UniqueIPs)
            {
                result += ipstring + " ";
            }

            if (result == "96.0.0.0/99 ")
            {
                result = "";
            }


            return result;
        }
    }
    }


