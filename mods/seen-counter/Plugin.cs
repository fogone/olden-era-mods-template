using System.Collections.Generic;
using BepInEx;
using Nobirds.OldenEra.Modding.Common;

namespace Example.SeenCounter;

// Counts how many times you looked at each thing (by its tooltip's header) since the map was loaded, and says so at
// the top or the bottom of the tooltip (a choice in Settings -> Mods).
[BepInPlugin(ModInfo.Id, ModInfo.Name, ModInfo.Version)]
public class Plugin : ModBase
{
    enum Place { Bottom, Top, Off }                         // the options, in this order: oe.seencounter.Place.Bottom ...

    Choice<Place> place;
    readonly Dictionary<string, int> seen = new();

    protected override void OnLoad()
    {
        place = Menu.Choose("Place", Place.Bottom);
        On(ModEvents.MapLoaded, _ => seen.Clear());         // a new map: counted from zero
        On(ModEvents.TooltipTexts, AddLine);                // a tooltip is about to show its texts: they may be changed
    }

    void AddLine(TooltipTexts texts)
    {
        var where = place.Value(whenOff: Place.Off);         // Off as well while the mod is switched off
        if (where == Place.Off || string.IsNullOrEmpty(texts.Header))
            return;
        seen[texts.Header] = seen.TryGetValue(texts.Header, out var times) ? times + 1 : 1;
        // The texts are the game's language: Texts.Get looks up our key in the game's localization.
        var line = $"<color=#A6A6A6>{string.Format(Texts.Get("oe.seencounter.Line"), seen[texts.Header])}</color>";
        texts.Content = where == Place.Top
            ? line + "\n" + texts.Content
            : texts.Content + "\n" + line;
    }
}
