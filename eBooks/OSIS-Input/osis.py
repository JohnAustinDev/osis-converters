from xml.sax import handler
from calibre_plugins.osis_input.structure import DocStructure, OsisError
from calibre_plugins.osis_input.footnote import BookFootnotes
import shutil
import re

class OsisHandler(handler.ContentHandler):
    def __init__(self, htmlWriter, context):
        self._breakCount = 0                        # Used to prevent too many succeive line breaks
        self._context = context
        self._defaultHeaderLevel = 1
        self._figHtml = ''                          # Html generated for a figure
        self._headerProcessed = False               # OSIS header has been fully processed
        self._hiHtmlTag = ['','','']                # Records tags used for up to 3 levels of nested <hi> tags
        self._hiLevel = 0                           # Number of currently nested <hi> tags
        self._htmlWriter = htmlWriter
        self._ignoreTitle = False                   # Title currently being processed should be ignored
        self._inCaption = False                     # Currently processing a figure caption
        self._ignoreText = False                    # Text encountered should currently be ignored
        self._inFootnote = False                    # Currently processing a footnote
        self._inGeneratedPara = False               # Currently within an html paragraph which does not correspond to an OSIS paragraph 
        self._inGlossaryRef = False                 # Currently processing a reference to a glossary entry
        self._inHeader = False                      # Currently processing OSIS header
        self._inParagraph = False                   # Currently within an html paragraph which corresponds to an OSIS paragraph
        self._inTable = False                       # Currently processing contents of a table
        self._inTitle = False                       # Currently processing a title
        self._inWork = False                        # Currently within a <work> tag
        self._lineGroupPara = False                 # A <div> tag has been written for the current line group
        self._osisFound = False                     # The <osis> tag has been found
        self._osisIDWork = None                     # Value of osisIDwork attribute in <osisText> tag
        self._osisTextFound = False                 # The <osisText> tag has been found
        self._suppressBreaks = False                # Set to prevent <br /> tags being written
        self._titleTag = ''                         # Opening tag html for title currently being processed
        self._titleText = ''                        # Text of title currently being processed
        self._writingFootnoteMarker = False         # Currently writing marker for a footnote
        self._workId = ''                           # Value of osisWork attribute in <work> tag
        self._footnotes = BookFootnotes(htmlWriter, self._context.config.epub3)
        
    def startDocument(self):
        self._breakCount = 0
        self._figHtml = ''
        self._firstBook = True
        self._headerProcessed = False
        self._hiHtmlTag = ['','','']
        self._hiLevel = 0
        self._inCaption = False
        self._ignoreText = False
        self._inFootnote = False
        self._inGeneratedPara = False
        self._inGlossaryRef = False
        self._inHeader = False
        self._inParagraph = False
        self._inTable = False
        self._inTitle = False
        self._inWork = False
        self._lineGroupPara = False
        self._osisFound = False
        self._osisTextFound = False
        self._suppressBreaks = False
        self._titleText = ''
  
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
            self._workId = self._getAttributeValue(attrs, 'osisWork')
            if self._workId is not None:
                self._inWork = True
        elif self._inWork:
            if self._workId == self._osisIDWork:
                if name == 'title':
                    self._inTitle = True
            else:
                if name == 'type':
                    workType = self._getAttributeValue(attrs, 'type')
                    if workType == 'x-glossary':
                        self._context.glossaries.append(self._workId)
                        
                
    def endElement(self, name):
        if name == 'caption':
            if self._inCaption:
                self._inCaption = False
                self._figHtml += '</figcaption>\n'
                
        elif name == 'catchWord':
            self._writeHtml('</i>')
            
        elif name == 'cell':
            self._writeHtml('</td>')
                               
        elif name == 'figure':
            self._figHtml += '</figure>\n'
            self._writeHtml(self._figHtml)
            self._figHtml = ''
                    
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
            if self._inGlossaryRef:
                if self._context.outputFmt == 'fb2':
                    # For FB2, <span> not effective, so use markers to be picked up by postprocessor
                    self._writeHtml('%%%')
                else:
                    self._writeHtml('</span>')
                self._inGlossaryRef = False
            elif self._figHtml != '':
                self._ignoreText = False
                
        elif name == 'row':
            self._writeHtml('</tr>\n')
            
        elif name == 'title':
            if self._inTitle:
                self._inTitle = False
                if self._ignoreTitle:
                    self._ignoreTitle = False
                elif self._headerProcessed:
                    self._writeTitle()

        elif name == 'table':
            self._writeHtml('</table>\n')
            self._inTable = False

        elif name == 'transChange':
            self._writeHtml('</span>')
            
        elif name == 'work':
            self._inWork = False

    def characters(self, content):
        # This is default handling, which will usually be overridden
        text = content.strip()
        if self._headerProcessed and len(text) > 0:
            self._checkGeneratePara()
            self._writeHtml(content)      

    def _getAttributeValue(self, attrs, attrName):
        for (name, value) in attrs.items():
            if name == attrName:
                return value
        return None
    
    def _processBodyTag(self, name, attrs):
        if name == 'caption':
            if self._figHtml != '':
                self._figHtml += '<figcaption>'
                self._inCaption = True
            else:
                print 'Caption not associated with a figure'

        elif name == 'catchWord':
            self._writeHtml('<i>')
            
        elif name == 'cell':
            self._writeHtml('<td>')

        elif name == 'figure':
            source = self._getAttributeValue(attrs, 'src')
            
            # Assume that a TIFF input file has been converted to JPG
            source = source.replace('.tiff', '.jpg')
            source = source.replace('.tif', '.jpg')
            
            # Copy the image file to the current directory
            fullFileSpec = self._context.config.imgFileDir + '/' + source
            shutil.copy(fullFileSpec, '.')
            
            # Set up the html
            self._figHtml = '<figure>\n<img src="%s" />\n' % source
            
            # Add the image file to the list
            if source not in self._context.imageFiles:
                self._context.imageFiles.append(source)
            
                    
        elif name == 'foreign':
            self._writeHtml('<span class="foreign">')
            
        elif name == 'head':
            self._writeHtml('<div class="heading">')         
                
        elif name == 'hi':
            self._handleHi(attrs)
            
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
            htmlTag = self._lineHtml(attrs)
            self._writeHtml(htmlTag)
            
        elif name == 'lg':
            if not self._inParagraph and not self._inGeneratedPara:
                self._writeHtml('<div>')
                self._lineGroupPara = True
            else:
                self._writeBreak(True)
            
        elif name == 'list':
            listType = self._getAttributeValue(attrs, 'subType')
            if listType is None:
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
                self._startFootnote(attrs)
            else:
                # Ignore other types of note (generally cross-references)
                self._ignoreText = True
            
        elif name == 'p':
            self._endGeneratedPara()
            paraTag = self._generateParaTag(attrs)
            self._inParagraph = True
            self._writeHtml(paraTag)

        elif name == 'reference':
            self._processReference(attrs)
                 
        elif name == 'row':
            self._writeHtml('<tr>')
                    
        elif name == 'seg':
            # <seg> tags are normally ignored (may be overridden in subclass)
            pass
        
        elif name == 'table':
            self._writeHtml('<table>\n')
            self._inTable = True
        
        elif name == 'title':
            if titleType == 'runningHead':
                self._inTitle = True
                self._ignoreTitle = True
            else:
                level = self._getAttributeValue(attrs,'level')
                if level is not None:
                    headerLevel = level
                else:
                    headerLevel = self._defaultHeaderLevel
                subType = self._getAttributeValue(attrs,'subType')
                if subType is not None:
                    self._titleTag = '<h%d class="%s">' % (headerLevel, subType)
                else:
                    self._titleTag = '<h%d>' % (headerLevel)
                self._inTitle = True
                self._titleText = ''
   
        elif name == 'transChange':
            self._writeHtml('<span class="transChange">')
                    
        else:
            self._context.unexpectedTag(name)

    def _writeHtml(self, html):
        self._suppressBreaks = False
        if self._inFootnote and not self._writingFootnoteMarker:
            self._footnotes.addFootnoteText(html)
        elif self._inTitle:
            self._titleText += html
        elif self._inCaption:
            self._figHtml += html
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
            self._writeBreak(False)
            self._writeHtml(self._titleTag)
            self._writeHtml(self._titleText)
            closingTag = '</h%s><br />\n' % self._titleTag[2]                    
            self._writeHtml(closingTag)
            self._suppressBreaks = True
            self._breakCount = 2
            return True
        else:
            return False
      
    def _startGeneratedPara(self):
        print 'Generating para'
        paraTag = '<p class="x-indent-0">'
        self._writeHtml(paraTag)
        self._inGeneratedPara = True
        
    def _endGeneratedPara(self):
        if self._inGeneratedPara:
            self._writeHtml('</p>')
            self._inGeneratedPara = False
                   
    def _closeParagraph(self):
        if self._inParagraph:
            self._writeHtml('</p>')
            self._inParagraph = False
        else:
            self._endGeneratedPara()
            
    def _footnoteMarker(self, refBook, noteRef):
        if self._context.config.epub3:
            refString = '<sup><a epub:type="noteref" href="#%s%d">[%d]</a></sup>' % (refBook, noteRef, noteRef)
        else:
            refString = '<sup><a href="#%s%d" id="Ref%s%d">[%d]</a></sup>' % (refBook, noteRef, refBook, noteRef, noteRef)
        return refString
   
    def _writeFootnoteMarker(self, refBook, noteRef):
        self._writingFootnoteMarker = True
        refString = self._footnoteMarker(refBook, noteRef)
        self._writeHtml(refString)
        self._writingFootnoteMarker = False
        
    def _lineHtml(self, attrs):
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
        return htmlTag
    
    def _startFootnote(self, attrs):
        # attrs not used here but may be used in overiding function
        footnoteNo = self._footnotes.newFootnote(self._osisIDWork, '')
        self._writeFootnoteMarker(self._osisIDWork, footnoteNo)
        self._inFootnote = True
        
    def _generateParaTag(self, attrs, overrideSubType = None):
        pClass = ''
        subClass = ''
        pType = self._getAttributeValue(attrs, 'type')
        if pType is not None:
            pClass = pType
        subType = overrideSubType
        if subType is None:
            subType = self._getAttributeValue(attrs, 'subType')
        if subType is not None:
            subClass = subType
        if pClass != '':
            pClass = subClass
        elif subClass != '':
            pClass += ' '
            pClass += subClass
        paraTag = '<p>'
        if pClass != '':
            paraTag = '<p class="%s">' % pClass
        return paraTag
    
    def _handleHi(self, attrs):
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
                self._writeHtml(html)
        else:
            self._hiHtmlTag[self._hiLevel] = ''
        self._hiLevel += 1
        
    def _processReference(self,attrs):
        # reference tags are expected but are ignored
        # apart from glossary references 
        refType = self._getAttributeValue(attrs, 'type')
        if refType == "x-glossary" or refType == "x-glosslink":
            html = '<span class="x-glossary-link">'
            if self._context.outputFmt == 'fb2':
                # This will be lost in conversion to FB2,
                # so instead use marker which will be picked up by FB2 post-processor
                html = '%&x-glossary-link&%'
            self._writeHtml(html)
            self._inGlossaryRef = True
        elif self._figHtml != '':
            self._ignoreText = True
            
    def _checkGeneratePara(self):
        if not self._inParagraph and not self._inTitle and not self._inGeneratedPara and not self._inCaption and not self._lineGroupPara and not self._inTable and not self._inFootnote:
            self._startGeneratedPara()

 
 




