## Asset-Importer
Used to help convert .dae files from Cryengine into something Blender can use more effectively.

**BE SURE TO USE THE -objectdir ARG.**

```powershell
Usage:  asset-importer.ps1 [-objectdir "<directory to \Object>"] <[-dae]|[-obj]> <-imageformat [dds|tif]>"
        Goes through a directory looking for .dae files created from cgf-converter and makes"
        an import.txt file with the import information for all the files in the directory.  This"
        can be pasted into the Blender python console.  This will also create the proper Cycles "
        material for each of the objects imported."

        Please update the script before running.  The following variables need to be properly defined:"
             `$basedir:  Where you extracted the object.pak files (and skins)"
             `$imageformat:  What image format you are using (default .dds)"

        This will only fully work when imported into Blender 2.79 or newer, as it uses the PrincipledBSDF shader."
```
