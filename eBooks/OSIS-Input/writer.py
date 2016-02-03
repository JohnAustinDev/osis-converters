import codecs

class HtmlWriter:

    def __init__(self, context):
        self._fh = None
        self._context = context
        
    def open(self, name):
        if self._fh is not None:
            self.close()
        filename = name.lower()
        self._fh = codecs.open(filename+'.xhtml', 'w', 'utf-8')
        self._writeHeader(name)
        self._context.htmlFiles.append(filename)
        
    def isOpen(self):
        return(self._fh is not None)
            
    def write(self, str):
        if self._fh is None:
            try:
                print 'cannot write %s - no HTML file open' % str
            except:
                print 'cannot write text - no HTML file open'
        else:
            self._fh.write(str)
    
    def close(self):
        self._writeFooter()
        self._fh.close()
        self._fh = None
          
    def _writeHeader(self, title):
        epubString = ''
        if self._context.config.epub3:
            epubString = 'xmlns:epub="http://www.idpf.org/2007/ops"'
        self._fh.write('''<?xml version='1.0' encoding='utf-8'?>
<html xmlns="http://www.w3.org/1999/xhtml" %s>
  <head>
    <meta name="generator" content="OSIS"/>
    <title>%s</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>\n''' % (epubString,title))
        if self._context.cssFile != '':
            self._fh.write('    <link href="%s" type="text/css" rel="stylesheet"/>\n' % self._context.cssFile)
        self._fh.write('''  </head>
  <body class="calibre">\n''')
            
    def _writeFooter(self):
            self._fh.write('''
  </body>
</html>\n''')
