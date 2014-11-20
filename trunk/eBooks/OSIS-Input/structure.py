
class DocStructure:
    GROUP = 1
    BOOK = 2
    SECTION = 3
    OTHER = 4
    IGNORED = 0
    ERROR = -1
    
    def __init__(self):     
        self.bookId = ''
        self.chapter = ''
        self.verse = ''
        self.verseRef = None
        self.groupNumber = 0
        self.inGroup = False
        self.inBook = False
        self.divStack =[]
        self.refStack =[]        
        
    def startGroup(self):
        if not self.inGroup:
            self.inGroup = True
            self.groupNumber += 1
            self.divStack.append(self.GROUP)
            self.refStack.append('')
            return True
        else:
            print "Ignoring book group start - already in group"
            self.divStack.append(self.IGNORED)
            self.refStack.append('')            
            return False

    def startBook(self, bookRef):
        if not self.inBook:
            self.inBook = True
            self.divStack.append(self.BOOK)
            self.refStack.append(bookRef)
            self.bookId = bookRef
            return True
        else:
            print "Ignoring %s book start - already in book" % bookRef
            self.divStack.append(self.IGNORED)
            self.refStack.append('')             
            return False
        
    def startSection(self, ref):
        self.divStack.append(self.SECTION)
        self.refStack.append(ref)            
        return True
    
    def otherDiv(self):
        self.divStack.append(self.OTHER)            
        return False
    
    def endDiv(self, ref):
        divType = self.divStack.pop()
        divRef = self.refStack.pop()
        if divType == self.SECTION and ref != divRef:
            print 'Section end mismatch - expected %s, found %s' % (divRef, ref)
            return self.ERROR
        else:
            if divType == self.BOOK:
                self.inBook = False
            elif divType == self.GROUP:
                self.inGroup = False
            return divType
        
    def newChapter(self, chId):
        comp = chId.split('.')
        if comp[0] != self.bookId:
            error = 'Invalid chapter %s in book %s' % (chId, self.bookId)
            raise OsisError(error)
        else:
            self.chapter = comp[1]
            
    def endChapter(self):
        self.chapter = ''
              
    def newVerse(self, vId):
        comp = vId.split('.')
        if comp[0] != self.bookId or comp[1] != self.chapter:
            error = 'Invalid verse %s in %s chapter %s' % (vId, self.bookId, self.chapter)
            raise OsisError(error)
        else:
            self.verse = comp[2]
            self.verseRef = vId
            
    def endVerse(self, vId):
        if vId == self.verseRef:
            self.verse = ''
            self.verseRef = None
        else:
            error = 'Verse end mismatch - expected %s, found %s' % (self.verseRef, vId)
            raise OsisError(error)
        
class OsisError(Exception):
    def __init__(self, value):
        self.value = value
        
    def __str__(self):
        return repr('OSIS file error: '+self.value)
    
