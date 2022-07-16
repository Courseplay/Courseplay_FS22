'''
	Automatically applies translation based on the master translation file.
	Translation that are removed there, will be removed in all the others files.
	Translation that are added there, will be added in all the others with the given text or the english text by default.
	The master translations will be used in case of a conflict between master and sub translation files.
	This means translations defined in the master file can only be changed there.
	
 	Dependencies: lxml with pip install.
'''
import os
from lxml import etree as ET
import re
seperator = "/"
workspaceDir = os.getcwd()
translationDir = workspaceDir + seperator + 'translations' + seperator # Dir where all translations files are stored.
newDirectory = workspaceDir + seperator + 'translations' + seperator  # Dir where all new translations files will be stored.
translationFilePrefix = "translation_" 
masterTranslationFile = workspaceDir + seperator +'config' + seperator + 'MasterTranslations.xml' # Developer setup file name.

supportedLanguages = ["en", "de", "jp", "pl", "cz", "fr", 
                      "es", "ru", "it", "pt", "hu", "nl", 
                      "cs", "ct", "br", "tr", "ro", "kr",
                      "ea", "da", "fi", "no", "sv", "fc"]

languageNames = [
	"English", "German", "Japanese", "Polski", "Czech",	"French",
	"Spanish", "Russian", "Italiano", "Portuguese", "Hungarian", "Dutch",
	"Chinese Simplified", "Chinese Traditional", "Brazilian Portuguese", "Turkish", "Romanian", "Korean",
	"Spanish LA", "Danish", "Finnish", "Norwegian", "Swedish", "Canadian French"
]
translationText = "{} translation"

# Replaces '\n' or/and '\r' with the xml special key: '&#xA;' to avoid formatting bugs.
def filter(string):
	string = re.sub("<\?.+\?>", "", string) # Removes the xml declaration.
	regex = "((?<=((=\")))[^\"]+(?<!\"))"
	matches = re.finditer(regex, string)
	for matchNum, match in reversed(list(enumerate(matches, start = 1))):
		s = re.sub("\n\r", "&#xA;", match.group())
		s = re.sub("\n", "&#xA;", s)
		s = re.sub("\r", "&#xA;", s)
		s = re.sub("&#10;", "&#xA;", s)
		string = string[:match.start()] + s + string[match.end():]
	return string

# Loads the developer setup.
# - Decides which texts are still valid and allowed.
# - Adds category comments for visibility.
# - New developer texts are automatically added to the other languages, with the default of english.
def loadMasterTranslations():
	categories = {}
	
	string = open(masterTranslationFile, encoding="utf-8").read()
 
	string = re.sub("<\?.+\?>", "", string)	# Removes the xml declaration.
	root = ET.fromstring(string)
	# Loads all translation sorted by their category, which are just comments in the separate translation files.
	for category in root.iter('Category'):
		categories[category.attrib['name']] = {}
		for entry in category.iter('Translation'):
			categories[category.attrib['name']][entry.attrib['name']] = {}
			for e in entry.iter('Text'):
				categories[category.attrib['name']][entry.attrib['name']][e.attrib['language']] = e.text
	return categories
    
# Goes trough all master translations and adds languages content form the translation_xx.xml files.
def loadTranslationFiles(categories):
	allLanguages = []
	# Goes through all language translation files. 
	for filename in os.listdir(translationDir):
		f = translationDir + filename
		if os.path.isfile(f):
			string = open(translationDir + filename, encoding="utf-8").read()
			#string = string.replace("\n"," &#xA; ")
			string = filter(string)			
			subRoot = ET.fromstring(string)[0]
			# Cuts the name from the filename: "translation_en.xml" -> "en"
			language = filename.split("_")[1][:-4]
			for entry in subRoot.iter('text'):
				for item in categories.values(): 
					if entry.attrib['name'] in item:
						# If the translation is not defined in the master translation under "<Text language=name>...<\\Text>", then add it here.
						if not language in item[entry.attrib['name']]:
							item[entry.attrib['name']][language] = entry.attrib['text']
			allLanguages.append(language)
	return categories, allLanguages

# Generated the new translation files for all languages, based on the translation setup by the master file and the user translations in the translation_xx.xml files.
# Missing translation texts for languages other than english, automatically get the english text defined in the master file.
def saveLanguageFiles():
	masterCategories = loadMasterTranslations()
	categories, allLanguages = loadTranslationFiles(masterCategories)
	for index, curLanguage in enumerate(supportedLanguages):
		# Creates a xml file for the language, for example: br -> tanslation_br.xml
		filename = newDirectory + translationFilePrefix + curLanguage + ".xml"
		# Base structure by giants needed.
		r = ET.Element("l10n")
		c = ET.Element("texts")
		r.append(c)  
		c.append(ET.Comment(translationText.format(languageNames[index])))
		for category, entry in categories.items():
			# Adds the comments at the top of the blocks.
			c.append(ET.Comment(""))
			c.append(ET.Comment(category))
			c.append(ET.Comment(""))
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
				if text == None:
					text = ""
				# Adds the translation xml element: <text name=name text=text \\>, as defined by giants.
				e = ET.Element("text")
				e.set("name", name)
				e.set("text", text)
				c.append(e)
		if os.path.isfile(filename):
			os.remove(filename)
		xml_object = ET.tostring(r,
                            pretty_print=True,
                            xml_declaration=True,
                            encoding='UTF-8',
                            method='xml')
		xml_object = xml_object.decode('utf-8')
		xml_object = re.sub("&#10;", "\n", xml_object) # Another hack, to keep the correct formatting.
		xml_object = re.sub("&#9;", "", xml_object) # Another hack, to remove tabs in the file.
		with open(filename, "wb") as writter: 
			writter.write(xml_object.encode('utf-8'))
  

if __name__ == "__main__":
	saveLanguageFiles()