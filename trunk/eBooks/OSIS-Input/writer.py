
class HtmlWriter:

    def __init__(self, context):
        self._fh = None
        self._context = context
        
    def open(self, name):
        if self._fh is not None:
            self.close()
        filename = name.lower()
        self._fh = open(filename+'.xhtml', 'w')
        self._writeHeader(name)
        self._context.htmlFiles.append(filename)
            
    def write(self, str):
        if self._fh is None:
            print 'cannot write %s - no HTML file open' % str
        else:
            self._fh.write(str)
    
    def close(self):
        self._writeFooter()
        self._fh.close()
        self._fh = None
          
    def _writeHeader(self, title):
        self._fh.write('''<?xml version='1.0' encoding='utf-8'?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta name="generator" content="OSIS"/>
    <title>%s</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>\n''' % title)
        if self._context.cssFile != '':
            self._fh.write('    <link href="%s" type="text/css" rel="stylesheet"/>\n' % self._context.cssFile)
        self._fh.write('''  </head>
  <body class="calibre">\n''')
            
    def _writeFooter(self):
            self._fh.write('''
  </body>
</html>\n''')