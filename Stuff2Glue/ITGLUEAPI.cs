using RestSharp;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;

namespace Stuff2Glue
{

    

    class LAN
    {
        public string name = "VLAN";
        public string HTML = "";
        public static string configTypeID = "40214";
    }
    class ConfigurationBackup
    {
        public string name = "ConfigurationBackup";
        public string File = "";
        public static string configTypeID = "934595842146471";
    }

    class Attachment
    {
        public string name = "";
        public string File = "";
        public string AttachmentID = "";
    }
    class Model
    {
        public string name = "";
        public string Manufacturerid = "";
    }

    static class ITGlueAPI
    {
        public enum resourcetypes
        {
            checklists, checklist_templates, configurations, contacts, documents, domains, locations, passwords, ssl_certificates, flexible_assets, tickets
        }

        public static string baseURL = "https://api.eu.itglue.com";
        //public static string path = "/organizations";
        public static string queryParamater = "sort=id";
        public static string requestJson = "";
        public static string responseJson = "";
        static string key = "ITG.ABCDEFG";


        private static string findID(string content)
        {
            Console.Write("Finding id");
            string[] split = content.Split(':');
            int index = HelperFunctions.FindIndexOf(split, "id",0);
            string id = split[index + 1].Split(',')[0].Replace("\"",string.Empty);

            Console.WriteLine("found id: " + id);
            return id;
        }


        public enum ITGlueRequestTypesConfigurations
        {
            Organisation,User,FlexibleAsset,Configuration,Manufacturer,Model,ConfigurationInterfaces,ITGLUEModel,Password,Configuration2Attachment
        }
        public enum ITGlueRequestTypesFlexAsset
        {
            LAN,ConfigurationBackup,Network,IT1DAConfiguration,Attachement
        }



        public static string GetManufacturerID(string name)
        {

            List<(string, string)> Parameters = new List<(string, string)>();
            Parameters.Add(("filter[name]",name));

            string content = requestData(ITGlueRequestTypesConfigurations.Manufacturer,Parameters,new List<(string,string)>());

            return findID(content);

        }

        public static bool GetModelID(string name, string ManuFacturerID, out string id)
        {

            List<(string, string)> Parameters = new List<(string, string)>();
            Parameters.Add(("manufacturer_id", ManuFacturerID));
            Parameters.Add(("filter[name]", name));
            Parameters.Add(("page[size]", "999"));


            string content = requestData(ITGlueRequestTypesConfigurations.Model, Parameters, new List<(string, string)>());

            string[] split = content.Split(",");
            int index = HelperFunctions.FindIndexOf(split, name, 0);
            int index2 = HelperFunctions.FindLastIndexOf(split, "{\"id", index);

            if ((index == -1) || (index2 == -1))
            {
                id = "Missing";
                return false;
            }

            string[] split2 = split[index2].Split("\"");
            
            id = split2[split2.Length - 2]; 
            return true;

        }

        private static bool GetCount(string content, out int count)
        {

            string[] split = content.Split("\"");

            int index = HelperFunctions.FindIndexOf(split, "otal-coun", 0);
            string strCount = split[index + 1];
            strCount = strCount.Replace(":", "").Replace(",", "");
            count = 0;
            Console.WriteLine("count is before conversion " + strCount);
            bool worked = int.TryParse(strCount, out count);
            return worked;
        }

        public static bool GetConfigID(string orgId, string name, string configtypeID, string ManuFacturerID, out string configID)
        {

            List<(string, string)> Parameters = new List<(string, string)>();
            Parameters.Add(("filter[name]", name));
          //  Parameters.Add(("filter[name]", name));
            Parameters.Add(("page[size]", "999"));
            Parameters.Add(("filter[organization_id]", orgId));

            string content = requestData(ITGlueRequestTypesConfigurations.Configuration, Parameters, new List<(string, string)>());

            //return findID(content);
            int count = 0;
            if (GetCount(content,out count))
            {


                if (count > 0)
                {
                    configID = findID(content);
                    return true;
                }
                else
                {
                    configID = "";
                    return false;
                }
            }
            else
            {
                configID = "";
                return false;
            }
            

           
        }


        public static List<(String,String)> GetConfigNameList(string orgId, string name, string configtypeID)
        {

            List<(string, string)> Parameters = new List<(string, string)>();
           // Parameters.Add(("filter[name]", name));
            //  Parameters.Add(("filter[name]", name));
            Parameters.Add(("page[size]", "999"));
            Parameters.Add(("filter[organization_id]", orgId));
            Parameters.Add(("filter[configuration_type_id]",configtypeID));
            string content = requestData(ITGlueRequestTypesConfigurations.Configuration, Parameters, new List<(string, string)>());

            List<(String,String)> results = new List<(String,String)>();
            string[] split = content.Split(new [] { ',', ':','\"'},StringSplitOptions.RemoveEmptyEntries);
            for (int t = 0; t < split.Length; t++)
            {
                if (split[t] == "name")
                {
                    t++;
           
                    results.Add((split[t], split[t+4]));
                    
                }
            }
            return results;
        }

        public static bool ExtractIDs(string content, string confID, out List<String> IDs)
        {
            IDs = new List<string>();
            string[] contentsplit = content.Split("\"");
            int t = 0;
            while ((HelperFunctions.FindIndexOf(contentsplit, "id", t) != -1) && (t < contentsplit.Length))
            {
                t = HelperFunctions.FindIndexOf(contentsplit, "id", t) +2;
                if (contentsplit[t].Replace("\"", "") != confID)
                {
                    IDs.Add(contentsplit[t].Replace("\"", ""));
                }
                
            }
            return true;
        }

        public static bool GetConfigurationInterfaces(string confId, out List<string> ConfigurationInterfacesIDs)
        {

            ConfigurationInterfacesIDs = new List<string>();

            List<(string, string)> URLParameters = new List<(string, string)>();

            //URLParameters.Add(("conf_id",confId));

            string content = requestData(ITGlueRequestTypesConfigurations.ConfigurationInterfaces, new List<(string, string)>(),URLParameters,confId);
            int count = 0;
            if (GetCount(content, out count))
            {
                Console.WriteLine("Found " + count + " interfaces");
            }
            else return false;

            if (count <= 0)
            {
               
                return false;
            }
            else
            {
                //extract the ids and add them tot the list
                if (ExtractIDs(content, confId, out ConfigurationInterfacesIDs))
                {
                    return true;
                } else
                {
                    return false;
                }
            }

            //return true;
        }

        private static string GetPath(ITGlueRequestTypesConfigurations ITGlueRequest, string id = "", bool Update = false)
        {
            if (Update && ITGlueRequest == ITGlueRequestTypesConfigurations.ConfigurationInterfaces)
            {
                return "/configuration_interfaces";
            }



            string path = "";
            if (ITGlueRequest == ITGlueRequestTypesConfigurations.Organisation)
            {
                path = "/organizations";
            }
            else if (ITGlueRequest == ITGlueRequestTypesConfigurations.Manufacturer)
            {
                path = "/manufacturers";
            }
            else if ((ITGlueRequest == ITGlueRequestTypesConfigurations.Model) || (ITGlueRequest == ITGlueRequestTypesConfigurations.ITGLUEModel))
            {
                path = "/models";
            }
            else if (ITGlueRequest == ITGlueRequestTypesConfigurations.Configuration)
            {
                path = "/configurations";
            }
            else if (ITGlueRequest == ITGlueRequestTypesConfigurations.ConfigurationInterfaces)
            {
                path = "/configurations/"+id+"/relationships/configuration_interfaces";
            }
            else if (ITGlueRequest == ITGlueRequestTypesConfigurations.Password)
            {
                path = "/passwords/" +id;
            }
            else if (ITGlueRequest == ITGlueRequestTypesConfigurations.Configuration2Attachment)
            {
                path = "/configurations/" + id;
            }
            return path;

        }

        private static string GetPath(ITGlueRequestTypesFlexAsset ITGlueRequest, string id = "", bool Update = false, string secondId = "", bool delete = false)
        {
            string path = "";
            if (ITGlueRequest == ITGlueRequestTypesFlexAsset.Attachement)
            {
                if (delete)
                {
                    path = "/configurations/" + id + "/relationships/attachments";
                } else
                {
                    if (Update)
                    {
                        path = "/configurations/" + id + "/relationships/attachments/" + secondId;
                    }
                    else
                    {
                        path = "/configurations/" + id + "/relationships/attachments";
                    }
                }
               
                
            } else
            {
                path = "/flexible_assets";
            }
            
            return path;

        }

        public static string requestData(ITGlueRequestTypesConfigurations ITGlueRequest, List<(string, string)> Parameters, List<(string, string)> URLParameters,string id = "")
        {
            string path = GetPath(ITGlueRequest,id);

            return requestData(path,Parameters,URLParameters);
         }


        public static string requestData(ITGlueRequestTypesFlexAsset ITGlueRequest, List<(string, string)> Parameters, List<(string, string)> URLParameters, string id = "")
        {
            string path = GetPath(ITGlueRequest, id);

            return requestData(path, Parameters, URLParameters);
        }


        public static bool setConfiguration(string orgId, object current, string ManuFacturerID, string configID, string modelID, bool createNew, string objectID = "")
        {
             Console.WriteLine("Creating configuration");
            List<(string, string)> Parameters = new List<(string, string)>();

            if (!createNew)
            {
                //Parameters.Add(("id",objectID));
               // Parameters.Add(("organization_id", orgId));
            }
            string content = "";
            if (current.GetType() == typeof(ConfigurationInterface))
            {
                content = setData(ITGlueRequestTypesConfigurations.ConfigurationInterfaces, Parameters, current, orgId, ManuFacturerID, modelID, createNew, objectID);
            }
            else
            {
                content = setData(ITGlueRequestTypesConfigurations.Configuration, Parameters, current, orgId, ManuFacturerID, modelID, createNew, objectID);
            }

            
            Console.WriteLine(content);
            return true;
        }



        public static string setData(ITGlueRequestTypesConfigurations ITGlueRequest, List<(string, string)> Parameters, object current, string orgId, string manufacturerID, string modelID, bool newObject, string objectID, bool delete = false)
        {
            string path = GetPath(ITGlueRequest,manufacturerID,true);

       
            return setData(path, Parameters,current, orgId,manufacturerID,modelID, newObject, objectID);
        }

        private static object GetJsonData(object current, string orgID, string manufacturerID, string modelID, bool newObject, string objectID, bool delete = false)
        {
            object json = null;

            if (current.GetType() == typeof(Fortigate))
            {
                Console.WriteLine("Generating json for Fortigate");
                Fortigate currentFG = (Fortigate)current;


                if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "configurations",
                            attributes = new
                            {
                                configuration_type_id = Fortigate.configTypeID,
                                organization_id = orgID,
                                name = currentFG.hostname,
                                primary_ip = currentFG.interfaces[0].IP,
                                manufacturer_id = manufacturerID,
                                model_id = modelID,
                                hostname = currentFG.hostname,
                                notes = "This configuration was automatically created by IT1 Stuff2Glue",
                                serial_number = currentFG.serial,
                                operating_system_notes = currentFG.version,
                                expiration_date = currentFG.expires,

                            }
                        }
                    };
                }
                else
                {
                    json = new
                    {
                        data = new
                        {
                            type = "configurations",

                            attributes = new
                            {
                                id = long.Parse(objectID),
                                configuration_type_id = Fortigate.configTypeID,
                                organization_id = orgID,
                                name = currentFG.hostname,
                                primary_ip = currentFG.interfaces[0].IP,
                                manufacturer_id = manufacturerID,
                                model_id = modelID,
                                hostname = currentFG.hostname,
                                notes = "This configuration was automatically created by IT1 Stuff2Glue",
                                serial_number = currentFG.serial,
                                operating_system_notes = currentFG.version,
                                expiration_date = currentFG.expires,
                            }
                        }
                    };
                }


            }
            else if (current.GetType() == typeof(Fortigate.Interface))
            {
                Console.WriteLine("Generating json for Fortigate Interface");
            }
            else if (current.GetType() == typeof(Switch))
            {
                Console.WriteLine("Generating json for Switch");

                Switch currentSW = (Switch)current;
                string osnote = "Layer3: " + ((currentSW.L3enabled) ? "Enabled " : "Disabled ") + ",GVRP: " + ((currentSW.GVRP) ? "Enabled " : "Disabled ") + ",Spanning tree: " + ((currentSW.spanningTree) ? "Enabled " : "Disabled ");

                if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "configurations",
                            attributes = new
                            {
                                configuration_type_id = Switch.configTypeID,
                                organization_id = orgID,
                                name = currentSW.HostName,
                                primary_ip = currentSW.PrimaryIP(),
                                manufacturer_id = manufacturerID,
                                model_id = modelID,
                                hostname = currentSW.HostName,
                                notes = "This configuration was automatically created by IT1 Stuff2Glue",
                                operating_system_notes = osnote

                            }
                        }
                    };
                }
                else
                {
                    json = new
                    {
                        data = new
                        {
                            type = "configurations",

                            attributes = new
                            {
                                id = long.Parse(objectID),
                                configuration_type_id = Switch.configTypeID,
                                organization_id = orgID,
                                name = currentSW.HostName,
                                primary_ip = currentSW.PrimaryIP(),
                                manufacturer_id = manufacturerID,
                                model_id = modelID,
                                hostname = currentSW.HostName,
                                notes = "This configuration was automatically created by IT1 Stuff2Glue",
                                operating_system_notes = osnote

                            }
                        }
                    };
                }




            }

            else if (current.GetType() == typeof(ConfigurationInterface))
            {
                Console.WriteLine("Generating json for Config Interface interface");

                ConfigurationInterface currentInt = (ConfigurationInterface)current;


                if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "configuration-interfaces",
                            attributes = new
                            {
                                configuration_id = manufacturerID,
                                name = currentInt.name,
                                ip_address = currentInt.ip,
                                notes = currentInt.comment

                            }
                        }
                    };
                }
                else
                {
                    json = new
                    {
                        data = new
                        {
                            id = objectID,
                            type = "configuration-interfaces",
                            attributes = new
                            {
                                id = objectID,
                                configuration_id = manufacturerID,
                                name = currentInt.name,
                                ip_address = currentInt.ip,
                                notes = currentInt.comment

                            }
                        }
                    };
                }


            }
            else if (current.GetType() == typeof(LAN))
            {
                Console.WriteLine("Generating json for LAN");
                LAN currentLAN = (LAN)current;


                if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "flexible-assets",
                            attributes = new
                            {
                                organization_id = orgID,
                                flexible_asset_type_id = LAN.configTypeID,
                                traits = new 
                                {
                                    name = currentLAN.name,
                                   file = new
                                    {
                                       
                                        content = HelperFunctions.Base64Encode(currentLAN.HTML),
                                        file_name = "vlanschema.html"
                                    }
                                }
                                

                            }
                        }
                    };
                }
                else
                {
                    json = new
                    {
                        data = new
                        {
                            
                            type = "flexible-assets",
                            name = currentLAN.name,
                            flexible_asset_type_id = LAN.configTypeID,
                            organization_id = orgID,
                            attributes = new
                            {
                                id = long.Parse(objectID),
                                name = currentLAN.name,
                                traits = new
                                {
                                    name = currentLAN.name,
                                    file = new
                                    {
                                        content = HelperFunctions.Base64Encode(currentLAN.HTML),
                                        file_name = "vlanschema.html"
                                    }
                                }
                                

                            }
                        }
                    };
                }
            }
            else if (current.GetType() == typeof(ConfigurationBackup))
            {
                Console.WriteLine("Generating json for Configuration Backup");
                ConfigurationBackup currentBackup = (ConfigurationBackup)current;


                if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "flexible-assets",
                            attributes = new
                            {
                                organization_id = orgID,
                                flexible_asset_type_id = ConfigurationBackup.configTypeID,
                                traits = new
                                {
                                    name = currentBackup.name,
                                    notes = "This configuration backup was automatically created by IT1 Stuff2Glue",
                                    file = new
                                    {

                                        content = currentBackup.File,
                                        file_name = "ConfigurationBackup.zip"
                                    }
                                }


                            }
                        }
                    };
                }
                else
                {
                    json = new
                    {
                        data = new
                        {

                            type = "flexible-assets",
                            name = currentBackup.name,
                            flexible_asset_type_id = ConfigurationBackup.configTypeID,
                            organization_id = orgID,
                            attributes = new
                            {
                                id = long.Parse(objectID),
                                name = currentBackup.name,
                                notes = "This configuration backup was automatically created by IT1 Stuff2Glue",
                                traits = new
                                {
                                    name = currentBackup.name,
                                    file = new
                                    {
                                        content = currentBackup.File,
                                        file_name = "ConfigurationBackup.zip"
                                    }
                                }


                            }
                        }
                    };
                }
            }
            else if (current.GetType() == typeof(Model))
            {
                Console.WriteLine("Generating json for Model");

                Model currentModel = (Model)current;


                if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "models",
                            attributes = new
                            {
                                manufacturer_id = manufacturerID,
                                name = currentModel.name
                            }
                        }
                    };
                }
                else
                {
                    json = new
                    {
                        data = new
                        {
                            id = objectID,
                            type = "models",
                            attributes = new
                            {
                                id = objectID,
                                manufacturer_id = manufacturerID,
                                name = currentModel.name

                            }
                        }
                    };
                }


            }
            else if (current.GetType() == typeof(Network))
            {
                Console.WriteLine("Generating json for Network");
                Network currentNetwork = (Network)current;
                if (currentNetwork.names.Count == 0)
                {
                    currentNetwork.names.Add("Empty");
                }
                if (currentNetwork.IPs.Count == 0)
                {
                    currentNetwork.IPs.Add(new IP("99.99.99.99/99"));
                }
                string vlanid = "";
                if (currentNetwork.vlanID != -1)
                {
                    vlanid = currentNetwork.vlanID.ToString();
                }
                string actionReq = "";
                if (currentNetwork.actionReq)
                {
                    actionReq = "Action required (Multiple names for this VLAN were found: ";
                    foreach(string name in currentNetwork.names)
                    {
                        actionReq += name + " ";
                    }
                    actionReq += ")";
                }

                if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "flexible-assets",
                            attributes = new
                            {
                                organization_id = orgID,
                                flexible_asset_type_id = LAN.configTypeID,
                                traits = new
                                {
                                    name = currentNetwork.names[0],
                                    subnet = currentNetwork.IPstring,
                                    vlans = vlanid,
                                    action = actionReq,
                                    firewall = currentNetwork.ConnectedFirewalls,
                                    switches = currentNetwork.ConnectedSwitches
                                }


                            }
                        }
                    };
                }
                else
                {
                   
                    json = new
                    {
                        data = new
                        {

                            type = "flexible-assets",
                            name = currentNetwork.names[0],
                            flexible_asset_type_id = LAN.configTypeID,
                            organization_id = orgID,
                            attributes = new
                            {
                                id = long.Parse(objectID),
                                name = currentNetwork.names[0],
                                traits = new
                                {
                                    name = currentNetwork.names[0],
                                    subnet = currentNetwork.IPstring,
                                    vlans = vlanid,
                                    action = actionReq,
                                    firewall = currentNetwork.ConnectedFirewalls,
                                    switches = currentNetwork.ConnectedSwitches

                                }


                            }
                        }
                    };
                }
            }
            else if (current.GetType() == typeof(Attachment))
            {
                Console.WriteLine("Generating json for Attachement");
                Attachment currentAttachement = (Attachment)current;
                if (delete)
                {
                    json = new
                    {
                        data = new []
                        {
                            new {
                                type = "attachments",
                                attributes = new
                                {
                                    id = currentAttachement.AttachmentID
                                }
                            }
                        }
             
                       
                    };
                } else if (newObject)
                {
                    json = new
                    {
                        data = new
                        {
                            type = "attachments",
                            attributes = new
                            {
                                attachment = new
                                {
                                    file_name = currentAttachement.name,
                                    content = currentAttachement.File
                                }


                            }
                        }
                    };
                }
                else
                {
                    json = new
                    {
                        data = new
                        {
                            type = "attachments",
                            attributes = new
                            {
                                attachment = new
                                {
                                    file_name = currentAttachement.name,
                                    content = currentAttachement.File
                                }


                            }
                        }
                    };
                }
            }
            return json;
        }


        private static string setData(string path, List<(string, string)> Parameters,object current, string orgID, string manufacturerID, string modelID, bool newObject, string objectID, bool delete = false)
         {
           

            RestClient client = new RestClient(baseURL + path);
           

            object json = GetJsonData(current,orgID,manufacturerID,modelID,newObject,objectID,delete);
            RestRequest request = new RestRequest(Method.PATCH);

            if (newObject)
            {
                request = new RestRequest(Method.POST);
            }
            if (delete)
            {
                request = new RestRequest(Method.DELETE);
                request.JsonSerializer.ContentType = "application/vnd.api+json";
            }
                
               
                var jsons = request.JsonSerializer.Serialize(json);
                Console.WriteLine("Serialized json request:   ");
                Console.WriteLine(jsons.ToString());
                request.AddJsonBody(json);


            if (!newObject)
            {
                Console.WriteLine("This is an update for:  " + objectID);
                request.AddParameter("id", long.Parse(objectID), ParameterType.UrlSegment);
            }
          


            request.AddHeader("cache-control", "no-cache");
            request.AddHeader("content-type", "application/vnd.api+json");

            request.AddHeader("x-api-key", key);



            foreach ((string, string) value in Parameters)
            {
                request.AddParameter(value.Item1, value.Item2);
            }
            


            IRestResponse response = client.Execute(request);

            string responsecontent = response.Content;
            Console.WriteLine("response: " + responsecontent);

            return responsecontent;
        }















        private static string requestData(string path, List<(string, string)> Parameters, List<(string, string)> URLParameters)
        {
          

            RestClient client = new RestClient(baseURL+path);


            RestRequest request = new RestRequest(Method.GET); ;
           

            
            request.AddHeader("cache-control", "no-cache");
            request.AddHeader("content-type", "application/vnd.api+json");
            request.AddHeader("x-api-key",key);

            

            foreach ((string, string) value in Parameters)
            {
                request.AddParameter(value.Item1, value.Item2);
            }
            foreach ((string, string) value in URLParameters)
            {
                request.AddParameter(value.Item1, value.Item2,ParameterType.UrlSegment);
            }

            request.RequestFormat = DataFormat.Json;
         
            IRestResponse response = client.Execute(request);

            string responsecontent = response.Content;
            Console.WriteLine("response: " + responsecontent);

            return responsecontent;
        }

        public static bool GetFlexAsset(List<(string, string)> Parameters, string FlexTypeID, out string flexID, ITGlueRequestTypesFlexAsset flexAssetType)
        {
            flexID = "";

            List<(string, string)> URLParameters = new List<(string, string)>();

            string content = requestData(flexAssetType, Parameters, URLParameters, FlexTypeID);
            int count = 0;
            if (GetCount(content, out count))
            {
                Console.WriteLine("Found " + count + " flex assets");
            }
            else return false;

            if (count <= 0)
            {

                return false;
            }
            else
            {
                //extract the ids and add them tot the list
                string[] contentSplit = content.Split(new char[] { '/', ' ', '"' });
                if (HelperFunctions.FindIndexOf(contentSplit, "records", 0) != -1)
                {
                    int location = HelperFunctions.FindIndexOf(contentSplit, "records", 0) + 1;
                    flexID = contentSplit[location];
                    return true;
                }
                else
                {
                    return false;

                }



            }

        

        }


        public static bool GetFlexAssetTraits( string FlexTypeID, Configuration currentConfig, out List<(string, string)> traits)
        {
            

            List<(string, string)> Parameters = new List<(string, string)>();
            Parameters.Add(("filter[flexible_asset_type_id]", "992453881397384"));
           
            Parameters.Add(("page[size]", "999"));
            Parameters.Add(("filter[organization_id]", currentConfig.GlueOrganisationID));
            
            traits = new List<(string, string)>();
            string readContent = "";
            if (GetFlexAssetContent(Parameters, "992453881397384", out readContent)) {
                Console.WriteLine("Read:" + readContent);
                string[] traitSplit = readContent.Split("traits");
                traitSplit = traitSplit[1].Split(",");
                traitSplit[0] = traitSplit[0].Substring(3,traitSplit[0].Length -3);

                for (int t = 0; t< traitSplit.Length; t++)
                {
                    traitSplit[t] = traitSplit[t].Trim(new char[] { ' ', '{', '}', '*','"' });
                }
                bool found = false;
                
                foreach (string trait in traitSplit)
                {
                    if (!found) {
                        if (trait.Contains("created"))
                        {
                            found = true;
                        }
                        else
                        {
                            if (trait.Contains(":"))
                            {
                                
                                string[] split = trait.Split(":");
                                if (split.Length == 3)
                                {
                                    Console.WriteLine("Trait: " + split[0].Trim(new char[] { ' ', '{', '}', '*', '"' }) + " and content: " + split[1].Trim(new char[] { ' ', '{', '}', '*', '"' }) + ":" + split[2].Trim(new char[] { ' ', '{', '}', '*', '"' }));
                                    traits.Add((split[0].Trim(new char[] { ' ', '{', '}', '*', '"' }), split[1].Trim(new char[] { ' ', '{', '}', '*', '"' }) + ":"+ split[2].Trim(new char[] { ' ', '{', '}', '*', '"' })));
                                }
                                else
                                {
                                    Console.WriteLine("Trait: " + split[0].Trim(new char[] { ' ', '{', '}', '*', '"' }) + " and content: " + split[1].Trim(new char[] { ' ', '{', '}', '*', '"' }));
                                    traits.Add((split[0].Trim(new char[] { ' ', '{', '}', '*', '"' }), split[1].Trim(new char[] { ' ', '{', '}', '*', '"' })));
                                }

                        
                            }
                            else
                            {

                                (string, string) temp = traits[traits.Count - 1];
                                traits.RemoveAt(traits.Count - 1);
                                temp.Item2+=  ","+trait;
                                traits.Add(temp);
                            }
                        }


                    }


                }
                               
            }


            return true;

        }

        public static bool GetPassword(string ID, string OrgID, out string password)
        {
            password = "";

          

            List<(string, string)> URLParameters = new List<(string, string)>();
            List<(string, string)> Parameters = new List<(string, string)>();
           

            string content = requestData(ITGlueRequestTypesConfigurations.Password, Parameters, URLParameters, ID); 
            string[] split = content.Split(new char[] { ',', '"' ,':'});
            int location = HelperFunctions.FindLastIndexOf(split, "password", split.Length-1);
            if (location != -1)
            {
                password = split[location + 3];
                return true;
            }
            




            return false;

        }



        public static bool GetFlexAssetContent(List<(string, string)> Parameters, string FlexTypeID, out string readContent)
        {
            readContent = "";

            List<(string, string)> URLParameters = new List<(string, string)>();

            //URLParameters.Add(("conf_id",confId));

            string content = requestData(ITGlueRequestTypesFlexAsset.LAN, Parameters, URLParameters, FlexTypeID);
            int count = 0;
            if (GetCount(content, out count))
            {
                Console.WriteLine("Found " + count + " flex assets");
            }
            else return false;

            if (count <= 0)
            {

                return false;
            }
            else
            {
                readContent = content;
                return true;
            }
               




        }


        public static bool GetFlexAsset(List<(string, string)> Parameters, string FlexTypeID ,out string flexID)
        {
            flexID = "";

            List<(string, string)> URLParameters = new List<(string, string)>();

          

            string content = requestData(ITGlueRequestTypesFlexAsset.LAN, Parameters, URLParameters, FlexTypeID);
            int count = 0;
            if (GetCount(content, out count))
            {
                Console.WriteLine("Found " + count + " flex assets");
            }
            else return false;

            if (count <= 0)
            {

                return false;
            }
            else
            {
                //extract the ids and add them tot the list
                string[] contentSplit = content.Split(new char[] { '/', ' ','"' });
                if (HelperFunctions.FindIndexOf(contentSplit,"records",0) != -1)
                {
                    int location = HelperFunctions.FindIndexOf(contentSplit, "records", 0) + 1;
                    flexID = contentSplit[location];
                    return true;
                } else
                {
                    return false;

                }

    

            }

            //return true;
            
        }

        public static string setData(ITGlueRequestTypesFlexAsset flexType, List<(string, string)> Parameters, object current, string orgId, string flexID, bool createnew, bool delete = false)
        {
            string path = "";

            if (current.GetType() == typeof(Attachment))
            {
                Attachment temp = (Attachment)current;
                path = GetPath(flexType, flexID, !createnew,temp.AttachmentID,delete);
            } else
            {
                path = GetPath(flexType, flexID, true);
            }

            return setData(path, Parameters, current, orgId, flexID,flexID,createnew,flexID,delete);
        }



        public static bool SetFlexAsset(List<(string, string)> Parameters, string flexID,ITGlueRequestTypesFlexAsset flexType, object current, string orgId, bool CreateNew, bool delete = false)
        {
            Console.WriteLine("Creating/Updating Flex Asset");

           
            string content = "";
           
            content = setData(flexType, Parameters, current, orgId, flexID,CreateNew,delete);
           
            


            Console.WriteLine(content);
            
            return true;
        }

        public static bool UpdateNetwork(string orgId, Network currentNetwork)
        {
            List<(string, string)> Parameters = new List<(string, string)>();
            Parameters.Add(("filter[flexible_asset_type_id]", LAN.configTypeID));
            Parameters.Add(("filter[name]", currentNetwork.names[0]));
            Parameters.Add(("page[size]", "999"));
            Parameters.Add(("filter[organization_id]", orgId));
            string flexID = "";

            bool createnew = !GetFlexAsset(Parameters, LAN.configTypeID, out flexID, ITGlueRequestTypesFlexAsset.Network);
            Parameters = new List<(string, string)>();
            
            if (!createnew)
            {
          
            }
            SetFlexAsset(Parameters, flexID, ITGlueRequestTypesFlexAsset.Network, currentNetwork, orgId, createnew);

            return true;
        }




        public static bool UpdateVLAN(string orgId,string html)
        {
            List<(string, string)> Parameters = new List<(string, string)>();
            Parameters.Add(("filter[flexible_asset_type_id]", "40214"));
            Parameters.Add(("filter[name]", "VLAN Schema"));
            Parameters.Add(("page[size]", "999"));
            Parameters.Add(("filter[organization_id]", orgId));
            string flexID = "";

            bool createnew = !GetFlexAsset(Parameters, "40214", out flexID);
            Parameters = new List<(string, string)>();
            LAN current = new LAN();
            current.HTML = html;
            current.name = "VLAN Schema";
            if (!createnew)
            {
             
            }
            SetFlexAsset(Parameters, flexID,ITGlueRequestTypesFlexAsset.LAN, current,orgId, createnew);

            return true;
        }


       

        public static bool UpdateAttachment(string orgId, string FileLocation, string resourceID, string fileDisplayName, resourcetypes resourceType)
        {
            if (resourceType != resourcetypes.configurations)
            {
                Console.WriteLine("We only support updating configuration attachements.");
                return false;
            }
            
            List<(string, string)> Parameters = new List<(string, string)>();
           
            
            Parameters = new List<(string, string)>();
            Attachment current = new Attachment();
            Byte[] bytes = File.ReadAllBytes(FileLocation);
            current.File = Convert.ToBase64String(bytes);
            current.name = fileDisplayName;
            string attachmentID = "";
             bool createnew = !GetAttachmentID(orgId, resourceID, Fortigate.configTypeID.ToString(), "", out attachmentID, fileDisplayName);
            current.AttachmentID = attachmentID;

            if (!createnew)
            {
                DeleteAttachment(orgId, resourceID, attachmentID);
                createnew = true;
            }


            SetFlexAsset(Parameters, resourceID, ITGlueRequestTypesFlexAsset.Attachement, current, orgId, createnew);

            return true;
        }

        public static bool DeleteAttachment(string orgId, string resourceID, string AttachmentID)
        {
           

            List<(string, string)> Parameters = new List<(string, string)>();
         

            Parameters = new List<(string, string)>();
            Attachment current = new Attachment();
           
            current.AttachmentID = AttachmentID;

            

            SetFlexAsset(Parameters, resourceID, ITGlueRequestTypesFlexAsset.Attachement, current, orgId, true,true);

            return true;
        }


        public static bool GetAttachmentID(string orgId, string ConfigurationID, string configtypeID, string ManuFacturerID, out string configID, string fileDisplayName)
        {

            List<(string, string)> Parameters = new List<(string, string)>();
            
            Parameters.Add(("include", "attachments"));
            string content = requestData(ITGlueRequestTypesConfigurations.Configuration2Attachment, Parameters, new List<(string, string)>(),ConfigurationID);
          
            configID = "";
            string[] split = content.Split(new char[] { ',', '"', '/' ,':'});
            int index = HelperFunctions.FindLastIndexOf(split,fileDisplayName,split.Length -1);
            if (index == -1)
            {
                return false;
            } else
            {
                configID = split[index - 11];

                return true;
            }
        }



        public static bool UpdateModel(Model currentModel, out string modelID, string orgID,string manufacturerID)
        {
            modelID = "";

            bool createnew = GetModelID(currentModel.name, currentModel.Manufacturerid,out modelID);
            if (modelID == "Missing")
            {
                createnew = true;
            }
            List<(string, string)>  Parameters = new List<(string, string)>();
  
            if (!createnew)
            {
                
            }
            
            


            SetModel(Parameters, currentModel, orgID,createnew,manufacturerID,modelID);
            return true;
        }

        public static bool SetModel(List<(string, string)> Parameters, Model current, string orgId, bool CreateNew, string manufacturerID, string modelID)
        {
            Console.WriteLine("Creating/Updating model Asset");


            string content = "";
            //TODO: continue here

            string path = GetPath(ITGlueRequestTypesConfigurations.ITGLUEModel, manufacturerID, true);


            content = setData(path, Parameters, current, orgId, manufacturerID, modelID, CreateNew, "");

            GetModelID(current.name, manufacturerID, out modelID);


            Console.WriteLine(content);

            return true;
        }

    }


   



}
