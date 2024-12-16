using System;
using Reo;

namespace ReoClient
{
    public class Program
    {
        public static void Main(){
            var jd = Astronomy.GregorianToJD(new ValueTuple<int, int, double>(2024, 10, 1.32));
            Console.WriteLine(Astronomy.GetTimeOfSunTransitRiseSet(jd, 0, true, true, true));
        }
    }
}