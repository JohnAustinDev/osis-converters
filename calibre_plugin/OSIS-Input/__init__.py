from calibre.customize.conversion import InputFormatPlugin, OptionRecommendation
import subprocess
import re
import shutil
import glob
import codecs
import os

class OsisInput(InputFormatPlugin):
    name        = 'OSIS Input'
    author      = 'David Booth'
    description = 'Convert IBT OSIS xml files to epub'
    version = (5, 0, 0)
    minimum_calibre_version = (1,38, 0)
    file_types = set(['xml'])
    supported_platforms = ['linux']

    def convert(self, stream, options, file_ext, log, accelerators):
            
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
            
        # Copy osis2xhtml.xsl
        shutil.copy(inputDir + "/osis2xhtml.xsl", '.')
        shutil.copy(inputDir + "/functions.xsl", '.')
            
        # Transform the OSIS files to XHTML
        command = ["saxonb-xslt", 
            "-ext:on", 
            "-xsl:osis2xhtml.xsl", 
            "-s:%s" % inputOSIS, 
            "-o:content.opf", 
            "css=%s" % (",").join(sorted(cssFileNames))
        ]
        print("Running XSLT: " + " ".join(command))
        p = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8')
        if p.returncode != 0:
            print("ERROR: XSLT failed!:")
        print(p.stdout)
        
        return os.path.abspath('content.opf')
        
