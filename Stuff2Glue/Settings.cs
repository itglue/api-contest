
using Stuff2Glue;
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Xml.Serialization;
using ObjectsComparer;

[Serializable]
public class Settings
{
    public List<Fortigate> fortigates = new List<Fortigate>();
    public List<Switch> switches = new List<Switch>();


  

    

    public bool AddConfigFile(string config)
    {
        string name = "";
        bool failed = false;
        bool backedUp = false;
       // try
       // {
            string[] configSplit = config.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
        if (HelperFunctions.DetermineType(config) == ConfigTypes.Fortigate)
        {

            Console.WriteLine("This config is a Fortigate config file");
            Fortigate newFortigate = new Fortigate(configSplit, config);

            bool found = false;
            name = newFortigate.hostname;

            for (int i = fortigates.Count - 1; i >= 0; i--)
            {
                //TODO: improve this selection to include updated fortigates

                Fortigate currentFG = fortigates[i];
                if (fortigates[i].hostname == newFortigate.hostname)
                {
                    Console.WriteLine("Getting differences");
                    var comparer = new ObjectsComparer.Comparer<Fortigate>();
                    IEnumerable<Difference> differences;
                    var isEqual = comparer.Compare(newFortigate, currentFG, out differences);
                    //Print results
                    Console.WriteLine(isEqual ? "Objects are equal" : string.Join(Environment.NewLine, differences));
                    if (isEqual)
                    {
                        Console.WriteLine("Found exact match, skipping");
                        found = true;
                    }
                    else
                    {

                        Console.WriteLine("Found updated Fortigate, removing old");
                        fortigates.RemoveAt(i);

                    }


                }
            }
            if (!found)
            {
                newFortigate.updated = true;
                
                Console.WriteLine("Adding fortigate");
                fortigates.Add(newFortigate);
            }
            

        }
        else if ((HelperFunctions.DetermineType(config) == ConfigTypes.Switch29xx) || (HelperFunctions.DetermineType(config) == ConfigTypes.Switch19xx) || (HelperFunctions.DetermineType(config) == ConfigTypes.Switch1920S) || (HelperFunctions.DetermineType(config) == ConfigTypes.CiscoSG200)  )
        {
            Console.WriteLine("This config is a Switch config file");
            Switch newSwitch = new Switch(configSplit, config, HelperFunctions.DetermineType(config));

            bool found = false;
            name = newSwitch.HostName;
            //MemoryStream streamNew = HelperFunctions.GetStreamFromFortigate(newSwitch);

            for (int i = switches.Count - 1; i >= 0; i--)
            {
                //TODO: improve this selection to include updated fortigates


                if (switches[i].HostName == newSwitch.HostName)
                {

                    Console.WriteLine("Getting differences");
                    var comparer = new ObjectsComparer.Comparer<Switch>();
                    IEnumerable<Difference> differences;
                    var isEqual = comparer.Compare(newSwitch, switches[i], out differences);
                    //Print results
                    Console.WriteLine(isEqual ? "Objects are equal" : string.Join(Environment.NewLine, differences));

                    if (isEqual)
                    {
                        Console.WriteLine("Found exact match, skipping");

                        found = true;
                    }
                    else
                    {
                        Console.WriteLine("Found updated switch, removing old");
                        switches.RemoveAt(i);
                    }


                }
            }
            if (!found)
            {
                Console.WriteLine("Adding switch");
                newSwitch.updated = true;
                
                switches.Add(newSwitch);
            }

        }
       
        else if (HelperFunctions.DetermineType(config) == ConfigTypes.unknown)

        {
            failed = true;
        }
   


       

        return !failed;
    }


    



    public Settings()
	{



	}
}
