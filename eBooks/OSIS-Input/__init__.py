from calibre.customize.conversion import InputFormatPlugin, OptionRecommendation
from calibre_plugins.osis_input.config import ConversionConfig
from calibre_plugins.osis_input.context import ConvertContext
from calibre_plugins.osis_input.writer import HtmlWriter
from calibre_plugins.osis_input.bible import BibleHandler
from calibre_plugins.osis_input.glossary import GlossaryHandler
from xml.sax import make_parser
import shutil
import glob
import codecs
import string
import os
from subprocess import Popen, PIPE
from lxml import etree
from os import walk

class OsisInput(InputFormatPlugin):
    name        = 'OSIS Input'
    author      = 'David Booth'
    description = 'Convert IBT OSIS files to ebooks'
    version = (2, 3, 0)
    minimum_calibre_version = (1,38, 0)
    file_types = set(['xml'])
    supported_platforms = ['windows', 'linux']

    options = set([
    OptionRecommendation(name='config_file', recommended_value='convert.txt',
            help=_('Config file containing Bible book names etc.')),
        OptionRecommendation(name='css_file', recommended_value='',
            help=_('Cascading style sheet file')),
        OptionRecommendation(name='output_fmt', recommended_value='epub',
            help=_('Output file format'))
    ])

    def convert(self, stream, options, file_ext, log, accelerators):
        #
        # Get config
        self.opts = options
        self.config = ConversionConfig(self.opts.config_file)
        self.context = ConvertContext(self.config)
        self.context.outputFmt = self.opts.output_fmt
        #
        # EPUB3 only relevant for epub
        if self.context.outputFmt != 'epub':
            self.config.epub3 = False
        #
        # Get CSS file, if any
        fontFiles = []
        cssPath = self.opts.css_file
        if cssPath is not '':
            filePos = cssPath.rfind('/') + 1
            if filePos == 0:
                # Maybe this is Windows and backslashes are used
                filePos = cssPath.rfind('\\') + 1
            if filePos != 0:
                # If it's in a css directory, copy everything there to the current directory, to get fonts etc.
                if cssPath.endswith('/css/', 0, filePos):
                    for cssDirFile in glob.glob('%s*' % cssPath[:filePos]):
                        print 'Copying css directory file: %s' % cssDirFile
                        shutil.copy(cssDirFile, '.')
                        if not cssDirFile.endswith('.css'):
                            dirFilePos = cssDirFile.rfind('/') + 1
                            fileName = cssDirFile[dirFilePos:]
                            fontFiles.append(fileName)
                # Otherwise copy the css file to the current directory
                else:
                    print 'Copying css file: %s' % cssPath
                    shutil.copy(cssPath, '.')
                self.context.cssFile = cssPath[filePos:]  
            #
            # Check CSS file definitions 
            cfile = codecs.open(self.context.cssFile, 'r', encoding="utf-8")
            css = cfile.read()
            #
            # Check for definition of the x-chapter-number class
            searchRes = string.find(css, '.x-chapter-number')
            if searchRes != -1:
                self.context.chNumClassDefined = True
            #
            # Check for definition of the of the canonical class
            searchRes = string.find(css, '.canonical')
            if searchRes != -1:
                self.context.canonicalClassDefined = True
            cfile.close()
            
        # Get the directory of the OSIS file
        filePath = stream.name
        filePos = filePath.rfind('/')
        inputDir = filePath[:filePos]
        
        # copy images
        for afile in glob.glob("%s/images/*.*" % inputDir):
            if not os.path.exists('./images'):
                os.makedirs('./images')                                                                                                                                 
            shutil.copy(afile, './images')
            
        # Transform the input OSIS files to XHTML
        for afile in glob.glob("%s/*.xml" % inputDir):                                                                                                                                   
            shutil.copy(afile, '.')
        with open("./osis2xhtml.xsl", "w") as text_file:
          text_file.write(get_resources('osis2xhtml.xsl'))
        p = Popen(["saxonb-xslt", "-ext:on", "-xsl:osis2xhtml.xsl", "-s:%s" % stream.name, "-o:content.opf", "tocnumber=%s" % self.context.config.toc, "optionalBreaks='false'", "epub3='%s'" % self.context.config.epub3, "outputfmt='%s'" % self.context.outputFmt], stdin=None, stdout=PIPE, stderr=PIPE)
        output, err = p.communicate()
        if p.returncode != 0:
            print "ERROR: XSLT failed with output=%s, error=%s, return=%s" % (output, err, p.returncode)
        os.remove('osis2xhtml.xsl')
        for afile in glob.glob("./*.xml"):                                                                                                                                   
            os.remove(afile)
            
        parser = etree.XMLParser(remove_blank_text=True)
        
        # Add file names to href attributes, since XSLT cannot easily predict these during transformation
        xhtml = {}
        allID = {}
        # open all xhtml documents and save file->target information
        for dirpath, dirnames, filenames in walk('./xhtml'):
            for somexhtml in filenames:
                xhtml[somexhtml] = etree.parse("./xhtml/%s" % somexhtml, parser)
                ids = xhtml[somexhtml].xpath("//@id")
                for someID in ids:
                    allID[someID] = somexhtml
        # search each xhtml document for hrefs pointing to other files, and prepend the file to those href values
        for somexhtml in xhtml:
            for elem in xhtml[somexhtml].xpath("//*[@href]"):
                foundID = '';
                s = elem.attrib['href'].split('#')
                if len(s) > 1:
                    if s[1] in allID:
                        foundID = s[1]
                    else:
                        for someID in allID:
                            if someID.startswith(s[1] + '.'):
                                foundID = someID
                                break
                    if not foundID:
                        print "ERROR: href '%s' of '%s' does not exist!" % (unicode(elem.attrib['href']).encode('utf8'), somexhtml)
                    elif (allID[foundID] != somexhtml):
                        elem.attrib['href'] = './' + allID[foundID] + '#' + foundID
        # save each xhtml document
        for somexhtml in xhtml:
            xhtmlfile = open("./xhtml/%s" % somexhtml, "w")
            xhtmlfile.write(etree.tostring(xhtml[somexhtml], encoding='utf-8', pretty_print=True))
                    
        # Add files which are not discoverable in the OSIS file to the manifest
        contentopf = etree.parse('content.opf', parser)
        namespace = {'opf': 'http://www.idpf.org/2007/opf'}
        manifest = contentopf.xpath("opf:manifest", namespaces=namespace)[0]
        for dirpath, dirnames, filenames in walk('.'):
            for name in filenames:
                if not contentopf.xpath("//opf:manifest/opf:item[@href='%s']" % name, namespaces=namespace):
                    ext = os.path.splitext(name)[1].lower()
                    elem = 'none'
                    if ext == '.css':
                        elem = etree.fromstring('<item href="%s" id="css" media-type="text/css"/>' % name)
                    elif ext == '.ttf':
                        elem = etree.fromstring('<item href="./%s" id="font_%s" media-type="application/x-font-ttf"/>' % (name, name))
                    elif ext == '.otf':
                        elem = etree.fromstring('<item href="./%s" id="font%s" media-type="application/vnd.ms-opentype"/>' % (name, name))
                    if elem != 'none':
                        print "Adding file %s to content.opf" % name
                        manifest.append(elem)
        opffile = open('content.opf', "w")
        opffile.write(etree.tostring(contentopf, encoding='utf-8', pretty_print=True))
        
        return os.path.abspath('content.opf')



    
    
    
