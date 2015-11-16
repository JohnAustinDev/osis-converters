import re
class Footnote:
    
    def __init__(self, ref, verse):
        self.ref = ref
        self.verse = verse
        self.content = ''

        
class BookFootnotes:
        
    def __init__(self, writer, epub3):
        self._writer = writer
        self._epub3 = epub3
        self._footnotes = []
        self._count = 0
        
    def reinit(self):
        del self._footnotes[:]
        self._count = 0
            
    def newFootnote(self, book, verse):
        self._count+= 1
        noteRef = '%s%d' % (book, self._count)
        self._footnotes.append(Footnote(noteRef, verse))
        return self._count
        
    def addFootnoteText(self, text):
        # Deal with verse numbers supplied as "[nn]"
        text = re.sub(r'\[([0-9]+)\]\s*', r'<sup>\1</sup>', text)
        self._footnotes[self._count-1].content += text
        
    def changeVerseId(self, vId):
        self._footnotes[self._count-1].verse = vId
        
    def writeFootnotes(self):
        count = 0
        if self._count > 0:
            self._writer.write('<hr></hr>\n')
        for note in self._footnotes:
            count += 1
            if self._epub3:
                self._writer.write('<aside epub:type="footnote" id="%s">\n' % note.ref)
                if note.verse == '':
                    self._writer.write('<p class="x-indent-0">[%d] %s</p>\n' % (count, note.content))
                else:
                    self._writer.write('<p class="x-indent-0">[%d] %s - %s</p>\n' % (count, note.verse, note.content))
                self._writer.write('</aside>\n')
            else:
                if note.verse == '':
                    self._writer.write('<p class="x-indent-0" id="%s"><a href="#Ref%s">[%d]</a> %s</p>\n' % (note.ref, note.ref, count, note.content))                    
                else:
                    self._writer.write('<p class="x-indent-0" id="%s">[%d] <a href="#Ref%s">%s</a> - %s</p>\n' % (note.ref, count, note.ref, note.verse, note.content))
        self.reinit()