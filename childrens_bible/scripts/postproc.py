#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import sys, codecs, re, os
from encodings.aliases import aliases

def processOSIS(osis):
    """ Return processed OSIS content.

    Keyword arguments:
    osis -- OSIS file content to be processed
	
    """

     
    # remove ... where appearing in a chapter osisID
    osis = re.sub(r'div type="chapter" osisID="(.*?)\.{2,}(.*)">', r'div type="chapter" osisID="\1\2">', osis)
    
    # remove unwanted references tags
    # (the required reference tags will be added by addScriptRefLinks)
    osis = re.sub(r'<reference type="parallel">(.*?)</reference>', r'\1', osis)
   
    # Deal with reference titles
    osis = re.sub(r'<title type="parallel">(.*?)</title>',
                  r'<title type="parallel" level="2" subType="x-right"><hi type="italic" subType="x-ref-cb">\1</hi></title>',
                  osis)

    # Deal with images
    osis = re.sub(r'<figure src="images/(\d{3})\.(\w+)" size="col">',
                  r'<figure subType="x-text-image" src="images/\1.\2">',
                  osis)

    # Deal with initial paragraphs of chapters
    osis = re.sub(r'<div type="chapter" (.*?)><title>(.*?)</title>(\s*)<figure (.*?)>(\s*)</figure>(\s*)<p(.*?)>',
                  r'<div type="chapter" \1><title>\2</title>\3<figure \4>\5</figure>\6<p\7 subType="x-p-first">',
                  osis)
     
    # Deal with initial line groups of chapters
    osis = re.sub(r'<div type="chapter" (.*?)><title>(.*?)</title>(\s*)<figure (.*?)>(\s*)</figure>(\s*)<lg>',
                  r'<div type="chapter" \1><title>\2</title>\3<figure \4>\5</figure>\6<lg subType="x-p-first">',
                  osis)
    
    # Remove Section divs
    osis = re.sub(r'<div type="Section">(.*?)</div>', r'\1', osis, 0, re.DOTALL)
    
    # Make line groups indented <l level="1">
    osis = re.sub(r'<l level="1">',
                  r'<l level="1" type="x-indent">',
                  osis)
                
    # Remove soft-hyphens from chapter names (osisIDs)
    osis = re.sub(r'(<div [^>]*osisID=")(.*?)(">)', lambda match: match.group(1) + match.group(2).replace(u"\u00AD", '') + match.group(3), osis)

    return osis


def printUsage():
    """Prints usage statement."""
    print('postproc.py -- add OSIS sub-types for correct formatting of children\'s Bible ')
    print('')
    print('Usage: postproc.py <input file> <output file>')
    print('')
    print('  <input file> is the input OSIS file')
    print('  <output file> is the processed OSIS file')
    print('')
    print('Example: ')
    print('  postproc.py sfm/LEZCB_1.xml sfm/LEZCB.xml') 
    


if __name__ == "__main__":
 
    if '-h' in sys.argv or '--help' in sys.argv or len(sys.argv) < 3:
        printUsage()
    else:
        osis = ''

        inFile = sys.argv[1]
        f = codecs.open(inFile, 'r', 'utf-8')
        osis = f.read().strip() + '\n'
                
        f.close()

        osis = processOSIS(osis)
        
        outFile = codecs.open(sys.argv[2], 'w', 'utf-8')
        outFile.write(osis)

