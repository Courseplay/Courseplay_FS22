'''
	Automatically applies translation based on the dev setup.
	Translation that are removed there, will be removed in all the others.
	Translation that are added there, will be add in all the others with the given text or the english text.
	The master translation will be used in case of conflict between master and sub translation files.
	This means translations defined in the master file can only be changed there.
	Dependencies: lxml with pip install.
'''
import os
from lxml import etree as ET
import xml.dom.minidom as Minidom
seperator = "/"
workspaceDir = os.getcwd()
translationDir = workspaceDir + seperator + 'translations' + seperator # Dir where all translations files are stored.
newDirectory = workspaceDir + seperator + 'translations' + seperator  # Dir where all new translations files will be stored.
translationFilePrefix = "translation_" 
masterTranslationFile = workspaceDir + seperator +'config' + seperator + 'MasterTranslations.xml' # Developer setup file name.
newDevSetup = workspaceDir + seperator +'newMasterTranslations.xml' # Developer setup file that was newly created.

# Loads the developer setup.
# - Decides which texts are still valid and allowed.
# - Adds category comments for visibility.
# - New developer texts are automatically added to the other languages, with the default of english.
def loadMasterTranslations():
	categories = {}
	tree = ET.parse(masterTranslationFile)
	root = tree.getroot()
	# Loads all translation sorted by their category, which is just a header translation.
	for category in root.iter('Category'):
		categories[category.attrib['name']] = {}
		for entry in category.iter('Translation'):
			categories[category.attrib['name']][entry.attrib['name']] = {}
			for e in entry.iter('Text'):
				categories[category.attrib['name']][entry.attrib['name']][e.attrib['language']] = e.text
	return categories
    
# Goes trough all master translations and adds other languages content form the translation_xx.xml files.
def loadTranslationFiles(categories):
	allLanguages = []
	# Goes through all language translation files. 
	for filename in os.listdir(translationDir):
		f = translationDir + filename
		print(filename)
		if os.path.isfile(f):
			subTree = ET.parse(translationDir + filename)
			subRoot = subTree.getroot()[0]
			# Cuts the name from the filename: "translation_en.xml" -> "en"
			language = filename.split("_")[1][:-4]
			for entry in subRoot.iter('text'):
				for item in categories.values(): 
					if entry.attrib['name'] in item:
						# If the translation is not defined in the dev setup under "<Text language=name>...<\\Text>", then add it here.
						if not language in item[entry.attrib['name']]:
							item[entry.attrib['name']][language] = entry.attrib['text']
			allLanguages.append(language)
	return categories, allLanguages

# Generated the new translation files for all languages, based on the translation setup by the devs and the user translations in the translation_xx.xml files.
# Missing translation texts for languages other than english, automatically get the english text defined in the dev file.
def saveLanguageFiles():
	masterCategories = loadMasterTranslations()
	categories, allLanguages = loadTranslationFiles(masterCategories)
	for curLanguage in allLanguages:
		# Creates a xml file for the language, for example: br -> tanslation_br.xml
		filename = newDirectory + translationFilePrefix + curLanguage + ".xml"
		# Base structure by giants needed.
		r = ET.Element("l10n")
		c = ET.Element("texts")
		r.append(c)
		for category, entry in categories.items():
			# Adds the comments at the top of the blocks.
			comment = ET.Comment(category)
			c.append(comment)
			for name, data in entry.items():
				text, enText = None, None
				# Try finding the translation for the language defined by the n, else use the english translation text.
				for language, t in data.items():
					if language == curLanguage:
						text = t
					if language == "en":
						enText = t
				if text == None:
					text = enText
				# Adds the translation xml element: <text name=name text=text \\>, as defined by giants.
				e = ET.Element("text")
				e.set("name", name)
				e.set("text", text or "")
				c.append(e)
		tree = ET.ElementTree(r)
		# Small hack to make the xml file readable with all the indent.
		ET.indent(tree, space="\t", level=0)
		os.remove(filename)
		xmlstr = Minidom.parseString(ET.tostring(tree.getroot())).toprettyxml()
		with open(filename, "wb") as f:
			f.write(xmlstr.encode('utf-8'))


if __name__ == "__main__":
	saveLanguageFiles()