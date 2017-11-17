from calibre.customize.conversion import InputFormatPlugin, OptionRecommendation
from subprocess import Popen, PIPE
import re
import shutil
import glob
import codecs
import os

class OsisInput(InputFormatPlugin):
    name        = 'OSIS Input'
    author      = 'David Booth'
    description = 'Convert IBT OSIS xml files to epub'
    version = (3, 1, 0)
    minimum_calibre_version = (1,38, 0)
    file_types = set(['xml'])
    supported_platforms = ['linux']

    options = set([
    OptionRecommendation(name='config_file', recommended_value='convert.txt', help=_('Config file'))
    ])

    def convert(self, stream, options, file_ext, log, accelerators):
        
        # Read convert.txt
        cfile = codecs.open(options.config_file, 'r', encoding="utf-8")  
        config = cfile.read().strip()
        config = re.sub(r"#.*", "", config)
        
        # TOC - a number from 1 to 3 selecting \toc1, \toc2 or \toc3 USFM tags to use creating the eBook TOC
        TOC = 2
        m = re.search(r"^\s*TOC=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            TOC = m.group(1).strip()
            
        # NoEpub3Markup - true means don't use epub3 markup
        NoEpub3Markup = 'false'
        m = re.search(r"^\s*NoEpub3Markup=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            NoEpub3Markup = m.group(1).strip()
            
        # BrokenLinkURL
        BrokenLinkURL = 'none'
        m = re.search(r"^\s*BrokenLinkURL=(.+)", config, re.MULTILINE|re.IGNORECASE)
        if m:
            BrokenLinkURL = m.group(1).strip()
            
        # Get the directory of our input files
        filePath = stream.name
        filePos = filePath.rfind('/')
        inputDir = filePath[:filePos]
        inputOSIS = filePath[(filePos+1):]
        
        # Copy css
        cssFileNames = []
        for afile in glob.glob("%s/css/*" % inputDir):
            shutil.copy(afile, '.')                                                                                                                              
            cssFileNames.append(os.path.basename(afile))
            
        # Copy images
        for afile in glob.glob("%s/images/*.*" % inputDir):
            if not os.path.exists('./images'):
                os.makedirs('./images')                                                                                                                                 
            shutil.copy(afile, './images')
            
        # Copy OSIS files
        for afile in glob.glob("%s/*.xml" % inputDir):                                                                                                                                   
            shutil.copy(afile, '.')
            
        # Transform the OSIS files to XHTML
        with open("./osis2xhtml.xsl", "w") as text_file:
          text_file.write(get_resources('osis2xhtml.xsl'))
        command = ["saxonb-xslt", 
            "-ext:on", 
            "-xsl:osis2xhtml.xsl", 
            "-s:%s" % inputOSIS, 
            "-o:content.opf", 
            "css=%s" % (",").join(sorted(cssFileNames)), 
            "tocnumber=%s" % TOC,
            "epub3=%s" % ('false' if NoEpub3Markup == 'true' else 'true'),
            "brokenLinkURL=%s" % BrokenLinkURL
        ]
        print "Running XSLT: " + unicode(command).encode('utf8')
        p = Popen(command, stdin=None, stdout=PIPE, stderr=PIPE)
        output, err = p.communicate()
        if p.returncode != 0:
            print "ERROR: XSLT failed with output=%s, error=%s, return=%s" % (output, err, p.returncode)
        os.remove('osis2xhtml.xsl')
        for afile in glob.glob("./*.xml"):                                                                                                                                   
            os.remove(afile)
        
        return os.path.abspath('content.opf')
        
