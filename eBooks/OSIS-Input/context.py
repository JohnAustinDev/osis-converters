class ConvertContext(object):
    def __init__(self, config):
        self.htmlFiles = []
        self.cssFile = ''
        self.imageFiles = []
        self.config = config
        self.lang = config.language
        self.title = config.title
        self.chNumClassDefined = False
        self.canonicalClassDefined = False
        self.outputFmt = ''
        self.unexpectedTags = []
        
    def unexpectedTag(self, tag):
        if tag not in self.unexpectedTags:
            self.unexpectedTags.append(tag)