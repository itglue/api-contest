using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Xml.Serialization;

namespace Stuff2Glue
{
    class Program
        
    {

        static void Main(string[] args)
        {
            
           //fake input from cli
         args = new string[16];
             args[0] = "NORMAL";
             args[1] = "-OrgId";
            args[2] = "1458135"; 
             args[3] = "-PathToPickup";
             args[4] = "C:\\NetwerkAdministratie\\Pickup";
             args[5] = "";
             args[6] = "";
             args[7] = "-AlternativePath";
             args[8] = "C:\\Netwerkadministratie\\Alternative";
             args[9] = "-NoDelete";
             args[10] = "-Debug";
            args[11] = "-WriteHTML";
            
             
            //init the class

            Configuration configuration = new Configuration(args);
           
     




            //done init

            if ((configuration.mode == "NORMAL") || (configuration.mode == "ALTERNATIVE"))
            {
                #region normal operation
                //fetch previous settings, if any.
                Settings settings = new Settings();

                //fetching all configuration from pickup folder

                if (HelperFunctions.CheckPickupFolder(configuration))
                {
                    Console.WriteLine("Getting configs from pickup folder");

                    if (Directory.GetFiles(configuration.PickupFolder).Length > 0)
                    {
                        string[] files = Directory.GetFiles(configuration.PickupFolder);
                        foreach (string file in files)
                        {
                            string config = HelperFunctions.GetFileConfig(file);
                            if (settings.AddConfigFile(config))
                            {
                                Console.WriteLine("Imported config succesfully");
                               
                            }
                            else
                            {
                                Console.WriteLine("Importing config failed");
                            }
                        }


                    }
                    else
                    {
                        Console.WriteLine("No items in pickup folder folder: " + configuration.PickupFolder + " count: " + Directory.GetFiles(configuration.PickupFolder).Length);

                    }


                }
                else
                {
                    Console.WriteLine("No pickup folder");
                }

                //end pickup folder

               
                Console.WriteLine("FINISHED import");


                if (configuration.noglue)
                {
                    Console.WriteLine("Skipping itglue");
                }
                else
                {
                    Console.WriteLine("Updating IT1 Fingerprint");
                    Console.WriteLine("Org id = " + configuration.GlueOrganisationID);
                    #region fortigate

                    foreach (Fortigate current in settings.fortigates)
                    {
                        Console.WriteLine("Searching for id");
                        string manufacturerid = ITGlueAPI.GetManufacturerID(current.manufacturer);
                        string modelid = "";
                        Console.WriteLine("searching for model: " + current.model);
                        if (ITGlueAPI.GetModelID(current.model, manufacturerid, out modelid))
                        {
                            Console.WriteLine("Found model id: " + modelid);
                        }
                        else
                        {
                            Model currentModel = new Model();
                            currentModel.name = current.model;
                            currentModel.Manufacturerid = manufacturerid;

                            if (ITGlueAPI.UpdateModel(currentModel, out modelid, configuration.GlueOrganisationID, manufacturerid))
                            {
                                Console.WriteLine("Added model");
                            }
                            else
                            {
                                Console.WriteLine("Adding model not supported yet, please add it manually and try again");
                                Thread.Sleep(1000000);
                                System.Environment.Exit(0);
                            }




                        }
                        string configurationID = "";
                        if (ITGlueAPI.GetConfigID(configuration.GlueOrganisationID, current.hostname, Fortigate.configTypeID.ToString(), manufacturerid, out configurationID))
                        {
                            Console.WriteLine("Found fortigate with id: " + configurationID);

                            if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, current, manufacturerid, configurationID, modelid, false, configurationID))
                            {
                                Console.WriteLine("Updated Fortigate");
                               
                            }
                            else
                            {
                                Console.WriteLine("Fortigate update error");
                            }

                        }
                        else
                        {
                            Console.WriteLine("Fortigate not found, we'll have to create it first");
                            if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, current, manufacturerid, configurationID, modelid, true))
                            {
                                Console.WriteLine("Fortigate created");
                                ITGlueAPI.GetConfigID(configuration.GlueOrganisationID, current.hostname, Fortigate.configTypeID.ToString(), manufacturerid, out configurationID);
                            }
                            else
                            {
                                Console.WriteLine("Fortigate creation error");
                            }

                        }
                        current.GlueConfigurationID = configurationID;

                        List<ConfigurationInterface> SWinterfaces = current.GetInterfaces();


                        if (SWinterfaces.Count > 0)
                        {
                            List<string> ConfigurationInterfaces = new List<string>();
                            if (ITGlueAPI.GetConfigurationInterfaces(configurationID, out ConfigurationInterfaces))
                            {
                                Console.WriteLine("Found some interfaces");
                            }
                            else
                            {
                                Console.WriteLine("Found no interfaces");
                            }
                            int t = 0;
                            foreach (ConfigurationInterface currentInterface in SWinterfaces)
                            {
                                if (t < ConfigurationInterfaces.Count)
                                {
                                    Console.WriteLine("Updating interface");
                                    if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, currentInterface, configurationID, ConfigurationInterfaces[t], modelid, false, ConfigurationInterfaces[t]))
                                    {
                                        Console.WriteLine("Updated Interface");
                                    }
                                    else
                                    {
                                        Console.WriteLine("Interface update error");
                                    }


                                }
                                else
                                {
                                    Console.WriteLine("Adding interface");

                                    if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, currentInterface, configurationID, configurationID, modelid, true))
                                    {
                                        Console.WriteLine("Interface created");
                                    }
                                    else
                                    {
                                        Console.WriteLine("Interface creation error");
                                    }

                                }
                                t++;
                            }

                        }



                    }

                    #endregion
                    #region switches

                    foreach (Switch current in settings.switches)
                    {
                        Console.WriteLine("Searching for id");
                        string manufacturerid = ITGlueAPI.GetManufacturerID(current.Manufacturer);
                        string modelid = "";
                        Console.WriteLine("searching for model: " + current.Type);
                        if (ITGlueAPI.GetModelID(current.Type.ToString(), manufacturerid, out modelid))
                        {
                            Console.WriteLine("Found model id: " + modelid);
                        }
                        else
                        {
                            Model currentModel = new Model();
                            currentModel.name = current.Type.ToString();
                            currentModel.Manufacturerid = manufacturerid;
                            if (ITGlueAPI.UpdateModel(currentModel, out modelid, configuration.GlueOrganisationID, manufacturerid))
                            {
                                Console.WriteLine("Added model");
                            }
                            else
                            {
                                Console.WriteLine("Adding model not supported yet, please add it manually and try again");
                                Thread.Sleep(1000000);
                                System.Environment.Exit(0);
                            }
                        }
                        string configurationID = "";
                        if (ITGlueAPI.GetConfigID(configuration.GlueOrganisationID, current.HostName, Switch.configTypeID.ToString(), manufacturerid, out configurationID))
                        {
                            Console.WriteLine("Found Switch with id: " + configurationID);

                            if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, current, manufacturerid, configurationID, modelid, false, configurationID))
                            {
                                Console.WriteLine("Updated Switch");
                               
                            }
                            else
                            {
                                Console.WriteLine("Switch update error");
                            }

                        }
                        else
                        {
                            Console.WriteLine("Switch not found, we'll have to create it first");
                            if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, current, manufacturerid, configurationID, modelid, true))
                            {
                                Console.WriteLine("Switch created");
                                ITGlueAPI.GetConfigID(configuration.GlueOrganisationID, current.HostName, Switch.configTypeID.ToString(), manufacturerid, out configurationID);
                            }
                            else
                            {
                                Console.WriteLine("Switch creation error");
                            }

                        }
                        current.GlueConfigurationID = configurationID;
                        List<ConfigurationInterface> SWinterfaces = current.GetInterfaces();


                        if (SWinterfaces.Count > 0)
                        {
                            List<string> ConfigurationInterfaces = new List<string>();
                            if (ITGlueAPI.GetConfigurationInterfaces(configurationID, out ConfigurationInterfaces))
                            {
                                Console.WriteLine("Found some interfaces");
                            }
                            else
                            {
                                Console.WriteLine("Found no interfaces");
                            }
                            int t = 0;
                            foreach (ConfigurationInterface currentInterface in SWinterfaces)
                            {
                                if (t < ConfigurationInterfaces.Count)
                                {
                                    Console.WriteLine("Updating interface");
                                    if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, currentInterface, configurationID, ConfigurationInterfaces[t], modelid, false, ConfigurationInterfaces[t]))
                                    {
                                        Console.WriteLine("Updated Interface");
                                    }
                                    else
                                    {
                                        Console.WriteLine("Interface update error");
                                    }


                                }
                                else
                                {
                                    Console.WriteLine("Adding interface");

                                    if (ITGlueAPI.setConfiguration(configuration.GlueOrganisationID, currentInterface, configurationID, configurationID, modelid, true))
                                    {
                                        Console.WriteLine("Interface created");
                                    }
                                    else
                                    {
                                        Console.WriteLine("Interface creation error");
                                    }

                                }
                                t++;
                            }

                        }
                    }

                    #endregion




                }

                if (configuration.html)
                {
                    Console.WriteLine("Writing html file");

                    string html = string.Empty;
                    settings.switches.Sort((x, y) => x.HostName.CompareTo(y.HostName));
                    foreach (Switch aSwitch in settings.switches)
                    {
                        html += "\n\n" + aSwitch.GetOutputHTML();
                        Console.WriteLine("Writing a switch to html");
                    }
                    HelperFunctions.WriteHTML(html, configuration.AlternativePath, "vlanschema");
                    if (!configuration.noglue)
                    {
                        HelperFunctions.WriteHTML(html, configuration.AlternativePath, "Vlanschema");
                        if (ITGlueAPI.UpdateVLAN(configuration.GlueOrganisationID, html))
                        {
                            Console.WriteLine("Wrote VLAN to IT1 Fingerprint");
                        }
                        else
                        {
                            Console.WriteLine("Writing VLAN to IT1 Fingerprint Failed");
                        }
                    }


                }

                //Creating LAN Objects Networks
                
                if (!configuration.noglue)
                {
                    List<Network> networks = Network.networks(settings.fortigates, settings.switches);

                    Console.WriteLine("Networks generated");
                    foreach (Network network in networks)
                    {
                        ITGlueAPI.UpdateNetwork(configuration.GlueOrganisationID, network);
                    }
                } else
                {
                    Console.WriteLine("Skipping Networks to itglue");
                }

                



                

                Console.WriteLine("Finished with normal operation");
                #endregion

            }
           
            if (configuration.debug)
            {
                Console.WriteLine("Finished");
                Thread.Sleep(1000000);
            }
        } 
        
       
    }

    

}
