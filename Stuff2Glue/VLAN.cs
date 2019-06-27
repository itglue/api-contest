using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.Text;
using System.Xml.Serialization;

public class StackInterface
{
    public int stackMember;
    public string switchInterface;

    public StackInterface()
    {

    }
    public StackInterface(int stack, string interfaceid) {
        this.stackMember = stack;
        this.switchInterface = interfaceid;
    }
  
}

public class VLAN
{

    public int ID;
    //[XmlIgnore]

    public SerializableDictionary<(int stackMember, string switchInterface), char> interfaces = new SerializableDictionary<(int, string), char>();
    public string VlanName;
    public List<IP> IPs = new List<IP>();
    public int stackSize = 0;
    public int switchSize = 0;
    public bool defaultVlan = false;
    public bool failed = false;
    public string comment;
    public int mtu = 1500;
    public VLAN() {


    }
    public VLAN(int ID, int stackSize, bool defaultVlan, string Name)
    {
        if (defaultVlan)
        {
            this.defaultVlan = true;
            
        }
        increaseStackSize(stackSize, 1);
        this.ID = ID;
        this.VlanName = Name;
    }

    public VLAN(int stackSize, bool defaultVlan)
    {
        if (defaultVlan)
        {
            this.defaultVlan = true;
            increaseStackSize(stackSize,1);
        }

    }


    public VLAN(string[] configsplit,int stacksize, Dictionary<string, List<(int stackMember, int switchInterface)>> trunks)
    {
        //Lets look for the vlan id
        if (configsplit[0].Split(" ")[1] == "1")
        {
            this.defaultVlan = true;
            increaseStackSize(stacksize, 1);
        }

        if (HelperFunctions.FindIndexOf(configsplit, "jumbo", 0) != -1)
        {
            this.mtu = 9000;
        }

        if (int.TryParse(configsplit[0].Split(" ")[1], out ID))
        {
            Console.WriteLine("VLAN ID Found: " + ID);
            //we found the id, so we can continue

            //look for the name
            if (HelperFunctions.FindIndexOf(configsplit, "name", 0) != -1)
            {
                VlanName = configsplit[HelperFunctions.FindIndexOf(configsplit, "name", 0)].Split("\"")[1];
                Console.WriteLine("Name of the VLAN is: " + VlanName);
            }

            int t = 0;

            //look for IPs
            while (HelperFunctions.FindIndexOf(configsplit, "ip", t, new string[] { "no","dhcp", "gateway" }) != -1)
            {
                int old = t;
                t = HelperFunctions.FindIndexOf(configsplit, "ip", old, new string[] { "no","dhcp","gateway"});
                string ip = configsplit[t].Split(" ")[5] + " " + configsplit[t].Split(" ")[6];
                Console.WriteLine("Found IP: " + ip);
                IPs.Add(new IP(ip));
                t++;
                
            }



            //look for untagged ports
            if (HelperFunctions.FindIndexOf(configsplit, "untagged", 0, new string[] { "no" }) != -1)
            {

                string[] untaggedPorts = configsplit[HelperFunctions.FindIndexOf(configsplit, "untagged", 0, new string[] { "no" })].Split(" ");
                Console.WriteLine("Untagged list: " + untaggedPorts[untaggedPorts.Length-1]);
                string untaggedPortsValues = untaggedPorts[untaggedPorts.Length - 1];
                List<StackInterface> StackInterfacesList =  HelperFunctions.GetStackInterfaces(untaggedPortsValues, trunks);
                foreach (StackInterface tempInterface in StackInterfacesList)
                {
                    //TODO: handle interfaces A1, A2 etc
                    if ((tempInterface.stackMember != 0) && (tempInterface.switchInterface != "0")) 
                    {
                        Console.WriteLine("Adding untagged interface: " + tempInterface.stackMember + "/" + tempInterface.switchInterface);
                        if (!interfaces.ContainsKey((tempInterface.stackMember, tempInterface.switchInterface.ToString())))
                        {
                            interfaces.Add((tempInterface.stackMember, tempInterface.switchInterface.ToString()), 'U');
                        }
                        
                       /* if (int.Parse(tempInterface.switchInterface) > switchSize)
                        {
                            switchSize = int.Parse(tempInterface.switchInterface);
                        }*/
                    }

                    
                }

            }
            else
            {
                Console.WriteLine("No untagged found");
            }

            //look for tagged ports
            if (HelperFunctions.FindIndexOf(configsplit, "tagged", 0, new string[] { "no","untagged" }) != -1)
            {

                string[] taggedPorts = configsplit[HelperFunctions.FindIndexOf(configsplit, "tagged", 0, new string[] { "no","untagged" })].Split(" ");
                Console.WriteLine("tagged list: " + taggedPorts[taggedPorts.Length - 1]);
                string taggedPortsValues = taggedPorts[taggedPorts.Length - 1];
                List<StackInterface> StackInterfacesList = HelperFunctions.GetStackInterfaces(taggedPortsValues, trunks);
                foreach (StackInterface tempInterface in StackInterfacesList)
                {
                    //TODO: handle interfaces A1, A2 etc
                    if ((tempInterface.stackMember != 0) && (tempInterface.switchInterface != "0"))
                    {
                        Console.WriteLine("Adding Tagged interface: " + tempInterface.stackMember + "/" + tempInterface.switchInterface);
                        if (!interfaces.ContainsKey((tempInterface.stackMember, tempInterface.switchInterface.ToString())))
                        {
                            interfaces.Add((tempInterface.stackMember, tempInterface.switchInterface.ToString()), 'T');
                        }
                        
                        
                       /* if (int.Parse(tempInterface.switchInterface) > switchSize)
                        {
                            switchSize = int.Parse(tempInterface.switchInterface);
                        }*/
                    }


                }

            }
            else
            {
                Console.WriteLine("No untagged found");
            }



        }
        else
        {
            Console.WriteLine("Something went wrong, cannot find vlan id");
            failed = true;


        }

    }






    public void increaseSwitchSize(int stackMember, int switchSize)
    {

        if (defaultVlan)
        {
            int oldLenght = this.switchSize;
            this.switchSize = switchSize;
            for (int t = 0; t < switchSize; t++)
            {
                if (!interfaces.ContainsKey((stackMember, t.ToString()))) {
                    interfaces.Add((stackMember, t.ToString()), 'U');

                }
            }

                
        }

        
    }

    public void increaseStackSize(int stackSize, int switchSize)
    {
        if (defaultVlan)
        {
            int oldSize = this.stackSize;
            this.stackSize = stackSize;
            for (int t = 0; t < stackSize; t++)
            {
                increaseSwitchSize(t, switchSize);
            }
        }
            
        
        
    }


    public void SetVLANInterface(int stackMember, int switchInterface,char value) {
        increaseStackSize(stackMember, switchInterface);
        if (interfaces.ContainsKey((stackMember, switchInterface.ToString())))
        {
            interfaces.Remove((stackMember, switchInterface.ToString()));
        }
        interfaces.Add((stackMember, switchInterface.ToString()), value);
        }


    public char GetVLANInterface(int stackMember, int switchInterface)
    {
        char value = 'E';
        if (interfaces.TryGetValue((stackMember, switchInterface.ToString()), out value))
        {
            return value;
        }  else
        {
            return 'E';
        }
    }

    public void test()
    {
        // interfaces.Add(Tuple.Create(1, 1), 'U');
        interfaces.Add((1, "1"), 'U');
        
        Console.WriteLine("Tuple test: " + interfaces[(1, "1")]) ;
    }




    }

