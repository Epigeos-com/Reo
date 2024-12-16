namespace Reo
{
    internal class Events
    {
        public static IJSRuntime JSRuntime;

        public static void AddEvent(DateTime firstDateGregorian, DateTime? lastDateGregorian, Dates.CalendarType calendar, Dates.CalendarTypeSetting repeatsCalendar, string repeats, string title, string backgroundColor, string textColor, List<ValueTuple<int, int, int>> notifications)
        {
            // all string inputs should use .Replace(';', ';') (the second one is a Greek question mark) to avoid input semicolons to be counted as end of argument
            title ??= "";
            backgroundColor ??= "";
            textColor ??= "";

            var fileName = "/events.data";
            if (repeats.StartsWith('$'))
            {
                repeats = repeats[1..];
                fileName = "/complexEvents.data";
            }
            File.AppendAllText(Settings.envPath + fileName, $"\n{firstDateGregorian};{lastDateGregorian};{(int)calendar};{(int)repeatsCalendar};{repeats};{title.Replace(';', ';')};{backgroundColor.Replace(';', ';')};{textColor.Replace(';', ';')}");
            if (fileName == "/complexEvents.data") PresaveComplexEvents(new(2020, 1, 1), new(2030, 1, 1));
        }
        public static void AddEvent(DateTime firstDateGregorian, Dates.CalendarType calendar, string title, string backgroundColor, string textColor, List<ValueTuple<int, int, int>> notifications)
        {
            // all string inputs should use .Replace(';', ';') (the second one is a Greek question mark) to avoid input semicolons to be counted as end of argument
            title ??= "";
            backgroundColor ??= "";
            textColor ??= "";
            File.AppendAllText(Settings.envPath + "/events.data", $"\n{firstDateGregorian};{firstDateGregorian};{(int)calendar};;;{title.Replace(';', ';')};{backgroundColor.Replace(';', ';')};{textColor.Replace(';', ';')}");
        }
        public static void RemoveEvent(string ev)
        {
            var fileName = ev.EndsWith('|') ? "/complexEvents.simplified.data" : "/events.data";
            var lines = File.ReadAllLines(Settings.envPath + fileName).ToList();
            lines.Remove(ev);
            File.WriteAllText(Settings.envPath + fileName, string.Join('\n', lines));
        }

        public static string[] GetViableEventsForDate(DateTime gregorianDate, string fileName = "events.data")
        {
            return GetViableEventsForDate(gregorianDate, gregorianDate, fileName);
        }
        public static string[] GetViableEventsForDate(DateTime firstGregorianDate, DateTime lastGregorianDate, string fileName = "events.data")
        {
            try
            {
                var events = File.ReadAllLines(Settings.envPath + "/" + fileName);
            Astronomy.JSRuntime.InvokeVoidAsync("console.log","qa: " + Settings.envPath + "/" + fileName);
            Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qb: " + string.Join('\n', events) + " : " + Settings.envPath + "/" + fileName);
                return events.Where(element =>
                {
                    try
                    {
                        Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qba: " + element + " : " + Settings.envPath + "/" + fileName);
                        if (element.StartsWith("//")) return false;
                        Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qbb: " + element + " : " + Settings.envPath + "/" + fileName);
                        if (element.Split(';', 3)[1].StartsWith('-')) return element.Split(';', 3)[1] switch
                        {
                            "-international" => Settings.internationalSDE,
                            "-christian" => Settings.christianSDE,
                            "-hellenic" => Settings.hellenicReligiousSDE,
                            _ => true
                        };
                        Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qc: " + element + " : " + Settings.envPath + "/" + fileName);

                        var l = element.Split(';', 3);
                        var startingDate = Dates.FloorDateTime(DateTime.Parse(l[0]), Settings.primaryCalendar);
                        if (startingDate.Date > lastGregorianDate.Date) return false;
                        Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qd: " + element + " : " + Settings.envPath + "/" + fileName);

                        if (string.IsNullOrEmpty(l[1])) return true;
                        Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qe: " + element + " : " + Settings.envPath + "/" + fileName);
                        var endingDate = Dates.FloorDateTime(DateTime.Parse(l[1]), Settings.primaryCalendar);
                        return endingDate.Date >= firstGregorianDate.Date;
                    }
                    catch
                    {
                        return false;
                    }
                }).ToArray();
            }
            catch
            {
                return Array.Empty<string>();
            }
        }
        public static string[] GetEventsForDay(DateTime gregorianDate)
        {
            var events = GetViableEventsForDate(gregorianDate).ToList();
            Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qp: " + string.Join('\n', events));
            events.AddRange(GetViableEventsForDate(gregorianDate, "complexEvents.simplified.data"));
            Astronomy.JSRuntime.InvokeVoidAsync("console.log", "qp: " + string.Join('\n', events));

            List<string> relevantEvents = new();
            foreach (var ev in events)
            {
                try
                {
                    var arguments = ev.ToLower().Split(';');

                    bool isRepeatTrue = true;
                    if (arguments[4] != "")
                    {
                        var repeatCalendar = Dates.ConvertCalendarTypeSetting(int.Parse(arguments[3]));
                        var date = Dates.GregorianToDate(repeatCalendar, gregorianDate, true, false);

                        foreach (var repeatFormula in arguments[4].Split('&'))
                        {
                            var conditionArgs = repeatFormula.Split('-');
                            if (conditionArgs[0] == "where")
                            {
                                int value = conditionArgs[1] switch
                                {
                                    "month" => date.Item2,
                                    _ => (int)Math.Floor(date.Item3)
                                };
                                if (value != int.Parse(conditionArgs[2]))
                                {
                                    isRepeatTrue = false;
                                    break;
                                }
                            }
                            else // every
                            {
                                DateTime gregorianFirstDate = DateTime.Parse(arguments[0]);
                                var result = 0;
                                if (conditionArgs.Length > 3)
                                {
                                    result = int.Parse(conditionArgs[3]);
                                }

                                bool meetsCondition = false;
                                if (conditionArgs[1] == "day")
                                {
                                    meetsCondition = Math.Floor((gregorianFirstDate - gregorianDate).TotalDays) % int.Parse(conditionArgs[2]) == result;
                                }
                                else
                                {
                                    var firstDate = Dates.GregorianToDate(repeatCalendar, gregorianFirstDate, true, false);
                                    if (date.Item3 == firstDate.Item3 && date.Item2 == firstDate.Item2) meetsCondition = (date.Item1 - firstDate.Item1) % int.Parse(conditionArgs[2]) == result;
                                }

                                if (!meetsCondition)
                                {
                                    isRepeatTrue = false;
                                    break;
                                }
                            }
                        }
                    }
                    if (isRepeatTrue) relevantEvents.Add(ev);
                } catch { }
            }

            if (Settings.newMoonsSDE){
                var newMoon = Astronomy.GetClosestMoonPhase(gregorianDate.Date, true);
                if (Dates.FloorDateTime(newMoon, Settings.primaryCalendar).Date == gregorianDate.Date) relevantEvents.Add($"default;newMoons;;;;New moon ({newMoon.Hour:00}:{newMoon.Minute:00});;");
            }
            if (Settings.fullMoonsSDE)
            {
                var fullMoon = Astronomy.GetClosestMoonPhase(gregorianDate.Date, true, 2);
                if (Dates.FloorDateTime(fullMoon, Settings.primaryCalendar).Date == gregorianDate.Date) relevantEvents.Add($"default;fullMoons;;;;Full moon ({fullMoon.Hour:00}:{fullMoon.Minute:00});;");
            }
            if (Settings.solsticesEqinoxesSDE)
            {

            }

            return relevantEvents.ToArray();
        }


        public static void PresaveComplexEvents(DateTime firstDate, DateTime lastDate)
        {
            var complexEvents = GetViableEventsForDate(firstDate, lastDate, "complexEvents.data");
                    Astronomy.JSRuntime.InvokeVoidAsync("console.log", "ea: " + string.Join('\n', complexEvents));
            List<string> simpleEvents = new();

            foreach (var ev in complexEvents)
            {
                    Astronomy.JSRuntime.InvokeVoidAsync("console.log", "ey: " + ev);
                var arguments = ev.Split(';');

                var results = EvaluateComplexExpression(arguments[4], Dates.ConvertCalendarTypeSetting(int.Parse(arguments[3])), firstDate, lastDate);
                    Astronomy.JSRuntime.InvokeVoidAsync("console.log", "je: " + string.Join('\n', results) + "\n" + ev);
                foreach (var result in results)
                {
                    arguments[4] = "";
                    arguments[0] = arguments[1] = result.ToString();
                    simpleEvents.Add($"{string.Join(';', arguments)};{arguments[0]}|{arguments[1]}|{arguments[4]}");
                }
            }
            File.WriteAllText(Settings.envPath + "/complexEvents.simplified.data", string.Join('\n', simpleEvents));
        }

        delegate DateTime GetClosestDel(DateTime dateTime, bool isForward = true, int phase = 0);
        public static DateTime[] EvaluateComplexExpression(string expression, Dates.CalendarType calendar, DateTime firstDate, DateTime lastDate)
        {
            bool isTopLevel = false;
            int currentTopStartingIndex = 0;
            int currentTopLength = 0;
            List<int> topParenthesesIndex = new();
            List<int> topParenthesesLength = new();

            for (int i = 0; i < expression.Length; i++)
            {
                var character = expression[i];
                currentTopLength++;
                if (character == '(')
                {
                    currentTopStartingIndex = i;
                    currentTopLength = 0;
                    isTopLevel = true;
                }
                else if (character == ')')
                {
                    if (isTopLevel)
                    {
                        topParenthesesIndex.Add(currentTopStartingIndex);
                        topParenthesesLength.Add(currentTopLength);
                    }
                    isTopLevel = false;
                }
            }
            var newExpression = expression;
            int offset = 0;
            for (int i = 0; i < topParenthesesIndex.Count; i++)
            {
                var newIndex = offset + topParenthesesIndex[i];
                var currentExpression = expression.Substring(topParenthesesIndex[i] + 1, topParenthesesLength[i] - 1);

                var expressionValue = EvaluateExpressionWithoutParentheses(currentExpression, calendar, firstDate, lastDate);
                offset += expressionValue.ToString().Length - topParenthesesLength[i] - 1;
                newExpression = newExpression.Remove(newIndex, topParenthesesLength[i] + 1).Insert(newIndex, expressionValue.ToString());
            }

            if (newExpression.Contains('('))
            {
                return EvaluateComplexExpression(newExpression, calendar, firstDate, lastDate);
            }
            else
            {
                return EvaluateExpressionWithoutParentheses(newExpression, calendar, firstDate, lastDate);
            }

            DateTime[] EvaluateExpressionWithoutParentheses(string expression, Dates.CalendarType calendar, DateTime firstDate, DateTime lastDate)
            {
                List<DateTime> simpleEvents = new();
                for (int i = 0; i < Math.Floor((lastDate.AddDays(400) - firstDate.AddDays(-400)).TotalDays); i += 28)
                {
                    var ev = EvaluateExpressionWithoutParenthesesForDate(firstDate.AddDays(i - 400), expression, calendar);
                    Astronomy.JSRuntime.InvokeVoidAsync("console.log", "ma: " + firstDate.AddDays(i - 400) + "\nmb: " + (ev > firstDate) + "\nmc: " + (ev < lastDate) + "\nmd: " + ev);
                    if (ev > firstDate && ev < lastDate) simpleEvents.Add(ev);
                }
                return simpleEvents.ToArray();

                DateTime EvaluateExpressionWithoutParenthesesForDate(DateTime dateTime, string expression, Dates.CalendarType calendar)
                {
                    var segments = expression.ToLower().Split('/');

                    DateTime referenceDateTime = dateTime;
                    int action = 0; // 0-next, 1-previous, 2-closest, 3-and, 4-or, 
                    for (int i = 0; i < segments.Length; i++)
                    {
                        var arguments = segments[i].Split(':');
                        switch (arguments[0])
                        {
                            case "next": action = 0; segments[i] = ""; break;
                            case "previous": action = 1; segments[i] = ""; break;
                            case "closest": action = 2; segments[i] = ""; break;
                            case "and": action = 3; segments[i] = ""; break;
                            case "or": action = 4; segments[i] = ""; break;

                            default:
                                if (DateTime.TryParse(arguments[0], out var outputDateTime))
                                {
                                    referenceDateTime = outputDateTime;
                                    segments[i] = "";
                                }
                                else segments[i] = EvaluateFunction(arguments).ToString();
                                break;
                        }
                    }
                    var newExpression = string.Join(':', segments);
                    if (DateTime.TryParse(newExpression, out var value)) return value;
                    else return EvaluateExpressionWithoutParenthesesForDate(dateTime, newExpression, calendar);

                    DateTime EvaluateFunction(string[] arguments)
                    {
                        GetClosestDel del = arguments[0] switch
                        {
                            "moon" => Astronomy.GetClosestMoonPhase,
                            _ => Astronomy.GetClosestSunPhase
                        };

                        if (action == 0)
                        {
                            return del(referenceDateTime, true, int.Parse(arguments[1]));
                        }
                        else if (action == 1)
                        {
                            return del(referenceDateTime, false, int.Parse(arguments[1]));
                        }
                        else if (action == 2)
                        {
                            var prev = del(referenceDateTime, false, int.Parse(arguments[1]));
                            var next = del(referenceDateTime, true, int.Parse(arguments[1]));
                            if (referenceDateTime - prev < next - referenceDateTime) return prev;
                            else return next;
                        }
                        else if (action == 3)
                        {
                            return del(referenceDateTime, true, 0); //
                        }
                        else // (action == 4)
                        {
                            return del(referenceDateTime, true, 0); //
                        }
                    }
                }
            }
        }
    }
}
