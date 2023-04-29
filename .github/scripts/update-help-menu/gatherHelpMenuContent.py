
import os, sys, re, json
from lxml import etree as ET
from dataclasses import dataclass, field
from dataclasses_serialization.json import JSONSerializer

outDir = os.getcwd() + "/.github/scripts/update-help-menu/data/" 

translationDir =  os.getcwd() + "/translations/"
configDir =  os.getcwd() + "/config/"

@dataclass
class Image:
	filename : str = ""
	size : list[float] = field(default_factory=list)
	raw_size : str = ""
	uvs : list[float] = field(default_factory=list)
	raw_uvs : str = ""
	def fromXml(self, xmlElement):
		if not xmlElement is None :
			self.filename = xmlElement.attrib['filename']
			self.raw_size = xmlElement.attrib['size']
			self.raw_uvs = xmlElement.attrib['uvs']
		return self

@dataclass
class Text:
	raw : str = ""
	text : str = ""
	def __init__(self, raw = "", text = ""):
		self.raw = re.sub("\$l10n_", "", raw)
	def fromXml(self, xmlElement):
		if not xmlElement is None :
			self.raw = re.sub("\$l10n_", "", xmlElement.attrib['text'])
		return self
@dataclass
class Paragraph:
	title : Text
	text : Text
	image : Image
	def __repr__(self):
		return f'\n		Paragraph(title: {self.title} text: {self.text})'

@dataclass
class Page:
	title : Text
	paragraphs : list[ Paragraph ]
	def __repr__(self):
		return f'\n	Page(title: {self.title} \n		{self.paragraps})'

@dataclass
class Category:
    title : Text
    pages : list[ Page ]
    def __repr__(self):
        return f'Category(title: {self.title} \n	{self.pages})'
    


def loadHelpMenuConfig():
	
	string = open(configDir + "HelpMenu.xml", encoding="utf-8").read()
 
	string = re.sub("<\?.+\?>", "", string)	# Removes the xml declaration.
	root = ET.fromstring(string)
	print(root)
	
	categories = []
 
	# Loads all translation sorted by their category, which are just comments in the separate translation files.
	for category in root.iter('category'):
		category_title = Text(category.attrib['title'])
		page_list = []
		for page in category.iter('page'):
			page_title = Text(page.attrib['title'])
			paragraph_list = []
			for paragraph in page.iter('paragraph'):
				para_title = Text().fromXml(paragraph.find('title'))
				para_text = Text().fromXml(paragraph.find('text'))
				para_image = Image().fromXml(paragraph.find('image'))
				para = Paragraph(para_title, para_text, para_image)
				paragraph_list.append(para)
			p = Page(page_title, paragraph_list)
			page_list.append(p)
		c = Category(category_title, page_list)
		categories.append(c)			
	return categories

# Replaces '\n' or/and '\r' with the xml special key: '&#xA;' to avoid formatting bugs.
def filter_text(string):
	string = re.sub("<\?.+\?>", "", string) # Removes the xml declaration.
	regex = "((?<=((=\")))[^\"]+(?<!\"))"
	matches = re.finditer(regex, string)
	for _, match in reversed(list(enumerate(matches, start = 1))):
		s = re.sub("\n\r", "&#xA;", match.group())
		s = re.sub("\n", "&#xA;", s)
		s = re.sub("\r", "&#xA;", s)
		s = re.sub("&#10;", "&#xA;", s)
		string = string[:match.start()] + s + string[match.end():]
	return string


def loadTranslations():
	translations = {}
	# Goes through all language translation files. 
	for filename in os.listdir(translationDir):
		f = translationDir + filename
		if os.path.isfile(f):
			string = open(translationDir + filename, encoding="utf-8").read()
			string = filter_text(string)	
			subRoot = ET.fromstring(string)[0]
			language = filename.split("_")[1][:-4]
			translations[language] = {}
			for entry in subRoot.iter('text'):
				name = entry.attrib['name']
				text = entry.attrib['text']
				translations[language][name] = text
	return translations
					

def main():
	if not os.path.exists(outDir):
		os.makedirs(outDir)
	# Help menu setup keys for the dom generation.
	categories = loadHelpMenuConfig()
	with open(outDir + "config.json", 'w') as f:
		json.dump(JSONSerializer.serialize(categories),f)
  
	# Load translations
	translations = loadTranslations()
	for t,data in translations.items():
		with open(outDir + t +".json", 'w', encoding='UTF-8') as f:
			json.dump(data,f)
 
if __name__ == "__main__":
    main()
