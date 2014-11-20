from xml.sax import handler
from calibre_plugins.osis_input.structure import DocStructure, OsisError
import re

class OsisHandler(handler.ContentHandler):
    
    def __init__(self, htmlWriter, context):
        self._bookTitle = ''
        self._breakCount = 0
        self._chNumWritten = False
        self._chHeadingWritten = False
        self._chTitleWritten = False
        self._context = context
        self._docStructure = DocStructure()
        self._firstBook = True
        self._firstVerse = False
        self._groupHtmlOpen = False
        self._headerProcessed = False
        self._hiHtmlTag = ''
        self._htmlWriter = htmlWriter
        self._inCanonicalTitle = False
        self._ignoreDivEnd = False
        self._ignoreText = False       
        self._inHeader = False
        self._inIntro = False       
        self._inTitle = False
        self._introText = ''
        self._introTextFound = False
        self._inVerse = False 
        self._inWork = False
        self._lineSpan = False
        self._osisFound = False
        self._osisIDWork= None
        self._osisTextFound = False
        self._singleChapterBook = False
        self._suppressBreaks = False
        self._startingChapter = False
        self._titleTag = ''
        self._titleWritten = False
        self._verseEmpty = True
        self._verseText = ''
        
    def startDocument(self):
        self._bookTitle = ''
        self._breakCount = 0
        self._chNumWritten = False
        self._chHeadingWritten = False
        self._firstBook = True
        self._groupHtmlOpen = False
        self._headerProcessed = False
        self._hiHtmlTag = ''
        self._inCanonicalTitle = False
        self._ignoreDivEnd = False
        self._ignoreText = False
        self._inHeader = False
        self._inIntro = False       
        self._inTitle = False
        self._introText = ''
        self._introTextFound = False
        self._inVerse = False 
        self._inWork = False
        self._osisFound = False
        self._osisTextFound = False
        self._suppressBreaks = False
        self._verseText = ''
  
    def endDocument(self):
        self._htmlWriter.close()
        
    def startElement(self, name, attrs):
        if self._headerProcessed:
            self._processBodyTag(name, attrs)
        elif not self._osisFound:
            if name == 'osis' or name == 'osis:osis' :
                self._osisFound = True
            else:
                raise OsisError('osis tag not found')
        elif not self._osisTextFound:
            if name == 'osisText':
                self._osisTextFound = True
                self._osisIDWork = self._getAttributeValue(attrs, 'osisIDWork')
                if self._context.lang == '':
                    lang = self._getAttributeValue(attrs, 'xml:lang')
                    if (lang is not None and lang != 'und'):
                        self._context.lang = lang
            else:
                raise OsisError('osisText tag not found')
        elif not self._inHeader:
            if name == 'header':
                self._inHeader = True
        elif name == 'work':
            osisWork = self._getAttributeValue(attrs, 'osisWork')
            if osisWork is not None and osisWork == self._osisIDWork:
                self._inWork = True
        elif self._inWork:        
            if name == 'title':
                self._inTitle = True
                
                
    def endElement(self, name):  
        if name == 'chapter':
            self._docStructure.endChapter()
            self._writeBreak(True)
        
        elif name == 'div':
            if self._ignoreDivEnd:
                self._ignoreDivEnd = False
            else:
                self._docStructure.endDiv(None)
                
        elif name == 'header':
            if self._inHeader:
                self._inHeader = False
                self._headerProcessed = True
            else:
                raise OsisError('unexpected end of header')
        
        elif name == 'hi':
            if self._hiHtmlTag != '':
                self._writeHtml('</%s>' % self._hiHtmlTag)
                self._hiHtmlTag = ''
                
        elif name == 'l':
            if self._lineSpan:
                self._writeHtml('</span>\n')
            else:
                self._writeHtml('</div>\n')
                self._breakCount = 1
            
        elif name == 'lg':
            self._writeBreak(True)
                        
        elif name == 'note':
            self._ignoreText = False
            
        elif name == 'p':
            self._writeHtml('</p>\n')
            self._breakCount = 1


        elif name == 'title':
            closingTag = ''
            if self._inTitle:
                self._inTitle = False
                if self._headerProcessed:
                    closingTag = '</h%s>\n' % self._titleTag[2]                    
                    if self._titleWritten:
                        self._writeHtml(closingTag)
                        self._suppressBreaks = True
                        if re.search('chapter', self._titleTag) is not None:
                            self._chHeadingWritten = True
            elif self._inCanonicalTitle:
                if self._context.canonicalClassDefined:
                    closingTag = '</span>'
                else:
                    closingTag = '</i>' 
                self._inCanonicalTitle = False
                self._writeHtml(closingTag + '<br /><br />\n')
                self._breakCount = 2
                if self._docStructure.verse != '':
                    self._inVerse = True
                    self._verseEmpty = True
                    if self._chTitleWritten or self._docStructure.verse != '1':
                        self._verseText = '<sup>' + self._docStructure.verse + '</sup>'
                        self._inVerse = True
                        
        elif name == 'work':
            if self._inWork:
                self._inWork = False

    def characters(self, content):
        text = content.strip()
        if self._headerProcessed:
            if self._inIntro:
                if self._inTitle:
                    if text == self._bookTitle:
                        if self._firstBook and self._introTextFound:
                            # For the first book in a group, anything before this is assumed to be a testament introduction
                            self._introText += '\n'
                            self._openGroupHtml()
                            self._htmlWriter.write(self._introText)
                            self._introText = ''
                            self._introTextFound = False
                        # If title is at the start of the intro, it is the book title
                        # Do not include this in intro text as book title will be included anyway
                        if (self._introTextFound):
                            self._writeTitle(text)
                        else:
                            self._introText = ''
                    else:
                         self._writeTitle(text)
                elif len(text) > 0:
                    self._introTextFound  = True
                    self._writeHtml(text)
            else:
                if not self._ignoreText:
                    if len(text) > 0:
                        if self._inTitle:
                            self._writeTitle(text)
                        else:
                            if self._inVerse:
                                self._verseEmpty = False
                            self._writeHtml(content)
                                
        elif self._inTitle:
            if self._context.title == '':
                self._context.title = content

    def _getAttributeValue(self, attrs, attrName):
        for (name, value) in attrs.items():
            if name == attrName:
                return value
        return None
    
    def _processBodyTag(self, name, attrs):
        if name == 'chapter':
            # If this is the first chapter of the book, write book title and any intro
            if self._inIntro:
                self._openBookHtml()
                self._htmlWriter.write('<h2>%s</h2>' % self._bookTitle)
                if len(self._introText) > 0:
                    # Remove unwanted breaks at start of intro before writing
                    while self._introText.startswith('<br />'):
                        self._introText = self._introText[6:]
                    self._htmlWriter.write(self._introText)
                    self._introText = ''
                self._inIntro = False
            chId = self._getAttributeValue(attrs,'osisID')
            self._docStructure.newChapter(chId)
            
            bookId = self._docStructure.bookId
            if bookId == 'Phlm' or bookId == '2John' or bookId == '3John' or bookId == 'Jude':
                self._singleChapterBook = True
            else:
                self._singleChapterBook = False
                
            # If this is a psalm and a psalm heading format is defined, then write the heading
            self._chTitleWritten = False
            self._chHeadingWritten = False
            self._startingChapter = True
            titleFormat = ''
            if bookId == 'Ps':
                titleFormat = self._context.config.psalmTitle
            elif not self._singleChapterBook:
                titleFormat = self._context.config.chapterTitle
            if titleFormat != '':
                title = titleFormat % self._docStructure.chapter
                self._htmlWriter.write('<h3 chapter="%s" class="x-chapter-title">%s</h3>' % (self._docStructure.chapter, title))
                self._chTitleWritten = True
                self._chHeadingWritten = True              
 
            self._firstBook = False
            
            # Do not write chapter number yet, in case there is a heading to write
                                  
        elif name == 'div':
            divType = self._getAttributeValue(attrs, 'type')
            if divType == 'bookGroup':
                if self._docStructure.startGroup():
                    groupNumber = self._docStructure.groupNumber
                    groupTitle = self._context.config.groupTitle(groupNumber)
                    self._firstBook = True
                    if groupTitle != '':
                        self._openGroupHtml()
                        self._htmlWriter.write('<h1>%s</h1>\n' % groupTitle)
            elif divType == 'book':
                bookRef = self._getAttributeValue(attrs,'osisID')
                if self._docStructure.startBook(bookRef):
                    self._bookTitle = self._context.config.bookTitle(bookRef)
                    self._inIntro = True
                    self._introText = ''
                    self._introTextFound = False
                    print 'Processing book ', bookRef
                    # Don't open book HTML yet, in case there is a testament introduction to write
            elif divType == 'section':
                secRef = self._getAttributeValue(attrs, 'sID')
                self._docStructure.startSection(secRef)
                self._ignoreDivEnd = True
                
            else:
                secRef = self._getAttributeValue(attrs, 'eID')
                if secRef is not None:
                    divType = self._docStructure.endDiv(secRef)
                    self._ignoreDivEnd = True
                else:
                    self._docStructure.otherDiv()
                
        elif name == 'hi':
            if not self._ignoreText:
                hiType = self._getAttributeValue(attrs, 'type')
                if hiType == 'bold':
                    self._hiHtmlTag = 'b'
                if hiType == 'emphasis':
                    self._hiHtmlTag = 'em'
                elif hiType == 'italic':
                    self._hiHtmlTag = 'i'
                elif hiType == 'line-through':
                    self._hiHtmlTag = 's'
                elif hiType == 'sub':
                    self._hiHtmlTag = 'sub'                
                elif hiType == 'super':
                    self._hiHtmlTag = 'sup'
                elif hiType == 'underline':
                    self._hiHtmlTag = 'u'
                else:
                    self._hiHtmlTag = ''
                    print 'Unsupported hi type %s' % hiType
                if self._hiHtmlTag != '':
                    self._writeHtml('<%s>' % self._hiHtmlTag)
            else:
                self._hiHtmlTag = ''
     
        elif name == 'lb':
            self._writeBreak(False)
            
        elif name == 'l':
            self._lineSpan = False
            lineType = self._getAttributeValue(attrs, 'type')
            if lineType is None:
                lineType = 'poetic-line'
            htmlTag = '<div class="%s">' % lineType
            if self._inVerse and self._verseEmpty:
                self._verseEmpty = False
                if self._chNumWritten:
                    self._lineSpan = True
                    self._writeHtml('<span class="first-para">')
                else:
                    self._verseText = htmlTag + self._verseText
            else:
                self._verseEmpty = False
                self._writeHtml(htmlTag)
            
        elif name == 'lg':
            self._writeBreak(False)
   
        elif name == 'note':
            # currently ignoring notes - handling of footnotes will be added later
            self._ignoreText = True
            
        elif name == 'p':
            subType = self._getAttributeValue(attrs, 'subType')
            if subType is not None:
                self._writeHtml('<p class="%s">' % subType)
            elif self._inVerse and self._verseEmpty and self._chNumWritten:
                self._writeHtml('<p class="first-para">')               
            else:
                self._writeHtml('<p>')
              
            
        elif name == 'reference':
            # reference tags are expected but ignored
            pass
        
        elif name == 'title':
            canonical = self._getAttributeValue(attrs,'canonical')
            if canonical == 'true':
                # A canonical title has special treatment
                if self._startingChapter and not self._chTitleWritten:
                    self._writeChapterNumber()
                    self._startingChapter = False
                if self._inVerse:
                    # A canonical title is not part of the verse
                    self._inVerse = False
                    self._verseText = ''
                    if self._firstVerse and not self._chTitleWritten:
                        self._writeChapterNumber()      
                if self._context.canonicalClassDefined:
                    self._writeHtml('<span class="canonical">')
                else:
                    self._writeHtml('<i>')
                self._inCanonicalTitle = True
                    
            else:
                level = self._getAttributeValue(attrs,'level')
                if level is not None:
                    # Header levels 1 and 2 are for testaments and books, so titles start at 3
                    headerLevel = int(level) + 2
                else:
                    headerLevel = 3
                subType = self._getAttributeValue(attrs,'subType')
                chapter = ''
                if (self._context.outputFmt != 'fb2'):
                    if (not self._singleChapterBook) and (self._startingChapter or (self._inVerse and self._firstVerse)):
                        if not self._chHeadingWritten:
                            chapter = 'chapter="%s"' % self._docStructure.chapter
                if subType is not None:
                    self._titleTag = '<h%d class="%s %s">' % (headerLevel, subType, chapter)
                else:
                    self._titleTag = '<h%d %s>' % (headerLevel, chapter)
                self._inTitle = True
                self._titleWritten = False
                
        elif name == 'verse':
            verse = self._getAttributeValue(attrs,'sID')
            if verse is not None:
                self._startVerse(verse)
            else:
                verse = self._getAttributeValue(attrs,'eID')
                if verse is not None:
                    self._docStructure.endVerse(verse)
                    if not self._verseEmpty:
                        if self._chHeadingWritten:
                            # remove chapter attribute from chapter number if a chapter heading has been written
                            self._verseText = re.sub(r'span chapter="\d+"', 'span', self._verseText)
                        self._htmlWriter.write(self._verseText + '\n')
                    self._inVerse = False
                    self._firstVerse = False
                    self._verseText =''
                    self._chHeadingWritten = False
                
        else:
            self._context.unexpectedTag(name)
                
    def _openGroupHtml(self):
        if not self._groupHtmlOpen:
            groupNumber = self._docStructure.groupNumber
            htmlName = 'group%d' % groupNumber
            self._htmlWriter.open(htmlName)
            self._groupHtmlOpen = True
                
    def _openBookHtml(self):
        bookId = self._docStructure.bookId
        self._htmlWriter.open(bookId)
        self._groupHtmlOpen = False
                
    def _writeHtml(self, html):
        self._suppressBreaks = False
        if self._inIntro:
            self._introText += html
        elif self._inVerse and not self._verseEmpty:
            self._verseText += html
        else:
            self._htmlWriter.write(html)
        self._breakCount = 0   # will be overwritten if called from _writeBreak()

    def _writeBreak(self, newline):
        if not self._suppressBreaks and self._breakCount < 2:
            storedCount = self._breakCount
            self._writeHtml('<br />')
            if newline:
                self._writeHtml('\n')
            self._breakCount = storedCount + 1
            
    def _writeTitle(self, content):
        if len(content) > 0:
            if not self._titleWritten:
                self._writeHtml(self._titleTag)
            self._writeHtml(content)
            self._titleWritten = True
        
    def _writeChapterNumber(self):
        if self._context.chNumClassDefined:
            spanHtml = '<span chapter="%s" class="x-chapter-number">%s</span>' % (self._docStructure.chapter, self._docStructure.chapter)
        else:
            spanHtml = '<span chapter="%s" style="font-size:36pt; float:left; line-height:1">%s</span>' % (self._docStructure.chapter, self._docStructure.chapter)
        if self._inVerse:
            self._verseText += spanHtml
        else:
            self._writeHtml(spanHtml)
        
    def _startVerse(self, verse):
        self._docStructure.newVerse(verse)
        self._inVerse = True
        self._verseText = ''
        self._verseEmpty = True
        self._chNumWritten = False         
        verseNumber = '<sup>' + self._docStructure.verse + '</sup>'
        if self._startingChapter:
            self._firstVerse = True
        else:
            self._firstVerse = False
        if self._startingChapter and self._chTitleWritten:
            self._verseText = verseNumber   
        elif self._startingChapter and ((not self._singleChapterBook) or self._docStructure.chapter != '1'):
            self._writeChapterNumber()
            self._chNumWritten = True           
            if self._docStructure.verse != '1':
                self._verseText += verseNumber
        else:
            self._verseText = verseNumber

        self._startingChapter = False
        
        
    
        
