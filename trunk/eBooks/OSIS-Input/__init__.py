from calibre.customize.conversion import InputFormatPlugin, OptionRecommendation
from calibre_plugins.osis_input.config import ConversionConfig
from calibre_plugins.osis_input.context import ConvertContext
from calibre_plugins.osis_input.writer import HtmlWriter
from calibre_plugins.osis_input.osis import OsisHandler
from xml.sax import make_parser
import shutil
import codecs
import string
import os

class OsisInput(InputFormatPlugin):
    name        = 'OSIS Input'
    author      = 'David Booth'
    description = 'Convert IBT OSIS files to ebooks'
    version = (1, 0, 0)
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
        # Get CSS file, if any
        cssPath = self.opts.css_file
        if cssPath is not '':
            filePos = cssPath.rfind('/') + 1
            if filePos == 0:
                # Maybe this is Windows and backslashes are used
                filePos = cssPath.rfind('\\') + 1
            if filePos != 0:
                # Copy the css file to the current directory
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

        # Prepare to parse the input file
        htmlWriter = HtmlWriter(self.context)
        osisParser = make_parser()
        osisHandler = OsisHandler(htmlWriter, self.context)
        osisParser.setContentHandler(osisHandler)
        osisParser.parse(stream)
        #
        # Report any unexpected tags
        for tag in self.context.unexpectedTags:
            print 'Unexpected tag: <%s>' % tag
        
        # Create the OPF file
        oh = open('content.opf', 'w')
        oh.write('''<?xml version='1.0' encoding='utf-8'?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uuid_id">
  <metadata xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:opf="http://www.idpf.org/2007/opf" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:calibre="http://calibre.kovidgoyal.net/2009/metadata" xmlns:dc="http://purl.org/dc/elements/1.1/">\n''')
        publisher = self.config.publisher
        if publisher == '':
            publisher = 'IBT'
        oh.write('    <dc:publisher>%s</dc:publisher>\n' % publisher)
        if self.context.title != '':
            oh.write('    <dc:title>%s</dc:title>\n' % self.context.title)
        if self.context.lang != '':
            oh.write('    <dc:language>%s</dc:language>\n' % self.context.lang)
        oh.write('''  </metadata>
          
  <manifest>\n''')
        for hf in self.context.htmlFiles:
            oh.write('    <item href="%s.xhtml" id="id%s" media-type="application/xhtml+xml"/>\n' % (hf, hf))
        if self.context.cssFile != '':
            oh.write('    <item href="%s" id="css" media-type="text/css"/>\n' % self.context.cssFile)
        for pf in self.context.imageFiles:
            imageIdEnd = pf.rfind('.') - 1
            imageId = pf[:imageIdEnd]
            oh.write('    <item href="%s" id="img%s" media-type="%s"/>\n' % (pf, imageId, self._getImageMime(pf)))
        oh.write('''  </manifest>
        
  <spine toc="ncx">\n''')
        for hf in self.context.htmlFiles:
            oh.write('    <itemref idref="id%s"/>\n' % hf)
        oh.write('''  </spine>
        
</package>\n''')
        oh.close()
        return os.path.abspath('content.opf')


    def _getImageMime(self, img):
        if img is None or img == '':
            return 'application/octet-stream'
        if img.lower().endswith('jpg') or img.lower().endswith('jpeg') or img.lower().endswith('jpe'):
            return 'image/jpeg'
        if img.lower().endswith('gif'):
            return 'image/gif'
        if img.lower().endswith('png'):
            return 'image/png'
        else:
            return 'application/octet-stream'

    
    
    