# Powershell script to create a text output that can be put in the Blender script engine to import
# Cryengine game assets into the proper position.
# Geoff Gerber, 2/25/2014 (markemp@gmail.com)
# 
# Version 0.9:  release for testing
# Version 0.92: Fixed problems with the wrong material being assigned
#               Now can make node groups for materials with no submaterials (like many of the purchasables)
# Version 1.0:  For use with .obj files created with cgf-converter.exe (https://github.com/Markemp/Cryengine-Converter/)
# Verison 2.0:  For use with .dae (Collada) files created with cgf-converter (https://github.com/Markemp/Cryengine-Converter/)

# No input necessary.  It will look for each .dae file in the current directory, and create an import.txt
# file that you can cut/paste into the python console.
# This will create an import.txt file for ALL the files in a particular directory.

# Input:  the directory to all the .dae files put in.

function Get-Usage {
    Write-host "Usage:  asset-importer.ps1 [-objectdir `"<directory to \Object>`"]" -ForegroundColor Yellow
	Write-Host "        Goes through a directory looking for .dae files created from cgf-converter and makes"
	Write-Host "        an import.txt file with the import information for all the files in the directory.  This"
	Write-Host "        can be pasted into the Blender python console.  This will also create the proper Cycles "
	Write-Host "        material for each of the objects imported."
	Write-Host
    Write-Host "        Please update the script before running.  The following variables need to be properly defined:"
    Write-Host "             `$basedir:  Where you extracted the object.pak files (and skins)"
    Write-Host "             `$imageformat:  What image format you are using (default .dds)"
    Write-Host
    pause
    exit
}

function Create-Material {

}

$basedir = "d:\blender projects\mechs"  # this is where you extracted all the *.pak files from the game. \objects, \textures etc
#$basedir = "e:\blender projects\Star Citizen"  
                                        # will be under this dir
$imageformat = ".dds"                   # Default image file format.  If you want to use .pngs, change this

# convert the path so it can be used by Blender
$basedir = $basedir.replace("\","\\")

# Python commands used by Blender
$scriptimport = "bpy.ops.import_scene.obj"
$scriptimportCollada = "bpy.ops.wm.collada_import"
$scriptscene = "bpy.context.scene.objects.active"
$scriptrotationmode = "bpy.context.active_object.rotation_mode=`"QUATERNION`" "
$scriptrotation = "bpy.context.active_object.rotation_quaternion"
$scripttransform = "bpy.ops.transform.translate"
$scriptseteditmode = "bpy.ops.object.mode_set(mode = `"EDIT`")"
$scriptsetobjectmode = "bpy.ops.object.mode_set(mode = `"OBJECT`")"
#$scriptclearmaterial = "bpy.context.object.data.materials.pop(0, update_data=True)"
$scriptclearmaterial = "bpy.context.object.data.materials.clear(update_data=True)"   #only works with 2.69 or newer
# Delete import.txt if it already exists.
try {
	$importtxt = Get-ChildItem "import.txt"
	Remove-Item $importtxt
}
catch  {
	# File not found.
	Write-Host "No existing import.txt file found. (this is ok)"
}

"# Asset Importer 2.0" >> .\import.txt
"#" >> .\import.txt

# Set Blender to Cycles
"bpy.context.scene.render.engine = 'CYCLES'" >> .\import.txt

# Get all the materials that are added into a List, so you don't add materials that already exist.
[System.Collections.ArrayList]$materialList = New-Object System.Collections.ArrayList

foreach ($file in (get-childitem -filter *.mtl) ) {        # create material for each material in the .mtl files

    Write-Host "Material file is $file"

    # *** MATERIALS ***
    # Load up materials from the <mtl> file
    [xml]$matfile = get-content ($file)
    
    # Get the materials from $matfile and create them in Blender
    #  material append wants an object of type material, not a string.  Will have to generate that.

    if (!($matfile.Material.SubMaterials.Material)) 
	{ 
        #write-host "File is $file"
        #$material = $matfile.Material
        #Write-host "Material flag is $material.mtlflags"
        $matname = $file.name.Substring(0,($file.tostring().Length-4))   # make $matname the name of the material file
		if (!($materialList -contains $matname)) 
		{
		        " " >> .\import.txt
			"### Material:  $matname" >> .\import.txt
			$materialList.Add($matname)

			"$matname=bpy.data.materials.new('$matname')"  >> .\import.txt
			"$matname.use_nodes=True" >> .\import.txt
			"$matname.active_node_material" >> .\import.txt
			"TreeNodes = $matname.node_tree" >> .\import.txt
			"links = TreeNodes.links" >> .\import.txt

"for n in TreeNodes.nodes:
   TreeNodes.nodes.remove(n)
" >> .\import.txt

			# Every material will have a PrincipleBSDF and Material output.  Add, place and link those
"shaderPrincipledBSDF = TreeNodes.nodes.new('ShaderNodeBsdfPrincipled')
shaderPrincipledBSDF.location =  300,500
shout=TreeNodes.nodes.new('ShaderNodeOutputMaterial')
shout.location = 500,500
links.new(shaderPrincipledBSDF.outputs[0], shout.inputs[0])
" >> .\import.txt


			$matfile.Material.Textures.texture | % {
			if ( $_.Map -eq "Diffuse") {
				#Diffuse Material
				$matdiffuse = $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\")  #assumes diffuse is in slot 0
"matDiffuse = bpy.data.images.load(filepath=`"$basedir\\$matdiffuse`", check_existing=True)
shaderDiffImg=TreeNodes.nodes.new('ShaderNodeTexImage')
shaderDiffImg.image=matDiffuse
shaderDiffImg.location = 0,600
links.new(shaderDiffImg.outputs[0], shaderPrincipledBSDF.inputs[0])
" >> .\import.txt
				}
                        
			if ($_.Map -eq "Specular") {
				# Specular
				$matspec =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
"matSpec=bpy.data.images.load(filepath='$basedir\\$matspec', check_existing=True)
shaderSpecImg=TreeNodes.nodes.new('ShaderNodeTexImage')
shaderSpecImg.color_space = 'NONE'
shaderSpecImg.image=matSpec
shaderSpecImg.location = 0,325
links.new(shaderSpecImg.outputs[0], shaderPrincipledBSDF.inputs[5])
" >> .\import.txt
				}   
                    
			if ($_.Map -eq "Bumpmap") {
				# Normal
				$matnormal =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
"matNormal=bpy.data.images.load(filepath=`"$basedir\\$matnormal`", check_existing=True)
shaderNormalImg=TreeNodes.nodes.new('ShaderNodeTexImage')
shaderNormalImg.color_space = 'NONE'
shaderNormalImg.image=matNormal
shaderNormalImg.location = -100,0
converterNormalMap=TreeNodes.nodes.new('ShaderNodeNormalMap')
converterNormalMap.location = 100,0
links.new(shaderNormalImg.outputs[0], converterNormalMap.inputs[1])
links.new(converterNormalMap.outputs[0], shaderPrincipledBSDF.inputs[17])

" >> .\import.txt
				}
			}
        }
    } # Material file with no submaterials.
	else 
	{
        $matfile.Material.SubMaterials.Material| % {
            $material = $_
            $matname = $material.Name   # $matname is the name of the material
			if (!($materialList -contains $matName)) {
				"" >> .\import.txt
				"### START Material:  $matname" >> .\import.txt
				$materialList.Add($matname)
				if (!($matname -eq "Proxy") ) {
					"$matname=bpy.data.materials.new('$matname')"  >> .\import.txt
					"$matname.use_nodes=True" >> .\import.txt
					"$matname.active_node_material" >> .\import.txt
					"TreeNodes = $matname.node_tree" >> .\import.txt
					"links = TreeNodes.links" >> .\import.txt

					"for n in TreeNodes.nodes:" >> .\import.txt
					"    TreeNodes.nodes.remove(n)" >> .\import.txt
					" " >> .\import.txt

					write-host "Material Name is $matname"
					$_.textures.Texture  | % {

						# Every material will have a PrincipleBSDF and Material output.  Add, place and link those
"shaderPrincipledBSDF = TreeNodes.nodes.new('ShaderNodeBsdfPrincipled')
shaderPrincipledBSDF.location =  300,500
shout=TreeNodes.nodes.new('ShaderNodeOutputMaterial')
shout.location = 500,500
links.new(shaderPrincipledBSDF.outputs[0], shout.inputs[0])
" >> .\import.txt
						if ( $_.Map -eq "Diffuse") {
							#Diffuse Material
							$matdiffuse = $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\")  #assumes diffuse is in slot 0
"matDiffuse = bpy.data.images.load(filepath=`"$basedir\\$matdiffuse`", check_existing=True)
shaderDiffImg=TreeNodes.nodes.new('ShaderNodeTexImage')
shaderDiffImg.image=matDiffuse
shaderDiffImg.location = 0,600
links.new(shaderDiffImg.outputs[0], shaderPrincipledBSDF.inputs[0])
" >> .\import.txt
							}
                        
						if ($_.Map -eq "Specular") {
							# Specular
							$matspec =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
"matSpec=bpy.data.images.load(filepath='$basedir\\$matspec', check_existing=True)
shaderSpecImg=TreeNodes.nodes.new('ShaderNodeTexImage')
shaderSpecImg.color_space = 'NONE'
shaderSpecImg.image=matSpec
shaderSpecImg.location = 0,325
links.new(shaderSpecImg.outputs[0], shaderPrincipledBSDF.inputs[5])
" >> .\import.txt
							}   
                    
						if ($_.Map -eq "Bumpmap") {
							# Normal
							$matnormal =  $_.file.replace(".tif","$imageformat").replace(".dds","$imageformat").replace("/","\\") 
"matNormal=bpy.data.images.load(filepath=`"$basedir\\$matnormal`", check_existing=True)
shaderNormalImg=TreeNodes.nodes.new('ShaderNodeTexImage')
shaderNormalImg.color_space = 'NONE'
shaderNormalImg.image=matNormal
shaderNormalImg.location = -100,0
converterNormalMap=TreeNodes.nodes.new('ShaderNodeNormalMap')
converterNormalMap.location = 100,0
links.new(shaderNormalImg.outputs[0], converterNormalMap.inputs[1])
links.new(converterNormalMap.outputs[0], shaderPrincipledBSDF.inputs[17])
" >> .\import.txt
						}
					}  # foreach texture
				}  # !proxy
	            "### END Material:  $matname " >> .\import.txt
			}
			"" >> .\import.txt
        } # Foreach submat
    }
}

# Get a list of the materials created; they will be needed
"materialList = []
for m in bpy.data.materials:
    materialList.append(m.name)
" >> .\import.txt

#  *** PARSING DAEs ***
#  Start parsing out the different object files in the directory.
foreach ($file in (Get-ChildItem -filter "*.dae")) {
    #  import each dae file
    # Time to generate the commands (in $parsedline, an array)
    " " >> .\import.txt
    "### Importing $file.name" >> .\import.txt
	$parsedline = @()
    $directory = $file.DirectoryName.Replace("\","\\")
    $filename = $file.Name
    $objectname = $filename.Substring(0,($filename.Length-4))

    # convert file to filepath for Blender

    #$parsedline += $scriptimport + "(filepath=`"$directory\\$filename`",use_groups_as_vgroups=True,split_mode=`'OFF`',axis_forward=`'-X`',axis_up=`'Z`')" 
	$parsedline += $scriptimportCollada + "(filepath='$directory\\$filename',find_chains=True,auto_connect=True)" 

    # set new object as the active object
    # Set $objectname to active object
    $parsedline += $scriptscene + "=bpy.data.objects[`"$objectname`"]"
    $parsedline += $scriptclearmaterial
	# for each material in the library_materials, add it to the object's materials.
	[xml] $daeFile = get-content ($directory+ "\" + $filename)
	$daeFile.COLLADA.library_materials | % {
		$mat = $_.name
		$parsedline += "bpy.context.object.data.materials.append($mat)"
	}
	#$parsedline += "bpy.context.object.data.materials.append($matname)"

	$parsedline += ""

	foreach ( $line in $parsedline ) {
		#write-host $line
		$line >> .\import.txt
	}
}

# Set material mode. # iterate through areas in current screen
"for area in bpy.context.screen.areas:
	if area.type == 'VIEW_3D':
		for space in area.spaces: 
			if space.type == 'VIEW_3D': 
				space.viewport_shade = 'MATERIAL'
				" >> .\import.txt


" " >> .\import.txt # Send a final line feed.
