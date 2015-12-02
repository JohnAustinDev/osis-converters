from xml.sax import handler
from calibre_plugins.osis_input.structure import DocStructure, OsisError
from calibre_plugins.osis_input.footnote import BookFootnotes
import re

class OsisHandler(handler.ContentHandler):
    def __init__(self, htmlWriter, context):
        self._bibleHtmlOpen = False
        self._bibleIntroWritten = False
        self._bibleStarting = True
        self._bookTitle = ''
        self._bookTitleFound = False
        self._bookTitleWritten = False
        self._breakCount = 0
        self._canonicalTitleWritten = False
        self._chFootnoteRef = ''
        self._chNumWritten = False
        self._chHeadingWritten = False
        self._chapterTitle = ''
        self._chTitleWritten = False
        self._context = context
        self._docStructure = DocStructure()
        self._firstBook = True                           # First book of testament
        self._firstTitle = False
        self._firstVerse = False
        self._footnoteNo = 0
        self._footnoteRefWritten = False
        self._groupEmpty = False
        self._groupIndex = 0
        self._groupIntroWritten = False
        self._groupHtmlOpen = False
        self._groupTitle = ''
        self._headerProcessed = False
        self._hiHtmlTag = ['','','']
        self._hiLevel = 0
        self._htmlWriter = htmlWriter
        self._inCanonicalTitle = False
        self._inChapterTitle = False
        self._ignoreChEnd = False
        self._ignoreDivEnd = False
        self._ignoreTitle = False
        self._ignoreText = False
        self._inFootnote = False
        self._inFootnoteRef = False
        self._inGeneratedPara = False
        self._inHeader = False
        self._inIntro = False
        self._inParagraph = False
        self._inTitle = False
        self._introStyleStarted = False
        self._introText = ''
        self._introTextFound = False
        self._introTitleWritten = False
        self._inVerse = False 
        self._inWork = False
        self._lineGroupPara = False
        self._lineSpan = False
        self._osisFound = False
        self._osisIDWork= None
        self._osisTextFound = False
        self._psDivTitle = False
        self._psDivTitleFound = False
        self._readyForSubtitle = False
        self._singleChapterBook = False
        self._suppressBreaks = False
        self._startingChapter = False
        self._titleTag = ''
        self._titleText = ''
        self._titleWritten = False
        self._verseEmpty = True
        self._verseNumWritten = False
        self._verseText = ''
        self._footnotes = BookFootnotes(htmlWriter, self._context.config.epub3)
        
        # For fb2, we need chapter/psalm titles.
        # If no format has been provided, set up format as the chapter/psalm number only
        
        if self._context.outputFmt == 'fb2':
            if self._context.config.chapterTitle == '':
                self._context.config.chapterTitle = '%s'
            if self._context.config.psalmTitle == '':
                self._context.config.psalmTitle = '%s'
        
    def startDocument(self):
        self._bibleHtmlOpen = False
        self._bibleIntroWritten = False
        self._bibleStarting = True
        self._bookTitle = ''
        self._breakCount = 0
        self._canonicalTitleWritten = False
        self._chapterTitle = ''
        self._chFootnoteRef = ''
        self._chNumWritten = False
        self._chHeadingWritten = False
        self._firstBook = True
        self._groupEmpty = False
        self._groupHtmlOpen = False
        self._groupIndex = 0
        self._headerProcessed = False
        self._hiHtmlTag = ['','','']
        self._hiLevel = 0
        self._inCanonicalTitle = False
        self._inChapterTitle = False
        self._ignoreChEnd = False
        self._ignoreDivEnd = False
        self._ignoreText = False
        self._ignoreTitle = False
        self._inFootnote = False
        self._inFootnoteRef = False
        self._inGeneratedPara = False
        self._inHeader = False
        self._inIntro = False
        self._inParagraph = False
        self._inTitle = False
        self._introStyleStarted = False
        self._introText = ''
        self._introTextFound = False
        self._introTitleWritten = False
        self._inVerse = False 
        self._inWork = False
        self._lineGroupPara = False
        self._osisFound = False
        self._osisTextFound = False
        self._psDivTitle = False
        self._psDivTitleFound = False
        self._readyForSubtitle = False
        self._suppressBreaks = False
        self._titleText = ''
        self._verseNumWritten = False
        self._verseText = ''
        self._verseTextFound = False
  
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
            if self._ignoreChEnd:
                self._ignoreChEnd = False
            else:
                self._docStructure.endChapter(self._docStructure.chapterRef)
                self._writeBreak(True)

        elif name == 'catchWord':
            self._writeHtml('</i>')
            
        elif name == 'div':
            if self._ignoreDivEnd:
                self._ignoreDivEnd = False
            else:
                divType = self._docStructure.endDiv(None)
                if divType == self._docStructure.BOOK:
                    self._footnotes.writeFootnotes()
                    
        elif name == 'foreign':
            self._writeHtml('</span>')
            
        elif name == 'head':
            self._writeHtml('</div>')
                
        elif name == 'header':
            if self._inHeader:
                self._inHeader = False
                self._headerProcessed = True
            else:
                raise OsisError('unexpected end of header')
        
        elif name == 'hi':
            self._hiLevel -= 1
            if self._hiHtmlTag[self._hiLevel] != '':
                self._writeHtml('</%s>' % self._hiHtmlTag[self._hiLevel])
                self._hiHtmlTag[self._hiLevel] = ''
                
        elif name == 'item':
            self._writeHtml('</li>\n')
                
        elif name == 'l':
            if self._lineSpan:
                self._writeHtml('</span>\n')
            else:
                if self._inIntro:
                    self._writeHtml('</span>')
                self._writeHtml('</div>\n')
                self._breakCount = 1
            
        elif name == 'lg':
            if self._lineGroupPara:
                self._writeHtml('</div>\n')
                self._lineGroupPara = False
            
        elif name == 'list':
            self._writeHtml('</ul>\n')
                        
        elif name == 'note':
            if self._inFootnote:
                self._inFootnote = False
                self._footnotes.footnoteComplete()
            else:
                self._ignoreText = False
            
        elif name == 'p':
            if self._inParagraph:
                self._writeHtml('</p>\n')
                self._breakCount = 1
                self._inParagraph = False
                
        elif name == 'reference':
            if self._inFootnoteRef:
                if not self._footnoteRefWritten:
                    self._writeFootnoteRef(self._docStructure.bookId, self._footnoteNo)
                self._inFootnoteRef = False

        elif name == 'title':
            if self._inTitle:
                self._inTitle = False
                if self._ignoreTitle:
                    self._ignoreTitle = False
                        
                elif self._headerProcessed:
                    if self._inIntro:
                        self._processIntroTitle()
                    else:
                        self._processScriptureTitle()                
                    if self._titleWritten:
                        self._breakCount = 2
                        self._psDivTitle = False
                        self._canonicalTitleWritten = False
                        self._suppressBreaks = True
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
                if self._chFootnoteRef != '':
                    self._chapterTitle += self._chFootnoteRef
                    self._chFootnoteRef = ''
                self._chapterTitle += '<br />'
                self._chHeadingWritten = True
                self._inChapterTitle = False
                        
        elif name == 'work':
            if self._inWork:
                self._inWork = False

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
                        self._titleText += text
                        self._breakCount = 0
            elif self._context.title == '':
                    self._context.title = text
                    
        elif self._inChapterTitle:
            if self._inFootnote:
                self._handleFootnoteTextInTitle(text)
            else:
                self._chapterTitle += text
                     
        else :
            if self._headerProcessed:
                if self._inIntro:
                    if len(text) > 0:
                        self._introTextFound  = True
                        self._readyForSubtitle = False
                        if self._inFootnote and not self._footnoteRefWritten:
                            # Footnote in introduction
                            self._startFootnoteAndWriteRef('')
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
                            self._readyForSubtitle = False
                            if not self._inParagraph and not self._inGeneratedPara and not self._inCanonicalTitle:
                                self._startGeneratedPara()
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
                            if self._inFootnote and not self._footnoteRefWritten:
                                # This is a footnote without a reference
                                verseRef = '%s:%s' % (self._docStructure.chapter, self._docStructure.verse)
                                self._startFootnoteAndWriteRef(verseRef)
                            self._writeHtml(content)           

    def _getAttributeValue(self, attrs, attrName):
        for (name, value) in attrs.items():
            if name == attrName:
                return value
        return None
    
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
                            self._writeIntroText()
                            self._bibleIntroWritten = True
                            self._introText = ''
                        elif self._firstBook and self._context.config.testamentIntro and not self._groupIntroWritten:
                            self._openGroupHtml()
                            self._writeIntroText()
                            self._introText = ''
                            self._groupIntroWritten = True
                            
                    # Ensure testament title is written
                    if self._firstBook and not self._groupHtmlOpen and self._groupTitle != '':
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
                    self._chHeadingWritten = True              
     
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
                    
        elif name == 'catchWord':
            self._writeHtml('<i>')
                                  
        elif name == 'div':
            divType = self._getAttributeValue(attrs, 'type')
            if divType == 'bookGroup':
                if self._docStructure.startGroup():
                    groupNumber = self._docStructure.groupNumber
                    if self._groupEmpty:
                        print 'Ignoring empty book group'
                        self._docStructure.groupNumber = groupNumber -1
                    else:
                        self._startGroup(groupNumber)
                        self._groupEmpty = True

            elif divType == 'book':
                self._groupEmpty = False
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
                    self._footnotes.reinit()
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
            
        elif name == 'head':
            self._writeHtml('<div class="heading">')         
                
        elif name == 'hi':
            if not self._ignoreText:
                hiType = self._getAttributeValue(attrs, 'type')
                if hiType == 'bold':
                    self._hiHtmlTag[self._hiLevel] = 'b'
                elif hiType == 'emphasis':
                    self._hiHtmlTag[self._hiLevel] = 'em'
                elif hiType == 'italic':
                    self._hiHtmlTag[self._hiLevel] = 'i'
                elif hiType == 'line-through':
                    self._hiHtmlTag[self._hiLevel] = 's'
                elif hiType == 'sub':
                    self._hiHtmlTag[self._hiLevel] = 'sub'                
                elif hiType == 'super':
                    self._hiHtmlTag[self._hiLevel] = 'sup'
                elif hiType == 'underline':
                    self._hiHtmlTag[self._hiLevel] = 'u'
                else:
                    self._hiHtmlTag[self._hiLevel] = ''
                    print 'Unsupported hi type %s' % hiType
                if self._hiHtmlTag[self._hiLevel] != '':
                    html = '<%s>' % self._hiHtmlTag[self._hiLevel]
                    if self._inVerse and self._verseEmpty:
                        self._verseText += html
                    else:
                        self._writeHtml('<%s>' % self._hiHtmlTag[self._hiLevel])
            else:
                self._hiHtmlTag[self._hiLevel] = ''
            self._hiLevel += 1
            
        elif name == 'index':
            # <index> tags are ignored
            pass
            
        elif name == 'item':
            itemType = self._getAttributeValue(attrs, 'type')
            itemSubType = self._getAttributeValue(attrs, 'subType')
            itemClass = ''
            if itemType is not None:
                itemClass = itemType
                if itemSubType is not None:
                    itemClass += ' '
                    itemClass += itemSubType
            elif itemSubType is not None:
                itemClass = itemSubType
            tag = '<li>'
            if itemClass != '':
                tag = '<li class="%s">' % itemClass     
            self._writeHtml(tag)
     
        elif name == 'lb':
            breakType = self._getAttributeValue(attrs, 'type')
            if breakType != 'x-optional' or self._context.config.optionalBreaks:
                self._writeBreak(False)
            else:
                self._writeHtml(' ')
            
        elif name == 'l':
            self._lineSpan = False
            lineType = self._getAttributeValue(attrs, 'type')
            lineSubType = self._getAttributeValue(attrs, 'subType')
            lineClass = 'poetic-line'
            if lineType is None:
                level = self._getAttributeValue(attrs, 'level')
                if level is not None:
                    lineType = 'x-indent-%s' % level
            if lineType is not None:
                lineClass = '%s %s' % (lineClass, lineType)
                if lineSubType is not None:
                    lineClass =  '%s %s' % (lineClass, lineSubType)
            htmlTag = '<div class="%s">' % lineClass
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
            if not self._inIntro and not self._bookTitleWritten:
                self._writeBookTitle()
            if self._firstVerse and not self._chTitleWritten and not self._singleChapterBook:
                self._writeChapterTitleOrNumber()
            if not self._inParagraph and not self._inGeneratedPara:
                self._writeHtml('<div>')
                self._lineGroupPara = True
            else:
                self._writeBreak(True)
            
        elif name == 'list':
            listType = self._getAttributeValue(attrs, 'subType')
            if listType is None:
                if self._inIntro and self._introStyleStarted:
                    htmlTag = '<ul class="x-introduction">\n'
                else:
                    htmlTag = '<ul>'
            else:
                htmlTag = '<ul class="%s">' % listType
            self._writeHtml(htmlTag)
            
        elif name == 'milestone':
            # <milestone> tags are ignored
            pass
        
        elif name == 'name':
            # <name> tags are ignored
            pass
                
        elif name == 'note':
            noteType = self._getAttributeValue(attrs, 'type')
            notePlace = self._getAttributeValue(attrs, 'placement')
            if noteType == 'study' or notePlace == 'foot':
                # This type of note is a footnote
                osisRef = self._getAttributeValue(attrs, 'osisID')
                if osisRef is not None:
                    self._inFootnoteRef = True
                    self._inFootnote = self._footnoteRef(osisRef)
                    self._inFootnoteRef = False
                else:
                    self._footnoteRefWritten = False
                self._inFootnote = True
            else:
                # Ignore other types of note (generally cross-references)
                self._ignoreText = True
            
        elif name == 'p':
            self._endGeneratedPara()
            if not self._inIntro and not self._bookTitleWritten:
                self._writeBookTitle()
            if self._firstVerse and not self._chTitleWritten and not self._singleChapterBook:
                self._writeChapterTitleOrNumber()
            pClass = ''
            subClass = ''
            pType = self._getAttributeValue(attrs, 'type')
            if pType is not None:
                pClass = pType
            subType = self._getAttributeValue(attrs, 'subType')
            if subType is not None:
                subClass = subType
                if subType == 'x-introduction' and self._inIntro:
                    self._introStyleStarted = True
            elif self._inVerse and self._verseEmpty and self._chNumWritten:
                subClass='first-para'
            elif self._introStyleStarted:
                subClass = '-introduction'
            if pClass == '':
                pClass = subClass
            elif subClass != '':
                pClass += ' '
                pClass += subClass
            paraTag = '<p>'
            if pClass != '':
                paraTag = '<p class="%s">' % pClass
            self._inParagraph = True
            if self._inVerse and self._verseEmpty:
                self._verseText = paraTag + self._verseText
            else:
                self._writeHtml(paraTag)

        elif name == 'reference':
            # reference tags are expected but ignored unless in footnote
            if self._inFootnote and not self._footnoteRefWritten:
                self._inFootnoteRef = True
                osisRef = self._getAttributeValue(attrs, 'osisRef')
                if osisRef is None:
                    # reference not supplied as an attribute
                    verseRef = '%s:%s' % (self._docStructure.chapter, self._docStructure.verse)
                    self._footnoteNo = self._footnotes.newFootnote(self._docStructure.bookId, verseRef)
                elif not self._footnoteRef(osisRef):
                    self._inFootnoteRef = False
                    self._inFootnote = False
                    self._ignoreText = True
                    
        elif name == 'seg':
            # <seg> tags are ignored
            pass
        
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
                elif titleType == 'x-chapterLabel':
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
                        headerLevel = 3
                    subType = self._getAttributeValue(attrs,'subType')
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
                    self._titleWritten = False
                    self._titleText = ''
                    self._readyForSubtitle = False
                    
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
            self._context.unexpectedTag(name)
                
    def _openGroupHtml(self):
        if not self._groupHtmlOpen:
            if self._bibleHtmlOpen:
                # Write out any footnotes in the preceding Bible introduction
                self._footnotes.writeFootnotes()
            groupNumber = self._docStructure.groupNumber
            htmlName = 'group%d' % groupNumber
            self._htmlWriter.open(htmlName)
            self._groupHtmlOpen = True
            self._bookHtmlOpen = False
            if self._groupTitle != '':
                self._htmlWriter.write('<h1>%s</h1>\n' % self._groupTitle)
                
    def _openBookHtml(self):
        if self._groupHtmlOpen or self._bibleHtmlOpen:
            # Write out any footnotes in the Bible or Testament introduction
            self._footnotes.writeFootnotes()

        bookId = self._docStructure.bookId
        self._htmlWriter.open(bookId)
        self._groupHtmlOpen = False
        self._bookHtmlOpen = False
                
    def _writeHtml(self, html):
        self._suppressBreaks = False
        if self._inFootnote and not self._inFootnoteRef:
            self._footnotes.addFootnoteText(html)
        elif self._inTitle:
            self._titleText += html
        elif self._inIntro:
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
            
    def _writeTitle(self):
        if len(self._titleText) > 0:
            origInVerse = self._inVerse
            if self._psDivTitle:
                self._inVerse = False      # causes title to be written before Psalm heading

            self._writeBreak(False)
            self._writeHtml(self._titleTag)
            self._writeHtml(self._titleText)
            closingTag = '</h%s><br />\n' % self._titleTag[2]                    
            self._writeHtml(closingTag)
            self._titleWritten = True
            self._inVerse = origInVerse
        
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
        
    def _endGeneratedPara(self):
        if self._inGeneratedPara:
            self._writeHtml('</p>')
            self._inGeneratedPara = False
               
    def _writeIntroText(self):
        #
        # adjust intro heading for Bible or Testament intro
        if self._bibleHtmlOpen or self._groupHtmlOpen:
            if self._context.config.introInContents:
                if self._groupTitle !='' and self._bibleHtmlOpen:
                    self._introText = re.sub(r'<h[34](.*?) chapter=".+?">(.+?)</h[34]>', r'<h1\1>\2</h1>', self._introText, 1)
                else:
                    self._introText = re.sub(r'<h[34](.*?) chapter=".+?">(.+?)</h[34]>', r'<h2\1>\2</h2>', self._introText, 1)
            else:
                if self._groupTitle !='' and self._bibleHtmlOpen:
                    self._introText = re.sub(r'<h[34](.*?)>(.+?)</h[34]>', r'<h1\1>\2</h1>', self._introText, 1)
                else:
                    self._introText = re.sub(r'<h[34](.*?)>(.+?)</h[34]>', r'<h2\1>\2</h2>', self._introText, 1)              
        self._htmlWriter.write(self._introText)
        
    def _closeParagraph(self):
        if self._inParagraph:
            self._writeHtml('</p>')
            self._inParagraph = False
        else:
            self._endGeneratedPara()
            
    def _handlePsDivHeading(self, text):
        self._psDivTitle = False
        if self._docStructure.bookId == 'Ps' and self._context.config.psalmDivTitle != '':
            if self._context.config.psalmDivSubtitle != ''  and self._psDivTitleFound:
                m = re.match(self._context.config.psalmDivSubtitle, text)
                if m:
                    self._psDivTitle = True
                    self._psDivTitleFound = False
            if not self._psDivTitle:
                m = re.match(self._context.config.psalmDivTitle, text)
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
        if rawText.lower() == self._groupTitle.lower():
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
            if self._firstBook and self._introTextFound:
                # For the first book in a group, anything before this is assumed to be a Bible/testament introduction
                self._closeParagraph()
                self._introText += '\n'
                self._openGroupHtml()
                self._writeIntroText()
                self._groupIntroWritten = True
                self._introText = ''
                self._introTextFound = False
                self._introTitleWritten = False
            #
            # If title is at the start of the intro, it is the book title
            # Do not include this in intro text as book title will be included anyway
            if self._introTextFound:
                self._writeTitle()
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
        
            self._writeTitle()
            
    def _processScriptureTitle(self):
        rawText = re.sub('<.*>', ' ', self._titleText)    
        if rawText == self._bookTitle and not self._bookTitleFound:
            self._bookTitleFound = True
            if self._verseTextFound or not self._firstTitle:
                self._writeTitle()
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
                self._writeTitle()
                
            else:
                # Write any chapter title before this title
                if self._chapterTitle != '':
                    self._writeChapterTitle()
                self._psDivTitleFound = False
                self._writeTitle()   
                self._firstTitle = False
                
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
            self._footnoteNo = self._footnotes.newFootnote(refBook, refVerse)
            self._writeFootnoteRef(refBook, self._footnoteNo)  
        return scriptureFootnote
    
    def _writeFootnoteRef(self, refBook, noteRef):
        if self._context.config.epub3:
            refString = '<sup><a epub:type="noteref" href="#%s%d">[%d]</a></sup>' % (refBook, noteRef, noteRef)
        else:
            refString = '<sup><a href="#%s%d" id="Ref%s%d">[%d]</a></sup>' % (refBook, noteRef, refBook, noteRef, noteRef)
        if self._inChapterTitle:
            self._chFootnoteRef += refString
        else:
            self._writeHtml(refString)
        self._footnoteRefWritten = True
        
    def _writeBookTitle(self):
        self._bookTitle = re.sub(r'(\S)<br />(\S)', r'\1 <br />\2', self._bookTitle)
        self._htmlWriter.write('<h2>%s</h2>' % self._bookTitle)
        self._bookTitleWritten = True
        
    def _startGroup(self, groupNumber):
        self._groupTitle = self._context.config.groupTitle(groupNumber)
        self._groupIntroWritten = False
        self._firstBook = True
        if self._groupTitle != '' and (groupNumber != 1 or not self._context.config.bibleIntro):
            self._openGroupHtml()
            
    def _writeChapterTitleOrNumber(self):
        if self._chapterTitle != '':
            self._writeChapterTitle()
        elif not self._chNumWritten:
            self._writeChapterNumber()
            
    def _startFootnoteAndWriteRef(self, verseRef):
        self._footnoteNo = self._footnotes.newFootnote(self._docStructure.bookId, verseRef)
        self._inFootnoteRef = True
        self._writeFootnoteRef(self._docStructure.bookId, self._footnoteNo)
        self._inFootnoteRef = False
        
    def _handleFootnoteTextInTitle(self, content):
        if not self._footnoteRefWritten:
            verseRef = '%s:%s' % (self._docStructure.chapter, self._docStructure.verse)
            if verseRef == ':':
                # Not in a verse
                verseRef = ''
            self._startFootnoteAndWriteRef(verseRef)
        self._footnotes.addFootnoteText(content)



