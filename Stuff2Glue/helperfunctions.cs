using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

using System.Collections.ObjectModel;
using System.Xml.Serialization;
using System.Collections.Generic;
using Renci.SshNet;
using Renci.SshNet.Common;
using System.Text.RegularExpressions;
using System.IO.Compression;

public enum ConfigTypes{
    Fortigate,Switch1910,Switch1920,Switch1920S,Switch2920,unknown,Switch29xx,Switch1950,Switch19xx,CiscoSG200
}

public static class HelperFunctions
{

   

    public static bool CheckPickupFolder(Configuration configuration)
    {
        bool failed = false;

        try
        {
            if (!Directory.Exists(configuration.PickupFolder))
            {
                Directory.CreateDirectory(configuration.PickupFolder);
                if (!Directory.Exists(configuration.PickupFolder))
                {
                    failed = true;
                }
            }
        }
        catch
        {
            failed = true;
        }
        

        return !failed;
    }




    public static bool WriteHTML(string script, string templocation, string name)
    {
        bool failed = false;
        try
        {
            
                File.WriteAllText(templocation + "\\" + name + ".html", script);
                //File.WriteAllText("C:\\Netwerkadministratie\\Alternative\\test.ps1", script);
            
        }
        catch (Exception e)
        {
            Console.WriteLine("Attempting to write : " + name);
            Console.WriteLine("Exception: " + e.ToString());
            failed = true;
        }

        return !failed;
    }



    public static ConfigTypes DetermineType(string config)
    {
        if (config.Contains("config system global") && config.Contains("config firewall policy"))
        {
            return ConfigTypes.Fortigate;
        }
        else if (config.Contains("Configuration Editor"))
        {
            return ConfigTypes.Switch29xx;
        }
        else if (config.Contains("sysname") && (!config.Contains("snmp-server sysname")))
        {
            return ConfigTypes.Switch19xx;
        }
        else if (config.Contains("!Current Configuration:"))
        {
            return ConfigTypes.Switch1920S;
        }
        else if (config.Contains("config-file-header"))
        {
            return ConfigTypes.CiscoSG200;
        }
        else
        {
            return ConfigTypes.unknown;
        }

        
    }


    public static String GetFileConfig(string filepath)
    {
        string text = System.IO.File.ReadAllText(filepath);

        return text;
    }

    public static int FindIndexOf(string[] array, string value ,int searchFrom)
    {
        try
        {
            for (int i = searchFrom; i < array.Length; i++)
            {
                if (array[i].Contains(value))
                {
                    return i;
                }
            }
            return -1;
        }
        catch
        {
            Console.WriteLine("Error in finding index");
            return -1;
        }

        

    }


    public static int FindIndexOf(string[] array, string value, int searchFrom, string[] exclude)
    {
        try
        {
            for (int i = searchFrom; i < array.Length; i++)
            {
                if (array[i].Contains(value))
                {
                    bool found = false;
                    foreach (string check in exclude)
                    {
                        if (array[i].Contains(check))
                        {
                            found = true;
                        }
                    }
                    if (!found)
                    {
                        return i;
                    }
                    
                }
            }
            return -1;
        }
        catch
        {
            Console.WriteLine("Error in finding index");
            return -1;
        }



    }



    public static int FindLastIndexOf(string[] array, string value, int searchFrom)
    {
        try
        {
            for (int i = searchFrom; i >= 0; i--)
            {
                if (array[i].Contains(value))
                {
                    return i;
                }
            }
            return -1;
        }
        catch
        {
            Console.WriteLine("Error in finding index");
            return -1;
        }



    }
 

    public static StackInterface GetStackInterface(string Source, Dictionary<string, List<(int stackMember, int switchInterface)>> trunks)
    {   //figures out the stack and the interface in a string for example: 1/1   or just 1, if no stack it returns it as 1
        StackInterface result = new StackInterface();
        if (Source.Contains("/"))
        {
            //it's a stacked interface
            string[] sourceSplit = Source.Split("/");
            int stackInterface = 0;
            if (int.TryParse(sourceSplit[0], out stackInterface))
            {
                result.stackMember = stackInterface;
            } else
            {
                result.stackMember = 0;
            }
            result.switchInterface = sourceSplit[1];
           


        }
        else
        {
            //it's not a stacked interface
           
            result.stackMember = 1;
            result.switchInterface = Source;
           
        }


        return result;
    }


    public static List<StackInterface> GetStackInterfaces(String interfaceSource, Dictionary<string, List<(int stackMember, int switchInterface)>> trunks)
    { //in this function we get all the interfaces out of a list as for example:  1/1,1/8,1/11-1/19,1/22-1/24,1/A1-1/A2,1/B1-1/B2,2/8,2/11-2/19,2/22-2/24,2/A1-2/A2,2/B1-2/B2,3/8,3/11-3/19,3/22-3/24,3/A1-3/A2,3/B1-3/B2,4/8,4/11-4/19,4/22-4/24,4/A1-4/A2,4/B1-4/B2
        List<StackInterface> interfaceList = new List<StackInterface>();
        String[] sourceSplit = interfaceSource.Split(",");

        foreach (string source in sourceSplit)
        {

            if ((source.Contains("Trk")) || (source.Contains("trk")))
            {
                List<String> trunkstoadd = new List<string>();
                if (source.Contains("-"))
                {
                    //multiple trunks
                    string[] sourcesplit = source.Split("-");
                    
                    int start = -1;
                    int end = -1;

                    if ((int.TryParse(sourcesplit[0][sourcesplit[0].Length - 1] + string.Empty, out start)) && (int.TryParse(sourcesplit[1][sourcesplit[1].Length - 1] + string.Empty, out end)))
                    {
                        for (int y = start; y <= end; y++)
                        {
                            trunkstoadd.Add("trk" + y);
                        }

                    }
                    
                    
                }
                else
                {
                    //single trunk
                    trunkstoadd.Add(source.ToLower());
                }
                foreach (string trunktoadd in trunkstoadd)
                {
                    if (trunks.ContainsKey(trunktoadd))
                    {
                        foreach((int stackMember, int switchInterface) interfacetoadd in trunks[trunktoadd])
                        {
                            interfaceList.Add(new StackInterface(interfacetoadd.stackMember, interfacetoadd.switchInterface.ToString()));
                        }
                    }
                }


                } else
            {
                //we need to know ift's a single or a range
                if (source.Contains("-"))
                {
                    //TODO: update for other type of names & prevent bug when none int interface name
                    //it's a range
                    string[] rangeSplit = source.Split("-");
                    StackInterface start = GetStackInterface(rangeSplit[0], trunks);
                    StackInterface end = GetStackInterface(rangeSplit[1], trunks);

                    int startint = 0;
                    int endint = 0;


                    if ((int.TryParse(start.switchInterface, out startint)) && (int.TryParse(end.switchInterface, out endint)))
                    {
                        for (int i = startint; i <= endint; i++)
                        {
                            StackInterface tempInterface = new StackInterface();
                            tempInterface.stackMember = start.stackMember;
                            tempInterface.switchInterface = i.ToString();
                            interfaceList.Add(tempInterface);
                        }
                    }
                    else
                    {
                        if ((int.TryParse(start.switchInterface[start.switchInterface.Length-1].ToString(), out startint)) && (int.TryParse(end.switchInterface[end.switchInterface.Length - 1].ToString(), out endint)))
                        {
                            for (int i = startint; i <= endint; i++)
                            {
                                StackInterface tempInterface = new StackInterface();
                                tempInterface.stackMember = start.stackMember;
                                tempInterface.switchInterface = start.switchInterface[0]+ i.ToString();
                                interfaceList.Add(tempInterface);
                            }
                        }
                    }

                   

                }
                else
                {
                    //it's a single
                    StackInterface tempInterface = GetStackInterface(source, trunks);
                    interfaceList.Add(tempInterface);

                }
            }


            
        }






        return interfaceList;
    }


    public static string[] CleanUpStrings(string[] input)
    {
        List<String> split = new List<String>(input);

        for (int t = split.Count - 1; t >= 0; t--)
        {
            if ((split[t] == "") || (split[t] == "---- More ----"))
            {
                split.RemoveAt(t);
            }
        }

        return split.ToArray();
    }

    public static string Base64Encode(string plainText)
    {
        var plainTextBytes = System.Text.Encoding.UTF8.GetBytes(plainText);
        return System.Convert.ToBase64String(plainTextBytes);
    }

    public static string Base64Decode(string base64EncodedData)
    {
        var base64EncodedBytes = System.Convert.FromBase64String(base64EncodedData);
        return System.Text.Encoding.UTF8.GetString(base64EncodedBytes);
    }

    public static void CreateZipFromFolder(string source, string target)
    {
        
        if (File.Exists(target))
        {
            File.Delete(target);
        }
        ZipFile.CreateFromDirectory(source, target, CompressionLevel.Optimal, false);

    }


}
