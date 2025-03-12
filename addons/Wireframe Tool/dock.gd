@tool
extends ScrollContainer

const SELECTION_TOOL_NONE = 0
const SELECTION_TOOL_VERTEX = 1
const SELECTION_TOOL_EDGES = 2
const SELECTION_TOOL_LOOP = 3
const SELECTION_TOOL_ALL = 4
const SELECTION_TOOL_INVERSE = 5

var wftScript # Reference to wireframetool.gd
var buttons = []
var isDockDisabled = false
var isWFTDisabled = true

func _ready():
	
	get_node("vbox/btnHelp").pressed.connect(wftScript.showHelp)
	
	buttons.append(get_node("vbox/hboxSur1/btnTMesh"))
	buttons[0].text = "Mesh"
	buttons[0].item_selected.connect(wftScript.targetMeshSelection)

	buttons.append(get_node("vbox/hboxSur1/btnTSur"))
	buttons[1].text = "Surface"
	buttons[1].item_selected.connect(wftScript.targetSurfaceSelection)

	buttons.append(get_node("vbox/hboxSur2/btnRenameS"))
	buttons[2].pressed.connect(wftScript.renameSurface)

	buttons.append(get_node("vbox/hboxSur2/btnRenameOk"))
	buttons[3].pressed.connect(wftScript.renameSurfaceOK)

	buttons.append(get_node("vbox/hboxSur2/btnDeleteS"))
	buttons[4].pressed.connect(wftScript.deleteSurface)

	buttons.append(get_node("vbox/hboxSur3/btnSMesh"))
	buttons[5].text = "Mesh"
	buttons[5].item_selected.connect(wftScript.sourceMeshSelection)

	buttons.append(get_node("vbox/hboxSur3/btnSSur"))
	buttons[6].text = "Surface"

	buttons.append(get_node("vbox/hboxSur3/btnCopyS"))
	buttons[7].pressed.connect(wftScript.copySurface)

	buttons.append(get_node("vbox/hboxWFT/btnGenerate"))
	buttons[8].pressed.connect(wftScript.generateWirefame)

	buttons.append(get_node("vbox/hboxWFT/btnCommit"))
	buttons[9].pressed.connect(wftScript.commitWireframe)

	buttons.append(get_node("vbox/hboxWFT/btnCancel"))
	buttons[10].pressed.connect(wftScript.cancelWireframe)

	buttons.append(get_node("vbox/group/GridContainer/btnNone"))
	buttons[11].pressed.connect(setToolNone)

	buttons.append(get_node("vbox/group/GridContainer/btnVertex"))
	buttons[12].pressed.connect(setToolVertex)

	buttons.append(get_node("vbox/group/GridContainer/btnEdge"))
	buttons[13].pressed.connect(setToolEdge)

	buttons.append(get_node("vbox/group/GridContainer/btnLoop"))
	buttons[14].pressed.connect(setToolLoop)

	buttons.append(get_node("vbox/group/GridContainer/btnAll"))
	buttons[15].pressed.connect(setToolALL)

	buttons.append(get_node("vbox/group/GridContainer/btnInverse"))
	buttons[16].pressed.connect(setToolInverse)

	buttons.append(get_node("vbox/gridActions/btnDelete"))
	buttons[17].pressed.connect(wftScript.deleteSelection)

	buttons.append(get_node("vbox/gridActions/btnColor"))
	buttons[18].pressed.connect(wftScript.colorSelection)

	buttons.append(get_node("vbox/gridActions/ColorPickerButton"))

	buttons.append(get_node("vbox/hboxMaterials/btnUnlit"))
	buttons[20].pressed.connect(wftScript.setUnlitShader)

	buttons.append(get_node("vbox/hboxMaterials/btnLit"))
	buttons[21].pressed.connect(wftScript.setLitShader)

	buttons.append(get_node("vbox/hboxMaterials/btnOutline"))
	buttons[22].pressed.connect(wftScript.setOutlineShader)
	
	buttons.append(get_node("vbox/hboxMaterials/btnOccluder"))
	buttons[23].pressed.connect(wftScript.setOccluderShader)
	#get_node("vbox/hboxMaterials/btnOccluder").pressed.connect(wftScript.setOccluderShader)

	disableAll(true)

func _exit_tree():
	for button in buttons:
		if button.pressed.is_connected(wftScript.deleteSelection):
			button.pressed.disconnect(wftScript.deleteSelection)
	
	var occluder_button = get_node("vbox/hboxMaterials/btnOccluder")

	if wftScript and (occluder_button.pressed.is_connected(wftScript.setOccluderShader)):
		occluder_button.pressed.disconnect(wftScript.setOccluderShader)

# Selection Tool Methods
func setToolNone(): wftScript.activeTool = SELECTION_TOOL_NONE
func setToolVertex(): wftScript.activeTool = SELECTION_TOOL_VERTEX
func setToolEdge(): wftScript.activeTool = SELECTION_TOOL_EDGES
func setToolLoop(): wftScript.activeTool = SELECTION_TOOL_LOOP
func setToolALL(): wftScript.activeTool = SELECTION_TOOL_ALL
func setToolInverse(): wftScript.activeTool = SELECTION_TOOL_INVERSE

# Setting Names
func setTargetMeshName(name, uid): buttons[0].add_item(name, uid)
func setTargetSurfaceName(name): buttons[1].add_item(name)
func setSourceMeshName(name, uid): buttons[5].add_item(name, uid)
func setSourceSurfaceName(name): buttons[6].add_item(name)

# Getting Selection
func getSelTargetMeshId(): return buttons[0].selected
func getSelTargetSurfaceName(): return buttons[1].get_item_text(buttons[1].selected)
func getSelSourceMeshId(): return buttons[5].selected
func getSelSourceSurfaceName(): return buttons[6].get_item_text(buttons[6].selected)

# Clearing Selections
func clearSelTargetMesh(): buttons[0].clear()
func clearSelTargetSurface(): buttons[1].clear()
func clearSelSourceMesh(): buttons[5].clear()
func clearSelSourceSurface(): buttons[6].clear()

# Color Management
func getColor(): return get_node("vbox/gridActions/ColorPickerButton").color
func setColor(color): get_node("vbox/gridActions/ColorPickerButton").color = color

# Warnings
func setWarning(text): get_node("vbox/lblWarning").text = text
func getWarning(): return get_node("vbox/lblWarning").text
func getRenameSurfaceText(): return get_node("vbox/hboxSur2/txtedSurName").text

# Show Rename Surface
func showRenameSurface(show):
	buttons[2].visible = not show
	get_node("vbox/hboxSur2/txtedSurName").visible = show
	buttons[3].visible = show
	if show:
		get_node("vbox/hboxSur2/txtedSurName").text = getSelTargetSurfaceName()

# Disabling Buttons
func disableTarget(disable):
	for i in range(5): buttons[i].disabled = disable

func disableSurfaceCopy(disable):
	for i in range(5, 8): buttons[i].disabled = disable

func disableWFT(disable):
	isWFTDisabled = disable
	for i in range(8, 23): buttons[i].disabled = disable

func disableAll(disable):
	for button in buttons:
		button.disabled = disable

func cleanAndLock():
	clearSelTargetMesh()
	clearSelTargetSurface()
	clearSelSourceMesh()
	clearSelSourceSurface()
	disableAll(true)
