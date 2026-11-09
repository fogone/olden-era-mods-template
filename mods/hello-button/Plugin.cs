using BepInEx;
using Hex.UI.GeneralKit;
using Nobirds.OldenEra.Modding.Common;

namespace Example.HelloButton;

// A button under "Load" in the main menu; a click opens the game's own message box. A switch in Settings -> Mods
// hides the button.
[BepInPlugin(ModInfo.Id, ModInfo.Name, ModInfo.Version)]   // ModInfo: written by the SDK from the csproj
public class Plugin : ModBase
{
    const string ButtonName = "EX_HelloButton";            // the scene object's name: its prefix is in ObjectPrefixes

    Switch shown;
    BhNavigationButton button;

    // Objects whose names start so are destroyed when the mod unloads (switched off, updated, removed).
    protected override string[] ObjectPrefixes => new[] { "EX_Hello" };

    protected override void OnLoad()
    {
        shown = Menu.Toggle("Shown", true);                 // texts: oe.hellobutton.Shown and .Shown.desc
        OnTick(Tick);                                       // every frame, on the main thread
    }

    void Tick()
    {
        if (!shown.On)                                      // switched off (or the mods do not work in this game)
        {
            Remove();
            return;
        }
        // Only in the main menu; a new main menu (back from a game) has no button: it is added again.
        if (button == null && MainMenu.View != null)
            button = MainMenu.AddButton(ButtonName, "oe.hellobutton.Button", SayHello, view => view.loadButton);
    }

    void SayHello() =>
        GameBoxes.Tell(Texts.Get("oe.hellobutton.title"), Texts.Get("oe.hellobutton.Hello"), Texts.Get("oe.hellobutton.Ok"), onOk: null);

    void Remove()
    {
        if (button != null)
            MainMenu.Remove(button);
        button = null;
    }

    protected override void OnUnload() => Remove();
}
