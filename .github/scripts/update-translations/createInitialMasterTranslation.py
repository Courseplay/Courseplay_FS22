import os
import xml.etree.ElementTree as ET
seperator = "/"
workspaceDir = os.getcwd()
translationDir = workspaceDir + seperator + 'translations' + seperator # Dir where all translations files are stored.
newDevSetup = workspaceDir + seperator + 'newMasterTranslations.xml' # Developer setup file that was newly created.

'''
	Developer functions below. They should only be used for a complete new translation setup file!
	They generate a translation setup file with existing translations and one blank Category.
'''
# Gets the raw translations data for all languages in the translation folder.
def readExistingTranslations():
	values = {}
	# Gets all translation of the files in the dir.
	for filename in os.listdir(translationDir):
		f = os.path.join(translationDir, filename)
		if os.path.isfile(f):
			subTree = ET.parse(translationDir+filename)
			subRoot = subTree.getroot()[0]
			language = filename.split("_")[1][:-4]
			for entry in subRoot.iter('text'):
				if not entry.attrib['name'] in values:
					values[entry.attrib['name']] = {}
				values[entry.attrib['name']][language] = entry.attrib['text']
	return values
 
# Creates a new dev translation setup file.
def createNewMasterTranslation():
	values = readExistingTranslations()
	r = ET.Element("Translations")
	# Adds a blank category.
	c = ET.Element("Category")
	r.append(c)
	for name,data in values.items():
		t = ET.SubElement(c, "Translation")
		t.set("name", name)
		for language,text in data.items():
			a = ET.SubElement(t, "Text")
			a.set("language", language)
			a.text = text 
	tree = ET.ElementTree(r)
	ET.indent(tree, space="\t", level=0)
	tree.write(newDevSetup, encoding="utf-8", xml_declaration=True)
 
if __name__ == "__main__":
	createNewMasterTranslation()