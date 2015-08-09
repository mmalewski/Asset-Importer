# Powershell script to create a text output that can be put in the Blender script engine to import
# Cryengine game assets into the proper position.
# Geoff Gerber, 2/25/2014 (markemp@gmail.com)
# 
# Version 0.9:  release for testing
# Version 0.92: Fixed problems with the wrong material being assigned
#               Now can make node groups for materials with no submaterials (like many of the purchasables)
# Version 1.0:  For use with .obj files created with cgf-converter.exe (https://github.com/Markemp/Cryengine-Converter/)

# No input necessary.  It will look for each .obj and .mtl file in the current directory, and create an import.py
# file that you can cut/paste into the python console.

# Input:  the directory to all the .obj files put in.

$basedir = "e:\blender projects\mechs"  # this is where you extracted all the *.pak files from the game. \objects, \textures etc
#$basedir = "e:\blender projects\Star Citizen"  
                                        # will be under this dir
$imageformat = ".dds"                   # Default image file format.  If you want to use .pngs, change this

# convert the path so it can be used by Blender
$basedir = $basedir.replace("\","\\")

# Python commands used by Blender
$scriptimport = "bpy.ops.import_scene.obj"
$scriptscene = "bpy.context.scene.objects.active"
$scriptrotationmode = "bpy.context.active_object.rotation_mode=`"QUATERNION`" "
$scriptrotation = "bpy.context.active_object.rotation_quaternion"
$scripttransform = "bpy.ops.transform.translate"
# $scriptremovedoubles = "bpy.ops.mesh.remove_doubles()"  No longer needed
# $scripttristoquads = "bpy.ops.mesh.tris_convert_to_quads()"  No longer needed
$scriptseteditmode = "bpy.ops.object.mode_set(mode = `"EDIT`")"
$scriptsetobjectmode = "bpy.ops.object.mode_set(mode = `"OBJECT`")"
#$scriptclearmaterial = "bpy.context.object.data.materials.pop(0, update_data=True)"
$scriptclearmaterial = "bpy.context.object.data.materials.clear(update_data=True)"   #only works with 2.69 or newer

"# Asset Importer 1.0" >> .\import.py
"#" >> .\import.py

# Set Blender to Cycles
"bpy.context.scene.render.engine = 'CYCLES'" >> .\import.py

foreach ($file in (get-childitem -filter *.mtl) ) {        # create material for each material in the .mtl files

    Write-Host "Material file is $file"

    # *** MATERIALS ***
    # Load up materials from the <mtl> file
    [xml]$matfile = get-content ($file)
    
    # Get the materials from $matfile and create them in Blender
    #  material append wants an object of type material, not a string.  Will have to generate that.
    #  Since we can't really generate a node layout at this time, we're just going to open the image files
    # so it's easier for the user to generate.

    # Yet another subloop added:  If there are no submaterials, it's a .mtl file with only one material, and material name doesn't exist. 
    # Handle it.

    if (!($matfile.Material.SubMaterials.Material)) { # Material file with no submaterials.
        #write-host "File is $file"
        #$material = $matfile.Material
        #Write-host "Material flag is $material.mtlflags"
        $matname = $file.name.Substring(0,($file.tostring().Length-4))   # make $matname the name of the material file
        " " >> .\import.py
        "### Material:  $matname" >> .\import.py

        "$matname=bpy.data.materials.new('$matname')"  >> .\import.py
        "$matname.use_nodes=True" >> .\import.py
        #"bpy.context.object.active_material_index = 0" >> .\import.py
        "$matname.active_node_material" >> .\import.py
        "TreeNodes = $matname.node_tree" >> .\import.py
        "links = TreeNodes.links" >> .\import.py

        "for n in TreeNodes.nodes:" >> .\import.py
        "    TreeNodes.nodes.remove(n)" >> .\import.py
        " " >> .\import.py

        $matfile.Material.Textures.texture | % {
            #write-host "Texture is $_"
            if ( $_.Map -eq "Diffuse") {
                $matdiffuse = $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\")  #assumes diffuse is in slot 0
                "matDiffuse = bpy.data.images.load(filepath=`"$basedir\\$matdiffuse`")" >> .\import.py
                "shaderDiffuse=TreeNodes.nodes.new('ShaderNodeBsdfDiffuse')" >> .\import.py
                "shaderMix=TreeNodes.nodes.new('ShaderNodeMixShader')" >> .\import.py
                "shout=TreeNodes.nodes.new('ShaderNodeOutputMaterial')" >> .\import.py
                "shaderDiffImg=TreeNodes.nodes.new('ShaderNodeTexImage')" >> .\import.py
                "shaderDiffImg.image=matDiffuse" >> .\import.py
                "shaderDiffuse.location = 100,500" >> .\import.py
                "shout.location = 500,400" >> .\import.py
                "shaderMix.location = 300,500" >> .\import.py
                "shaderDiffImg.location = -100,500" >> .\import.py
                "links.new(shaderDiffuse.outputs[0],shaderMix.inputs[1])" >> .\import.py
                "links.new(shaderMix.outputs[0],shout.inputs[0])" >> .\import.py
                "links.new(shaderDiffImg.outputs[0],shaderDiffuse.inputs[0])" >> .\import.py
                }
                        
            if ($_.Map -eq "Specular") {
                $matspec =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
                "matSpec=bpy.data.images.load(filepath=`"$basedir\\$matspec`")" >> .\import.py
                "shaderSpec=TreeNodes.nodes.new('ShaderNodeBsdfGlossy')" >> .\import.py
                "shaderSpecImg=TreeNodes.nodes.new('ShaderNodeTexImage')" >> .\import.py
                "shaderSpecImg.image=matSpec" >> .\import.py
                "shaderSpec.location = 100,300" >> .\import.py
                "shaderSpecImg.location = -100,300" >> .\import.py
                "links.new(shaderSpec.outputs[0],shaderMix.inputs[2])" >> .\import.py
                "links.new(shaderSpecImg.outputs[0],shaderSpec.inputs[0])" >> .\import.py
                }   
                    
            if ($_.Map -eq "Bumpmap") {
                $matnormal =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
                "matNormal=bpy.data.images.load(filepath=`"$basedir\\$matnormal`")" >> .\import.py
                "shaderNormalImg=TreeNodes.nodes.new('ShaderNodeTexImage')" >> .\import.py
                "shaderRGBtoBW=TreeNodes.nodes.new('ShaderNodeRGBToBW')" >> .\import.py
                "shaderNormalImg.image=matNormal" >> .\import.py
                "shaderNormalImg.location = -100,100" >> .\import.py
                "shaderRGBtoBW.location = 100,100" >> .\import.py
                "links.new(shaderNormalImg.outputs[0],shaderRGBtoBW.inputs[0])" >> .\import.py
                "links.new(shaderRGBtoBW.outputs[0],shout.inputs[2])" >> .\import.py
            }
        }

    } else {
        $matfile.Material.SubMaterials.Material| % {
            $material = $_
            $matname = $material.Name   # $matname is the name of the material
            " " >> .\import.py
            "### Material:  $matname" >> .\import.py

            if (!($matname -eq "Proxy") ) {
                "$matname=bpy.data.materials.new('$matname')"  >> .\import.py
                "$matname.use_nodes=True" >> .\import.py
                #"bpy.context.object.active_material_index = 0" >> .\import.py
                "$matname.active_node_material" >> .\import.py
                "TreeNodes = $matname.node_tree" >> .\import.py
                "links = TreeNodes.links" >> .\import.py

                "for n in TreeNodes.nodes:" >> .\import.py
                "    TreeNodes.nodes.remove(n)" >> .\import.py
                " " >> .\import.py

                write-host "Material Name is $matname"
                $_.textures.Texture  | % {
                    if ( $_.Map -eq "Diffuse") {
                        $matdiffuse = $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\")  #assumes diffuse is in slot 0
                        "matDiffuse = bpy.data.images.load(filepath=`"$basedir\\$matdiffuse`")" >> .\import.py
                        "shaderDiffuse=TreeNodes.nodes.new('ShaderNodeBsdfDiffuse')" >> .\import.py
                        "shaderMix=TreeNodes.nodes.new('ShaderNodeMixShader')" >> .\import.py
                        "shout=TreeNodes.nodes.new('ShaderNodeOutputMaterial')" >> .\import.py
                        "shaderDiffImg=TreeNodes.nodes.new('ShaderNodeTexImage')" >> .\import.py
                        "shaderDiffImg.image=matDiffuse" >> .\import.py
                        "shaderDiffuse.location = 100,500" >> .\import.py
                        "shout.location = 500,400" >> .\import.py
                        "shaderMix.location = 300,500" >> .\import.py
                        "shaderDiffImg.location = -100,500" >> .\import.py
                        "links.new(shaderDiffuse.outputs[0],shaderMix.inputs[1])" >> .\import.py
                        "links.new(shaderMix.outputs[0],shout.inputs[0])" >> .\import.py
                        "links.new(shaderDiffImg.outputs[0],shaderDiffuse.inputs[0])" >> .\import.py
                        }
                        
                    if ($_.Map -eq "Specular") {
                        $matspec =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
                        "matSpec=bpy.data.images.load(filepath=`"$basedir\\$matspec`")" >> .\import.py
                        "shaderSpec=TreeNodes.nodes.new('ShaderNodeBsdfGlossy')" >> .\import.py
                        "shaderSpecImg=TreeNodes.nodes.new('ShaderNodeTexImage')" >> .\import.py
                        "shaderSpecImg.image=matSpec" >> .\import.py
                        "shaderSpec.location = 100,300" >> .\import.py
                        "shaderSpecImg.location = -100,300" >> .\import.py
                        "links.new(shaderSpec.outputs[0],shaderMix.inputs[2])" >> .\import.py
                        "links.new(shaderSpecImg.outputs[0],shaderSpec.inputs[0])" >> .\import.py
                        }   
                    
                    if ($_.Map -eq "Bumpmap") {
                        $matnormal =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
                        "matNormal=bpy.data.images.load(filepath=`"$basedir\\$matnormal`")" >> .\import.py
                        "shaderNormalImg=TreeNodes.nodes.new('ShaderNodeTexImage')" >> .\import.py
                        "shaderRGBtoBW=TreeNodes.nodes.new('ShaderNodeRGBToBW')" >> .\import.py
                        "shaderNormalImg.image=matNormal" >> .\import.py
                        "shaderNormalImg.location = -100,100" >> .\import.py
                        "shaderRGBtoBW.location = 100,100" >> .\import.py
                        "links.new(shaderNormalImg.outputs[0],shaderRGBtoBW.inputs[0])" >> .\import.py
                        "links.new(shaderRGBtoBW.outputs[0],shout.inputs[2])" >> .\import.py
                    }
                }  # foreach texture
            }  # !proxy
        } # Foreach submat
    }
}

# Get a list of the materials created; they will be needed
"materialList = []" >> .\import.py
"for m in bpy.data.materials:" >> .\import.py
"    materialList.append(m.name)" >> .\import.py
" " >> .\import.py

#  *** PARSING OBJs ***
#  Start parsing out the different object files in the directory.
foreach ($file in (Get-ChildItem -filter "*.obj")) {
    #  import each obj file
    # Time to generate the commands (in $parsedline, an array)
    " " >> .\import.py
    "### Importing $file.name" >> .\import.py
	$parsedline = @()
    $directory = $file.DirectoryName.Replace("\","\\")
    $filename = $file.Name
    $objectname = $filename.Substring(0,($filename.Length-4))

    # convert file to filepath for Blender

    # if it's a cockpit item, it'll have multiple groups.  to avoid screwing up naming, we will import these keeping the vertex
    # order with split_mode('OFF').  

    $parsedline += $scriptimport + "(filepath=`"$directory\\$filename`",use_groups_as_vgroups=True,split_mode=`'OFF`',axis_forward=`'-X`',axis_up=`'Z`')" 
    #$parsedline += $scriptimport + "(filepath=`"$directory\\$filename`",use_groups_as_vgroups=False)" 

    # set new object as the active object
    # $parsedline += $scriptscene + "=bpy.data.objects[`"$objectname`"]"
    # Parent the object to the Armature:  Assumes armature name is Armature and that it's been imported!
    # $parsedline += $scriptscene + "=bpy.data.objects[`"Armature`"]"
    # Set $objectname to active object
    $parsedline += $scriptscene + "=bpy.data.objects[`"$objectname`"]"
    # $parsedline += $scriptclearmaterial
    # Most of the lines below aren't needed since the object is rotated properly when imported, and materials just work.
	#$parsedline += $scriptrotationmode 
	#$parsedline += $scriptrotation + "=[270,0,0,0]"
	#$parsedline += $scripttransform + "(value=($position))"
	#$parsedline += $scriptseteditmode
	# Check to see if it's a cockpit item, and if so don't remove doubles! (from mech-importer. skip for asset importer)
    #if ( !$objectname.Contains("cockpit")) {
        #$parsedline += $scriptremovedoubles }

	#$parsedline += $scripttristoquads
    #$parsedline += "bpy.ops.mesh.select_all(action=`'SELECT`')"
    #$parsedline += "bpy.ops.object.vertex_group_assign()"
    #$parsedline += "bpy.ops.mesh.select_all(action=`'TOGGLE`')"

	#$parsedline += $scriptsetobjectmode

	foreach ( $line in $parsedline ) {
		#write-host $line
		$line >> .\import.py
	}
}

" " >> .\import.py # Send a final line feed.
