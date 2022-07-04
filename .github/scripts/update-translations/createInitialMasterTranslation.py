import os
from lxml import etree as ET
import re 
seperator = "/"
workspaceDir = os.getcwd()
translationDir = workspaceDir + seperator + 'translations' + seperator # Dir where all translations files are stored.
newDevSetup = workspaceDir + '/config/MasterTranslations.xml' # Developer setup file that was newly created.
languages = ["de", "en"] #Languages added to the master translation file.

'''
	Generates a new master translation file.
'''

# Replaces '\n' with the xml special key: '&#xA;' to avoid formatting bugs.
def filter(string):
	string = re.sub("<\?.+\?>", "", string)
	regex = "((?<=((=\")))[^\"]+(?<!\"))"
	matches = re.finditer(regex, string)
	for matchNum, match in reversed(list(enumerate(matches, start = 1))):
		#print("{matchNum}: {match}".format(matchNum = matchNum, match = match.group()))
		s = re.sub("\n", "&#xA;", match.group())
		s = re.sub("&#x10;", "&#xA;", s)
		print("----> " + s)
		string = string[:match.start()] + s + string[match.end():]
	return string

# Gets the raw translations data for all languages in the translation folder.
def readExistingTranslations():
	values = {}
	# Gets all translation of the files in the dir.
	for filename in os.listdir(translationDir):
		f = os.path.join(translationDir, filename)
		if os.path.isfile(f):  
			string = open(translationDir + filename, encoding="utf-8").read()
			#string = string.replace("\n"," &#xA; ")
			string = filter(string)			
			with open(translationDir + filename, "w", encoding="utf-8") as file:
				file.write(string)
			subTree = ET.fromstring(string)
			#subRoot = subTree.getroot()[0]
			subRoot = subTree[0]
			language = filename.split("_")[1][:-4]
			for entry in subRoot.iter('text'):
				if not entry.attrib['name'] in values:
					values[entry.attrib['name']] = {}
				values[entry.attrib['name']][language] = entry.attrib['text']
	return values
 
# Creates a new dev translation setup file.
def createNewMasterTranslation(languages):
	values = readExistingTranslations()
	r = ET.Element("Translations")
	# Adds a blank category.
	c = ET.Element("Category")
	c.set("name", "basic")
	r.append(c)
	for name, data in values.items():
		t = ET.SubElement(c, "Translation")
		t.set("name", name)
		for language, text in data.items():
			if language in languages:
				a = ET.SubElement(t, "Text")
				a.set("language", language)
				a.text = ET.CDATA(text)
	tree = ET.ElementTree(r)
	ET.indent(tree, space="\t", level=0)
	tree.write(newDevSetup, encoding="utf-8", xml_declaration=True)
 
if __name__ == "__main__":
	createNewMasterTranslation(languages)