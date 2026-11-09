# Olden Era mods: a template

A starting point for your own set of mods for **Heroes of Might and Magic: Olden Era** (BepInEx 6, IL2CPP), built on
the [Olden Era mods](https://github.com/fogone/olden-era-mods) framework, and a catalog of them that players install
from the game: main menu → **Mods**. Not affiliated with the game's publishers.

What is here:

```
mods/hello-button/        a mod without the core: a button in the main menu opening the game's message box
mods/seen-counter/        a mod on the core's events: a line added to the map's tooltips, a choice in the settings
catalog/                  your catalog (made by release.ps1 on the first release): the mod manager reads it
Directory.Build.props     your name and repository, for every mod
global.json               the SDK's version (Nobirds.OldenEra.Modding.Sdk on nuget.org)
.config/dotnet-tools.json the catalog tool (oe-catalog)
release.ps1               build, try in the game, release
```

## 1. Start

1. **Use this template** (the green button on GitHub) or fork it, and clone your repository.
2. In `Directory.Build.props` put your name (`ModAuthor`) and your repository's address (`ModSource`).
3. In each mod's csproj, change `example` in `ModId` to your name (`yourname.oldenera.hellobutton`), and the
   `AssemblyName` and `RootNamespace` to yours.

You need:

- **The game**, with **BepInEx 6.0.0-be.788 (IL2CPP x64)** unpacked into its folder (the one with
  `HeroesOldenEra.exe`, <https://builds.bepinex.dev/projects/bepinex_be>), started once to the main menu: BepInEx then
  makes the wrappers of the game's code your mods compile against (`BepInEx\interop`). After a game patch, start it
  once more.
- **The Olden Era mod manager** in the game (its [releases](https://github.com/fogone/olden-era-mods/releases)): it
  installs the framework's library your mods run on, and the mod core.
- **The .NET SDK 10** (<https://dotnet.microsoft.com/download>). The mods target .NET 6, the game's runtime; nothing of
  the game is downloaded: it builds against your installed game.

The SDK finds a Game Pass install (`C:`, `D:`, `E:` `\XboxGames`) and tries Steam's default library. Anywhere else, set the
environment variable `OLDENERA_GAME` to the game's folder (or pass `-GameDir` to `release.ps1`).

## 2. Build and try

```powershell
.\release.ps1                         # the packages: mods\<mod>\bin\Release\net6.0\<id>-<version>.zip
.\release.ps1 -Install                # and the DLLs into <game>\BepInEx\plugins (close the game first)
```

Start the game: the mods are in Settings → **Mods** (their switches) and in the **Mods** window as installed by hand.
Their log lines are in `<game>\BepInEx\LogOutput.log`, under the mod's name. To remove a mod you tried, delete its DLL
from `BepInEx\plugins`.

## 3. A mod of your own

Copy a mod's folder (`hello-button` without the core, `seen-counter` with it) and change its csproj:

```xml
<Project Sdk="Nobirds.OldenEra.Modding.Sdk">
  <PropertyGroup>
    <AssemblyName>YourName.MyMod</AssemblyName>
    <RootNamespace>YourName.MyMod</RootNamespace>
    <ModId>yourname.oldenera.mymod</ModId>          <!-- the BepInEx GUID: never change it once released -->
    <ModName>My mod</ModName>
    <Version>0.1.0</Version>                        <!-- raise it for every release -->
    <ModTags>map;tooltip</ModTags>                  <!-- the catalog's tags, the Mods window filters by them -->
    <ModRequires>nobirds.oldenera.core</ModRequires><!-- only when it uses the core's events (ModEvents) -->
  </PropertyGroup>
</Project>
```

The SDK references the game, BepInEx and the library, embeds `lang\*.json`, writes `ModInfo` (`Id`, `Name`,
`Version`) for the plugin's attribute, and `-t:ModPackage` makes the package: the zip with `manifest.json` (what the mod
is, its names and descriptions in every language, the game version it was built on) and the DLL under `plugins/`. The
mod manager installs exactly that.

**The plugin** derives from `ModBase`:

```csharp
[BepInPlugin(ModInfo.Id, ModInfo.Name, ModInfo.Version)]
public class Plugin : ModBase
{
    Switch on;
    protected override void OnLoad()
    {
        on = Menu.Toggle("Shown", true);                         // a switch in Settings -> Mods
        On(ModEvents.MapLoaded, _ => Logs.Info("a map"));        // the core's events
        OnTick(() => { if (on.On) { /* every frame */ } });
    }
}
```

- Use `OnLoad`/`OnUnload`, patch with the base class's `Harmony`, never `new Harmony`: the base class undoes it all
  when the mod is switched off, updated or removed, without restarting the game. Put back what you changed in the
  game's objects in `OnUnload`; name the objects you create with a prefix you return from `ObjectPrefixes`.
- Read a switch where it is used (`on.On`): it is false while the mod is off, and in online games and replays, where
  mods never work.
- Do not write `MonoBehaviour`s of your own (a reloaded build cannot register the class again): use `OnTick`.

**Texts**: every string the player sees is a key in `lang\<language>.json` (`english`, `russian`, `german`, `zhcn`,
...; a missing language falls back to English), never a literal in code. The keys are `oe.<the last part of ModId>.*`, so make that
last part your own (`yournamemymod` rather than `tooltips`): every mod's texts share the game's table.

| Key | What |
|---|---|
| `oe.mymod.title` (for `yourname.oldenera.mymod`) | the mod's name (the Mods window, the settings, the catalog) |
| `oe.mymod.description` | one or two sentences on what it does (the Mods window, the catalog) |
| `oe.mymod.<Key>`, `.<Key>.desc` | a switch's label and hover text (`Menu.Toggle("<Key>", ...)`) |
| `oe.mymod.<Key>.<Value>` | a choice's options (`Menu.Choose("<Key>", MyEnum.Value)`) |

In code: `Texts.Get("oe.mymod.Key")`, the text in the game's language.

**The framework**: the library's public API works across game patches (a new library comes with each patch):

- `ModBase`, `ModMenu` (`Toggle`, `Choose`), `Texts`, `Logs`;
- the core's events, `ModEvents`: `MapLoaded`, `MapClosed`, `HeroSelected`, `LanguageChanged`, `AltInfo`,
  `TooltipTexts` (change a tooltip's texts), `TooltipShown`, `SquadTooltipFilled`, `SkullsFilled`,
  `DwellingTooltipFilled`, `EncounterStarting`/`Encounter`, `ForecastShown`, `CounterDecided`;
- UI from the game's own widgets: `MainMenu` (a button), `GameBoxes` (message and input boxes), `ModScreen` (a screen
  of yours), `SettingsTab`, `SaveRow`, `Pictures`, `UiLayout`;
- the game's own classes through BepInEx's wrappers (`Hex.*`, `UnityEngine.*`): the readable ones (`Hex.UI...`) stay
  across patches, the obfuscated ones (`abc.xyz`) change with every patch, so leave those to the library.

The details: [writing a mod](https://github.com/fogone/olden-era-mods/blob/main/docs/writing-a-mod.md) (sections 3 and
5), and the library's sources in that repository (`mod-common`).

## 4. Release: your catalog

```powershell
gh auth login                                     # once: GitHub's command line, https://cli.github.com
.\release.ps1 -Publish -CatalogName "Your mods"   # the first time; later: .\release.ps1 -Publish
```

For each mod whose version is not released yet it makes a GitHub release `<id>-v<version>` with the package, adds it to
`catalog\` (`dotnet oe-catalog`, the tool from `.config/dotnet-tools.json`), commits and pushes the catalog to `main`.

**Players** add your catalog in the game: Mods → **Sources** → add `your-name/your-repo` (the manager reads
`catalog/catalog.json` from the repository's default branch). Your mods then show in the Catalog tab, with their
updates.

- A version is released once: change a mod, raise its `<Version>`, release again.
- A package is built for the game version on your machine: after a game patch, update the game (and the mod manager),
  rebuild and release a new version, so the catalog has a build for the new game version.
- The catalog's format and options (an icon, screenshots): [catalog.md](https://github.com/fogone/olden-era-mods/blob/main/docs/catalog.md),
  `dotnet oe-catalog` without arguments.

## Rules worth keeping

- **Use the game's own functions**, do not rewrite its logic: a tooltip, a calculation, a widget is best taken from the
  game itself.
- **No advantage online**: the framework keeps mods off in online games and replays; do not work around it.
- **Hidden numbers** (exact counts, chances) off by default, behind a switch.

MIT. Questions and ideas: [the framework's issues](https://github.com/fogone/olden-era-mods/issues).
