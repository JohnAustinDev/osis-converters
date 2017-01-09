from calibre_plugins.osis_input.osis import OsisHandler
from calibre_plugins.osis_input.structure import DocStructure, OsisError
import shutil
import re

class BibleHandler(OsisHandler):
    
    # Tuple to define div types for introductions
    INTRO_DIVS = ('introduction', 'front', 'back', 'concordance', 'glossary', 'index', 'gazetteer', 'x-other', 'preface','coverPage', 'titlePage')
    
    def __init__(self, htmlWriter, context):
        OsisHandler.__init__(self, htmlWriter, context)
        self._bibleHtmlOpen = False
        self._bibleIntroWritten = False             # A Bible introduction has been written
        self._bibleStarting = True                  # Not yet found first Bible chapter
        self._bookTitle = ''                        # Book title either from config or found in OSIS
        self._bookHtmlOpen = False
        self._bookTitleFound = False                # Found title which will be used as book title
        self._bookTitleWritten = False              # Title of current book written to output file
        self._canonicalTitleWritten = False         # Last output written was a canonical title
        self._chFootnoteMarker = ''                 # Footnote marker in a chapter title
        self._chNumWritten = False                  # Chapter number written before current verse
        self._chHeadingWritten = False              # Found or generated a title at the start of a chapter 
        self._chapterTitle = ''                     # HTML for chapter title ready to be written to output
        self._chTitleWritten = False                # Chapter title has been written to output
        self._docStructure = DocStructure()
        self._firstBook = True                      # First book of testament
        self._firstTitle = False                    # Next title found will be first in book
        self._firstVerse = False                    # Current verse is first in chapter
        self._footnoteMarkerWritten = False         # Marker for current footnote has been written (and any scripture reference processed)
        self._groupEmpty = False                    # No books yet found in current book group
        self._groupIndex = 0                        # Used to check for start of new testament where separate book groups not used
        self._groupIntroWritten = False             # A testament introduction has been written for current testament
        self._groupHtmlOpen = False
        self._groupTitle = ''                       # Title for current testament, obtained from config
        self._groupTitleWritten = False             # The current testament title has been written
        self._inCanonicalTitle = False              # Currently processing a canonical title
        self._inChapterTitle = False                # Currently processing a chapter title
        self._ignoreChEnd = False                   # Processing <chapter> tag which is a milestone tag
        self._ignoreDivEnd = False                  # Processing <div> tag which is a milestone tag
        self._inFootnoteRef = False                 # Processing initial reference in a footnote
        self._inIntro = False                       # Processing an introduction rather than scripture
        self._introDivTextFound = False             # Some text has been processed for current introduction <div>
        self._introStyleStarted = False             # Found first occurrence of 'x-introduction' (sub)type in current introduction
        self._introText = ''                        # Html generated for current introduction
        self._introTextFound = False                # Some text has been processed for current introduction
        self._introTitleWritten = False             # A title for the current introduction has been written
        self._inVerse = False                       # Currently within a scripture verse and not within a canonical title
        self._lineSpan = False                      # Current poetic line in first line of chapter, to the right of a chapter number
        self._psDivTitle = False                    # Title being processed had been identified as a Psalm division title or subtitle
        self._psDivTitleFound = False               # Last title processed was a Psalm division title, so next may be corresponding subtitle
        self._readyForSubtitle = False              # Last title processed was a book title, so next may be corresponding subtitle
        self._singleChapterBook = False             # Current book should have only one chapter
        self._startingChapter = False               # <chapter> tag processed, but initial <verse> tag not yet found
        self._verseEmpty = True                     # Not yet processed any text in this verse (excluding canonical title)
        self._verseNumWritten = False               # Html for the number of the current verse has been generater
        self._verseText = ''                        # Text of verse currently beeing processed

        
        # For fb2, we need chapter/psalm titles.
        # If no format has been provided, set up format as the chapter/psalm number only
        
        if self._context.outputFmt == 'fb2':
            if self._context.config.chapterTitle == '':
                self._context.config.chapterTitle = '%s'
            if self._context.config.psalmTitle == '':
                self._context.config.psalmTitle = '%s'
        
    def startDocument(self):
        OsisHandler.startDocument(self)
        self._bibleHtmlOpen = False
        self._bibleIntroWritten = False
        self._bibleStarting = True
        self._bookHtmlOpen = False
        self._bookTitle = ''
        self._canonicalTitleWritten = False
        self._chapterTitle = ''
        self._chFootnoteMarker = ''
        self._chNumWritten = False
        self._chHeadingWritten = False
        self._firstBook = True
        self._groupEmpty = False
        self._groupHtmlOpen = False
        self._groupIndex = 0
        self._inCanonicalTitle = False
        self._inChapterTitle = False
        self._ignoreChEnd = False
        self._ignoreDivEnd = False
        self._inFootnoteRef = False
        self._inIntro = False
        self._introDivTextFound = False
        self._introStyleStarted = False
        self._introText = ''
        self._introTextFound = False
        self._introTitleWritten = False
        self._inVerse = False 
        self._psDivTitle = False
        self._psDivTitleFound = False
        self._readyForSubtitle = False
        self._verseNumWritten = False
        self._verseText = ''
        self._verseTextFound = False
        self._defaultHeaderLevel = 3  
                
    def endElement(self, name):
        if name == 'chapter':
            if self._ignoreChEnd:
                self._ignoreChEnd = False
            else:
                self._docStructure.endChapter(self._docStructure.chapterRef)
                self._writeBreak(True)
      
        elif name == 'div':
            if self._ignoreDivEnd:
                self._ignoreDivEnd = False
            else:
                divType = self._docStructure.endDiv(None)
                if divType == self._docStructure.BOOK:
                    self._footnotes.writeFootnotes()
                elif divType == self._docStructure.GROUP:
                    if self._groupEmpty:
                        print 'Ignoring empty book group'
                        self._docStructure.groupNumber -= 1
                        self._htmlWriter.closeAndRemove()
                        self._groupHtmlOpen = False
                elif divType == self._docStructure.INTRO:
                    if self._bibleHtmlOpen:
                        self._bibleIntroWritten = True
                    elif self._groupHtmlOpen:
                        self._groupIntroWritten = True
                        
        elif name == 'figure':
            if self._inIntro:
                self._introTextFound = True
            OsisHandler.endElement(self, name)
                
        elif name == 'l':
            if self._lineSpan:
                self._writeHtml('</span>\n')
            else:
                if self._inIntro:
                    self._writeHtml('</span>')
                OsisHandler.endElement(self, name)
              
        elif name == 'note':
            if self._inFootnote:
                self._inFootnoteRef = False
            OsisHandler.endElement(self, name)
                
        elif name == 'reference':
            if self._inFootnoteRef:
                self._inFootnoteRef = False
            else:
                OsisHandler.endElement(self, name)
        
        elif name == 'title':
            if self._inTitle:
                self._inTitle = False
                if self._ignoreTitle:
                    self._ignoreTitle = False
                        
                elif self._headerProcessed:
                    titleWritten = False
                    if not self._docStructure.inBook:
                        titleWritten = self._processIntroTitle()
                    elif self._inIntro:
                        titleWritten = self._processBookIntroTitle()
                    else:
                        titleWritten = self._processScriptureTitle()                
                    if titleWritten:
                        self._breakCount = 2
                        self._psDivTitle = False
                        self._canonicalTitleWritten = False
                        if re.search('chapter', self._titleTag) is not None:
                            self._chHeadingWritten = True
                
            elif self._inCanonicalTitle:
                closingTag = ''
                if self._context.canonicalClassDefined:
                    closingTag = '</span>'
                else:
                    closingTag = '</i>' 
                self._inCanonicalTitle = False
                self._writeHtml(closingTag + '<br />\n')
                self._breakCount = 1
                self._canonicalTitleWritten = True
                if self._docStructure.verse != '':
                    self._inVerse = True
                    self._verseEmpty = True
                    if self._chTitleWritten or self._docStructure.verse != '1':
                        self._verseText = '<sup>' + self._docStructure.verse + '</sup>'
                        self._verseNumWritten = True
                        
            elif self._inChapterTitle:
                chAttribute =''
                if not self._chHeadingWritten:
                    chAttribute = 'chapter="%s" ' % self._docStructure.chapter
                self._chapterTitle = '<h3 %s class="x-chapter-title">%s</h3>' % (chAttribute, self._chapterTitle)
                if self._chFootnoteMarker != '':
                    self._chapterTitle += self._chFootnoteMarker
                    self._chFootnoteMarker = ''
                self._chapterTitle += '<br />'
                self._chHeadingWritten = True
                self._inChapterTitle = False
                
        else:
            OsisHandler.endElement(self, name)


    def characters(self, content):
        text = content.strip()
        
        if self._inFootnoteRef:
            self._footnotes.changeVerseId(text)
            
        elif self._inTitle:
            if self._headerProcessed:
                if not self._ignoreTitle:
                    if self._inFootnote:
                        self._handleFootnoteTextInTitle(text)
                    else:
                        self._titleText += content
                        self._breakCount = 0
            elif self._context.title == '':
                    self._context.title = content
                    
        elif self._inChapterTitle:
            if self._inFootnote:
                self._handleFootnoteTextInTitle(text)
            else:
                self._chapterTitle += text
                     
        else:
            if self._headerProcessed:
                if self._inIntro or not self._docStructure.inBook:
                    if len(text) > 0:
                        self._introTextFound  = True
                        self._introDivTextFound  = True
                        self._readyForSubtitle = False
                        if self._inFootnote and not self._footnoteMarkerWritten:
                            # Footnote in introduction
                            self._startFootnoteAndWriteMarker('')
                        self._checkGeneratePara()
                        self._writeHtml(content)
                else:
                    if self._inVerse and self._firstVerse and self._verseEmpty and not self._verseNumWritten:
                        if not self._bookTitleWritten:
                            self._writeBookTitle()
                        if not self._chTitleWritten and not self._singleChapterBook:
                            self._writeChapterTitleOrNumber()          
                        if not self._chNumWritten or self._docStructure.verse != '1':
                            verseNumber = '<sup>' + self._docStructure.verse + '</sup>'
                            self._verseText += verseNumber
                            self._verseNumWritten = True
                        
                    if not self._ignoreText:
                        if len(text) > 0:
                            if not self._inCanonicalTitle:
                                self._checkGeneratePara()
                            if self._inVerse and not self._inFootnote:
                                self._verseTextFound = True
                                # Write book/chapter title if not already written
                                if not self._bookTitleWritten:
                                    self._writeBookTitle()
                                if self._chapterTitle != '':
                                    self._writeChapterTitle()
                                # Deal with verse numbers supplied as "[nn]"
                                # First of all, check for such a number right at the start of the verse
                                # This needs to replace the verse number obtained from osisID
                                if self._verseEmpty and self._verseNumWritten:
                                    match = re.match(r'\[([0-9-]+)\]',content)
                                    if match and match.group(1) != self._docStructure.verse:
                                        # Remove the existing verse number (<sup>nn</sup>)
                                        verseLen = len(self._docStructure.verse) + 11
                                        self._verseText = self._verseText[:-verseLen]                                       
                                self._verseEmpty = False
                                content = re.sub(r'\['+self._docStructure.verse+r'\]\s*', '', content)
                                content = re.sub(r'\[([0-9-]+)\]\s*', r'<sup>\1</sup>', content)
                            if self._inFootnote and not self._footnoteMarkerWritten:
                                # This is a footnote without a reference
                                verseRef = '%s:%s' % (self._docStructure.chapter, self._docStructure.verse)
                                self._startFootnoteAndWriteMarker(verseRef)
                            self._writeHtml(content)           

    # The _processBodyTag function is called from the base class startElement
    def _processBodyTag(self, name, attrs):   
        if name == 'chapter':
            osisId = self._getAttributeValue(attrs,'osisID')
            if osisId is not None:
                # Start of a chapter
                # If this is the first chapter of the book, write book title and any intro

                if self._inIntro:   
                    if len(self._introText) > 0:
                        # Remove unwanted breaks at start of intro before writing
                        while self._introText.startswith('<br />'):
                            self._introText = self._introText[6:]
                        if self._bibleStarting and self._context.config.bibleIntro and not self._bibleIntroWritten:
                            self._htmlWriter.open('bible')
                            self._bibleHtmlOpen = True
                            self._closeParagraph()
                            self._writeIntroText()
                            self._bibleIntroWritten = True
                            self._introText = ''
                        elif self._firstBook and self._context.config.testamentIntro and not self._groupIntroWritten:
                            self._openGroupHtml()
                            self._closeParagraph()
                            self._writeIntroText()
                            self._introText = ''
                            self._groupIntroWritten = True
                            
                    # Ensure testament title is written
                    if self._firstBook and not self._groupTitleWritten and self._groupTitle != '':
                        self._openGroupHtml()
                    
                    self._openBookHtml()

                    if self._bookTitleFound or not self._context.config.bookTitlesInOSIS:
                        self._writeBookTitle()
                    if len(self._introText) > 0:
                        if not self._bookTitleWritten:
                            self._writeBookTitle()
                        self._introText += '<br />\n' 
                        self._writeIntroText()
                        self._introText = ''
                    self._inIntro = False
                    self._introStyleStarted = False
                
                chId = self._getAttributeValue(attrs,'sID')
                if chId is not None:
                    self._ignoreChEnd = True        # This is a milestone tag
                else:
                    self._ignoreChEnd = False       # This is an enclosing tag
                    chId = osisId
                self._docStructure.newChapter(chId)
                                
                # If a chapter/psalm heading format is defined, then write the heading
                self._chapterTitle = ''
                self._chTitleWritten = False
                self._chHeadingWritten = False
                self._startingChapter = True
                titleFormat = ''
                bookId = self._docStructure.bookId
                if bookId == 'Ps':
                    titleFormat = self._context.config.psalmTitle
                elif not self._singleChapterBook:
                    titleFormat = self._context.config.chapterTitle
                if titleFormat != '':
                    title = titleFormat % self._docStructure.chapter
                    self._chapterTitle = '<h3 chapter="%s" class="x-chapter-title">%s</h3><br />' % (self._docStructure.chapter, title)             
     
                self._bibleStarting = False
                self._firstBook = False
                
                # Do not write chapter number yet, in case there is a heading to write
            
            else:
                chId = self._getAttributeValue(attrs,'eID')
                if chId is not None:
                    self._docStructure.endChapter(chId)
                    self._writeBreak(True)
                else:
                    print 'Chapter tag does not have expected attributes - ignoring'
                    
        elif name == 'div':
            divType = self._getAttributeValue(attrs, 'type')
            if divType == 'bookGroup':
                if self._docStructure.startGroup():
                    groupNumber = self._docStructure.groupNumber
                    self._startGroup(groupNumber)

            elif divType == 'book':
                self._groupEmpty = False
                
                # Finish off any preceding Bible or testament introduction
                if self._bibleHtmlOpen or self._groupHtmlOpen:
                    self._footnotes.writeFootnotes()
                    self._htmlWriter.close()
                    self._bibleHtmlOpen = False
                    self._groupHtmlOpen = False
                
                # See which book is starting
                bookRef = self._getAttributeValue(attrs,'osisID')
                if self._docStructure.startBook(bookRef):
                    if not self._context.config.testamentGroups:
                        groupIndex = self._context.config.bookGroup(bookRef)
                        if not self._firstBook and groupIndex != self._groupIndex:
                            self._docStructure.groupNumber += 1
                            self._startGroup(self._docStructure.groupNumber)

                        self._groupIndex = groupIndex
                            
                    self._bookTitle = self._context.config.bookTitle(bookRef)
                    self._inIntro = True
                    self._introText = ''
                    self._introTextFound = False
                    self._introTitleWritten = False
                    self._bookTitleFound = False
                    self._bookTitleWritten = False
                    self._firstTitle = True
                    self._verseTextFound = False
                    print 'Processing book ', bookRef
                    if bookRef == 'Phlm' or bookRef == '2John' or bookRef == '3John' or bookRef == 'Jude' or bookRef == 'Obad':
                        self._singleChapterBook = True
                    else:
                        self._singleChapterBook = False
                    # Don't open book HTML yet, in case there is a testament introduction to write
                    
            elif divType == 'section':
                secRef = self._getAttributeValue(attrs, 'sID')
                self._docStructure.startSection(secRef)
                if secRef is not None:
                    self._ignoreDivEnd = True           # Milestone tag
                    
            elif divType in self.INTRO_DIVS:
                if self._bibleStarting and not self._docStructure.inGroup:
                    self._introDivTextFound = False
                    if not self._bibleHtmlOpen:
                        self._htmlWriter.open('bible')
                        self._bibleHtmlOpen = True
                        self._introTextFound = False
                        self._bibleIntroWritten = True
                    self._docStructure.startIntro()
                elif self._docStructure.inGroup and self._groupEmpty:
                    self._introDivTextFound = False
                    if not self._groupHtmlOpen:
                        self._openGroupHtml()
                        self._introTextFound = False
                    self._docStructure.startIntro()
                else:
                    self._docStructure.otherDiv()
 
            else:
                secRef = self._getAttributeValue(attrs, 'eID')
                if secRef is not None:
                    divType = self._docStructure.endDiv(secRef)
                    self._ignoreDivEnd = True
                else:
                    self._docStructure.otherDiv()
                    
        elif name == 'foreign':
            verseEmpty = self._verseEmpty
            if self._inVerse:
                # prevents style being applied to verse number
                self._verseEmpty = False
            self._writeHtml('<span class="foreign">')
            self._verseEmpty = verseEmpty
              
        elif name == 'hi':
            verseEmpty = self._verseEmpty
            if self._inVerse:
                self._verseEmpty = False  # Prevents highlight being applied to verse number
            OsisHandler._handleHi(self, attrs)
            self._verseEmpty = verseEmpty
            
        elif name == 'l':
            self._lineSpan = False
            htmlTag = self._lineHtml(attrs)
            if self._inVerse and self._verseEmpty:
                if self._chNumWritten:
                    self._lineSpan = True
                    self._verseText = self._verseText + '<span class="first-line">'
                else:
                    self._verseText = htmlTag + self._verseText
            else:
                self._verseEmpty = False
                self._writeHtml(htmlTag)
                if self._introStyleStarted:
                    self._writeHtml('<span class="x-introduction">')
            
        elif name == 'lg':
            if not self._inIntro and not self._bookTitleWritten and self._bookHtmlOpen:
                self._writeBookTitle()
            if self._firstVerse and not self._chTitleWritten and not self._singleChapterBook:
                self._writeChapterTitleOrNumber()
            OsisHandler._processBodyTag(self, name, attrs)
            
        elif name == 'list':
            listType = self._getAttributeValue(attrs, 'subType')
            if listType is None and self._inIntro and self._introStyleStarted:
                htmlTag = '<ul class="x-introduction">\n'
                self._writeHtml(htmlTag)
                self._inList = True
            else:
                OsisHandler._processBodyTag(self, name, attrs)
            
        elif name == 'p':
            self._endGeneratedPara()
            if not self._inIntro and not self._bookTitleWritten and self._bookHtmlOpen:
                self._writeBookTitle()
            if self._firstVerse and not self._chTitleWritten and not self._singleChapterBook:
                self._writeChapterTitleOrNumber()
            overrideSubType = None
            if self._inVerse and self._verseEmpty and self._chNumWritten:
                overrideSubType='first-para'
            elif self._introStyleStarted:
                overrideSubType = 'x-introduction'
            paraTag = self._generateParaTag(attrs, overrideSubType)
            if 'x-introduction' in paraTag and self._inIntro:
                self._introStyleStarted = True
            self._inParagraph = True
            if self._inVerse and self._verseEmpty:
                self._verseText = paraTag + self._verseText
            else:
                self._writeHtml(paraTag)

        elif name == 'reference':
            # reference tags are expected but are ignored
            # apart from glossary references and references in footnotes
            refType = self._getAttributeValue(attrs, 'type')
            if refType == "x-glossary":
                verseEmpty = self._verseEmpty
                if self._inVerse:
                    # prevents style being applied to verse number
                    self._verseEmpty = False
                OsisHandler._processReference(self, attrs)
                self._verseEmpty = verseEmpty
    
            elif self._inFootnote and not self._footnoteMarkerWritten:
                self._inFootnoteRef = True
                osisRef = self._getAttributeValue(attrs, 'osisRef')
                if osisRef is None:
                    # reference not supplied as an attribute
                    verseRef = '%s:%s' % (self._docStructure.chapter, self._docStructure.verse)
                    self._startFootnoteAndWriteMarker(verseRef)
                elif not self._footnoteRef(osisRef):
                    # We already have a reference, so do not process contents of this reference tag
                    self._inFootnoteRef = False
                    self._inFootnote = False
                    self._ignoreText = True
                    
            elif self._figHtml != '':
                self._ignoreText = True
       
        elif name == 'title':
            canonical = self._getAttributeValue(attrs,'canonical')
            if canonical == 'true':
                # A canonical title has special treatment
                # Make sure Psalm title or number is written before the cannonical title
                if not self._bookTitleWritten:
                    self._writeBookTitle()
                if self._startingChapter and not self._chTitleWritten:
                    self._writeChapterTitleOrNumber()
                    self._startingChapter = False
                if self._inVerse:
                    # A canonical title is not part of the verse
                    self._inVerse = False
                    self._verseText = ''
                    if self._firstVerse and not self._chTitleWritten:
                        self._writeChapterTitleOrNumber()
                if self._context.canonicalClassDefined:
                    self._writeHtml('<span class="canonical">')
                else:
                    self._writeHtml('<i>')
                self._inCanonicalTitle = True
                    
            else:
                titleType = self._getAttributeValue(attrs,'type')
                if titleType == 'runningHead':
                    self._inTitle = True
                    self._ignoreTitle = True
                elif titleType == 'x-chapterLabel' and self._docStructure.inBook and not self._inIntro:
                    if self._singleChapterBook:
                        self._inTitle = True
                        self._ignoreTitle = True
                    else: 
                        self._chapterTitle = ''
                        self._inChapterTitle = True
                else:
                    level = self._getAttributeValue(attrs,'level')
                    if level is not None:
                        # Header levels 1 and 2 are for testaments and books, so titles start at 3
                        headerLevel = int(level) + 2
                    else:
                        headerLevel = self._defaultHeaderLevel
                    subType = self._getAttributeValue(attrs,'subType')
                    if titleType == 'x-chapterLabel':
                        subType += ' x-chapter-title'
                    chapter = ''
                    if (self._context.outputFmt != 'fb2'):
                        if (not self._singleChapterBook) and (self._startingChapter or (self._inVerse and self._firstVerse and self._verseEmpty and not self._canonicalTitleWritten)):
                            if not self._chHeadingWritten:
                                chapter = ' chapter="%s"' % self._docStructure.chapter
                    if self._readyForSubtitle and headerLevel == 4:
                         self._titleTag = '<h4 class="book-subtitle">'              
                    elif subType is not None:
                        self._titleTag = '<h%d class="%s"%s>' % (headerLevel, subType, chapter)
                    else:
                        self._titleTag = '<h%d%s>' % (headerLevel, chapter)
                    self._inTitle = True
                    self._titleText = ''
                    self._readyForSubtitle = False
                    
        elif name == 'transChange':
            verseEmpty = self._verseEmpty
            if self._inVerse:
                # prevents style being applied to verse number
                self._verseEmpty = False
            self._writeHtml('<span class="transChange">')
            self._verseEmpty = verseEmpty
                    
        elif name == 'verse':
            verse = self._getAttributeValue(attrs,'sID')
            if verse is not None:
                self._startVerse(verse)
            else:
                verse = self._getAttributeValue(attrs,'eID')
                if verse is not None:
                    self._docStructure.endVerse(verse)
                    if not self._lineGroupPara:
                        self._endGeneratedPara()
                    if not self._verseEmpty:
                        if self._chHeadingWritten:
                            # remove chapter attribute from chapter number if a chapter heading has been written
                            self._verseText = re.sub(r'span chapter="\d+"', 'span', self._verseText)
                        # Add a break if immediately following a canonical title
                        if self._canonicalTitleWritten:
                            self._htmlWriter.write('<br />')
                            self._canonicalTitleWritten = False
                        self._htmlWriter.write(self._verseText + '\n')
                        self._firstVerse = False
                        self._chHeadingWritten = False
                    self._inVerse = False
                    self._verseText =''
        else:
             OsisHandler._processBodyTag(self, name, attrs)
                
    def _openGroupHtml(self):
        if not self._groupHtmlOpen:
            if self._bibleHtmlOpen:
                # Write out any footnotes in the preceding Bible introduction
                self._footnotes.writeFootnotes()
            else:
                self._footnotes.reinit()
            groupNumber = self._docStructure.groupNumber
            htmlName = 'group%d' % groupNumber
            self._htmlWriter.open(htmlName)
            self._groupHtmlOpen = True
            self._bookHtmlOpen = False
            self._bibleHtmlOpen = False
            if self._groupTitle != '':
                self._htmlWriter.write('<h1>%s</h1>\n' % self._groupTitle)
                self._groupTitleWritten = True
                
    def _openBookHtml(self):
        if self._groupHtmlOpen or self._bibleHtmlOpen:
            # Write out any footnotes in the Bible or Testament introduction
            self._footnotes.writeFootnotes()
        bookId = self._docStructure.bookId
        self._htmlWriter.open(bookId)
        self._groupHtmlOpen = False
        self._bookHtmlOpen = True
        self._bibleHtmlOpen = False
                
    def _writeHtml(self, html):
        if self._inFootnote and not self._writingFootnoteMarker:
            OsisHandler._writeHtml(self, html)
        elif not self._inTitle and not self._inCaption:
            self._suppressBreaks = False
            if self._inIntro:
                self._introText += html
            elif self._inVerse and not self._verseEmpty:
                self._verseText += html
            else:
                OsisHandler._writeHtml(self, html)
            self._breakCount = 0   # will be overwritten if called from _writeBreak()
        else:
            OsisHandler._writeHtml(self, html)

    def _writeTitle(self):
        if len(self._titleText) > 0:
            origInVerse = self._inVerse
            if self._psDivTitle:
                self._inVerse = False      # causes title to be written before Psalm heading
            titleWritten = OsisHandler._writeTitle(self)
            self._inVerse = origInVerse
            return titleWritten
        else:
            return False
        
    def _writeChapterNumber(self):
        chAttribute = ''
        if not self._chHeadingWritten:
            chAttribute = 'chapter="%s"' % self._docStructure.chapter
        if self._context.chNumClassDefined:
            spanHtml = '<span %s class="x-chapter-number">%s</span>' % (chAttribute, self._docStructure.chapter)
        else:
            spanHtml = '<span %s style="font-size:36pt; float:left; line-height:1">%s</span>' % (chAttribute, self._docStructure.chapter)
        if self._inVerse:
            self._verseText += spanHtml
        else:
            self._writeHtml(spanHtml)
        self._chNumWritten = True 
            
    def _writeChapterTitle(self):
        self._htmlWriter.write(self._chapterTitle)
        self._chapterTitle = ''
        self._chTitleWritten = True
        self._chHeadingWritten = True
        self._breakCount = 2
        
    def _startVerse(self, verse):
        self._docStructure.newVerse(verse)
        self._inVerse = True
        self._verseText = ''
        self._verseEmpty = True
        self._chNumWritten = False
        self._verseNumWritten = False
        self._psDivTitleFound = False
        if self._startingChapter:
            self._firstVerse = True
        else:
            verseNumber = '<sup>' + self._docStructure.verse + '</sup>'
            self._firstVerse = False
            self._verseText = verseNumber
            self._verseNumWritten = True
            
        self._startingChapter = False
        
    def _startGeneratedPara(self):
        paraTag = '<p class="x-indent-0">'
        if self._inVerse and self._firstVerse and self._verseEmpty and self._chNumWritten:
            paraTag = '<p class="first-para">'
        self._writeHtml(paraTag)
        self._inGeneratedPara = True
        
    def _writeIntroText(self):
        # If this is being written as a book or testament introduction, adjust any initial heading level to create TOC entry as required
        if not self._bookHtmlOpen:
            # Find the first title, and check that this is before the start of the first paragrapph
            title = re.search(r'<h3.*?>(.*?)</h3>', self._introText, re.DOTALL)
            para = re.search(r'<p.*?>', self._introText)
            if title:
                if para is None or title.start() < para.start():
                    headerLevel = self._context.topHeaderLevel
                    if self._groupHtmlOpen:
                        if self._groupTitle != '':
                            if self._context.config.introInContents:
                                headerLevel += 1
                            else:
                                headerLevel = 0  # No toc entry required
                                
                    if headerLevel == 1 or headerLevel == 2:
                        newTitle = '<h%d>%s</h%d>' % (headerLevel, title.group(1), headerLevel)
                        newIntro = self._introText[:title.start()] + newTitle + self._introText[title.end():]
                        self._introText = newIntro
            
        self._htmlWriter.write(self._introText)
        
    def _handlePsDivHeading(self, text):
        self._psDivTitle = False
        if self._docStructure.bookId == 'Ps' and self._context.config.psalmDivTitle != '':
            if self._context.config.psalmDivSubtitle != ''  and self._psDivTitleFound:
                m = re.match(self._context.config.psalmDivSubtitle, text, re.UNICODE)
                if m:
                    self._psDivTitle = True
                    self._psDivTitleFound = False
            if not self._psDivTitle:
                m = re.match(self._context.config.psalmDivTitle, text, re.UNICODE)
                if m:
                    self._psDivTitle = True
                    self._psDivTitleFound = True
                                            
            if (self._psDivTitle):
                # This is a psalm division title or subtitle
                # Apply approriate style and make sure this is not marked as a chapter heading
                self._titleTag = re.sub(' chapter=".+"', '', self._titleTag)
                self._titleTag = re.sub(' class=".+"', '', self._titleTag)
                self._titleTag = re.sub('>', ' class="psalm-div-heading">', self._titleTag)
                
    def _processIntroTitle(self):   
        rawText = re.sub('<.*>', ' ', self._titleText)
        writeTitle = True
        titleWritten = False
        if not self._introTextFound:
            self._introTextFound = True
            self._introDivTextFound = True
            # This is the initial title
            if self._docStructure.inGroup and self._groupEmpty and self._groupTitle != '' and rawText.lower() == self._groupTitle.lower():
                # Do not write initial title which duplicates the testament heading
                writeTitle = False
                self._introTextFound = False
                self._introDivTextFound = False
            elif self._context.config.introInContents or not self._docStructure.inGroup or self._groupTitle == '':
                # Adjust initial title level to create the appropriete TOC entry
                headerLevel = self._context.topHeaderLevel
                if self._docStructure.inGroup and self._groupTitle != '':
                    headerLevel = 2
                self._titleTag = re.sub(r'<h\d+','<h%d' % headerLevel, self._titleTag)
        elif not self._introDivTextFound:
            self._introDivTextFound = True
            if self._context.config.introInContents:
                headerLevel = self._context.topHeaderLevel
                if self._docStructure.inGroup:
                     headerLevel = 2
                self._titleTag = re.sub(r'<h\d+','<h%d' % headerLevel, self._titleTag)
                           
        if writeTitle:
            titleWritten = self._writeTitle()

    def _processBookIntroTitle(self):
        titleWritten = False
        rawText = re.sub('<.*>', ' ', self._titleText)
        if self._context.config.combinedIntros and rawText.lower() == self._groupTitle.lower():
            if self._context.config.bibleIntro and self._docStructure.groupNumber == 1 and self._introTextFound:
                # If testament title is found in Bible intro, this is division between Bible and testament intro
                self._closeParagraph()
                self._introText += '\n'
                self._htmlWriter.open('bible')
                self._bibleHtmlOpen = True
                self._writeIntroText()
                self._bibleIntroWritten = True
                self._introText = ''
                self._introTextFound = False
                self._introTitleWritten = False
                self._openGroupHtml()
                    
        elif rawText.lower() == self._bookTitle.lower():
            self._bookTitleFound = True
            if self._context.config.combinedIntros and self._firstBook and self._introTextFound:
                # For the first book in a group, anything before this is assumed to be a Bible/testament introduction
                self._closeParagraph()
                self._introText += '\n'               
                self._openGroupHtml()
                self._writeIntroText()
                self._groupIntroWritten = True
                self._introText = ''
                self._introTextFound = False
                self._introTitleWritten = False
                self._openBookHtml()
            #
            # If title is at the start of the intro, it is the book title
            # Do not include this in intro text as book title will be included anyway
            if self._introTextFound:
                titleWritten = self._writeTitle()
            else:
                self._introText = ''
                if self._context.config.bookTitlesInOSIS:
                    self._bookTitle = self._titleText
                if self._context.config.bookSubtitles:
                    self._readyForSubtitle = True
                    
        elif not self._bookTitleFound and self._context.config.bookTitlesInOSIS and not self._introTextFound:
                #
                # This is the book title
                self._bookTitle = self._titleText
                self._bookTitleFound = True
                if self._context.config.bookSubtitles:
                    self._readyForSubtitle = True
                    
        else:
                        
            if not self._introTextFound and not self._introTitleWritten and not self._singleChapterBook:
                # Intro title may be needed in toc - but make sure this is not a book subtitle
                titleTag = self._titleTag
                if self._context.config.introInContents and not 'book-subtitle' in titleTag:
                    self._titleTag = titleTag.replace('>', ' chapter="'+rawText+'">')
                    self._introTitleWritten = True
            else:
                # An initial psalm division title may occur at the end of the intro - handle this
                self._handlePsDivHeading(rawText)
                    
                # Terminate any current paragraph to avoid an unwanted introduction style from being applied
                if self._inParagraph:
                    self._writeHtml('</p>\n')
                    self._inParagraph = False
        
            titleWritten = self._writeTitle()
        return titleWritten
            
    def _processScriptureTitle(self):
        titleWritten = False
        rawText = re.sub('<.*>', ' ', self._titleText)    
        if rawText.lower() == self._bookTitle.lower() and not self._bookTitleFound:
            self._bookTitleFound = True
            if self._verseTextFound or not self._firstTitle:
                titleWritten = self._writeTitle()
            elif self._context.config.bookSubtitles:
                self._readyForSubtitle = True
        elif self._firstTitle and not self._bookTitleFound and self._context.config.bookTitlesInOSIS and not self._verseTextFound and not self._docStructure.inSection:
            #
            # This is the book title
            self._bookTitle = self._titleText
            self._bookTitleFound = True
            self._firstTitle = True
            if self._context.config.bookSubtitles:
                self._readyForSubtitle = True
        else:
            # Write book title before any others
            if not self._bookTitleWritten:
                self._writeBookTitle()
            # Check for Psalm division titles
            self._handlePsDivHeading(rawText)
                    
            if (self._psDivTitle):
                # This is a psalm division title or subtitle
                titleWritten = self._writeTitle()
                
            else:
                # Write any chapter title before this title
                if self._chapterTitle != '':
                    self._writeChapterTitle()
                self._psDivTitleFound = False
                titleWritten = self._writeTitle()   
                self._firstTitle = False
        return titleWritten
                
    def _footnoteRef(self, osisRef):
        isRange = False
        endRef = ''
        scriptureFootnote = True
        colonPos = osisRef.find(':')
        if colonPos >= 0:
            workRef = osisRef[:colonPos]
            if workRef == self._osisIDWork:
                reference = osisRef[colonPos+1:]
            else:
                # Footnote is not linked to scripture
                scriptureFootnote = False
        else:
            reference = osisRef
        if (scriptureFootnote):
            separatorPos = reference.find('-')
            if separatorPos >= 0:
                isRange = True
                endRef = reference[separatorPos+1:]
                reference = reference[:separatorPos]
            refParts = re.split('[.!]', reference)
            refBook = refParts[0]
            refVerse = '%s:%s' % (refParts[1], refParts[2])
            if isRange:
                refVerse += '-'
                endParts = re.split('.', endRef)
                if endParts[1] != refParts[1]:
                    refVerse += '%s:' % endParts[1]
                refVerse += endParts[2]
            footnoteNo = self._footnotes.newFootnote(refBook, refVerse)
            self._writeFootnoteMarker(refBook, footnoteNo)  
        return scriptureFootnote
    
    def _writeFootnoteMarker(self, refBook, noteRef):
        if self._inChapterTitle:
            refString = self._footnoteMarker(refBook, noteRef)    
            self._chFootnoteMarker += refString
        else:
            OsisHandler._writeFootnoteMarker(self, refBook, noteRef)
        self._footnoteMarkerWritten = True
        
    def _writeBookTitle(self):
        self._bookTitle = re.sub(r'(\S)<br />(\S)', r'\1 <br />\2', self._bookTitle)
        self._htmlWriter.write('<h2>%s</h2>' % self._bookTitle)
        self._bookTitleWritten = True
        self._breakCount = 2
        
    def _startGroup(self, groupNumber):
        self._groupTitle = self._context.config.groupTitle(groupNumber)
        self._groupIntroWritten = False
        self._groupTitleWritten = False
        self._firstBook = True
        self._groupEmpty = True
        if self._groupTitle != '' and (groupNumber != 1 or not self._context.config.bibleIntro):
            self._openGroupHtml()
            self._introTextFound = False
            
    def _writeChapterTitleOrNumber(self):
        if self._chapterTitle != '':
            self._writeChapterTitle()
        elif not self._chNumWritten:
            self._writeChapterNumber()
            
    def _startFootnoteAndWriteMarker(self, verseRef):
        book = self._docStructure.bookRef()
        footnoteNo = self._footnotes.newFootnote(book, verseRef)
        self._writeFootnoteMarker(book, footnoteNo)
        
    def _handleFootnoteTextInTitle(self, content):
        if not self._footnoteMarkerWritten:
            verseRef = '%s:%s' % (self._docStructure.chapter, self._docStructure.verse)
            if verseRef == ':':
                # Not in a verse
                verseRef = ''
            self._startFootnoteAndWriteMarker(verseRef)
        self._footnotes.addFootnoteText(content)
        
    def _startFootnote(self, attrs):
        # This function will be called from the base class _processBodyTag function
        osisRef = self._getAttributeValue(attrs, 'osisID')
        if osisRef is not None:
            self._inFootnoteRef = True
            self._inFootnote = self._footnoteRef(osisRef)
        else:
            self._footnoteMarkerWritten = False
            self._inFootnote = True
        self._inFootnoteRef = False


