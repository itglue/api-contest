using System;
using System.Collections.Generic;
using System.Text;

    class VLANColour
    {

    class ForeBackColour
    {
        public string ForegroundColour = "";
        public string BackgroundColour = "";

        public ForeBackColour()
        {

        }

        public ForeBackColour(string foreground, string background)
        {
            this.ForegroundColour = foreground;
            this.BackgroundColour = background;
        }

    }

    String[] cforeground = new string[15];
    String[] cbackground = new string[15];
    int t = 0;
    Dictionary<int, ForeBackColour> ColourTable = new Dictionary<int, ForeBackColour>();



    public VLANColour()
    {
        cforeground[0] = "#000000";
        cbackground[0] = "#C0392B";
        cforeground[1] = "#000000";
        cbackground[1] = "#9B59B6";
        cforeground[2] = "#000000";
        cbackground[2] = "#2980B9";
        cforeground[3] = "#000000";
        cbackground[3] = "#1ABC9C";
        cforeground[4] = "#000000";
        cbackground[4] = "#27AE60";
        cforeground[5] = "#000000";
        cbackground[5] = "#F1C40F";
        cforeground[6] = "#000000";
        cbackground[6] = "#E67E22";
        cforeground[7] = "#000000";
        cbackground[7] = "#BDC3C7";
        cforeground[8] = "#000000";
        cbackground[8] = "#7F8C8D";
        cforeground[9] = "#000000";
        cbackground[9] = "#2C3E50";
        cforeground[10] = "#ffffff";
        cbackground[10] = "#B03A2E";
        cforeground[11] = "#000000";
        cbackground[11] = "#6C3483";
        cforeground[12] = "#000000";
        cbackground[12] = "#2874A6";
        cforeground[13] = "#000000";
        cbackground[13] = "#117A65";
        cforeground[14] = "#000000";
        cbackground[14] = "#626567";



    }
    

    public String GetColour(int ID, bool isForeground)
    {
        ForeBackColour current = new ForeBackColour();
        if (ColourTable.TryGetValue(ID, out current))
        {
            if (isForeground)
            {
                return current.ForegroundColour;
            }
            else
            {
                return current.BackgroundColour;
            }
        }
        else
        {
            current = new ForeBackColour(cforeground[t], cbackground[t]);
            ColourTable.Add(ID, current);
            t++;
            if (t >= cforeground.Length)
            {
                t = 0;
            }

            if (isForeground)
            {
                return current.ForegroundColour;
            }
            else
            {
                return current.BackgroundColour;
            }

        }

    }



    }

