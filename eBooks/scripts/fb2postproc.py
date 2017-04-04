#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys, codecs, tempfile, re
import os.path

if __name__ == "__main__":
    
    bookNumber = 1
    inFnSection = False
    fnFound = False
    fnCount = 0
    fnText = []

    print 'Post-processing FB2 output'
    
    # Open the input and output FB2 files  and the CSS file  
    inFile = sys.argv[1]
    fi = codecs.open(inFile, 'r', 'utf-8')
    outFile = sys.argv[2]
    fo = codecs.open(outFile, 'w', 'utf-8')
    cssFile = sys.argv[3]
    cf = None
    if os.path.isfile(cssFile):
        cf = codecs.open(cssFile, 'r', 'utf-8')

    # Process the input file
    for line in fi:
        
        # Check for a style to be applied
        tempLine = re.sub(r'%&amp;(\S+?)&amp;%', r'<style name="\1">', line)
        line = re.sub('%%%', "</style>", tempLine)

        lineOut = ''
    
        if not inFnSection:
            # Handle footnote references
            lineOut = re.sub(r'<sup>\[(\d+)\]</sup>', r'<a xlink:href="#' + str(bookNumber) + r'_\1" type="note">[\1]</a>', line)
            
            # Check for starting footnotes section
            if re.search(r'<p>\[1\]', line) is not None:
                inFnSection = True;
                line = lineOut
                       
        if inFnSection:
            # Handle footnote text        
            match = re.search(r'<p>\[(\d+)\](.*)</p>', line)
            
            if match is not None:
                fnFound = True
            
                # Remove from output text
                lineOut = line.replace(match.group(0),'')
            
                # Process and store
                footnote = '<section id="%d_%s"><title><p>[%s]</p></title><p>%s</p></section>\n' % (bookNumber, match.group(1), match.group(1), match.group(2))
                fnText.append(footnote)
                fnCount += 1
            else:
                lineOut = line
                
            # Check for end of footnotes
            index = line.find('</section>')
            if index != -1:
                inFnSection = False
                bookNumber += 1
                print 'Footnotes found: %d' % fnCount
                fnCount = 0
                
        # Write to output file
        if len(lineOut.strip()) > 0:
            if re.match('</FictionBook>', lineOut) is None:
                fo.write(lineOut)
                
        # If this is the end of the description, copy the stylesheet to the output file
        if re.search('</description>', line) is not None and cssFile is not None:
            fo.write('<stylesheet type="text/css">\n')
            for cssLine in cf:
                if len(cssLine.strip()) > 0:
                    fo.write(cssLine)
            fo.write('</stylesheet>\n')
            cf.close()
            
    # Finished processing input file
    fi.close()
    
    # Write the footnone body to the output file
    if fnFound:
        fo.write('<body name="notes">\n')
        for line in fnText:
            fo.write(line)
        fo.write('</body>\n')
    
    fo.write('</FictionBook>')
    fo.close()

        
        
        
    
    