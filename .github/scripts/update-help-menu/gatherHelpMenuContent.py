
"""
File used to process help menu data for the courseplay website.

1) Generates a DOM structure for the website and saves it in .json
2) Generates .json files for all the translations
3) Converts all .dds help menu images to .png

"""

import os, sys, re, json
from lxml import etree as ET
from dataclasses import dataclass, field
from dataclasses_serialization.json import JSONSerializer
from PIL import Image as PIL_Image

outDir = os.getcwd() + "/help_menu_cache_data/"

translationDir =  os.getcwd() + "/translations/"
configDir =  os.getcwd() + "/config/"
imgDir = os.getcwd() + "/img/"
helpImgDir = imgDir + "helpmenu/"

# Data structures defined in the help menu config file

@dataclass
class Image:
	filename : str = ""
	size : list[float] = field(default_factory=list)
	size_str : str = ""
	uvs : list[float] = field(default_factory=list)
	uvs_str : str = ""
	def fromXml(self, xmlElement):
		if not xmlElement is None :
			# Website uses png images
			dirname, filename = os.path.split(xmlElement.attrib['filename'])
			self.filename = re.sub(".dds", ".png", filename)
			self.size_str = xmlElement.attrib['size']
			size = re.sub("px", "", self.size_str)
			size_array = size.split()
			for s in size_array:
						self.size.append(int(s))
			self.uvs_str = xmlElement.attrib['uvs']
			uvs = re.sub("px", "", self.uvs_str)
			uvs_array = uvs.split()
			for uv in uvs_array:
				self.uvs.append(int(uv))
			self.saveUvScaledImage()
		return self

	def saveUvScaledImage(self):
		# Applies the uvs, as the website can not do it.
		img = PIL_Image.open(outDir+self.filename)
		img = img.crop(self.uvs)
		self.filename = re.sub(".png","",self.filename) + f"_{self.uvs[0]}_{self.uvs[1]}_{self.uvs[2]}_{self.uvs[3]}.png"
		img.save(outDir+self.filename)

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
		return f'\n	Page(title: {self.title} \n		{self.paragraphs})'

@dataclass
class Category:
    title : Text
    subTitle : Text
    pages : list[ Page ]
    def __repr__(self):
        return f'Category(title: {self.title} \n	{self.pages})'
    

# First load the config file and build a python data tree
def loadHelpMenuConfig():
	
	string = open(configDir + "HelpMenu.xml", encoding="utf-8").read()
 
	string = re.sub("<\?.+\?>", "", string)	# Removes the xml declaration.
	root = ET.fromstring(string)
	
	categories = []
 
	# Loads all translation sorted by their category, which are just comments in the separate translation files.
	for category in root.iter('category'):
		category_title = Text(category.attrib['title'])
		category_subTitle = Text(category.attrib['title'])
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
		c = Category(category_title, category_subTitle, page_list)
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
    # Loads all translations and creates a json file for each.
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
    
def convertImagesToPNG():
    # Converts help menu images from .dds to .png
	for filename in os.listdir(helpImgDir):
		f = helpImgDir + filename
		if os.path.isfile(f):
			img = PIL_Image.open(f, mode='r')
			newFileName = outDir+re.sub(".dds", ".png", filename)
			img.save(newFileName)
			print(f"Converted image to {newFileName}")
	img = PIL_Image.open(os.getcwd()+"/icon_courseplay.dds")
	img.save(outDir+"/icon_courseplay.png")

	img = PIL_Image.open(imgDir+"ui_courseplay.dds")
	img.save(outDir+"/ui_courseplay.png")

	img = PIL_Image.open(imgDir+"iconSprite.dds")
	img.save(outDir+"/iconSprite.png")	
 
	img = PIL_Image.open(imgDir+"courseplayIconHud.dds")
	img.save(outDir+"/courseplayIconHud.png")


 
def main():
	if not os.path.exists(outDir):
		os.makedirs(outDir)
	# Converts help menu images to png
	convertImagesToPNG()
  
	# Help menu setup keys for the dom generation.
	categories = loadHelpMenuConfig()
	filename = outDir + "config.json"
	with open(filename, 'w') as f:
		json.dump(JSONSerializer.serialize(categories),f)
		print(f"Created config file at {filename}")
		print(categories)
  
	# Load translations
	translations = loadTranslations()
	for t, data in translations.items():
		filename = outDir + t +".json"
		with open(filename, 'w', encoding='UTF-8') as f:
			json.dump( data, f )
			print(f'Saved translations to {filename}')
 
if __name__ == "__main__":
    main()
