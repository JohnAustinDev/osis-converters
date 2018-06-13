#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import sys, codecs, re, os
from encodings.aliases import aliases

def preprocessUSFM(usfm, extension):
    """ Return preprocessed USFM content.

    Keyword arguments:
    usfm -- USFM file content to be preprocessed
    extension -- Extenstion to add to picture file names 
	
    """

    def cvtPreprocess(usfm):
        """Perform preprocessing on a USFM document, returning the processed text as a string.
        Removes excess spaces & CRs.
        Removes $ characters

        Keyword arguments:
        usfm -- The document as a string.

        """

        # lines should never start with non-tags
        usfm = re.sub('\n\s*([^\\\s])', r' \1', usfm)
        # convert CR to LF
        usfm = usfm.replace('\r', '\n')
        # lines should never end with whitespace (other than \n)
        usfm = re.sub('\s+\n', '\n', usfm)
        # $ characters which are line breaks in titles should be removed
        usfm = usfm.replace('$', '')

        return usfm
    
    usfm = cvtPreprocess(usfm)
    
    # replace ~ with soft-hyphen
    usfm = usfm.replace('~', u"\u00AD")
    
    # Find section headings (\s, \s1 or \st) immediately following \c. These  are chhapter titles.
    # For the moment - convert to \sc - the correct tag will be substituted later.
    usfm = re.sub(r'\\c\s(.+)\s*\n\\s[t1]?',r'\\c \1\n\\sc', usfm)
    
    # concatate \s1, \st or \s with preceding \sc
    usfm = re.sub(r'(\n\\sc.*)\n\\s[1t]?(\s+.*)', r' \1\2', usfm)
    
    # convert other \s, \s1 or \st to \s2 
    usfm = re.sub(r'\\s[1t]?\s', r'\\s2 ', usfm)
    
    # convert the \sc placeholders to \s
    usfm = re.sub(r'\\sc ', r'\\s ', usfm)
    
    # convert \c tags to \fig tags
    usfm = re.sub(r'\\c\s+\d+ (\S+)',r'\\c \1', usfm)
    usfm = re.sub(r'\\c\s+(\S+).*\n', lambda m: '\\fig |images/' + m.group(1) +'.' + extension + '|col||||\\fig*\n', usfm)

    # swap with \s or \ms
    usfm = re.sub(r'(\\fig\b.+\\fig\*)[\s\n]+(\\m?s\b.+)', r'\2\n\1' , usfm)
    
    # remove \id
    usfm = re.sub(r'\\id\s.*', '', usfm)
    
    # remove '//'
    usfm = re.sub('//', '', usfm)

    return usfm


def addMaterial(usfm, addFile, prefix):
    """Add extra material to USFM string.
    Returns string including added material

    Keyword arguments:
    usfm -- Input USFM string
    addFile -- Path to file containing additional material
    prefix -- String to substitute for "<prefix>"

    """
    
    addStart = ''
    addBeforeMS = ''
    addEnd = ''    
    
    try:
        print('Adding additional material')

        addMaterial = codecs.open(addFile, 'r', 'utf-8').read().strip() + '\n'
        m = re.search(r'^\[START\](.+?)^\[', addMaterial, re.MULTILINE|re.DOTALL)
        if m:
            addStart = m.group(1)
            addStart = re.sub('<prefix>', prefix, addStart)
            usfm = usfm[1:]
        m = re.search(r'^\[BEFORE_MS\](.+?)^\[', addMaterial, re.MULTILINE|re.DOTALL)
        if m:
            addBeforeMS = m.group(1)
            addBeforeMS = re.sub('<prefix>', prefix, addBeforeMS)    
        m = re.search(r'^\[END\](.+?)\Z', addMaterial, re.MULTILINE|re.DOTALL)
        if m:
            addEnd = m.group(1)
            addEnd = re.sub('<prefix>', prefix, addEnd)
    
    except IOError:
        print('Cannot open file ' + addFile)

    if addBeforeMS:
        m = re.search(r'^\\ms\s', usfm, re.MULTILINE)
        if not m:
            m = re.search(r'^\\s\s', usfm, re.MULTILINE)
    
    if m:
        insertPos = m.start();
        usfm = usfm[:insertPos] + addBeforeMS + '\n' + usfm[insertPos:]
    else:
        addStart = addStart + addBeforeMS	

    usfm = addStart + usfm + addEnd
    
    return usfm
    
    
def printUsage():
    """Prints usage statement."""
    print('preproc.py -- replace \\c UFSM tags in children\'s Bible with appropriate \\fig tags')
    print('                replace ~ with soft hyphens, remove \\id tags,')
    print('                standardise section heading tags')
    print('                and optionally add aditional material to the file')
    print('')
    print('Usage: preproc.py [-a <additions file>] [-l] <input file> <output file> <extension> [<prefix>]')
    print('')
    print('  <input file>) is the input USFM file or, if -l is specified, a file containing a list of USFM files')
    print('  <extension> is the extension to be added to picture file names, e.g. jpg')
    print('  <prefix> is a prefix to be added to additional language specific picture file names')
    print('  <additions file> is a file specifying material to be added at start and/or end')
    print('')
    print('Example: ')
    print('  preproc.py -a SFM_Extras.txt -l S sfm/LEZCB_1.sfm jpg LezCB') 
    


if __name__ == "__main__":
 
    if '-h' in sys.argv or '--help' in sys.argv or len(sys.argv) < 4:
        printUsage()
    else:
        ok = True
        prefix = ''
        addFile = ''
        pos = 1
        inList = False
        usfm = ''
        if '-a' in sys.argv:
            i = sys.argv.index('-a') + 1
            osisFileName = sys.argv[i]	    
            if (i > 2) or (len(sys.argv) < pos + 5):
                printUsage()
                ok = False
            addFile = sys.argv[i]
            pos += 2

        if '-l' in sys.argv:
            inList = True
            if (sys.argv.index('-l') > pos) or (len(sys.argv) < pos + 4):
                printUsage()
                ok = False
            pos += 1

        if ok:

            inFile = sys.argv[pos]
            f = codecs.open(inFile, 'r', 'utf-8')
            if inList:
                # Listed file paths will be relative to list file location
                m = re.search(r'^(.*)[\\/].*$',inFile)
                newloc = m.group(1)
                oldloc = os.getcwd()
                os.chdir(newloc)

                for line in f.readlines():
                    line = line.strip()
                    usfmFile = codecs.open(line, 'r', 'utf-8')
                    usfm += usfmFile.read().strip() + '\n'
                    usfmFile.close()
                    
                os.chdir(oldloc)

            else:
                usfm = f.read().strip() + '\n'
                
            f.close()
    
            if len(sys.argv) > pos + 3:
                prefix = sys.argv[pos + 3]

            usfm = preprocessUSFM(usfm, sys.argv[pos + 2])
            if addFile:
                usfm = addMaterial(usfm, addFile, prefix)
        
            outFile = codecs.open(sys.argv[pos + 1], 'w', 'utf-8')
            outFile.write(usfm)

